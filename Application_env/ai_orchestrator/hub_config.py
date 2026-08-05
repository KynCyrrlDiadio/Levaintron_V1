#!/usr/bin/env python3
"""
Ordering-hub integration config — single source of truth for the ordering-hub session
token and URL.

DEMO BUILD: the "hub" is the local mock ordering hub (demo/mock-ordering-hub/),
which needs no authentication — the session token stays at its harmless
placeholder and the URL defaults to http://127.0.0.1:8099/index.html. The
resolution machinery is kept identical to production so the code reads the
same; only the defaults differ.

Resolution order (first hit wins), for the token and every other key:
  1. process environment (already-exported vars)
  2. ``.env`` at the repo root

Importable symbols:
  HUB_SESSION_TOKEN        the resolved token string
  HUB_BASE_URL             the ordering-hub base URL (no query string)
  ORDERING_HUB_URL         base + ``?hash=<token>`` — what the scraper navigates to
  build_ordering_hub_url() build the URL for an arbitrary token (defaults to the
                           resolved one)
  token_is_placeholder()   True when no real token was found (guards live runs)

Point at a different hub instance by setting ``HUB_BASE_URL`` in ``.env`` —
no code change needed.
"""

import os
from pathlib import Path

__all__ = [
    'HUB_SESSION_TOKEN',
    'HUB_BASE_URL',
    'ORDERING_HUB_URL',
    'build_ordering_hub_url',
    'token_is_placeholder',
    'mask_url',
    'mask_hash',
    'PLACEHOLDER_HASH',
]

# Returned when no real token is configured. Also the value baked into the
# filming-safe copy — keep it obviously non-functional.
PLACEHOLDER_HASH = 'SESSION_HASH_REDACTED_FOR_DEMO'

# repo root = two levels up from Application_env/ai_orchestrator/
_REPO_ROOT = Path(__file__).resolve().parents[2]

# Candidate env files, lowest priority first (later files do NOT override a key
# already present from the process environment or an earlier file).
_ENV_FILE_CANDIDATES = [
    _REPO_ROOT / '.env',
]


def _parse_env_file(path: Path) -> dict:
    """Minimal KEY=VALUE parser (matches the baselinebot.env / systemd format).

    Handles ``# comments``, blank lines, ``export KEY=...`` prefixes, and single
    or double quoted values. No dependency on python-dotenv.
    """
    out = {}
    try:
        text = path.read_text(encoding='utf-8')
    except (OSError, UnicodeDecodeError):
        return out
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        if line.startswith('export '):
            line = line[len('export '):]
        key, _, value = line.partition('=')
        key = key.strip()
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in ('"', "'"):
            value = value[1:-1]
        if key:
            out[key] = value
    return out


def _load_config() -> dict:
    """Merge process env over the candidate files (process env wins)."""
    merged = {}
    for path in _ENV_FILE_CANDIDATES:
        for k, v in _parse_env_file(path).items():
            merged.setdefault(k, v)   # first file to set a key keeps it
    # Process environment always wins over any file.
    merged.update({k: v for k, v in os.environ.items()})
    return merged


_CONFIG = _load_config()


def _get(key: str, default: str = '') -> str:
    val = _CONFIG.get(key)
    return val if val not in (None, '') else default


# ── Resolved values ──────────────────────────────────────────────────────────
# Resolved from HUB_SESSION_TOKEN in the environment or .env; falls back to the
# placeholder, which keeps imports and the mock-hub demo working.
HUB_SESSION_TOKEN = _get('HUB_SESSION_TOKEN') or PLACEHOLDER_HASH
# Demo default: the local mock ordering hub (see demo/mock-ordering-hub/).
HUB_BASE_URL = _get('HUB_BASE_URL', 'http://127.0.0.1:8099/index.html')


def build_ordering_hub_url(session_hash: str = None, base_url: str = None) -> str:
    """Build the ordering-hub URL for a token (defaults to the resolved one)."""
    h = session_hash or HUB_SESSION_TOKEN
    base = base_url or HUB_BASE_URL
    return f"{base}?hash={h}"


def token_is_placeholder() -> bool:
    """True when no real token is configured — callers should refuse live runs."""
    return HUB_SESSION_TOKEN == PLACEHOLDER_HASH


def mask_hash(value: str) -> str:
    """Redact a token for safe display: keep 3 head + 2 tail chars, star the rest.

    ``Ab1XyZexampleTOKEN0000000000000000`` -> ``Ab1…00`` (never the placeholder,
    which is shown verbatim so demo logs read clearly)."""
    if not value or value == PLACEHOLDER_HASH:
        return value or ''
    if len(value) <= 6:
        return '…'
    return f"{value[:3]}…{value[-2:]}"


def mask_url(url: str) -> str:
    """Return *url* with any ``hash=<token>`` query value masked for logging.

    Safe to print to stdout / journald / on camera — the live token never
    appears. The placeholder is left readable so demo output stays legible."""
    if not url or 'hash=' not in url:
        return url
    head, _, tail = url.partition('hash=')
    # token runs until the next query separator, if any
    for sep in ('&', '#'):
        if sep in tail:
            token, sep_char, rest = tail.partition(sep)
            return f"{head}hash={mask_hash(token)}{sep_char}{rest}"
    return f"{head}hash={mask_hash(tail)}"


ORDERING_HUB_URL = build_ordering_hub_url()
