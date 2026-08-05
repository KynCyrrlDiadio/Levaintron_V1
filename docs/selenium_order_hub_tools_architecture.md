# `custom_selenium_order_hub_tools.py` — Architecture & Design Rationale

**2,643 lines. Two classes. One job: be the only part of the system that touches the outside world — and never lie about what happened there.**

This document explains how the ordering-hub integration tool is built, why each decision was made, and what real-world pressure produced it. Line references are to `Application_env/ai_orchestrator/custom_selenium_order_hub_tools.py`.

> **About this build.** This is the Levaintron demo codebase. The tool here is the production integration tool with vendor names redacted and its defaults pointed at the local mock ordering hub (`demo/mock-ordering-hub/`) instead of a live portal. The architecture, the hardening, and the line numbers are unchanged — the code you are reading is the code that runs unattended in production. Store and product identities are fictional throughout.

---

## 1. What this file is

It is the **hands and eyes** of the Levaintron pipeline. The MLP inventory bridge decides *what* to order; this file is the only code that can read the ordering portal's grid and write an order into it.

The architectural law of the system:

> The brain never touches the world. The suit never makes a decision.

`mlp_inventory_bridge.py` contains zero Selenium. This file contains zero database access and zero forecasting logic. They never import each other. `tests/run_pipeline_autonomous.py` is the only wire between them, and everything that crosses that wire is a plain Python dict.

That separation is what makes the system testable and repairable: a portal UI change breaks only this file, and a modelling change breaks only the bridge.

---

## 2. The environment this code actually runs in

Every unusual thing in this file traces back to one of these five facts. Read this section first or the code looks paranoid for no reason.

### 2.1 There is no API

The ordering hub is a vendor-run Angular application for bread ordering. There is no REST endpoint, no CSV export, no EDI feed available at this account tier. **The DOM is the API.** Everything the system knows about the outside world is scraped out of rendered HTML, and every order it places is typed into a form field like a human would.

This single fact justifies the file's existence and its size.

### 2.2 It runs unattended, at 3AM, with nobody watching

The daemon fires at 03:00 and 11:30 daily on a small always-on host. There is no human to click "retry," no human to notice a dialog didn't close, no human to spot that a value silently failed to save. Every operation must therefore either **verify itself** or **report its own failure in actionable terms**. A function that returns `True` when it merely *attempted* something is a bug in this environment.

### 2.3 The production portal fingerprints headless browsers

A standard `--headless` Chrome is detected (the `HeadlessChrome` user-agent string and `navigator.webdriver === true` are the tells) and the session never reaches the ordering hub. This constraint shapes the entire browser bootstrap — see §4.1. *(The demo mock hub has no such check by design; the bootstrap behaves identically against both.)*

### 2.4 Real money and real bread are on the other end

A wrong ADJ value becomes an actual bread delivery to an actual store: over-order and product expires on the shelf as a write-off, under-order and the shelf is empty on a Saturday morning. There is no "undo" once the daily capture sweeps an order into committed state. **This is why writes are verified rather than assumed**, and why the submit chain is triple-confirmed.

### 2.5 The portal is a moving target owned by someone else

The vendor ships UI changes without notice: CSS classes get renamed, dialogs get restructured, copy changes ("Filter" → "Filter / Search"). The tool cannot prevent this, so it is built to (a) survive cosmetic changes via layered selector fallbacks, and (b) when it truly breaks, say *which* thing broke rather than emitting a bare Selenium timeout.

---

## 3. Class structure

```
OrderHubTool                        (lines 33-736)   — session + write primitives
└── OrderHubScraper                 (lines 739-2643) — reading, week nav, verified writes, submit
```

The split is historical but has held up well:

- **`OrderHubTool`** owns everything about *having a browser session*: driver bootstrap, browser-presentation flags, navigation, readiness detection, store switching, product filtering, and the original v1 order-placement path (`place_order`, `click_adj_cell`).
- **`OrderHubScraper`** subclasses it and adds everything the autonomous pipeline needs: the grid reader, week navigation, index-addressed verified writes, and the submit/confirm dialog chain.

The pipeline instantiates **`OrderHubScraper` only** — one instance, one browser, all products, for the whole run. Login is expensive (and repeated logins look machine-like), so the session is established once and reused across every SKU.

The v1 methods on the parent class (`click_adj_cell`, `place_order`, `find_adj_row`) are retained deliberately: they are the interactive/LLM-driven path where an agent says "order 10 of product X three days out," using *date offsets* instead of the column indices the autonomous path uses. They are also the reference implementation that the v2 index-based path was derived from.

---

## 4. Subsystem deep-dives

### 4.1 Browser bootstrap — presenting as an ordinary browser (`setup_driver`, lines 50-103)

This is the most counter-intuitive code in the file, and the comments say why:

```python
# Deliberately NOT --headless: that token trips the portal's bot challenge.
```

The design: **`headless=True` is a lie the caller tells, and the tool honours the *intent* rather than the flag.**

When a caller asks for headless on a machine with no display, the tool starts an **Xvfb virtual display** (`pyvirtualdisplay`, lines 65-73) and runs a **fully headful Chrome inside it**. The browser is genuinely rendering to a real (virtual) framebuffer — it just has no monitor attached. From the portal's perspective this is an ordinary desktop Chrome.

Layered on top:

| Measure | Line | Purpose |
|---|---|---|
| `--disable-blink-features=AutomationControlled` | 88 | removes the automation flag from the Blink runtime |
| `excludeSwitches: ["enable-automation"]` | 89 | drops the "Chrome is being controlled" infobar and its side effects |
| `useAutomationExtension: False` | 90 | suppresses the automation extension |
| CDP `Page.addScriptToEvaluateOnNewDocument` overriding `navigator.webdriver` | 95-97 | hides the primary JS-visible tell, injected before any page script runs |
| Persistent `--user-data-dir` profile | 82-85 | carries the session clearance cookie and returning-visitor history |

The **persistent profile** is the strategic piece. The portal's human check is satisfied *once* interactively, and the resulting clearance cookie plus browsing history live in the profile directory. Every subsequent daemon run that shares that directory presents as a returning, established session. The env var `LEVAINTRON_CHROME_PROFILE` keeps the daemon and the interactive helper pointed at the same profile.

The documented caveat (line 83): **only one Chrome may hold the profile lock at a time** — the daemon and the interactive helper must never run concurrently.

`close()` (lines 723-736) tears down both the driver and the virtual display, in that order, each independently guarded.

> **Design note.** This is not evasion for its own sake — it is the minimum posture required for a legitimate, authorized account to use its own ordering portal unattended. The identity never changes; only the automation tells are suppressed. Against the demo mock hub none of it is needed, and it costs nothing.

### 4.2 Readiness ladders — never sleep-and-pray (`_wait_for_hub_ready`, lines 126-158)

Naïve Selenium code is a graveyard of `time.sleep(5)`. This file's rule: **wait for a state, not for a duration.**

The hub-load ladder checks three signals in sequence:

1. **Store input is clickable** (`input[formcontrolname='customer']`) — a hard gate. If this never becomes clickable, the page is not the hub, and the tool immediately runs block diagnostics (§7.1) and fails.
2. **Grid day columns are present** (`.div-content.day`) — a soft gate. Logged as a warning if missing; some flows still work.
3. **A randomized human-like settle**: `time.sleep(random.uniform(2.5, 5.5))` (line 152).

That third one is deliberate and the comment is precise: *"timing entropy only — identity stays fixed."* A daemon that interacts on exactly the same millisecond cadence every run is a machine-shaped signal. Jittering the dwell blurs the cadence without ever misrepresenting who is connecting. The daemon layers its own ±10-minute start jitter on top of this.

`_wait_for_page_ready` (184-197) is the lighter version used after week switches and store changes.

### 4.3 Overlay hygiene (`_dismiss_overlays`, lines 199-212)

Angular Material leaves dropdown panels and spinners floating over the page; these cause the classic `element click intercepted` failure. Before any consequential interaction, the tool clicks the body and sends `ESCAPE`, each in its own bare `try/except` — best-effort cleanup that must never itself throw.

### 4.4 Store switching (`switch_to_store` + `_wait_for_store_switch`, lines 214-333)

Sequence: dismiss overlays → read the current store from the input's **placeholder** → early-exit if already correct → clear via JS → focus/click via JS → `send_keys` the store ID → wait for `mat-option` autocomplete entries → match by substring → click.

Two details worth noting:

- **JS clicks for the plumbing, native clicks for the target.** JS clicks bypass overlay interception, which is what you want when clearing/focusing an input. But a JS click doesn't produce the full event sequence Angular sometimes needs, so the option click tries native first and falls back to JS (271-274).
- **Confirmation is triple-laddered** (`_wait_for_store_switch`, 287-333): poll the input's placeholder/value up to 3 times → if that fails, look for the grid's `.current` day marker as circumstantial evidence → if that fails, fall back to a settle-and-continue. It degrades rather than dying, because a false negative here would abort an entire nightly run.

### 4.5 Product filtering (`search_product`, lines 335-392)

Three selectors are tried in priority order:

```python
"input.filter-input"                        # class anchor — stable across copy changes
"input[placeholder='Filter / Search']"      # current copy
"input[placeholder='Filter']"               # older copy
```

The class anchor is first *on purpose*: vendor copy changes (the placeholder text) are far more frequent than structural class changes. Each selector is tried with an explicit wait, then all are retried without waiting.

The genuinely thoughtful part is the failure path (369-380). When nothing matches, the tool **fingerprints every `<input>` on the page** — placeholder, aria-label, class, id — and logs the lot. The 3AM failure email therefore contains the evidence needed to write the new selector, instead of "element not found."

### 4.6 The grid reader — the crown jewel (`read_pipeline`, lines 954-1261)

This is the hardest problem in the file and the most carefully engineered solution.

#### The problem: four interleaved layers under one selector

The hub renders the ordering grid as a flat sequence of `.div-content.day` elements, but that single class covers **four semantically different bands**:

```
Layer 1  Date headers          "Aug-11 Tue", "Week 33 Totals"
Layer 2  Bookmark icons        "bookmark_border"
Layer 3  Product data rows     S.O. / ADJ / F.O. / SFO cell stacks
Layer 4  Grand totals row      large aggregate numbers
```

A run typically sees ~64 elements where only 14 are meaningful product columns. Naïve index arithmetic across that flat list is where most scraper attempts die.

#### The solution: classify by structure, pair by position

**Step 1 — taxonomy (1009-1034).** Each column is classified by *what it contains*, not where it sits:

| Class | Test |
|---|---|
| bookmark | text contains `bookmark` |
| product data | contains a `.cell.fo` child |
| header | matches `[A-Za-z]{3}-\d{1,2}` or contains `Week`/`Totals`, **and has no `.cell.fo`** |
| other | everything else (grand totals) |

The `.cell.fo` test is the discriminator, and the `and not has_fo_cell` clause on headers is what keeps "Week 33 Totals" *header* cells from being confused with the product-layer totals column.

**Step 2 — week-total elimination by sequence position (1036-1076).** Week-total columns appear in both the header band and the product band at the *same ordinal position*. The reader records those positions while parsing headers (`header_week_total_positions`) and then drops the same sequence positions from the product band. This is why the logs read:

```
Skipping product col 39 (seq 7) as week total
Skipping product col 47 (seq 15) as week total
```

**Step 3 — position-symmetry pairing (1089-1093).** After elimination, header *n* corresponds to product column *n*. The two bands are zipped by ordinal position, not by any shared ID — because the DOM provides none.

**Step 4 — temporal anchoring (1078-1082).** "Today" is the header carrying the CSS class `current`. Everything else derives from it: `is_past`, `is_future`, and `offset_from_today`. The tool never trusts the system clock to locate today's column on the grid — it asks the grid.

#### Cell-level extraction (1100-1207)

Per paired column, three cells are read with a consistent defensive pattern — *text first, input value as fallback, zero as floor*:

- **F.O.** (`.cell.fo`): first line of text only (the cell can carry a second line).
- **S.O.** (`.cell.so`): text, falling back to `input[value]`.
- **ADJ** (`.cell.adj`): the class string is inspected to determine state.

The **lock taxonomy** (1147-1150) is the load-bearing logic:

```python
if has_filler or "unadjustable" in adj_class_str:   is_locked = True
elif "adjustable" in adj_class_str:                 is_adjustable = True
```

A `.filler-button` sibling *or* the `unadjustable` class means the cell is committed — the order is already locked in and must not be touched. Only an explicitly `adjustable` cell is writable.

Each column emits a single-line `[DEBUG]` record showing date, position, past/today/future, S.O., raw and parsed F.O., raw and parsed ADJ, lock state, filler presence, the raw class string, and the DOM column index. **This is the single most valuable diagnostic in the system** — when the vendor changes the UI, a diff of these lines localizes the change immediately.

#### Classification into the output contract (1170-1207)

| Bucket | Condition | Consumed by |
|---|---|---|
| `delivered_dates` | (past or today) and F.O. > 0 | token sync — becomes physical inventory |
| `pipeline_incoming` / `locked_dates` | future and F.O. > 0 and locked | the MLP's pipeline feature |
| `adjustable_dates` | cell is adjustable | the dates the MLP may decide on |

Plus two page-level scrapes: **tray factor** via `TF (\d+)` (1209-1215) and the **4-week return rate** via a `%` match (1219-1226).

Everything is returned in **raw pieces**. No tray multiplication ever crosses this boundary — a rule stated in the docstring and honoured by both the reader and the writers.

### 4.7 Cell-state detection, the general case (`is_cell_greyed`, lines 830-868)

A broader lock detector used by `scrape_product_row`, checking in order: class tokens (`unadjustable`/`committed`/`locked`) → `readonly`/`disabled` attributes → `aria-disabled`/`aria-readonly` → `data-locked`/`data-committed`. Five independent ways a portal might express "you can't edit this," because the vendor has used more than one over time.

### 4.8 Week navigation (`_find_week_form_field` → `navigate_to_week`, lines 1263-1587)

The portal has several `mat-select` dropdowns (Route, Customers, Week). Selecting the wrong one silently changes the store or route — a serious failure mode. `_find_week_form_field` (1263-1315) therefore identifies it three ways in priority order:

1. `mat-form-field.week` (class anchor)
2. `mat-select[formcontrolname='week']` (form binding)
3. Scan every `mat-form-field` for a `mat-label` whose text is exactly `'Week'`

`_select_week_option` (1393-1493) then has to find the *options*, which Angular Material renders in a **CDK overlay** attached to the document body — not inside the form field. Three fallbacks: visible `.cdk-overlay-pane` → known panel classes/`[role='listbox']` → global visible `mat-option` scan. When all fail, it dumps the state of every overlay pane before giving up (1459-1466), then dismisses overlays so the page isn't left in a broken state.

Option matching is anchored (`^(\d+)`) so that "3" never matches "32", and the current-week label ("32 (Current)") parses correctly.

### 4.9 The extended read — solving the 7-day lead time (`read_pipeline_extended`, lines 1589-1709)

**The problem.** The demo rye SKU has a 7-day lead time. The portal shows a two-week window. On a Friday, every cell inside the current window is already locked — the only writable cells for a 7-day-lead product live on *next week's* view. A reader that only ever looks at the current week concludes "nothing to order" and the product silently starves.

**The solution**, optimized to at most one week switch:

1. Read the current week — this yields delivered dates, locked pipeline, and inventory context.
2. Measure the furthest adjustable date: `max_future_offset`.
3. If that already covers `required_future_days`, return immediately with `week_navigation_used=False`. **No unnecessary navigation.**
4. Otherwise navigate to week *N+1*, wait for re-render, and read again.
5. **Replace** `adjustable_dates` wholesale with the new week's (line 1688) — the old week's are all locked, so there is nothing to merge. **Merge** locked dates additively, adding their F.O. to `pipeline_incoming` (1690-1694).
6. **Deliberately stay on week N+1** and tell the caller so, via `currently_on_week`.

Step 6 is critical and the reason for the log line *"Browser stays on week N — write here, submit, then return."* Column indices are **DOM positions on a specific rendered week**. Navigating away invalidates every index the reader just produced. The contract is: the reader leaves the browser exactly where the writes must happen.

Failure of the extended read is non-fatal (1680-1686): it navigates back and returns the original data with a warning flag.

### 4.10 Verified writes — the anti-lie mechanism (lines 1822-2023)

The most important behavioural property in the file.

**The failure it defends against:** the grid, when "cold" (freshly rendered, Angular still binding), silently drops keystrokes. The cell shows the old value. Selenium reports success — it did send the keys. Without verification, the pipeline would log "ordered 36" while the portal holds `0`, and the shelf would be empty a week later with a green log file saying everything was fine.

**The mechanism** (`write_adj_cell_by_index`, 1848-1940):

```
for attempt in 1..3:
    re-find the column fresh by index      (avoids stale element references)
    scroll into view
    click the cell
    locate input[inputmode='numeric'][apphubcell], falling back to any <input>
    clear() → send_keys(value) → RETURN
    read the value back from the DOM
    if read_back == intended:  return success(attempt=N)
    else: log the mismatch, retry
return failure(value_read_back=..., wanted=...)
```

`_read_committed_cell_value` (1822-1846) performs the read-back by **re-querying from `.div-content.day` every time** rather than reusing the element handle — a write re-renders the grid and stale handles throw. It mirrors the reader's parsing exactly (blank adjustable cell counts as `0`) so the verification is apples-to-apples, and returns `None` only for a genuine structural failure, which is distinguishable from a legitimate `0`.

The failure return carries **both** what was wanted and what was actually read — the alert email tells you the discrepancy, not just that something went wrong.

`write_so_cell_by_index` (1942-2023) is the identical pattern targeting `.cell.so.adjustable`. It exists so the MLP can zero the standing order and **fully own** the final order: with `S.O.=0`, `F.O. = ADJ` exactly, rather than the model's decision being added on top of a human-configured standing order.

Both writers are addressed by **`column_index`** — the raw index into the `.div-content.day` list carried over from the read that produced it. This is the tightest possible coupling between read and write, and it is intentional: the tool writes to the exact DOM position it read, with no re-derivation and no date re-matching in between.

### 4.11 The submit chain — three gates (lines 2025-2411)

Submitting is the irreversible act, so it has the most armor.

**Gate 1 — the green counter button** (`find_green_submit_button`, 2025-2074). Five selectors from most to least specific, plus a parent-class verification (`"counter" in classes and "green" in classes`) to avoid clicking some other green button.

`click_green_submit_button` (2076-2139) counts `app-changed-orders` elements **before and after** the click. If the count didn't increase, no popup appeared — meaning there were no pending changes — and it says so honestly rather than pretending to submit. It also detects the explicit "no orders" state and dismisses cleanly.

**The popup scrape** (`_extract_popup_orders`, 2141-2178) reads back every changed row — customer, product, S.O., ADJ, F.O. — which is what produces the log lines:

```
Row 1: Product 500107, S.O.=0, ADJ=36, F.O.=36
```

This is a **pre-commit audit**: the portal's own account of what is about to be submitted, captured before the irreversible click, and it is the last chance to catch a mismatch between intent and reality.

**Gate 2 — the second dialog** (`_handle_vendor_confirmation_dialog`, 2245-2410). The hardest DOM problem in the submit path, and the docstring diagrams it (2248-2266):

```
cdk-overlay-container
  ├─ cdk-overlay-pane   ← first overlay (app-changed-orders popup)
  └─ cdk-overlay-pane   ← SECOND overlay (the confirmation dialog) — LAST in DOM
       └─ mat-dialog-container → app-dialog → div.actions
            ├─ button.mat-primary  (Submit)
            └─ button.mat-warn     (Cancel)
```

Both overlays contain a button whose text is "Submit." Searching the document for "the Submit button" finds the *first* one and re-clicks the popup — a hang, or worse. So the tool **iterates overlay panes in reverse** (`for overlay in reversed(all_overlays)`), takes the last visible one containing a `mat-dialog-container` or `app-dialog`, and scopes every subsequent query **inside that overlay**. Seven scoped selectors, then a full button scan within the overlay, then a `'submit changes'` text match as a last resort — and it logs the overlay's text preview so a vendor copy change is visible in the logs.

**Gate 3 — success dialog + closure verification** (2383-2406). After the final click it closes the "Success!" dialog (`_close_success_dialog`, 2412-2458 — tolerant of auto-close) and then **verifies both overlays are actually gone**, checking `app-changed-orders` and any visible `mat-dialog-container`/`app-dialog`. The result distinguishes *"Submission confirmed (both dialogs closed)"* from *"Final submit clicked but dialogs may still be visible."* Honest reporting over optimistic reporting, again.

### 4.12 `_force_click` — the escalation ladder (lines 2460-2563)

Angular Material buttons nest several spans (ripple, focus-indicator, touch-target) that intercept clicks. This helper first locates the inner `span.mdc-button__label` — the element that actually receives real user clicks — then runs **six strategies in escalating order**:

| # | Strategy |
|---|---|
| 1 | Full JS pointer sequence (`pointerdown`/`mousedown`/`pointerup`/`mouseup`/`click`) on label **and** button |
| 2 | ActionChains `move_to_element` + `click` (real browser-level input) |
| 3 | JS `focus()` + `click()` |
| 4 | Coordinate-based pointer events computed from `getBoundingClientRect()` |
| 5 | Selenium native `click()` |
| 6 | `Enter` keypress on the focused button |

Strategy 1 is first because it reproduces the *complete* event sequence a real click generates, which is what Angular's event handlers listen for — a bare `.click()` often fires nothing useful. The ladder runs to completion rather than stopping at the first success, because "executed without throwing" is not proof the framework reacted; the caller verifies the *outcome* (dialogs closed) rather than trusting the click.

---

## 5. Cross-cutting hardening patterns

These recur throughout the file and are the real "house style."

**1. Layered selectors, class-anchor first.** Every important element has 3-7 selectors ordered by durability: structural class → framework binding → copy text → brute-force scan. Cosmetic vendor changes degrade one rung instead of breaking the run.

**2. Verify state, never assume it.** Writes are read back. Submissions are confirmed by dialog disappearance. Store switches are confirmed by placeholder text. The pipeline reads the grid *twice* after submitting.

**3. Re-query, never cache elements.** Any DOM mutation invalidates handles. The read-back helper re-finds columns from the root every single time — the disciplined answer to `StaleElementReferenceException`.

**4. Fail loudly, fail *specifically*.** Failure paths dump evidence: every input's fingerprint, every overlay's text, every button's classes, the read-back value alongside the intended one. The design target is that a 3AM failure email is actionable without reproducing the failure.

**5. Bounded retries with backoff, never infinite loops.** Writes retry 3×; store-switch confirmation polls 3×. A hung daemon is worse than a failed one.

**6. Degrade rather than die.** Extended-read failure returns partial data. A missing grid is a warning; a missing store input is fatal. The severity assignment reflects what actually blocks ordering.

**7. Structured returns, never bare booleans.** Methods return dicts carrying `success`, the value written, the value read back, attempt counts, and human-readable messages — which is what makes the decision log and alert emails informative.

**8. Timing entropy without identity change.** Randomized dwells and daemon jitter, never a rotating or falsified identity.

---

## 6. The data contract

What crosses the boundary to the rest of the system — all in **raw pieces**, no tray math:

**Scraper → bridge** (`read_pipeline` return):

| Key | Type | Consumer |
|---|---|---|
| `pipeline_incoming` | int | MLP pipeline feature |
| `locked_dates` | `{date: {fo_value, column_index, date_position}}` | per-date pipeline split |
| `adjustable_dates` | `[{date, dow, column_index, offset_from_today, fo_value, current_adj, current_so, date_position}]` | the dates the MLP decides on |
| `delivered_dates` | `[{date, dow, fo_value, adj_value, total_delivered}]` | token sync → inventory |
| `tray_factor_detected`, `four_week_return_pct`, `today`, `today_position` | — | context / logging |

**Bridge → scraper:** just `column_index` + the integer to write. The decision dict carries the index straight back from the read that produced it.

---

## 7. Failure taxonomy & diagnostics

### 7.1 Bot challenge vs. UI change (`_report_cloudflare_block`, lines 160-182)

The killer diagnostic. Both failure modes look identical to Selenium: a timeout waiting for the store input. But the fixes are completely different — one means "the browser-presentation posture regressed," the other means "the vendor changed their HTML."

So on hub-load failure the tool inspects the page title and source for challenge markers (`just a moment`, `challenge-platform`, `checking your browser`, `attention required`) and sets `last_block_kind` to one of:

- **`cloudflare`** — logs that Chrome must run headful via Xvfb, never `--headless`.
- **`ui_change`** — logs that this is likely a genuine UI revision and names the selector to inspect.
- **`unknown`** — diagnostic itself failed.

The daemon surfaces this in its alert. A blind timeout becomes a triaged incident.

### 7.2 Known failure modes and their signatures

| Symptom | Meaning | Fix |
|---|---|---|
| Store input never clickable + `last_block_kind='cloudflare'` | bot challenge on the live portal | re-satisfy the check into the persistent profile; confirm no `--headless` |
| Same + `last_block_kind='ui_change'` | vendor changed the store input | update the `formcontrolname='customer'` selector |
| `No filter input matched. Page inputs: [...]` | filter selector changed | pick the new selector from the logged fingerprint |
| Write returns `read_back != wanted` after 3 attempts | cold-grid keystroke loss or a genuinely locked cell | usually transient; re-run the product |
| `Found confirmation overlay but no Submit button inside it` | confirmation dialog restructured | update the scoped selector list; overlay text preview is in the log |
| `Week N not found in dropdown. Available: [...]` | week range shifted or wrong dropdown found | check `_find_week_form_field` matched the Week field |
| Grid layer counts look wrong in the log | grid structure changed | diff the `[DEBUG]` lines against a known-good run |

---

## 8. Security posture

- **No credentials in source.** The session token and hub URL resolve at import time from the environment via `hub_config` (lines 22-28), with resolution order: process env → repo `.env`. Absent both, a harmless placeholder keeps imports and the mock-hub demo working while making real auth impossible.
- **URLs are masked in logs** (`mask_url`) so the session token never lands in a log file or a screen recording.
- **Rotation is config-only** — replace `HUB_SESSION_TOKEN` in the env file; no code change, no redeploy.
- **`token_is_placeholder()`** lets callers refuse to attempt a live run with a non-functional token.

---

## 9. Design trade-offs, stated honestly

**Column indices are fragile by nature.** A `column_index` is meaningful only on the exact week view it was read from. The mitigation is architectural — the reader leaves the browser on the write week and reports `currently_on_week` — rather than defensive. An alternative (re-deriving columns by date at write time) would be more robust but would double the DOM work and introduce its own date-matching failure mode. The current approach is faster and its failure mode is loud.

**The tool is slow on purpose.** A 7-date write cycle takes ~2 minutes: verified writes with read-backs, human-like dwells, and generous settles. Speed is worthless here; correctness is everything, and haste is also a machine-shaped signal.

**Wide `except:` clauses.** Common in the cell-parsing paths. Deliberate: a single malformed cell must never abort a whole grid read. The trade-off is that genuine bugs can hide — which is why the `[DEBUG]` per-column logging exists as the compensating control.

**Two overlapping write paths.** The v1 offset-based path (`click_adj_cell`/`place_order`) and the v2 index-based path (`write_*_cell_by_index`) coexist. v1 serves interactive/LLM use with human-friendly date offsets; v2 serves the autonomous pipeline. Consolidating them would cost the interactive ergonomics.

**Print statements alongside logging.** Residue from live debugging sessions in the v1 paths. Harmless, and honestly useful when driving the tool interactively.

---

## 10. Method reference

### `OrderHubTool` — session & primitives

| Method | Line | Role |
|---|---|---|
| `setup_driver` | 50 | Xvfb + headful Chrome + presentation flags + persistent profile |
| `navigate_to_ordering_hub` | 105 | load the hub, gate on readiness |
| `_wait_for_hub_ready` | 126 | 3-signal readiness ladder + jittered settle |
| `_report_cloudflare_block` | 160 | bot-challenge vs. UI-change triage |
| `_wait_for_page_ready` | 184 | post-navigation grid-render wait |
| `_dismiss_overlays` | 199 | body click + ESCAPE |
| `switch_to_store` | 214 | store autocomplete selection |
| `_wait_for_store_switch` | 287 | 3-ladder switch confirmation |
| `search_product` | 335 | filter with layered selectors + input fingerprint on failure |
| `find_adj_row` | 394 | locate a product's ADJ row (v1) |
| `click_single_adj_cell` | 413 | click + type into a cell element (v1) |
| `click_adj_cell_in_column` | 446 | find + write the adjustable cell in a column (v1) |
| `click_adj_cell` | 498 | offset-addressed write from the `current` anchor (v1) |
| `place_order` | 604 | full interactive order flow (v1 / LLM path) |
| `close` | 723 | quit driver + stop Xvfb |

### `OrderHubScraper` — reading, navigation, verified writes, submit

| Method | Line | Role |
|---|---|---|
| `get_day_columns_with_dates` | 749 | column→date mapping (data-date → child element → text regex) |
| `is_cell_greyed` | 830 | 5-way lock detection |
| `scrape_product_row` | 870 | per-product all-dates + greyed-cells snapshot |
| **`read_pipeline`** | **954** | **the grid reader — 4-layer taxonomy, position pairing, cell extraction** |
| `_find_week_form_field` | 1263 | disambiguate the Week dropdown from Route/Customers |
| `get_current_week_number` | 1316 | current week + is-current flag |
| `_find_week_dropdown` | 1363 | locate the clickable dropdown trigger |
| `_select_week_option` | 1393 | pick a week from the CDK overlay |
| `navigate_to_week` | 1495 | go to a specific week (early-exit if already there) |
| `navigate_week` | 1558 | relative ±1 week with 1↔53 wrap |
| **`read_pipeline_extended`** | **1589** | **long-lead week hop; leaves browser on the write week** |
| `_submit_and_confirm` | 1711 | internal submit+confirm for per-week flows |
| `write_and_submit_on_current_week` | 1739 | batch write + submit on the current view |
| `_read_committed_cell_value` | 1822 | fresh re-query read-back for verification |
| **`write_adj_cell_by_index`** | **1848** | **verified ADJ write, 3 attempts** |
| **`write_so_cell_by_index`** | **1942** | **verified S.O. zeroing, 3 attempts** |
| `find_green_submit_button` | 2025 | 5 selectors + parent-class verification |
| `click_green_submit_button` | 2076 | click + before/after popup detection + scrape |
| `_extract_popup_orders` | 2141 | pre-commit audit of changed rows |
| `confirm_popup_submit` | 2180 | first Submit, then hand off to the second dialog |
| `_find_submit_button_in` | 2214 | scoped Submit lookup |
| **`_handle_vendor_confirmation_dialog`** | **2245** | **last-overlay targeting for the second dialog** |
| `_close_success_dialog` | 2412 | close the Success! dialog (tolerant of auto-close) |
| **`_force_click`** | **2460** | **6-strategy click escalation ladder** |
| `dismiss_popup` / `_dismiss_popup` | 2565 / 2573 | close popup without confirming |
| `scrape_committed_orders` | 2582 | committed-order snapshot for baseline comparison |

---

## 11. Seeing it work

The demo mock hub reproduces the exact DOM contract this tool depends on — the four grid layers, the lock classes, the CDK overlay dialog stack, the week dropdown — so the unmodified tool drives it the same way it drives the production portal:

```bash
# terminal 1 — the mock hub
python demo/mock-ordering-hub/serve.py

# terminal 2 — the pipeline, visible browser
python -m tests.run_pipeline_autonomous --mode live --visible --force-extended
```

Watch for these beats in the log, each one a section above: the store switch (§4.4), the week hop for the 7-day lead (§4.9), `Zeroed S.O.` then `Wrote ADJ ... (verified, attempt 1/3)` (§4.10), the popup audit rows (§4.11), and `Submission confirmed (both dialogs closed)`.

---

## 12. Summary — why this file is the way it is

Strip away the details and the file is an answer to one question: **how do you let an autonomous model act on the physical world through a UI built for humans, that you don't own, that actively resists automation, when nobody is watching and mistakes cost money?**

The answer, encoded here:

1. **Look like a legitimate human session** — because the portal will not talk to anything else. Headful behind Xvfb, persistent trusted profile, suppressed automation tells, jittered timing, unchanging identity.
2. **Never assume the DOM means what it looks like** — classify structurally, pair positionally, anchor on the portal's own "today," and test the same thing five ways.
3. **Never trust your own writes** — read every one back, retry, and report the discrepancy when it doesn't match.
4. **Never claim more than you verified** — "submitted" means both dialogs closed and a re-read of the grid confirms the value.
5. **When you break, say exactly how** — bot challenge or UI change, which selector, what was read versus what was wanted.

Everything in these 2,643 lines is one of those five ideas applied to a specific piece of someone else's Angular application.
