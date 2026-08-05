#!/usr/bin/env python3
"""hubctl — manage the Mock Ordering Hub demo server.

Usage:
    python hubctl.py status              # show PIDs listening on the hub port
    python hubctl.py kill                # SIGTERM (then SIGKILL) whatever holds the port
    python hubctl.py start               # start `python -m serve` detached, log to hub_server.log
    python hubctl.py restart             # kill + start
    python hubctl.py <cmd> --port 8099   # non-default port

The server is started detached (its own session), so it survives this
terminal closing. Output goes to hub_server.log next to this script.
"""

import argparse
import os
import re
import signal
import socket
import subprocess
import sys
import time
from pathlib import Path

HUB_DIR = Path(__file__).resolve().parent
LOG_FILE = HUB_DIR / "hub_server.log"
DEFAULT_PORT = 8099
DEFAULT_HOST = "127.0.0.1"


# ---------------------------------------------------------------- find PIDs

def _pids_via_ss(port: int) -> set[int]:
    try:
        out = subprocess.run(["ss", "-ltnp"], capture_output=True, text=True).stdout
    except FileNotFoundError:
        return set()
    pids: set[int] = set()
    for line in out.splitlines():
        # match ":8099 " in the local-address column only
        if re.search(rf"[:\]]{port}\s", line):
            pids.update(int(p) for p in re.findall(r"pid=(\d+)", line))
    return pids


def _pids_via_proc(port: int) -> set[int]:
    """Dependency-free fallback: /proc/net/tcp* inode -> owning process."""
    inodes: set[str] = set()
    for table in ("/proc/net/tcp", "/proc/net/tcp6"):
        try:
            with open(table) as fh:
                next(fh)  # header
                for line in fh:
                    parts = line.split()
                    local, state, inode = parts[1], parts[3], parts[9]
                    if state == "0A" and int(local.rsplit(":", 1)[1], 16) == port:
                        inodes.add(inode)
        except OSError:
            continue
    if not inodes:
        return set()
    targets = {f"socket:[{i}]" for i in inodes}
    pids: set[int] = set()
    for pid_dir in Path("/proc").iterdir():
        if not pid_dir.name.isdigit():
            continue
        try:
            for fd in (pid_dir / "fd").iterdir():
                if os.readlink(fd) in targets:
                    pids.add(int(pid_dir.name))
                    break
        except OSError:
            continue  # process died or not ours
    return pids


def find_pids(port: int) -> list[int]:
    return sorted(_pids_via_ss(port) or _pids_via_proc(port))


def cmdline(pid: int) -> str:
    try:
        raw = Path(f"/proc/{pid}/cmdline").read_bytes()
        return raw.replace(b"\0", b" ").decode(errors="replace").strip()
    except OSError:
        return "(gone)"


def port_open(host: str, port: int) -> bool:
    with socket.socket() as s:
        s.settimeout(0.5)
        return s.connect_ex((host, port)) == 0


# ----------------------------------------------------------------- commands

def cmd_status(args) -> int:
    pids = find_pids(args.port)
    if not pids:
        print(f"Port {args.port}: free — no server running.")
        return 1
    print(f"Port {args.port}: in use by {len(pids)} process(es)")
    for pid in pids:
        print(f"  PID {pid}: {cmdline(pid)}")
    return 0


def cmd_kill(args) -> int:
    pids = find_pids(args.port)
    if not pids:
        print(f"Port {args.port}: nothing to kill.")
        return 0
    for pid in pids:
        print(f"SIGTERM -> PID {pid} ({cmdline(pid)})")
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    deadline = time.time() + args.timeout
    while time.time() < deadline and find_pids(args.port):
        time.sleep(0.3)
    leftovers = find_pids(args.port)
    for pid in leftovers:
        print(f"still alive after {args.timeout}s, SIGKILL -> PID {pid}")
        try:
            os.kill(pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    time.sleep(0.3 if leftovers else 0)
    if find_pids(args.port):
        print("ERROR: port still held.", file=sys.stderr)
        return 1
    print(f"Port {args.port} is free.")
    return 0


def cmd_start(args) -> int:
    if find_pids(args.port):
        print(f"Already running on port {args.port} — use restart.", file=sys.stderr)
        return 1
    serve_args = [sys.executable, "-m", "serve", "--host", args.host, "--port", str(args.port)]
    log = open(LOG_FILE, "ab")
    log.write(f"\n===== hubctl start {time.strftime('%Y-%m-%d %H:%M:%S')} =====\n".encode())
    proc = subprocess.Popen(
        serve_args, cwd=HUB_DIR, stdout=log, stderr=subprocess.STDOUT,
        stdin=subprocess.DEVNULL, start_new_session=True,
    )
    for _ in range(40):  # up to ~10 s
        if proc.poll() is not None:
            print(f"Server exited immediately (code {proc.returncode}). Last log lines:",
                  file=sys.stderr)
            print("\n".join(LOG_FILE.read_text(errors="replace").splitlines()[-15:]),
                  file=sys.stderr)
            return 1
        if port_open(args.host, args.port):
            print(f"Server up: PID {proc.pid}  http://{args.host}:{args.port}/index.html")
            print(f"Logs: {LOG_FILE}")
            return 0
        time.sleep(0.25)
    print("Timed out waiting for the server to listen; check hub_server.log.", file=sys.stderr)
    return 1


def cmd_restart(args) -> int:
    if find_pids(args.port) and cmd_kill(args) != 0:
        return 1
    return cmd_start(args)


def main() -> int:
    parser = argparse.ArgumentParser(description="Manage the Mock Ordering Hub demo server.")
    parser.add_argument("command", choices=["status", "kill", "stop", "start", "restart"])
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--timeout", type=float, default=8.0,
                        help="seconds to wait after SIGTERM before SIGKILL")
    args = parser.parse_args()
    handlers = {"status": cmd_status, "kill": cmd_kill, "stop": cmd_kill,
                "start": cmd_start, "restart": cmd_restart}
    return handlers[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
