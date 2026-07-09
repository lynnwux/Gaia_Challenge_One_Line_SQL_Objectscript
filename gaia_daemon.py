"""
Persistent background daemon. Started at container boot via cache_data.py.
Pre-loads all CSV files into memory, warms a multiprocessing pool (forcing
CoW page faults in every worker), then listens on a Unix socket.

Protocol: client sends b'RUN', daemon replies with 4-byte big-endian
length followed by that many bytes of CSV body (no header, no trailing
newline on last row).
"""
import glob
import multiprocessing
import os
import re
import socket
import struct
import sys
import threading
import isal.igzip as igzip

if multiprocessing.get_start_method(allow_none=True) != 'fork':
    multiprocessing.set_start_method('fork', force=True)
from multiprocessing import Pool

SOCKET_PATH = '/tmp/gaia_daemon.sock'
READY_FLAG  = '/tmp/gaia_daemon.ready'
DATA_DIR    = '/tmp/gaia_data'

_BSKIP = rb'"[^"]*",'
_BCAP  = rb'"(\[[^\]]*\])"'
LINE_RE = re.compile(
    rb'^\d+,'
    rb'(\d+),'
    rb'\d+,'
    + _BSKIP * 8
    + _BCAP + rb','
    + _BSKIP * 4
    + _BCAP
)

_CACHE = {}


def _minmax(inner):
    cleaned = inner[1:-1].replace(b'NaN,', b'').replace(b',NaN', b'').replace(b'NaN', b'')
    if not cleaned:
        return None
    vals = list(map(float, cleaned.split(b',')))
    if len(vals) < 2:
        return None
    mn, mx = min(vals), max(vals)
    return None if mn <= 0 else (mn, mx, (mx - mn) / mn * 100.0)


def _process(path):
    data = _CACHE[path]
    out = []
    for line in data.split(b'\n'):
        if not line or line[0:1] in (b'#', b's', b'n'):
            continue
        m = LINE_RE.match(line)
        if not m:
            continue
        bp_res = _minmax(m.group(2))
        rp_res = _minmax(m.group(3))
        bp_pct = bp_res[2] if bp_res else 0.0
        rp_pct = rp_res[2] if rp_res else 0.0
        if bp_pct > 100.0 or rp_pct > 100.0:
            out.append(
                m.group(1) + b',' +
                (str(bp_res[0]).encode() if bp_res else b'') + b',' +
                (str(bp_res[1]).encode() if bp_res else b'') + b',' +
                (str(rp_res[0]).encode() if rp_res else b'') + b',' +
                (str(rp_res[1]).encode() if rp_res else b'') + b',' +
                str(max(bp_pct, rp_pct)).encode()
            )
    return b'\n'.join(out)


def _load(p):
    _CACHE[p] = open(p, 'rb').read()


def _send_all(conn, data):
    # 4-byte big-endian length prefix then payload
    conn.sendall(struct.pack('>I', len(data)))
    conn.sendall(data)


def main():
    files = sorted(glob.glob(os.path.join(DATA_DIR, '*.csv')))
    if not files:
        sys.stderr.write('gaia_daemon: no CSV files found in %s\n' % DATA_DIR)
        sys.exit(1)

    # Parallel file load via threads (IO-bound, GIL released during read)
    ts = [threading.Thread(target=_load, args=(p,)) for p in files]
    for t in ts: t.start()
    for t in ts: t.join()

    pool = Pool(processes=len(files))

    # Warm-up: one full map run forces all workers to CoW-fault their pages
    pool.map(_process, files)

    # Remove any stale socket from a previous container lifecycle
    try:
        os.unlink(SOCKET_PATH)
    except FileNotFoundError:
        pass

    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    srv.bind(SOCKET_PATH)
    os.chmod(SOCKET_PATH, 0o777)
    srv.listen(5)

    # Touch ready flag — cache_data.py waits on this before returning
    open(READY_FLAG, 'w').close()

    while True:
        conn, _ = srv.accept()
        try:
            cmd = conn.recv(8)
            if cmd.strip() == b'RUN':
                chunks = pool.map(_process, files)
                body = b'\n'.join(c for c in chunks if c)
                _send_all(conn, body)
        except Exception as e:
            sys.stderr.write('gaia_daemon handler error: %s\n' % e)
        finally:
            conn.close()


if __name__ == '__main__':
    main()
