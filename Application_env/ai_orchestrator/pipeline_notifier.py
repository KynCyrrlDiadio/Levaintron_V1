#!/usr/bin/env python3
"""
Levaintron Pipeline Notifier — emails a detailed MLP decision/write summary
after every autonomous pipeline run.

Reuses the Baseline BaselineBot email scheme (SMTP via env vars, paired plain-text +
HTML bodies, graceful "not configured" fallback) but is self-contained so the
demo pipeline stays import-light.

Env vars (autoloaded from the repo-root .env
here for manual runs): SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM,
NOTIFICATION_EMAIL.
"""

import os
import sys
import json
import smtplib
import argparse
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime
from pathlib import Path

# Auto-load the repo-root .env for any SMTP vars not already in the environment.
# Demo build: no system env file — SMTP is optional and silently skipped when
# unconfigured.
_ENV_FILE = Path(__file__).resolve().parents[2] / '.env'
if _ENV_FILE.exists():
    try:
        for _line in _ENV_FILE.read_text().splitlines():
            _line = _line.strip()
            if not _line or _line.startswith('#') or '=' not in _line:
                continue
            _key, _val = _line.split('=', 1)
            _val = _val.strip()
            if len(_val) >= 2 and _val[0] == _val[-1] and _val[0] in ('"', "'"):
                _val = _val[1:-1]
            if _key not in os.environ:
                os.environ[_key] = _val
    except Exception:
        pass


def send_email(subject, text_body, html_body=None):
    """Send email via SMTP. Mirrors Baseline BaselineBot notifier.send_email."""
    smtp_host = os.environ.get('SMTP_HOST', 'smtp.gmail.com')
    smtp_port = int(os.environ.get('SMTP_PORT', 587))
    smtp_user = os.environ.get('SMTP_USER')
    smtp_pass = os.environ.get('SMTP_PASS')
    email_to = os.environ.get('NOTIFICATION_EMAIL')
    email_from = os.environ.get('SMTP_FROM', smtp_user)

    if smtp_pass:
        smtp_pass = smtp_pass.replace(' ', '')  # Gmail app pw works with/without spaces

    if not all([smtp_user, smtp_pass, email_to]):
        missing = [k for k, v in (('SMTP_USER', smtp_user),
                                  ('SMTP_PASS', smtp_pass),
                                  ('NOTIFICATION_EMAIL', email_to)) if not v]
        print(f"Email not configured — missing: {', '.join(missing)}", file=sys.stderr)
        print("Would have sent:\n" + text_body, file=sys.stderr)
        return False

    msg = MIMEMultipart('alternative')
    msg['Subject'] = subject
    msg['From'] = email_from
    msg['To'] = email_to
    msg.attach(MIMEText(text_body, 'plain'))
    if html_body:
        msg.attach(MIMEText(html_body, 'html'))

    try:
        with smtplib.SMTP(smtp_host, smtp_port) as server:
            server.starttls()
            server.login(smtp_user, smtp_pass)
            server.sendmail(email_from, [email_to], msg.as_string())
        print(f"Pipeline summary email sent to {email_to}", file=sys.stderr)
        return True
    except Exception as e:
        print(f"Failed to send pipeline summary email: {e}", file=sys.stderr)
        return False


# ── Decision field extraction (defensive — fields vary by code path) ──────────

def _decision_view(d):
    """Normalize one decision dict into the fields the email cares about."""
    qty = d.get('final_decision', 0) or 0
    inputs = d.get('inputs', {}) or {}
    stock = d.get('projected_stock_at_delivery')
    if stock is None:
        stock = inputs.get('current_stock')
    conf = d.get('confidence')
    action = d.get('otto_action', '?')
    verified = d.get('verified')

    if action == 'failed':
        status = 'WRITE FAILED'
    elif action == 'submitted':
        status = 'submitted ✓' if verified else 'submitted / NOT VERIFIED'
    elif action == 'written':
        status = 'written'
    elif action == 'skipped':
        status = 'skipped'
    else:
        status = action

    wx = inputs.get('outdoor_score') if inputs.get('weather_aware') else None

    return {
        'date': d.get('delivery_date', '?'),
        'qty': qty,
        'action': 'HOLD' if qty == 0 else f'ORDER {qty}',
        'stock': stock,
        'conf': conf,
        'method': d.get('method', '?'),
        'status': status,
        'failed': action == 'failed',
        'wx': wx,
    }


def _aggregate(results, product_names=None):
    """Compute run-level rollups from the results dict."""
    product_names = product_names or {}
    products = []
    total_ordered = 0
    total_failures = 0
    any_submitted = False

    for pid, r in results.items():
        r = r or {}
        decs = [_decision_view(d) for d in (r.get('decisions_data') or [])]
        ordered_pcs = sum(v['qty'] for v in decs
                          if v['qty'] > 0 and not v['failed'])
        fails = sum(1 for v in decs if v['failed']) or r.get('failed', 0) or 0
        total_ordered += ordered_pcs
        total_failures += fails
        if r.get('submitted'):
            any_submitted = True
        products.append({
            'id': pid,
            'name': product_names.get(pid, pid),
            'success': r.get('success', False),
            'error': r.get('error'),
            'written': r.get('written', 0),
            'failed': fails,
            'verified': r.get('verified'),
            'submitted': bool(r.get('submitted')),
            'ordered_pcs': ordered_pcs,
            'decisions': decs,
        })

    return {
        'products': products,
        'total_ordered': total_ordered,
        'total_failures': total_failures,
        'any_submitted': any_submitted,
        'n_products': len(products),
        'n_success': sum(1 for p in products if p['success']),
    }


def _fmt_conf(c):
    return f"{c:.0%}" if isinstance(c, (int, float)) else "?"


def _fmt_stock(s):
    return f"{s:.1f}" if isinstance(s, (int, float)) else str(s if s is not None else "?")


def format_summary_text(run_id, agg, mode, error=None):
    L = []
    L.append("=" * 64)
    L.append("LEVAINTRON PIPELINE SUMMARY")
    L.append(f"Run: {run_id}")
    L.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    L.append(f"Mode: {mode.upper()}")
    L.append(f"Products: {agg['n_success']}/{agg['n_products']} ok | "
             f"Ordered: {agg['total_ordered']} pcs | "
             f"Write failures: {agg['total_failures']} | "
             f"Submitted: {'YES' if agg['any_submitted'] else 'no'}")
    L.append("=" * 64)

    if error:
        L.append("")
        L.append("!!! PIPELINE ERROR !!!")
        L.append(str(error))
        L.append("")

    if agg['total_failures']:
        L.append("")
        L.append(f"!!! {agg['total_failures']} WRITE FAILURE(S) — The hub did not accept these values:")
        for p in agg['products']:
            for v in p['decisions']:
                if v['failed']:
                    L.append(f"    {p['name']} ({p['id']})  {v['date']}  wanted {v['action']}")
        L.append("    -> re-run the affected product(s).")

    for p in agg['products']:
        L.append("")
        L.append(f"PRODUCT: {p['name']} ({p['id']})")
        L.append("-" * 64)
        if not p['success'] and not p['decisions']:
            L.append(f"  Status: FAILED — {p['error'] or 'unknown error'}")
            continue
        ver = p['verified']
        L.append(f"  written={p['written']} failed={p['failed']} "
                 f"verified={ver if ver is not None else '-'} "
                 f"submitted={'YES' if p['submitted'] else 'no'} "
                 f"ordered={p['ordered_pcs']} pcs")
        if not p['decisions']:
            L.append("  (no adjustable delivery dates this run)")
            continue
        L.append("  Decisions:")
        for v in p['decisions']:
            wx = f" wx={v['wx']:.3f}" if isinstance(v['wx'], (int, float)) else ""
            L.append(f"    {v['date']:<12} {v['action']:<9} "
                     f"stock={_fmt_stock(v['stock']):<6} conf={_fmt_conf(v['conf']):<5} "
                     f"{v['method']:<16} [{v['status']}]{wx}")

    L.append("")
    L.append("=" * 64)
    L.append("Automated message from the Levaintron autonomous ordering pipeline.")
    L.append("=" * 64)
    return "\n".join(L)


def format_summary_html(run_id, agg, mode, error=None):
    H = []
    H.append("""<html><head><style>
        body { font-family: Arial, sans-serif; margin: 20px; color:#222; }
        h1 { color:#333; border-bottom:2px solid #6f4e37; padding-bottom:8px; }
        .meta { color:#555; font-size:13px; }
        .product { background:#f8f9fa; padding:12px 15px; margin:12px 0;
                   border-radius:5px; border-left:4px solid #6f4e37; }
        .pname { font-size:16px; font-weight:bold; }
        table { border-collapse:collapse; width:100%; margin:8px 0; font-size:13px; }
        th,td { border:1px solid #ddd; padding:5px 9px; text-align:left; }
        th { background:#6f4e37; color:#fff; }
        .order { color:#28a745; font-weight:bold; }
        .hold { color:#777; }
        .fail-banner { background:#f8d7da; border:2px solid #dc3545; padding:12px;
                       margin:14px 0; border-radius:5px; }
        .fail-banner h2 { color:#721c24; margin:0 0 6px 0; }
        .err-banner { background:#fff3cd; border:2px solid #ffc107; padding:12px;
                      margin:14px 0; border-radius:5px; }
        .stfail { color:#dc3545; font-weight:bold; }
        .stok { color:#28a745; }
        .footer { margin-top:24px; padding-top:10px; border-top:1px solid #ddd;
                  color:#666; font-size:12px; }
    </style></head><body>""")
    H.append("<h1>Levaintron Pipeline Summary</h1>")
    H.append(f'<p class="meta"><b>Run:</b> {run_id} &nbsp;|&nbsp; '
             f'<b>Generated:</b> {datetime.now().strftime("%Y-%m-%d %H:%M:%S")} &nbsp;|&nbsp; '
             f'<b>Mode:</b> {mode.upper()}</p>')
    H.append(f'<p class="meta"><b>{agg["n_success"]}/{agg["n_products"]}</b> products ok &nbsp;|&nbsp; '
             f'<b>{agg["total_ordered"]} pcs</b> ordered &nbsp;|&nbsp; '
             f'<b>{agg["total_failures"]}</b> write failures &nbsp;|&nbsp; '
             f'Submitted: <b>{"YES" if agg["any_submitted"] else "no"}</b></p>')

    if error:
        H.append(f'<div class="err-banner"><h2>Pipeline Error</h2><pre>{error}</pre></div>')

    if agg['total_failures']:
        H.append(f'<div class="fail-banner"><h2>{agg["total_failures"]} write failure(s) — '
                 'The hub did not accept these values</h2><ul>')
        for p in agg['products']:
            for v in p['decisions']:
                if v['failed']:
                    H.append(f"<li>{p['name']} ({p['id']}) — {v['date']} — wanted {v['action']}</li>")
        H.append("</ul><i>Re-run the affected product(s).</i></div>")

    for p in agg['products']:
        H.append('<div class="product">')
        H.append(f'<div class="pname">{p["name"]} ({p["id"]})</div>')
        if not p['success'] and not p['decisions']:
            H.append(f'<p class="stfail">FAILED — {p["error"] or "unknown error"}</p></div>')
            continue
        ver = p['verified'] if p['verified'] is not None else '-'
        H.append(f'<p class="meta">written={p["written"]} | failed={p["failed"]} | '
                 f'verified={ver} | submitted={"YES" if p["submitted"] else "no"} | '
                 f'ordered={p["ordered_pcs"]} pcs</p>')
        if not p['decisions']:
            H.append('<p class="meta">No adjustable delivery dates this run.</p></div>')
            continue
        H.append('<table><tr><th>Date</th><th>Action</th><th>Stock</th>'
                 '<th>Conf</th><th>Method</th><th>Status</th><th>Wx</th></tr>')
        for v in p['decisions']:
            acls = 'order' if v['qty'] > 0 else 'hold'
            scls = 'stfail' if v['failed'] else 'stok'
            wx = f"{v['wx']:.3f}" if isinstance(v['wx'], (int, float)) else ""
            H.append(f'<tr><td>{v["date"]}</td><td class="{acls}">{v["action"]}</td>'
                     f'<td>{_fmt_stock(v["stock"])}</td><td>{_fmt_conf(v["conf"])}</td>'
                     f'<td>{v["method"]}</td><td class="{scls}">{v["status"]}</td>'
                     f'<td>{wx}</td></tr>')
        H.append('</table></div>')

    H.append('<div class="footer">Automated message from the Levaintron autonomous '
             'ordering pipeline.</div></body></html>')
    return "".join(H)


def send_pipeline_summary(run_id, results, mode='live', product_names=None,
                          error=None, dry_run=False):
    """Build and send the run summary email. Never raises — returns a status dict."""
    try:
        if dry_run:
            return {'success': True, 'email_sent': False, 'reason': 'dry_run'}

        agg = _aggregate(results or {}, product_names)

        date_tag = datetime.now().strftime('%Y-%m-%d')
        if error:
            subject = f"Levaintron run {date_tag}: PIPELINE ERROR"
        else:
            subject = (f"Levaintron run {date_tag}: {agg['n_success']}/{agg['n_products']} products, "
                       f"{agg['total_ordered']} pcs"
                       + (f", {agg['total_failures']} WRITE FAILURES" if agg['total_failures'] else "")
                       + (", submitted" if agg['any_submitted'] else ""))

        text_body = format_summary_text(run_id, agg, mode, error)
        html_body = format_summary_html(run_id, agg, mode, error)
        sent = send_email(subject, text_body, html_body)
        return {'success': True, 'email_sent': sent,
                'failures': agg['total_failures'], 'ordered': agg['total_ordered']}
    except Exception as e:
        print(f"send_pipeline_summary error (non-fatal): {e}", file=sys.stderr)
        return {'success': False, 'error': str(e)}


def main():
    parser = argparse.ArgumentParser(description='Levaintron Pipeline Notifier')
    parser.add_argument('--results-json', help='Path to a JSON file with a run results dict')
    parser.add_argument('--run-id', default='manual_preview')
    parser.add_argument('--mode', default='live')
    parser.add_argument('--preview', action='store_true',
                        help='Print the text body without sending')
    args = parser.parse_args()

    if not args.results_json:
        parser.error('--results-json required')
    with open(args.results_json) as f:
        results = json.load(f)

    if args.preview:
        agg = _aggregate(results)
        print(format_summary_text(args.run_id, agg, args.mode))
    else:
        print(json.dumps(send_pipeline_summary(args.run_id, results, args.mode), indent=2))


if __name__ == '__main__':
    main()
