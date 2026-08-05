"""AI Orchestrator — Levaintron demo build.

Single-product demo of the autonomous ordering pipeline:
MLP inventory bridge + Selenium hub tools + pipeline runner, wired to the
local mock ordering hub and the levaintron_demo Postgres database.

The production build also exposes the LLM session manager / tool registry
here; the demo keeps this package import-light on purpose.
"""
