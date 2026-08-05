# Mock Ordering Hub — filming-safe demo prop

A **fictional, local** stand-in for the vendor ordering portal, built so the
**real, unmodified** `OrderHubScraper` drives it end-to-end. Use it for
screen recordings / social content without touching any production system,
credential, or third-party data.

Everything here is invented — the chain (*Bread Store Demo*), the stores, the SKUs,
the numbers. Swap any of it in `data.js`.

## Why this exists

Sharing the ordering automation publicly has two hazards the rest of the project
avoids: (1) showing how a specific vendor's bot-check is bypassed, and (2)
exposing real stores' order volumes. This mock removes both — it has no bot
check (it's your own prop) and no real data — while still letting you film the
genuine bot filling in a grid.

## Run it

```bash
# terminal 1 — serve the mock (static files + cell-state API + noon capture)
python demo/mock-ordering-hub/serve.py            # http://127.0.0.1:8099/index.html

# terminal 2 — drive it with the REAL scraper (repo root, venv active)
python demo/mock-ordering-hub/run_demo.py         # visible window, for filming
```

Requires the local PostgreSQL (creates/uses database `mock_hub`, fully isolated
from the pipeline demo DB). Override with `MOCK_HUB_DB_URL`. If Postgres is
down the hub still works — it just degrades to the old in-memory behaviour.

`run_demo.py` switches store → filters each SKU → reads the grid → writes ADJ to
every adjustable date → clicks submit → confirms both dialogs. The only
difference from a live run is `hub_url` pointing at localhost:

```python
OrderHubScraper(headless=False, hub_url="http://127.0.0.1:8099/index.html")
```

Options: `--store`, `--products 500101,500102`, `--qty`, `--url`, `--headless`
(run behind Xvfb instead of a visible window).

## What's faithful to the real portal

The layout mirrors the real hub's arrangement: top nav tabs, Routes/Customers
sub-tabs, Route + Customers + Week controls with S-M-T-W-T-F-S chips and a
Revert All Changes button, a multi-product grid (left product panels with
UPC-SKU, Rtn% badge, TF, and S.O./ADJ/F.O./SFO row labels), a bookmark row,
"Week N Totals" columns, a Grand Totals row, and a bottom action bar (green
counter FAB + Email / Download Report / Review).

The mock reproduces the exact DOM selectors the scraper depends on, so no scraper
code changes are needed:

| Feature | Selector honored |
|---|---|
| Store picker | `input[formcontrolname='customer']` + `mat-option` list |
| Week picker | `mat-form-field.week > mat-select[formcontrolname='week']`, value text "29 (Current)" |
| Product filter | `input.filter-input` |
| Grid columns | `.div-content.day` (date headers + product cols), `.current` = today |
| Header text | stacked "Jul-13" / "Mon" spans → Selenium `.text` = `Jul-13\nMon`, matches the date regex |
| Week totals | `.div-content.day` in header ("Week N Totals" text) AND in each product row at the same sequence position, with a `.cell.fo` inside and an ADJ cell carrying neither `adjustable` nor `unadjustable` — that's how `read_pipeline` seq-skips them |
| Ignored layers | bookmark + grand-totals rows: `.div-content.day` with no `.cell.fo`, no date text, no "Week"/"Totals" text → the scraper's "other" bucket |
| Order cells | `.cell.fo`, `.cell.so`, `.cell.adj.adjustable` / `.unadjustable` (+ cosmetic `.cell.sfo`) |
| Editable ADJ | `input[inputmode='numeric'][apphubcell]` (verify-and-retry read-back works) |
| Submit | `button[mat-mini-fab].green.counter` + `span.mat-mdc-button-touch-target` (bottom-left FAB) |
| Review popup | `app-changed-orders` with `.row` / `.col` order rows |
| Confirm dialog | `.cdk-overlay-pane > mat-dialog-container > app-dialog > .actions > button.mat-primary` |
| Tray factor / returns | per-product `TF N` and `N%` text — the topbar stays free of both so the *filtered* product's values win the scraper's body-text regexes |

Store and week switches replicate the real hub's rebuild characteristic: the
grid is torn down FIRST (held Selenium refs genuinely go stale), the selection
round-trips to a server-held session (`hub_session` table), a realistic
latency elapses (`reloadMs` in `data.js`, default 700ms, spinner overlay),
and only then does the grid refetch and repaint — with the customer input's
placeholder updating *after* the rebuild, which is exactly the signal the
scraper's store-switch confirmation polls for. The session also makes the
selection sticky like the real portal's: the week survives store switches
AND full page refreshes (the same global/sticky paginator behaviour the real
`product_fo_scraper` navigation has to cope with).

Grid dates are generated relative to *today* each load (two Sun→Sat weeks),
so it always looks live. The week picker spans the **entire current year**
(week 1 → 52/53, scrollable, current week marked) — any week can be paged to.
Past dates with no database record show deterministic synthetic history
(seeded per store+product+date, so filming takes are repeatable); real
committed cells always win. Future delivery-day columns (Mon/Tue/Thu/Fri/Sat —
only Wed/Sun are no-delivery days) are adjustable; past ones show delivered
F.O. values. The **current-day column is
highlighted red** (like the real portal) and rolls forward automatically at
midnight without a reload.

## Stateful backend (Postgres, three-table model)

Since v3 the hub is a real system, not just a facade. `serve.py` exposes a
JSON API backed by PostgreSQL database `mock_hub`:

- **`draft_cells`** — written on EVERY grid edit commit (blur/Enter), before
  any submit. This is the persistent pending-changes queue (like the real
  portal's): typed edits survive a page refresh, still yellow, still counted
  on the green FAB. Cleared per-cell by submit, wholly by Revert All Changes,
  and swept of expired rows (lock boundary passed) by the noon rollover.
- **`uncommitted_cells`** — written ONLY when the green submit button
  completes. Each row carries `lock_after` — the date whose noon capture will
  lock it (computed from the product's `leadDays`: `cell_date - lead - 1`).
- **`committed_cells`** — written ONLY by the daily noon rollover: every day
  after 12:00 the committed boundary advances one day, sweeping due
  uncommitted rows (S.O./ADJ/F.O. snapshot) into this table.
- **`cell_events`** — append-only audit trail
  (`draft` / `revert` / `submit` / `rollover` / `draft_expired`).

Cell lifecycle:

| State | Where it lives | Grid look |
|---|---|---|
| edited, unsubmitted | `draft_cells` (+ browser map) | yellow band across S.O./ADJ/F.O. |
| submitted | `uncommitted_cells` | normal filled cell (no special paint) |
| committed / locked / no-delivery | `committed_cells` / date rule | one uniform grey band across S.O./ADJ/F.O. |

The lead-time boundary is **noon-aware**: before 12:00 a product with lead 3
can order `today+4` onward; after 12:00 the boundary advances one more day
(both on the grid and via the server rollover). Override the hour with
`MOCK_HUB_CAPTURE_HOUR`; trigger the rollover on demand (testing/filming)
with `POST /api/capture` or `serve.py --capture-now`. The bottom bar shows a
countdown chip to the next capture.

API: `GET /api/state`, `GET /api/version`, `GET /api/events?limit=N`,
`GET/POST /api/session`, `POST /api/draft`, `POST /api/revert`,
`POST /api/submit`, `POST /api/capture`.

The page hydrates from `/api/state` on load, so drafts and
submitted/committed orders survive restarts; committed history on past delivery days replaces the
synthetic "delivered" numbers. A guarded 8s poll picks up rollovers and the
midnight/noon boundary changes, but never re-renders while an ADJ input is
focused, so it cannot detach an input mid-scraper-write.

Two hard rules keep the scraper happy (learned the hard way):

1. ADJ commits update F.O./totals cells **in place** — a re-render mid-write
   detaches the input and breaks verify-and-retry.
2. Filtering **rebuilds** the product rows with only the matches in the DOM —
   Selenium finds `display:none` elements, so CSS-hiding would break the
   header↔product column pairing.

## Files

- `index.html` / `styles.css` — the page (generic B2B look, fictional branding)
- `app.js` — behavioural layer honoring the DOM contract above + API sync
- `data.js` — the fictional Bread Store Demo seed data (edit freely)
- `serve.py` — localhost server: static files + Postgres cell-state API + noon capture
- `run_demo.py` — drives the real scraper against the mock

## Safety notes for recording

- This prop contains no secrets, but your **terminal and editor** might — keep
  any real credentials, env files, private IPs, and real store names out of
  frame.
- Talk about the automation as a *general* browser-driving problem. The mock has
  no bot-check by design; don't narrate how the real one is bypassed.
