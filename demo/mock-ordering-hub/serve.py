#!/usr/bin/env python3
"""
Mock Ordering Hub server — static files + three-table cell-state API.

State model (PostgreSQL database `mock_hub`, isolated from the pipeline demo DB):

    draft_cells         written on EVERY grid edit commit (blur/Enter), before
                        any submit — the persistent pending-changes queue, so
                        typed edits survive a page refresh (matches the real
                        portal's behaviour). Cleared per-cell by submit, wholly
                        by Revert All, and swept of expired rows by the rollover.
    uncommitted_cells   written ONLY when the green submit button completes.
    committed_cells     written ONLY by the daily noon rollover: every day
                        after NOON_HOUR the committed boundary advances one
                        day, sweeping due uncommitted rows (their S.O./ADJ/F.O.
                        snapshot) into this table.

Each uncommitted row carries `lock_after` (computed by the frontend from the
product's lead time): the first date whose noon capture locks that cell. The
rollover moves every row with lock_after <= today.

A single-row `hub_session` table replicates the real portal's server-held
selection: the current store and (absolute) week number persist across page
refreshes, and the week stays sticky across store switches — the same
global/sticky paginator characteristic the real scraper has to handle.

    python demo/mock-ordering-hub/serve.py            # http://127.0.0.1:8099
    python demo/mock-ordering-hub/serve.py --capture-now   # run a rollover at boot

API (all JSON):
    GET  /api/state              -> {version, committed: [...], uncommitted: [...], drafts: [...]}
    GET  /api/version            -> {version}
    GET  /api/events?limit=100   -> {events: [...]}  (append-only audit trail)
    GET  /api/session            -> {store, week} (server-held selection, sticky)
    POST /api/session            -> {store?, week?} partial upsert of the selection
    POST /api/draft              -> {cells: [...]} upsert into draft_cells (per grid edit)
    POST /api/revert             -> delete ALL draft rows (Revert All Changes)
    POST /api/submit             -> {cells: [...]} upsert into uncommitted_cells
    POST /api/capture            -> manually trigger the noon rollover

Everything served here is fictional and local. No credentials, no live systems.
"""
import argparse
import datetime
import json
import os
import threading
import time
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

import psycopg2
import psycopg2.extras

HERE = os.path.dirname(os.path.abspath(__file__))
DB_URL = os.environ.get('MOCK_HUB_DB_URL',
                        'postgresql://postgres:8989@127.0.0.1:5432/mock_hub')
NOON_HOUR = int(os.environ.get('MOCK_HUB_CAPTURE_HOUR', '12'))

SCHEMA = """
CREATE TABLE IF NOT EXISTS committed_cells (
    id           SERIAL PRIMARY KEY,
    store_id     TEXT NOT NULL,
    product_id   TEXT NOT NULL,
    cell_date    DATE NOT NULL,
    so           INT  NOT NULL DEFAULT 0,
    adj          INT  NOT NULL DEFAULT 0,
    fo           INT  NOT NULL DEFAULT 0,
    source       TEXT,
    committed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (store_id, product_id, cell_date)
);
CREATE TABLE IF NOT EXISTS uncommitted_cells (
    id           SERIAL PRIMARY KEY,
    store_id     TEXT NOT NULL,
    product_id   TEXT NOT NULL,
    cell_date    DATE NOT NULL,
    so           INT  NOT NULL DEFAULT 0,
    adj          INT  NOT NULL DEFAULT 0,
    fo           INT  NOT NULL DEFAULT 0,
    lock_after   DATE NOT NULL,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (store_id, product_id, cell_date)
);
CREATE TABLE IF NOT EXISTS draft_cells (
    id           SERIAL PRIMARY KEY,
    store_id     TEXT NOT NULL,
    product_id   TEXT NOT NULL,
    cell_date    DATE NOT NULL,
    so           INT  NOT NULL DEFAULT 0,
    adj          INT  NOT NULL DEFAULT 0,
    fo           INT  NOT NULL DEFAULT 0,
    lock_after   DATE NOT NULL,
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (store_id, product_id, cell_date)
);
CREATE TABLE IF NOT EXISTS hub_session (
    id          INT PRIMARY KEY CHECK (id = 1),
    store_id    TEXT,
    week_number INT,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS cell_events (
    id         SERIAL PRIMARY KEY,
    store_id   TEXT,
    product_id TEXT,
    cell_date  DATE,
    action     TEXT NOT NULL,
    old_adj    INT,
    new_adj    INT,
    fo         INT,
    source     TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
"""


def db():
    return psycopg2.connect(DB_URL)


def init_schema():
    with db() as conn, conn.cursor() as cur:
        cur.execute(SCHEMA)
        # One-time migration from the old single-table layout: committed rows
        # move to committed_cells, then the old table is dropped.
        cur.execute("SELECT to_regclass('cell_states')")
        if cur.fetchone()[0]:
            cur.execute("""
                INSERT INTO committed_cells (store_id, product_id, cell_date, so, adj, fo, source, committed_at)
                SELECT store_id, product_id, cell_date, so, adj, fo,
                       COALESCE(source, 'migrated'), COALESCE(committed_at, now())
                FROM cell_states WHERE status = 'committed'
                ON CONFLICT (store_id, product_id, cell_date) DO NOTHING
            """)
            cur.execute('DROP TABLE cell_states')
            print('  DB:      migrated old cell_states -> committed_cells')
    print(f'  DB:      {DB_URL} (schema ready)')


def current_version(cur):
    cur.execute('SELECT COALESCE(MAX(id), 0) AS v FROM cell_events')
    row = cur.fetchone()
    return row['v'] if isinstance(row, dict) else row[0]


def _rows(cur, table, extra_cols=''):
    cur.execute(f'SELECT store_id, product_id, cell_date, so, adj, fo{extra_cols} '
                f'FROM {table} ORDER BY store_id, product_id, cell_date')
    out = []
    for r in cur.fetchall():
        out.append({
            'store': r['store_id'], 'product': r['product_id'],
            'date': r['cell_date'].isoformat(),
            'so': r['so'], 'adj': r['adj'], 'fo': r['fo'],
            **({'lock_after': r['lock_after'].isoformat()} if 'lock_after' in r else {}),
        })
    return out


def get_state():
    with db() as conn, conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        return {
            'version': current_version(cur),
            'committed': _rows(cur, 'committed_cells'),
            'uncommitted': _rows(cur, 'uncommitted_cells', ', lock_after'),
            'drafts': _rows(cur, 'draft_cells', ', lock_after'),
        }


def _int(v, lo=-9999, hi=9999):
    n = int(v)
    if not (lo <= n <= hi):
        raise ValueError(f'value out of range: {n}')
    return n


def _date(s):
    return datetime.date.fromisoformat(str(s)).isoformat()


def _ident(s, maxlen=40):
    s = str(s)
    if not s or len(s) > maxlen:
        raise ValueError('bad identifier')
    return s


def get_session():
    """The server-held selection — what makes store/week sticky across refreshes."""
    with db() as conn, conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute('SELECT store_id, week_number FROM hub_session WHERE id = 1')
        row = cur.fetchone()
        return {'store': row['store_id'] if row else None,
                'week': row['week_number'] if row else None}


def set_session(body):
    """Partial upsert: {store} and/or {week}. Mirrors the real portal, where a
    store switch keeps the sticky week and a week switch keeps the store."""
    store = _ident(body['store']) if body.get('store') is not None else None
    week = _int(body['week'], 1, 53) if body.get('week') is not None else None
    if store is None and week is None:
        raise ValueError('need store and/or week')
    with db() as conn, conn.cursor() as cur:
        cur.execute("""
            INSERT INTO hub_session (id, store_id, week_number, updated_at)
            VALUES (1, %s, %s, now())
            ON CONFLICT (id) DO UPDATE
              SET store_id    = COALESCE(EXCLUDED.store_id, hub_session.store_id),
                  week_number = COALESCE(EXCLUDED.week_number, hub_session.week_number),
                  updated_at  = now()
        """, (store, week))
    return {'ok': True, **get_session()}


def save_drafts(body):
    """Persist grid edits BEFORE any submit — the pending-changes queue.

    Called on every ADJ/S.O. edit commit (blur/Enter) so typed-but-unsubmitted
    cells survive a page refresh, exactly like the real portal's queue.
    """
    cells = body.get('cells') or []
    if not isinstance(cells, list) or len(cells) > 1000:
        raise ValueError('cells must be a list of at most 1000 items')
    with db() as conn, conn.cursor() as cur:
        for c in cells:
            store, product, date = _ident(c['store']), _ident(c['product']), _date(c['date'])
            so, adj, fo = _int(c.get('so', 0)), _int(c.get('adj', 0)), _int(c.get('fo', 0))
            lock_after = _date(c.get('lock_after') or date)
            cur.execute('SELECT adj FROM draft_cells WHERE store_id=%s AND product_id=%s AND cell_date=%s',
                        (store, product, date))
            row = cur.fetchone()
            old_adj = row[0] if row else None
            cur.execute("""
                INSERT INTO draft_cells (store_id, product_id, cell_date, so, adj, fo, lock_after, updated_at)
                VALUES (%s,%s,%s,%s,%s,%s,%s,now())
                ON CONFLICT (store_id, product_id, cell_date) DO UPDATE
                  SET so=EXCLUDED.so, adj=EXCLUDED.adj, fo=EXCLUDED.fo,
                      lock_after=EXCLUDED.lock_after, updated_at=now()
            """, (store, product, date, so, adj, fo, lock_after))
            cur.execute("""
                INSERT INTO cell_events (store_id, product_id, cell_date, action, old_adj, new_adj, fo, source)
                VALUES (%s,%s,%s,'draft',%s,%s,%s,'grid_edit')
            """, (store, product, date, old_adj, adj, fo))
        return {'ok': True, 'drafted': len(cells), 'version': current_version(cur)}


def revert_drafts():
    """Revert All Changes: drop every pending draft row."""
    with db() as conn, conn.cursor() as cur:
        cur.execute('DELETE FROM draft_cells')
        n = cur.rowcount
        if n:
            cur.execute("INSERT INTO cell_events (action, source) VALUES ('revert', 'revert_all')")
        return {'ok': True, 'reverted': n, 'version': current_version(cur)}


def submit_cells(body):
    cells = body.get('cells') or []
    if not isinstance(cells, list) or len(cells) > 1000:
        raise ValueError('cells must be a list of at most 1000 items')
    with db() as conn, conn.cursor() as cur:
        for c in cells:
            store, product, date = _ident(c['store']), _ident(c['product']), _date(c['date'])
            so, adj, fo = _int(c.get('so', 0)), _int(c.get('adj', 0)), _int(c.get('fo', 0))
            lock_after = _date(c.get('lock_after') or date)
            cur.execute('SELECT adj FROM uncommitted_cells WHERE store_id=%s AND product_id=%s AND cell_date=%s',
                        (store, product, date))
            row = cur.fetchone()
            old_adj = row[0] if row else None
            cur.execute("""
                INSERT INTO uncommitted_cells (store_id, product_id, cell_date, so, adj, fo, lock_after, submitted_at)
                VALUES (%s,%s,%s,%s,%s,%s,%s,now())
                ON CONFLICT (store_id, product_id, cell_date) DO UPDATE
                  SET so=EXCLUDED.so, adj=EXCLUDED.adj, fo=EXCLUDED.fo,
                      lock_after=EXCLUDED.lock_after, submitted_at=now()
            """, (store, product, date, so, adj, fo, lock_after))
            cur.execute("""
                INSERT INTO cell_events (store_id, product_id, cell_date, action, old_adj, new_adj, fo, source)
                VALUES (%s,%s,%s,'submit',%s,%s,%s,'green_button')
            """, (store, product, date, old_adj, adj, fo))
            # The draft graduated to uncommitted — clear it from the queue.
            cur.execute('DELETE FROM draft_cells WHERE store_id=%s AND product_id=%s AND cell_date=%s',
                        (store, product, date))
        return {'ok': True, 'submitted': len(cells), 'version': current_version(cur)}


def get_events(limit=100):
    with db() as conn, conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute('SELECT * FROM cell_events ORDER BY id DESC LIMIT %s', (limit,))
        events = []
        for r in cur.fetchall():
            r = dict(r)
            r['cell_date'] = r['cell_date'].isoformat() if r['cell_date'] else None
            r['created_at'] = r['created_at'].isoformat()
            events.append(r)
        return {'events': events}


# ── Noon rollover: advance the committed boundary by one day ─────────────────
def run_rollover(reason):
    try:
        with db() as conn, conn.cursor() as cur:
            cur.execute("""
                SELECT store_id, product_id, cell_date, so, adj, fo
                FROM uncommitted_cells WHERE lock_after <= CURRENT_DATE
            """)
            due = cur.fetchall()
            for (store, product, date, so, adj, fo) in due:
                cur.execute("""
                    INSERT INTO committed_cells (store_id, product_id, cell_date, so, adj, fo, source, committed_at)
                    VALUES (%s,%s,%s,%s,%s,%s,'noon_rollover',now())
                    ON CONFLICT (store_id, product_id, cell_date) DO UPDATE
                      SET so=EXCLUDED.so, adj=EXCLUDED.adj, fo=EXCLUDED.fo,
                          source='noon_rollover', committed_at=now()
                """, (store, product, date, so, adj, fo))
                cur.execute('DELETE FROM uncommitted_cells WHERE store_id=%s AND product_id=%s AND cell_date=%s',
                            (store, product, date))
                cur.execute("""
                    INSERT INTO cell_events (store_id, product_id, cell_date, action, old_adj, new_adj, fo, source)
                    VALUES (%s,%s,%s,'rollover',%s,%s,%s,'noon_capture')
                """, (store, product, date, adj, adj, fo))
            # Drafts whose lock boundary passed were never submitted — the
            # order window closed on them, so they expire rather than commit.
            cur.execute('DELETE FROM draft_cells WHERE lock_after <= CURRENT_DATE')
            expired = cur.rowcount
            if expired:
                cur.execute("INSERT INTO cell_events (action, source) VALUES ('draft_expired', 'noon_capture')")
            version = current_version(cur)
        stamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        print(f'[rollover {stamp}] {reason}: committed {len(due)} due cell(s)')
        return {'ok': True, 'committed': len(due), 'version': version}
    except Exception as e:
        print(f'[rollover] FAILED: {e}')
        return {'ok': False, 'error': str(e)}


def capture_loop():
    while True:
        now = datetime.datetime.now()
        target = now.replace(hour=NOON_HOUR, minute=0, second=0, microsecond=0)
        if now >= target:
            target += datetime.timedelta(days=1)
        while True:
            remaining = (target - datetime.datetime.now()).total_seconds()
            if remaining <= 0:
                break
            time.sleep(min(30, max(1, remaining)))
        run_rollover(f'{NOON_HOUR:02d}:00 daily rollover')


# ── HTTP layer ────────────────────────────────────────────────────────────────
class HubHandler(SimpleHTTPRequestHandler):

    def log_message(self, fmt, *args):
        if self.path.startswith('/api/'):
            print(f'[api] {self.command} {self.path}')

    def _json(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(body)

    def _body(self):
        n = int(self.headers.get('Content-Length') or 0)
        if not n:
            return {}
        return json.loads(self.rfile.read(n).decode() or '{}')

    def do_GET(self):
        parsed = urlparse(self.path)
        if not parsed.path.startswith('/api/'):
            return super().do_GET()
        try:
            qs = parse_qs(parsed.query)
            if parsed.path == '/api/state':
                return self._json(200, get_state())
            if parsed.path == '/api/version':
                with db() as conn, conn.cursor() as cur:
                    return self._json(200, {'version': current_version(cur)})
            if parsed.path == '/api/events':
                limit = int((qs.get('limit') or ['100'])[0])
                return self._json(200, get_events(limit=limit))
            if parsed.path == '/api/session':
                return self._json(200, get_session())
            return self._json(404, {'error': 'unknown endpoint'})
        except Exception as e:
            return self._json(500, {'error': str(e)})

    def do_POST(self):
        parsed = urlparse(self.path)
        try:
            body = self._body()
            if parsed.path == '/api/session':
                return self._json(200, set_session(body))
            if parsed.path == '/api/draft':
                return self._json(200, save_drafts(body))
            if parsed.path == '/api/revert':
                return self._json(200, revert_drafts())
            if parsed.path == '/api/submit':
                return self._json(200, submit_cells(body))
            if parsed.path == '/api/capture':
                return self._json(200, run_rollover('manual trigger'))
            return self._json(404, {'error': 'unknown endpoint'})
        except (ValueError, KeyError, TypeError) as e:
            return self._json(400, {'error': f'invalid payload: {e}'})
        except Exception as e:
            return self._json(500, {'error': str(e)})


def main():
    ap = argparse.ArgumentParser(description='Mock ordering hub server (static + three-table cell-state API)')
    ap.add_argument('--port', type=int, default=8099)
    ap.add_argument('--host', default='127.0.0.1')
    ap.add_argument('--capture-now', action='store_true',
                    help='Run one rollover pass immediately at boot (testing/filming)')
    args = ap.parse_args()

    print('=' * 60)
    print('Mock Ordering Hub — Bread Store Demo (fictional)')
    print(f'  Serving: {HERE}')
    init_schema()
    url = f'http://{args.host}:{args.port}/index.html'
    print(f'  URL:     {url}')
    print(f'  Rollover: daily at {NOON_HOUR:02d}:00 (uncommitted -> committed as the boundary advances)')
    print(f'  Point the scraper at it:')
    print(f'    OrderHubScraper(headless=False, hub_url="{url}")')
    print('  Ctrl-C to stop.')
    print('=' * 60)

    if args.capture_now:
        run_rollover('boot --capture-now')

    threading.Thread(target=capture_loop, daemon=True, name='noon-rollover').start()

    handler = partial(HubHandler, directory=HERE)
    httpd = ThreadingHTTPServer((args.host, args.port), handler)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print('\nStopped.')
        httpd.shutdown()


if __name__ == '__main__':
    main()
