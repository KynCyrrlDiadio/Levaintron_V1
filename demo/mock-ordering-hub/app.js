/*
 * Mock Ordering Hub — behavioural layer.
 *
 * This reproduces the DOM *contract* that custom_selenium_order_hub_tools.py
 * depends on, so the real, unmodified scraper drives this page exactly as it
 * drives the production portal:
 *
 *   store picker   input[formcontrolname='customer'] + .customer-dropdown mat-option
 *   week picker    mat-form-field.week > mat-select[formcontrolname='week']
 *                    (value span carries .mat-mdc-select-value-text, text "29 (Current)")
 *   filter         input.filter-input
 *   grid layers    .div-content.day — the scraper classifies each one:
 *                    header  = has "Jul-13\nMon" or "Week N Totals" text, no .cell.fo
 *                    product = contains .cell.fo (week-total product cols are
 *                              skipped by sequence position, so they MUST exist
 *                              in every product row at the same position)
 *                    other   = bookmark row + grand totals (no .cell.fo, no date
 *                              text, no "Week"/"Totals" text) — ignored
 *   adj write      .cell.adj.adjustable > input[inputmode='numeric'][apphubcell]
 *   locked cells   .cell.adj.unadjustable  (week-total ADJ cells carry NEITHER class)
 *   tf / returns   per-product "TF N" and "N%" text (topbar must stay free of both,
 *                    so the filtered product's values win the body-text regex)
 *   submit         button[mat-mini-fab].green.counter > span.mat-mdc-button-touch-target
 *   popup 1        app-changed-orders  (.row > .col×6, plus a Submit button)
 *   popup 2        .cdk-overlay-pane > mat-dialog-container > app-dialog
 *                    > .notification-message + .actions > button.mat-primary
 *
 * Two hard rules learned from the verified v1:
 *   1. ADJ commits update dependent cells IN PLACE — a re-render mid-write
 *      detaches the input and breaks the scraper's verify-and-retry.
 *   2. Filtering REBUILDS the product rows with only the matches — hidden
 *      (display:none) rows would still be found by Selenium and break the
 *      header↔product column pairing.
 *
 * Everything is fictional and local. No network calls, no credentials.
 */

(function () {
  'use strict';

  const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  const DOW = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

  // ── State ──────────────────────────────────────────────────────────────────
  let currentStore = DEMO.stores[0];
  let filterQuery = '';
  let weekOffset = 0;               // 0 = current week; +N advances the visible window
  let columns = [];                 // date + week-total column models, in DOM order
  const changes = new Map();        // `${store}|${product}|${date}` -> {store, product, so, adj, fo, ...}
                                    //   UNSUBMITTED edits (yellow). Mirrored to draft_cells on
                                    //   every commit so they survive a page refresh.
  const submittedMap = new Map();   // saved via the green submit button (uncommitted_cells table)
  const committedMap = new Map();   // locked in by the noon rollover (committed_cells table)
  const refs = {                    // live DOM refs for in-place updates (rebuilt on render)
    products: new Map(),            // pid -> { foCells, adjCells: Map(date->el), weeks: [{so,adj,fo,sfo,sfoBase}] }
    gtDate: new Map(),              // date -> grand-total cell el
    gtWeek: [],                     // weekIdx -> grand-total cell el
  };

  // ── Backend persistence (serve.py API → PostgreSQL) ─────────────────────────
  // Every cell write is tracked server-side; pending cells are auto-committed
  // by the daily noon capture. If the API is unreachable the hub degrades to
  // the old in-memory behaviour (e.g. when opened straight from file://).
  let serverVersion = 0;
  let serverOK = false;
  let draftsInFlight = 0;           // POST /api/draft calls not yet acknowledged
  let reloading = false;            // store/week switch round-trip in progress

  function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

  // ── Grid reload: replicate the real portal's teardown → round-trip → rebuild.
  // The old cells leave the DOM FIRST (held Selenium refs genuinely go stale),
  // the selection round-trips to the server-held session, a realistic latency
  // elapses, then the grid refetches and repaints.
  async function reloadGrid(msg, apply) {
    reloading = true;
    const overlay = document.getElementById('grid-reload');
    document.getElementById('grid-reload-msg').textContent = msg;
    overlay.hidden = false;
    for (const id of ['header-cols', 'bookmark-cols', 'product-rows', 'gt-cols']) {
      document.getElementById(id).innerHTML = '';
    }
    refs.products.clear(); refs.gtDate.clear(); refs.gtWeek.length = 0;
    const t0 = Date.now();
    await apply();                                   // POST /api/session (+ local state)
    const wait = DEMO.reloadMs - (Date.now() - t0);
    if (wait > 0) await sleep(wait);
    buildColumns();
    const ok = await loadState();                    // refetch + render
    if (!ok) render();                               // offline fallback: still repaint
    overlay.hidden = true;
    reloading = false;
  }

  // ISO week number of the current display week (its Monday) — the anchor the
  // sticky server-held week number is resolved against.
  function baseIsoWeek() {
    const monday = new Date(); monday.setHours(0, 0, 0, 0);
    monday.setDate(monday.getDate() - monday.getDay() + 1);
    return isoWeek(monday);
  }

  // Boot default: the portal always OPENS on the first customer (70012001)
  // and the real current week — like the production portal. Any bot or user
  // must perform a visible store switch each session. The server session
  // still tracks the live selection mid-session (store switches and week
  // hops POST to it); on load we re-anchor it to the defaults so the two
  // never disagree.
  async function restoreSession() {
    await api('/api/session', { store: currentStore.id, week: baseIsoWeek() });
    buildColumns();
  }

  async function api(path, body) {
    try {
      const res = await fetch(path, body === undefined ? undefined : {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      if (!res.ok) throw new Error('HTTP ' + res.status);
      serverOK = true;
      return await res.json();
    } catch (e) {
      serverOK = false;
      return null;
    }
  }

  async function loadState() {
    const data = await api('/api/state');
    if (!data) {
      status('Backend offline — grid running in-memory only (state will not persist).');
      return false;
    }
    serverVersion = data.version;
    submittedMap.clear();
    committedMap.clear();
    const toRec = (c) => {
      const store = DEMO.stores.find(s => s.id === c.store);
      const product = DEMO.products.find(p => p.id === c.product);
      return {
        store: c.store, storeName: store ? store.name : c.store,
        product: c.product, productName: product ? product.name : c.product,
        date: c.date, so: c.so, adj: c.adj, fo: c.fo,
      };
    };
    for (const c of data.committed) committedMap.set(`${c.store}|${c.product}|${c.date}`, toRec(c));
    for (const c of data.uncommitted) submittedMap.set(`${c.store}|${c.product}|${c.date}`, toRec(c));
    // Drafts (unsubmitted edits) are server-authoritative: every commit POSTs
    // immediately, so rebuild `changes` from draft_cells — this is what makes
    // yellow cells survive a refresh. Skip only while a POST is still in
    // flight, so a just-typed edit can't be momentarily wiped by a poll race.
    if (draftsInFlight === 0 && data.drafts) {
      changes.clear();
      for (const c of data.drafts) changes.set(`${c.store}|${c.product}|${c.date}`, toRec(c));
    }
    render();
    return true;
  }

  function pushDraft(rec) {
    draftsInFlight++;
    api('/api/draft', { cells: [{ ...rec, lock_after: lockAfterDate(rec) }] })
      .then(r => { if (r) serverVersion = r.version; })
      .finally(() => { draftsInFlight--; });
  }

  // ── Date helpers ────────────────────────────────────────────────────────────
  function mondayIndex(d) { return (d.getDay() + 6) % 7; }   // 0=Mon … 6=Sun
  function isoWeek(d) {
    const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
    const day = (t.getUTCDay() + 6) % 7;
    t.setUTCDate(t.getUTCDate() - day + 3);
    const firstThu = new Date(Date.UTC(t.getUTCFullYear(), 0, 4));
    const firstDay = (firstThu.getUTCDay() + 6) % 7;
    firstThu.setUTCDate(firstThu.getUTCDate() - firstDay + 3);
    return 1 + Math.round((t - firstThu) / (7 * 864e5));
  }
  function isoDate(d) {
    return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
  }

  // Deterministic per (store, product) so delivered history looks stable on film.
  function seedFor(storeId, productId) {
    return (storeId + productId).split('')
      .reduce((a,c) => (a*31 + c.charCodeAt(0)) >>> 0, 7);
  }

  // ── Column model: Sun→Sat weeks with a totals column after each Saturday ────
  function buildColumns() {
    columns = [];
    const today = new Date(); today.setHours(0,0,0,0);
    const sunday = new Date(today);
    sunday.setDate(sunday.getDate() - sunday.getDay() + weekOffset * 7);

    for (let w = 0; w < DEMO.weeksToShow; w++) {
      for (let i = 0; i < 7; i++) {
        const d = new Date(sunday); d.setDate(d.getDate() + w * 7 + i);
        const off = Math.round((d - today) / 864e5);
        const dowIdx = mondayIndex(d);
        columns.push({
          type: 'date',
          date: isoDate(d),
          mon: `${MONTHS[d.getMonth()]}-${d.getDate()}`,   // "Jul-13" — scraper regex food
          dow: DOW[dowIdx],
          dowIdx,
          off,                                             // days from today
          weekIdx: w,
          isToday: off === 0,
          isPast: off < 0,
          isFuture: off > 0,
          isDelivery: DEMO.deliveryDays.includes(dowIdx),
        });
      }
      const monday = new Date(sunday); monday.setDate(monday.getDate() + w * 7 + 1);
      columns.push({ type: 'week', weekIdx: w, weekNum: isoWeek(monday) });
    }
  }

  // ── Per-product value model (reads the state maps; never touches DOM) ──────
  function cellKey(product, col) {
    return `${currentStore.id}|${product.id}|${col.date}`;
  }
  function committedAdj(product, col) {
    const k = cellKey(product, col);
    if (changes.has(k)) return changes.get(k).adj;
    if (submittedMap.has(k)) return submittedMap.get(k).adj;
    if (committedMap.has(k)) return committedMap.get(k).adj;
    return null;
  }
  // 'pending' (unsaved, amber) | 'submitted' (saved, awaiting capture) |
  // 'committed' (locked by the rollover, dark) | null.
  function cellState(product, col) {
    const k = cellKey(product, col);
    if (changes.has(k)) return 'pending';
    if (submittedMap.has(k)) return 'submitted';
    if (committedMap.has(k)) return 'committed';
    return null;
  }
  // Deterministic per (store, product, date) — history must not shift
  // between loads or filming takes.
  function histJitter(product, col) {
    let h = seedFor(currentStore.id, product.id);
    for (const c of col.date) h = (h * 31 + c.charCodeAt(0)) >>> 0;
    // Avalanche before the modulus — without it, dates 7 days apart (same
    // month) hash to the same residue mod 7 and whole weeks render identical.
    h ^= h >>> 13; h = Math.imul(h, 0x85ebca6b) >>> 0; h ^= h >>> 16;
    return (h % 7) - 2 + (col.dowIdx >= 4 ? 1 : 0);   // -2..+4, Fri/Sat bump
  }
  function deliveredFo(product, col) {
    if (!col.isDelivery || col.isFuture) return 0;
    // Real committed F.O. from Postgres always wins. Days from before the
    // database existed get deterministic synthetic history (S.O. plus a
    // seeded jitter), so paginating across the whole year shows believable
    // delivered volumes instead of a flat standing order.
    const k = cellKey(product, col);
    if (committedMap.has(k)) return committedMap.get(k).fo;
    return Math.max(0, colSo(product, col) + histJitter(product, col));
  }
  // Lead time: a future delivery day is editable only once it's MORE than the
  // product's leadDays away (lead 3 on a Friday morning → next Tuesday is the
  // first editable cell). After the NOON cutoff the boundary advances one more
  // day — the rolling daily capture. Inside the window the cell renders locked.
  function noonPassed() { return new Date().getHours() >= DEMO.captureHour; }
  function adjustableFor(product, col) {
    if (col.type !== 'date' || !col.isDelivery) return false;
    const lead = product.leadDays != null ? product.leadDays : 3;
    return col.off > lead + (noonPassed() ? 1 : 0);
  }
  // The date whose noon capture locks this cell: cell_date - lead - 1.
  function lockAfterDate(rec) {
    const p = DEMO.products.find(x => x.id === rec.product);
    const lead = p && p.leadDays != null ? p.leadDays : 3;
    const d = new Date(rec.date + 'T00:00:00');
    d.setDate(d.getDate() - lead - 1);
    return isoDate(d);
  }
  function colSo(product, col) {
    if (!col.isDelivery) return 0;
    // Per-date S.O. overrides (edited on the grid) win over the store default.
    const k = cellKey(product, col);
    const rec = changes.get(k) || submittedMap.get(k) || committedMap.get(k);
    if (rec && rec.so != null) return rec.so;
    // Store default: `so` is either a number (all stores) or a per-store map.
    const so = product.so;
    if (typeof so === 'number') return so;
    const v = so[currentStore.id];
    return v != null ? v : (so.default || 0);
  }
  function colAdj(product, col) {
    if (adjustableFor(product, col)) {
      const adj = committedAdj(product, col);
      return adj != null ? adj : 0;
    }
    // Locked cells still display an ADJ that was committed (or submitted just
    // before the boundary swept past it).
    const k = cellKey(product, col);
    const rec = committedMap.get(k) || submittedMap.get(k);
    if (rec) return rec.adj;
    // Synthetic history: show the implied adjustment (F.O. − S.O.) so past
    // weeks look worked and per-cell arithmetic (and week totals) stay true.
    if (col.isDelivery && !col.isFuture) {
      return deliveredFo(product, col) - colSo(product, col);
    }
    return 0;
  }
  function colFo(product, col) {
    if (adjustableFor(product, col)) return colSo(product, col) + colAdj(product, col);
    if (col.isFuture && col.isDelivery) {
      // Inside the lead-time window: locked at S.O. plus any earlier commit.
      const k = cellKey(product, col);
      const rec = committedMap.get(k) || submittedMap.get(k);
      return rec ? rec.fo : colSo(product, col);
    }
    return deliveredFo(product, col);
  }
  function weekTotals(product, weekIdx) {
    let so = 0, adj = 0, fo = 0;
    for (const col of columns) {
      if (col.type !== 'date' || col.weekIdx !== weekIdx) continue;
      so += colSo(product, col);
      adj += colAdj(product, col);
      fo += colFo(product, col);
    }
    return { so, adj, fo };
  }
  function sfoBase(product, weekIdx) {
    // Static "suggested final order" the portal's own forecast would show.
    const seed = seedFor(currentStore.id, product.id);
    const wk = weekTotals(product, weekIdx);
    return Math.max(0, wk.so + ((seed >> (weekIdx * 3)) % 9) - 2);
  }
  function grandDateTotal(col) {
    return DEMO.products.reduce((t, p) => t + colFo(p, col), 0);
  }
  function grandWeekTotal(weekIdx) {
    return DEMO.products.reduce((t, p) => t + weekTotals(p, weekIdx).fo, 0);
  }

  function visibleProducts() {
    const q = filterQuery.trim().toLowerCase();
    if (!q) return DEMO.products;
    return DEMO.products.filter(p =>
      p.id.toLowerCase().includes(q) || p.name.toLowerCase().includes(q));
  }

  // ── Render ───────────────────────────────────────────────────────────────────
  function el(tag, className, text) {
    const e = document.createElement(tag);
    if (className) e.className = className;
    if (text != null) e.textContent = text;
    return e;
  }
  const BOOKMARK_SVG =
    '<svg viewBox="0 0 24 24" width="13" height="13"><path d="M6 3h12v18l-6-4.5L6 21z"/></svg>';

  function render() {
    const firstWeek = columns.find(c => c.type === 'week');
    document.getElementById('week-value').textContent =
      weekOffset === 0 ? `${firstWeek.weekNum} (Current)` : String(firstWeek.weekNum);
    document.getElementById('route-label').textContent = DEMO.route;
    document.getElementById('route-value').textContent = DEMO.route;

    renderHeaderRow();
    renderBookmarkRow();
    renderProductRows();
    renderGrandTotals();
    updateCounter();
  }

  function renderHeaderRow() {
    const host = document.getElementById('header-cols');
    host.innerHTML = '';
    for (const col of columns) {
      if (col.type === 'week') {
        // "Week 29\nTotals" — classified as a header week-total by the scraper.
        const h = el('div', 'div-content day week-total header-cell');
        h.appendChild(el('span', 'hdr-mon', `Week ${col.weekNum}`));
        h.appendChild(el('span', 'hdr-dow', 'Totals'));
        host.appendChild(h);
      } else {
        // "Jul-13\nMon" — matches ([A-Za-z]{3})-(\d{1,2})\s+([A-Za-z]{3}).
        const h = el('div', 'div-content day header-cell' + (col.isToday ? ' current' : ''));
        h.appendChild(el('span', 'hdr-mon', col.mon));
        h.appendChild(el('span', 'hdr-dow', col.dow));
        host.appendChild(h);
      }
    }
  }

  function renderBookmarkRow() {
    // Icon-only cells: no text at all, so the scraper files them under
    // "other" and ignores them (visible text would change classification).
    const host = document.getElementById('bookmark-cols');
    host.innerHTML = '';
    for (const col of columns) {
      const b = el('div', 'div-content day bookmark-cell'
        + (col.type === 'week' ? ' week-total' : '')
        + (col.isToday ? ' current' : ''));
      b.innerHTML = BOOKMARK_SVG;
      host.appendChild(b);
    }
  }

  function renderProductRows() {
    const host = document.getElementById('product-rows');
    host.innerHTML = '';
    refs.products.clear();

    for (const p of visibleProducts()) {
      const pref = { foCells: new Map(), adjCells: new Map(), soCells: new Map(), weeks: [] };
      refs.products.set(p.id, pref);

      const row = el('div', 'grid-row product-block');

      // ── Left panel: product meta + S.O./ADJ/F.O./SFO row labels ──
      const left = el('div', 'left-panel product-left');
      const meta = el('div', 'p-meta');
      const tags = el('div', 'p-tags');
      tags.appendChild(el('span', 'p-tag-label', 'Product'));
      tags.appendChild(el('span', 'p-heart', '♥'));
      if (p.featured) tags.appendChild(el('span', 'p-featured', 'FEATURED'));
      const rtn = el('span', 'p-rtn' + (p.rtnPct >= 15 ? ' high' : ''), `${p.rtnPct}%`);
      const rtnWrap = el('div', 'p-rtn-wrap');
      rtnWrap.appendChild(el('span', 'p-rtn-label', '4wk Rtn'));
      rtnWrap.appendChild(rtn);
      meta.appendChild(tags);
      meta.appendChild(el('div', 'p-name', p.name.toUpperCase()));
      meta.appendChild(el('div', 'p-code', `${p.upc} - ${p.id}`));
      meta.appendChild(rtnWrap);
      meta.appendChild(el('div', 'p-tf', `TF ${p.tf}`));
      const labels = el('div', 'p-rowlabels');
      ['S.O.','ADJ','F.O.','SFO'].forEach(t => labels.appendChild(el('div', 'p-rowlabel', t)));
      left.appendChild(meta);
      left.appendChild(labels);
      row.appendChild(left);

      // ── Day columns: .div-content.day stacks of .cell.so/.adj/.fo/.sfo ──
      const cols = el('div', 'day-cols');
      for (const col of columns) {
        if (col.type === 'week') {
          cols.appendChild(buildWeekTotalCol(p, col, pref));
        } else {
          cols.appendChild(buildDateCol(p, col, pref));
        }
      }
      row.appendChild(cols);
      host.appendChild(row);
    }
  }

  function buildDateCol(product, col, pref) {
    const d = el('div', 'div-content day data-col' + (col.isToday ? ' current' : ''));

    const soCell = el('div', 'cell so', String(colSo(product, col)));
    pref.soCells.set(col.date, soCell);
    d.appendChild(soCell);

    // ADJ — delivery days beyond the product's lead time get a live numeric
    // input. State classes are ADDITIVE ('pending'/'committed') — the
    // scraper's .cell.adj.adjustable selector still matches unchanged.
    const adjCell = el('div');
    const foCell = el('div', 'cell fo');   // created early so commit can capture it
    if (adjustableFor(product, col)) {
      const state = cellState(product, col);
      adjCell.className = 'cell adj adjustable' + (state ? ' ' + state : '');
      if (state) { foCell.classList.add(state); soCell.classList.add(state); }
      // S.O. in the open zone is a persistent numeric input, exactly like ADJ
      // and the real portal: .cell.so.adjustable > input[apphubcell]. (It was
      // click-to-edit before, but a swap-on-click cell strands WebDriver —
      // clear() and Enter both blur, and removing the input mid-keystroke
      // throws stale element reference.)
      soCell.classList.add('adjustable', 'so-editable');
      soCell.title = 'Standing order for this date';
      soCell.textContent = '';
      const soInput = document.createElement('input');
      soInput.className = 'so-input';
      soInput.setAttribute('inputmode', 'numeric');
      soInput.setAttribute('apphubcell', '');
      soInput.value = String(colSo(product, col));
      soInput.addEventListener('input', () => {
        const clean = soInput.value.replace(/[^0-9]/g, '');
        if (clean !== soInput.value) soInput.value = clean;
      });
      soInput.addEventListener('change', () => commitSo(product, col, soInput.value));
      soInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') { commitSo(product, col, soInput.value); soInput.blur(); }
      });
      soCell.appendChild(soInput);
      const input = document.createElement('input');
      input.setAttribute('inputmode', 'numeric');
      input.setAttribute('apphubcell', '');
      input.className = 'adj-input';
      const adj = committedAdj(product, col);
      input.value = adj != null ? String(adj) : '';
      // Numeric-only: strip anything that isn't a digit (or a leading minus)
      // as it's typed or pasted.
      input.addEventListener('input', () => {
        const clean = input.value.replace(/(?!^-)[^0-9]/g, '');
        if (clean !== input.value) input.value = clean;
      });
      // In-place commit — updates the map + dependent cells WITHOUT rebuilding
      // the grid, so element references stay valid through the scraper's
      // click→type→verify cycle (exactly like the production Angular grid).
      input.addEventListener('change', () => commitAdj(product, col, input.value));
      input.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') { commitAdj(product, col, input.value); input.blur(); }
      });
      adjCell.appendChild(input);
      pref.adjCells.set(col.date, adjCell);
    } else {
      const k = cellKey(product, col);
      const committed = committedMap.has(k) || submittedMap.has(k);
      adjCell.className = 'cell adj unadjustable' + (committed ? ' committed' : '');
      adjCell.textContent = String(colAdj(product, col));
      if (committed) {
        foCell.classList.add('committed'); soCell.classList.add('committed');
      } else {
        // Non-editable, non-committed columns (past days, Wed/Sun no-delivery,
        // lead-time window) grey the whole S.O./ADJ/F.O. stack uniformly.
        soCell.classList.add('locked'); foCell.classList.add('locked');
      }
    }
    d.appendChild(adjCell);

    const fo = colFo(product, col);
    foCell.textContent = String(fo);
    foCell.classList.toggle('has-value', fo > 0);
    pref.foCells.set(col.date, foCell);
    d.appendChild(foCell);

    d.appendChild(el('div', 'cell sfo', ''));
    return d;
  }

  function buildWeekTotalCol(product, col, pref) {
    // Product-layer week totals: MUST contain .cell.fo (so the scraper counts
    // then seq-skips it); the ADJ cell carries neither adjustable nor
    // unadjustable, matching the real portal's totals columns.
    const d = el('div', 'div-content day week-total data-col');
    const wk = weekTotals(product, col.weekIdx);
    const base = sfoBase(product, col.weekIdx);

    const soCell = el('div', 'cell so total', String(wk.so));
    const adjCell = el('div', 'cell adj total', String(wk.adj));
    const foCell = el('div', 'cell fo total', String(wk.fo));
    const sfoCell = el('div', 'cell sfo total');
    setSfo(sfoCell, base, wk.fo);

    d.appendChild(soCell); d.appendChild(adjCell); d.appendChild(foCell); d.appendChild(sfoCell);
    pref.weeks[col.weekIdx] = { so: soCell, adj: adjCell, fo: foCell, sfo: sfoCell, sfoBase: base };
    return d;
  }

  function setSfo(cell, base, fo) {
    const delta = base - fo;
    cell.innerHTML = '';
    cell.appendChild(el('span', 'sfo-val', String(base)));
    if (delta !== 0) {
      cell.appendChild(el('sup', 'sfo-delta' + (delta < 0 ? ' neg' : ' pos'),
        (delta > 0 ? '+' : '') + delta));
    }
  }

  function renderGrandTotals() {
    // Number-only cells with no .cell.fo → the scraper's "other" layer.
    const host = document.getElementById('gt-cols');
    host.innerHTML = '';
    refs.gtDate.clear();
    refs.gtWeek.length = 0;
    for (const col of columns) {
      if (col.type === 'week') {
        const g = el('div', 'div-content day week-total gt-cell', String(grandWeekTotal(col.weekIdx)));
        refs.gtWeek[col.weekIdx] = g;
        host.appendChild(g);
      } else {
        const g = el('div', 'div-content day gt-cell' + (col.isToday ? ' current' : ''),
          String(grandDateTotal(col)));
        refs.gtDate.set(col.date, g);
        host.appendChild(g);
      }
    }
  }

  // ── ADJ commit: map update + surgical in-place cell refreshes ───────────────
  function commitAdj(product, col, raw) {
    const v = parseInt(String(raw).trim(), 10);
    const adj = Number.isFinite(v) ? v : 0;
    const k = `${currentStore.id}|${product.id}|${col.date}`;
    // Enter + blur both fire for one write — skip the duplicate no-op.
    if (changes.has(k) && changes.get(k).adj === adj) return;
    const fo = colSo(product, col) + adj;
    changes.set(k, {
      store: currentStore.id,
      storeName: currentStore.name,
      product: product.id,
      productName: product.name,
      date: col.date,
      so: colSo(product, col),
      adj,
      fo,
    });

    // Persist the draft immediately — unsubmitted edits land in draft_cells
    // so a refresh brings them back (still yellow, still counted on the FAB).
    pushDraft(changes.get(k));

    const pref = refs.products.get(product.id);
    if (pref) {
      const adjEl = pref.adjCells.get(col.date);
      if (adjEl) { adjEl.classList.remove('committed', 'submitted'); adjEl.classList.add('pending'); }
      // Re-editing a committed date lifts the dark block off the S.O. cell too.
      const soEl = pref.soCells.get(col.date);
      if (soEl) soEl.classList.remove('committed');
      const foCell = pref.foCells.get(col.date);
      if (foCell) {
        foCell.textContent = String(fo);
        foCell.classList.toggle('has-value', fo > 0);
        foCell.classList.remove('committed', 'submitted');
        foCell.classList.add('pending');
      }
      const wkRef = pref.weeks[col.weekIdx];
      if (wkRef) {
        const wk = weekTotals(product, col.weekIdx);
        wkRef.adj.textContent = String(wk.adj);
        wkRef.fo.textContent = String(wk.fo);
        setSfo(wkRef.sfo, wkRef.sfoBase, wk.fo);
      }
    }
    const gtD = refs.gtDate.get(col.date);
    if (gtD) gtD.textContent = String(grandDateTotal(col));
    const gtW = refs.gtWeek[col.weekIdx];
    if (gtW) gtW.textContent = String(grandWeekTotal(col.weekIdx));

    updateCounter();
    status(`ADJ ${adj} drafted → ${product.id} @ ${currentStore.name} (${col.date}), F.O.=${fo} — persisted, yellow until Submit`);
  }

  function updateCounter() {
    document.getElementById('pending-count').textContent = String(changes.size);
  }

  // ── S.O. staging: persistent inputs commit through the same pipeline as ADJ ──
  function commitSo(product, col, raw) {
    const v = parseInt(String(raw).trim(), 10);
    const so = Number.isFinite(v) && v >= 0 ? v : colSo(product, col);
    const k = `${currentStore.id}|${product.id}|${col.date}`;
    if (changes.has(k) ? changes.get(k).so === so : so === colSo(product, col)) return;
    const prev = changes.get(k) || submittedMap.get(k) || committedMap.get(k);
    const adj = prev ? prev.adj : 0;
    const fo = so + adj;
    changes.set(k, {
      store: currentStore.id, storeName: currentStore.name,
      product: product.id, productName: product.name,
      date: col.date, so, adj, fo,
    });
    pushDraft(changes.get(k));

    const pref = refs.products.get(product.id);
    if (pref) {
      const soEl = pref.soCells.get(col.date);
      if (soEl) { soEl.classList.remove('committed', 'submitted'); soEl.classList.add('pending'); }
      const adjEl = pref.adjCells.get(col.date);
      if (adjEl) { adjEl.classList.remove('committed', 'submitted'); adjEl.classList.add('pending'); }
      const foCell = pref.foCells.get(col.date);
      if (foCell) {
        foCell.textContent = String(fo);
        foCell.classList.toggle('has-value', fo > 0);
        foCell.classList.remove('committed', 'submitted');
        foCell.classList.add('pending');
      }
      const wkRef = pref.weeks[col.weekIdx];
      if (wkRef) {
        const wk = weekTotals(product, col.weekIdx);
        wkRef.so.textContent = String(wk.so);
        wkRef.adj.textContent = String(wk.adj);
        wkRef.fo.textContent = String(wk.fo);
        setSfo(wkRef.sfo, wkRef.sfoBase, wk.fo);
      }
    }
    const gtD = refs.gtDate.get(col.date);
    if (gtD) gtD.textContent = String(grandDateTotal(col));
    const gtW = refs.gtWeek[col.weekIdx];
    if (gtW) gtW.textContent = String(grandWeekTotal(col.weekIdx));

    updateCounter();
    status(`S.O. ${so} drafted → ${product.id} @ ${currentStore.name} (${col.date}), F.O.=${fo} — persisted, yellow until Submit`);
  }

  // ── Store picker (input[formcontrolname='customer'] + mat-option list) ────────
  function setupStorePicker() {
    const input = document.querySelector("input[formcontrolname='customer']");
    const dropdown = document.getElementById('customer-dropdown');
    input.placeholder = `${currentStore.id} — ${currentStore.name}`;

    function openDropdown() {
      const q = input.value.trim();
      const matches = DEMO.stores.filter(s =>
        !q || s.id.includes(q) || s.name.toLowerCase().includes(q.toLowerCase()));
      dropdown.innerHTML = '';
      for (const s of matches) {
        // Scraper anchor: mat-option whose text contains the store id.
        const opt = document.createElement('mat-option');
        opt.className = 'mat-option';
        opt.setAttribute('role', 'option');
        opt.textContent = `${s.id} — ${s.name}`;
        // mousedown beats input blur for humans; click covers synthetic
        // .click() dispatches (see the week picker note).
        let fired = false;
        const choose = (e) => {
          e.preventDefault();
          if (fired) return;
          fired = true;
          selectStore(s);
        };
        opt.addEventListener('mousedown', choose);
        opt.addEventListener('click', choose);
        dropdown.appendChild(opt);
      }
      dropdown.hidden = matches.length === 0;
    }

    input.addEventListener('focus', openDropdown);
    input.addEventListener('input', openDropdown);
    input.addEventListener('blur', () => setTimeout(() => { dropdown.hidden = true; }, 150));
  }

  async function selectStore(store) {
    const input = document.querySelector("input[formcontrolname='customer']");
    input.value = '';                                    // clear BEFORE the round-trip: the typed
    document.getElementById('customer-dropdown').hidden = true;  // id must not confirm the switch early
    status(`Switching to ${store.name} (${store.id})…`);
    await reloadGrid(`Loading ${store.name}…`, async () => {
      await api('/api/session', { store: store.id });    // week stays sticky server-side
      currentStore = store;
    });
    // Placeholder updates only AFTER the rebuild lands — the scraper's
    // store-switch confirmation polls for exactly this.
    input.placeholder = `${store.id} — ${store.name}`;
    status(`Switched to ${store.name} (${store.id})`);
  }

  // ── Product filter (input.filter-input) ──────────────────────────────────────
  // Rebuilds product rows with ONLY the matches in the DOM — Selenium sees
  // display:none elements, so hiding via CSS would break column pairing.
  function setupFilter() {
    const filter = document.querySelector('input.filter-input');
    filter.addEventListener('input', () => applyFilter(filter.value));
    filter.addEventListener('change', () => applyFilter(filter.value));
  }
  function applyFilter(q) {
    filterQuery = String(q || '');
    renderProductRows();
    renderGrandTotals();
    const vis = visibleProducts();
    status(filterQuery.trim()
      ? `Filtered to ${vis.length} product(s): ${vis.map(p => p.id).join(', ') || 'none'}`
      : 'Filter cleared — showing all products');
  }

  // ── Week paginator: actually moves the visible window by whole weeks ─────────
  // The scraper's navigate_to_week clicks the mat-select then a mat-option
  // whose text is the target week number — both now really navigate. The list
  // spans the ENTIRE current year (week 1 → 52/53), scrollable, so any week's
  // grid can be paged to; option text stays a bare week number (unique within
  // the year) so the scraper's text match keeps working.
  function isoWeeksInYear(y) { return isoWeek(new Date(y, 11, 28)); }
  function setupWeekPicker() {
    const select = document.getElementById('week-select');
    select.addEventListener('click', () => {
      const container = document.getElementById('overlay-container');
      container.innerHTML = '';
      const wrap = document.createElement('div');
      wrap.className = 'cdk-global-overlay-wrapper';
      const pane = document.createElement('div');
      pane.className = 'cdk-overlay-pane week-pane';
      // Same week-number convention as the column headers: the Monday inside
      // the Sun→Sat display week.
      const base = baseIsoWeek();
      const total = isoWeeksInYear(new Date().getFullYear());
      let selectedEl = null;
      for (let w = 1; w <= total; w++) {
        const off = w - base;
        const opt = document.createElement('mat-option');
        opt.className = 'mat-option' + (off === weekOffset ? ' selected' : '');
        opt.setAttribute('role', 'option');
        opt.textContent = w === base ? `${w} (Current)` : String(w);
        if (off === weekOffset) selectedEl = opt;
        // Both mousedown AND click: a human's mousedown beats focus loss, but
        // a synthetic .click() (how the real scraper drives Material options)
        // dispatches only 'click' — Angular Material honors it, so must we.
        let fired = false;
        const choose = (e) => {
          e.preventDefault();
          if (fired) return;
          fired = true;
          wrap.remove();
          setWeekOffset(off);
        };
        opt.addEventListener('mousedown', choose);
        opt.addEventListener('click', choose);
        pane.appendChild(opt);
      }
      wrap.appendChild(pane);
      container.appendChild(wrap);
      if (selectedEl) selectedEl.scrollIntoView({ block: 'center' });
      setTimeout(() => wrap.remove(), 8000);
    });
  }

  async function setWeekOffset(off) {
    if (off === weekOffset) return;
    const target = baseIsoWeek() + off;
    status(`Loading week ${target}…`);
    await reloadGrid(`Loading week ${target}…`, async () => {
      await api('/api/session', { week: target });       // sticky: survives store switch + refresh
      weekOffset = off;
    });
    status(off === 0
      ? 'Back to the current week.'
      : `Week view moved ${off > 0 ? 'forward' : 'back'} ${Math.abs(off)} week(s).`);
  }

  // ── Decorative controls: DOW chips, revert, advanced, bottom bar ─────────────
  function setupChrome() {
    const chips = document.getElementById('dow-chips');
    ['S','M','T','W','T','F','S'].forEach((c, i) => {
      const chip = el('button', 'dow-chip', c);
      chip.addEventListener('click', () => chip.classList.toggle('off'));
      chips.appendChild(chip);
    });

    document.getElementById('revert-all').addEventListener('click', () => {
      // Drafts are persisted server-side now, so revert clears both the local
      // map and the draft_cells queue.
      const n = changes.size;
      changes.clear();
      api('/api/revert', {}).then(r => { if (r) serverVersion = r.version; });
      renderProductRows();
      renderGrandTotals();
      updateCounter();
      status(`Reverted ${n} draft change(s). Submitted and committed cells are untouched.`);
    });

    const advBar = document.getElementById('advanced-bar');
    const advPanel = document.getElementById('advanced-panel');
    advBar.addEventListener('click', () => {
      advPanel.hidden = !advPanel.hidden;
      document.getElementById('advanced-plus').textContent = advPanel.hidden ? '+' : '−';
    });

    document.getElementById('scroll-top').addEventListener('click', () =>
      window.scrollTo({ top: 0, behavior: 'smooth' }));
    document.getElementById('email-btn').addEventListener('click', () =>
      status('Demo: order report emailed (fictional — nothing sent).'));
    document.getElementById('report-btn').addEventListener('click', () =>
      status('Demo: report download queued (fictional).'));
    document.getElementById('review-btn').addEventListener('click', openChangedOrdersPopup);
  }

  // ── Submit flow: green counter → app-changed-orders → confirm dialog ─────────
  function setupSubmit() {
    document.getElementById('green-submit').addEventListener('click', openChangedOrdersPopup);
  }

  function openChangedOrdersPopup() {
    const container = document.getElementById('overlay-container');
    container.innerHTML = '';  // clear any stale panes

    const wrap = document.createElement('div');
    wrap.className = 'cdk-global-overlay-wrapper';
    const pane = document.createElement('div');
    pane.className = 'cdk-overlay-pane';
    const popup = document.createElement('app-changed-orders');
    popup.className = 'changed-orders';

    const rows = Array.from(changes.values());

    if (rows.length === 0) {
      const none = document.createElement('div');
      none.className = 'no-orders';
      none.textContent = 'No orders have been adjusted.';
      popup.appendChild(none);
    } else {
      const title = document.createElement('div');
      title.className = 'popup-title';
      title.textContent = 'Changed Orders — review before submit';
      popup.appendChild(title);

      const scroller = document.createElement('div');
      scroller.className = 'table-scroller';

      // Header row — scraper skips a row whose first col text is "customer".
      const head = document.createElement('div');
      head.className = 'row head-row';
      ['Customer','Product','S.O.','ADJ','F.O.','Date'].forEach(t => {
        const c = document.createElement('div'); c.className = 'col'; c.textContent = t; head.appendChild(c);
      });
      scroller.appendChild(head);

      for (const r of rows) {
        const row = document.createElement('div');
        row.className = 'row order-row';
        [r.store, r.product, String(r.so), String(r.adj), String(r.fo), r.date].forEach(t => {
          const c = document.createElement('div'); c.className = 'col'; c.textContent = t; row.appendChild(c);
        });
        scroller.appendChild(row);
      }
      popup.appendChild(scroller);

      const actions = document.createElement('div');
      actions.className = 'actions';
      const submit = document.createElement('button');
      submit.className = 'submit mat-primary';
      submit.textContent = 'Submit';
      submit.addEventListener('click', openVendorDialog);
      const cancel = document.createElement('button');
      cancel.className = 'cancel mat-warn';
      cancel.textContent = 'Cancel';
      cancel.addEventListener('click', () => { container.innerHTML = ''; });
      actions.appendChild(submit); actions.appendChild(cancel);
      popup.appendChild(actions);
    }

    pane.appendChild(popup);
    wrap.appendChild(pane);
    container.appendChild(wrap);
    status(`Submit clicked — ${rows.length} changed order(s) in review popup`);
  }

  function openVendorDialog() {
    const container = document.getElementById('overlay-container');
    // SECOND cdk-overlay-pane, added AFTER the first — scraper targets the last one.
    const wrap = document.createElement('div');
    wrap.className = 'cdk-global-overlay-wrapper';
    const pane = document.createElement('div');
    pane.className = 'cdk-overlay-pane';

    const dialog = document.createElement('mat-dialog-container');
    dialog.id = 'mat-mdc-dialog-2';
    dialog.className = 'mat-mdc-dialog-container';
    const surface = document.createElement('div');
    surface.className = 'mat-mdc-dialog-surface';
    const appDialog = document.createElement('app-dialog');

    const msg = document.createElement('div');
    msg.className = 'notification-message';
    const h2 = document.createElement('h2');
    h2.textContent = `Submit changes to ${DEMO.brand}`;
    const sub = document.createElement('p');
    const n = changes.size;
    sub.textContent = `You will be submitting any/all of the changes you've made to the ${n} adjustment(s) on route ${DEMO.route}.`;
    msg.appendChild(h2); msg.appendChild(sub);

    const actions = document.createElement('div');
    actions.className = 'actions';
    const submit = document.createElement('button');
    submit.className = 'mat-primary mdc-button--unelevated';
    submit.textContent = 'Submit';
    submit.addEventListener('click', () => finalizeSubmit(n));
    const cancel = document.createElement('button');
    cancel.className = 'mat-warn';
    cancel.textContent = 'Cancel';
    cancel.addEventListener('click', () => { container.innerHTML = ''; });
    actions.appendChild(submit); actions.appendChild(cancel);

    appDialog.appendChild(msg); appDialog.appendChild(actions);
    surface.appendChild(appDialog);
    dialog.appendChild(surface);
    pane.appendChild(dialog);
    wrap.appendChild(pane);
    container.appendChild(wrap);
    status(`Confirm dialog: submit ${n} change(s) to ${DEMO.brand}`);
  }

  function finalizeSubmit(n) {
    document.getElementById('overlay-container').innerHTML = '';
    // The ONLY write path to the database: submitted cells land in
    // uncommitted_cells (with their lock_after date) and wait for the noon
    // rollover to sweep them into committed_cells.
    const cells = Array.from(changes.values()).map(r => ({ ...r, lock_after: lockAfterDate(r) }));
    api('/api/submit', { cells }).then(r => { if (r) serverVersion = r.version; });
    for (const [k, rec] of changes) submittedMap.set(k, rec);
    changes.clear();
    buildColumns();
    render();
    status(`✓ Submitted ${n} change(s) to ${DEMO.brand}. Saved — cells lock at the ${String(DEMO.captureHour).padStart(2, '0')}:00 capture.`);
  }

  function status(msg) { document.getElementById('status-msg').textContent = msg; }

  // ── Live clock: day/noon rollover + external-change sync + countdown ────────
  // The boundary key changes at MIDNIGHT (grid window slides, red highlight
  // advances) and at NOON (the committed boundary rolls one day forward).
  function boundaryKey() {
    return isoDate(new Date()) + (noonPassed() ? '|pm' : '|am');
  }
  let currentBoundary = boundaryKey();

  function anyAdjInputFocused() {
    const a = document.activeElement;
    return !!(a && a.classList && a.classList.contains('adj-input'));
  }

  async function tick() {
    if (reloading) return;           // never poll/render mid store/week rebuild
    const nowBoundary = boundaryKey();
    if (nowBoundary !== currentBoundary) {
      currentBoundary = nowBoundary;
      buildColumns();
      await loadState();   // pick up the server-side rollover result too
      render();
      status(noonPassed()
        ? 'Noon capture passed — committed boundary advanced one day.'
        : 'New day — grid advanced.');
      return;
    }
    // Pick up external commits (the noon capture, another session). Never
    // re-render while an ADJ input is focused — a mid-write rebuild would
    // detach the input under the scraper's verify-and-retry cycle.
    if (anyAdjInputFocused()) return;
    const v = await api('/api/version');
    if (v && v.version !== serverVersion) {
      const before = committedMap.size;
      await loadState();
      if (committedMap.size > before) {
        status(`Order capture — ${committedMap.size - before} cell(s) locked in (green).`);
      }
    }
  }

  function updateCaptureChip() {
    const chip = document.getElementById('capture-chip');
    if (!chip) return;
    const now = new Date();
    const target = new Date(now);
    target.setHours(DEMO.captureHour, 0, 0, 0);
    if (now >= target) target.setDate(target.getDate() + 1);
    const s = Math.floor((target - now) / 1000);
    const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
    chip.textContent =
      `Daily order capture ${String(DEMO.captureHour).padStart(2, '0')}:00 — in ${h}h ${String(m).padStart(2, '0')}m`;
  }

  // ── Init ─────────────────────────────────────────────────────────────────────
  buildColumns();
  render();
  setupStorePicker();
  setupFilter();
  setupWeekPicker();
  setupChrome();
  setupSubmit();
  restoreSession().then(loadState);  // sticky store/week first, then cell hydration
  setInterval(tick, 8000);
  updateCaptureChip();
  setInterval(updateCaptureChip, 1000);
})();
