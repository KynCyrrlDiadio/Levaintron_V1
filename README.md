# Levaintron V1 — Single-Product Demo Build

A fully sanitized, self-contained demo of the autonomous bread-ordering
pipeline: the **MLP inventory bridge**, the **Selenium hub tools**, and the
**pipeline runner**, wired to a **local mock ordering hub** and a dedicated
**demo Postgres database**. One fictional product, real model, real data
shapes.

## The demo product

| | |
|---|---|
| Product | `Demo_500g_Rye_Bread` |
| SKU | `500107` |
| Order classes | `[0, 9, 18, 27, 36]` (tray factor 9) |
| Lead time | 7 days (exercises the week-extension read) |
| Model | `Application_env/ai_orchestrator/models/Demo_500g_Rye_Bread.pt` |

The model weights, seasonal/DOW/week-of-month multipliers, daily forecast,
sales history, and token inventory are the *real* data of a production rye
SKU, re-keyed to the fictional product. Nothing else about the pipeline was
simplified — this is the production machinery with one `PRODUCT_CONFIGS`
entry.

## Safety: fully decoupled from production

- **Database**: reads `DEMO_DATABASE_URL` (default
  `postgresql://postgres:8989@127.0.0.1:5432/levaintron_demo`). It deliberately
  does **not** read `DATABASE_URL`, so it can never inherit a production
  connection string from your shell.
- **Hub**: `HUB_BASE_URL` defaults to the local mock hub
  (`http://127.0.0.1:8099/index.html`). No session token needed.
- No production URLs, credentials, store numbers, or product identities remain
  in code, data, or model metadata.

## Layout

```
Application_env/ai_orchestrator/
  mlp_inventory_bridge.py     MLP bridge v9.0 (single-entry PRODUCT_CONFIGS)
  custom_selenium_order_hub_tools.py   Selenium grid scraper/writer
  hub_config.py              hub URL/token resolution (mock-hub defaults)
  returns_invoice_parser.py   token creation / expiry / returns
  pipeline_notifier.py        optional SMTP summaries (off by default)
  build_forecast_from_sales.py  offline multiplier/forecast builder
  mlp_engine/                 model definition, training, data generator
  database_crumbs/            Postgres layer (InventoryDatabasePG)
  models/Demo_500g_Rye_Bread.pt
  custom_selenium_order_integration_tool.py  hand-built scraper (stage exercise)
  tool_stage_testing.py                      its stage-by-stage live tests
tests/
  run_pipeline_autonomous.py  the pipeline runner (the "only wire")
  pipeline_daemon.py          scheduling daemon (03:00 / 11:30 slots)
  test_full_pipeline_live.py  verbose single-product live walkthrough
demo/mock-ordering-hub/       the mock hub (serve.py, port 8099)
demo_data/
  levaintron_demo.sql         demo database dump (3,920 rows re-keyed)
  setup_demo_db.sh            drop/create/load the demo DB
```

## Setup

```bash
# 1. python deps (venv `levaintron/` already exists in this repo)
source levaintron/bin/activate
pip install -r requirements.txt

# 2. demo database (drops/creates ONLY levaintron_demo)
./demo_data/setup_demo_db.sh

# 3. start the mock hub (own terminal; uses its own `mock_hub` database)
python demo/mock-ordering-hub/serve.py
```

## Run the pipeline

```bash
# preview decisions, no grid writes
python -m tests.run_pipeline_autonomous --mode dry_run --product 500107

# 7-day lead: adjustable cells live on next week's view. The runner hops
# weeks automatically on Fri/Sat; force it on other days:
python -m tests.run_pipeline_autonomous --mode dry_run --product 500107 --force-extended

# live run: writes ADJ cells to the mock hub, submits, verifies, logs
python -m tests.run_pipeline_autonomous --mode live --all-products --force-extended
```

Every decision is logged to `mlp_order_log` in the demo DB; run artifacts go
to `/tmp/levaintron_demo_run_<timestamp>.json`.

## Identity mapping (production → demo)

Every production identity was re-keyed; none appear anywhere in this repo:

| Production | Demo |
|---|---|
| A real rye SKU + product name | SKU 500107 / Demo_500g_Rye_Bread |
| The real banner + portal store numbers | Hub stores 70012004 / 70012002 |
| The production database | levaintron_demo |
| The real ordering portal + session hash | Mock hub, no auth |

## Omitted from the demo

The React dashboard, the LLM orchestrator layer (session manager / tool
registry), the baseline grid monitor, the other 16 product configs and
models, and all production deploy files. The pipeline path itself —
read → token sync → multi-date MLP decisions → verified writes → submit →
log — is complete.
