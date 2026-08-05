/*
 * Bread Store Demo — fictional seed data for the mock ordering hub.
 *
 * NOTHING in this file corresponds to a real store, SKU, supplier, or sales
 * figure. It exists purely so the demo grid looks plausible on camera. Swap
 * these values freely; the scraper only cares about the DOM shape, not the
 * numbers.
 */

const DEMO = {
  // The fictional distribution brand shown on the confirmation dialog.
  brand: 'Bread Store Demo Distribution',

  // Route shown in the controls row (fictional — do not use the real route number).
  route: 'Bread_dev',

  // Fictional stores. `id` is what the scraper types into the customer picker.
  stores: [
    { id: '70012001', name: 'Fictional Grocery Store Demo #1' },
    { id: '70012002', name: 'Fictional Co-op Store Demo #2' },
    { id: '70012003', name: 'Fictional Value Foods Demo #3' },
    { id: '70012004', name: 'Fictional Market Demo #4' },
    { id: '70012005', name: 'Fictional Provisions Demo #5' },
  ],

  // Fictional bread SKUs (mirrors the real system's shape: id, name, UPC,
  // per-store standing order, per-product tray factor + 4-week return rate).
  // `tf` renders as "TF N" and `rtnPct` as "N%" so the scraper's regexes
  // read the FILTERED product's values, like on the real portal.
  // `leadDays` = order lead time: a delivery day is only editable once it's
  // MORE than leadDays out (lead 3 on a Friday → next Tuesday is the first
  // editable cell, like the real portal). Longer-lead products lock earlier.
  // `so` = standing order, PER STORE: either a plain number (same for every
  // store) or a map { default, [storeId]: n }. On-grid S.O. edits stage
  // per-date overrides on top of these defaults.
  products: [
    { id: '500101', name: 'Country White 570g',      upc: '063004500101', so: { default: 4, '70012002': 6, '70012004': 2 }, tf: 8,  rtnPct: 12.4, leadDays: 3, featured: true  },
    { id: '500102', name: 'Heritage Rye 500g',        upc: '063004500102', so: { default: 3, '70012003': 5, '70012005': 2 }, tf: 9,  rtnPct: 23.1, leadDays: 5, featured: true  },
    { id: '500103', name: 'Sourdough Boule 550g',     upc: '063004500103', so: { default: 4, '70012002': 3, '70012005': 6 }, tf: 10, rtnPct: 8.6,  leadDays: 3, featured: false },
    { id: '500104', name: 'Multigrain Sandwich 600g', upc: '063004500104', so: { default: 2, '70012003': 4 },               tf: 10, rtnPct: 15.9, leadDays: 3, featured: false },
    { id: '500105', name: 'Sunrise Bagels 6pk',       upc: '063004500105', so: { default: 4, '70012002': 2, '70012004': 5 }, tf: 6,  rtnPct: 5.2,  leadDays: 3, featured: true  },
    { id: '500106', name: 'Postgres Bread',           upc: '063004500106', so: 0, tf: 9,  rtnPct: 10.4, leadDays: 3, featured: false },
    // Long-lead rye, like the real 7-day-lead Rye: it locks a full week out,
    // so it's the product that exercises week-extension navigation on film.
    { id: '500107', name: 'Demo 500g Rye Bread', upc: '063004500107', so: { default: 3, '70012002': 2, '70012004': 4 }, tf: 9,  rtnPct: 19.7, leadDays: 7, featured: false },
  ],

  // Delivery weekdays (0=Mon … 6=Sun). Future columns on these days are
  // adjustable (beyond lead time); everything else renders locked.
  // Mon/Tue/Thu/Fri/Sat — only Wednesday and Sunday are no-delivery days.
  deliveryDays: [0, 1, 3, 4, 5],

  // Sun→Sat weeks rendered (current week first), each followed by a
  // "Week N Totals" column like the real portal.
  weeksToShow: 2,

  // Daily order-capture hour (24h local). At this time the backend auto-commits
  // every pending cell — mirroring the real portal's noon order-capture bot.
  // Keep in sync with MOCK_HUB_CAPTURE_HOUR if you override it on serve.py.
  captureHour: 12,

  // Store/week switch latency (ms). The real hub tears the grid down and
  // refetches on every switch; the mock replicates that rebuild — old DOM
  // nodes really are destroyed (Selenium refs go stale) and the new grid
  // paints after this delay. Keep it realistic but snappy.
  reloadMs: 700,
};
