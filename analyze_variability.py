import glob
import multiprocessing
import os
import re
import socket
import struct
import isal.igzip as igzip

if multiprocessing.get_start_method(allow_none=True) != 'fork':
    multiprocessing.set_start_method('fork', force=True)
from multiprocessing import Pool

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
_PREDECOMP  = "/tmp/gaia_data"
OUT_DIR     = os.path.join(BASE_DIR, "data", "out")
OUTPUT_FILE = os.path.join(OUT_DIR, "variable_objects.csv")
SOCKET_PATH = "/tmp/gaia_daemon.sock"

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


def _minmax(inner):
    cleaned = inner[1:-1].replace(b'NaN,', b'').replace(b',NaN', b'').replace(b'NaN', b'')
    if not cleaned:
        return None
    vals = list(map(float, cleaned.split(b',')))
    if len(vals) < 2:
        return None
    mn, mx = min(vals), max(vals)
    return None if mn <= 0 else (mn, mx, (mx - mn) / mn * 100.0)


def process_file(path):
    with open(path, 'rb') as f:
        data = f.read()
    raw = igzip.decompress(data) if path.endswith('.gz') else data
    out = []
    for line in raw.split(b'\n'):
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


def _recv_exact(sock, n):
    buf = bytearray()
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise ConnectionError('daemon closed connection prematurely')
        buf.extend(chunk)
    return bytes(buf)


def _run_via_daemon():
    """Ask the background daemon for results. Returns CSV body bytes or None."""
    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.settimeout(30)
        sock.connect(SOCKET_PATH)
        sock.sendall(b'RUN')
        length = struct.unpack('>I', _recv_exact(sock, 4))[0]
        body = _recv_exact(sock, length)
        sock.close()
        return body if body else None
    except Exception:
        return None


def _run_direct(file_paths):
    with Pool(processes=len(file_paths)) as pool:
        chunks = list(pool.imap_unordered(process_file, file_paths))
    return chunks


def main():
    data_dir = _PREDECOMP if os.path.isdir(_PREDECOMP) and os.listdir(_PREDECOMP) else os.path.join(BASE_DIR, "data", "in")
    os.makedirs(OUT_DIR, exist_ok=True)

    file_paths = sorted(set(
        glob.glob(os.path.join(data_dir, "**", "*.csv.gz"), recursive=True)
        + glob.glob(os.path.join(data_dir, "**", "*.csv"),  recursive=True)
    ))

    print(f"Found {len(file_paths)} files")
    if not file_paths:
        raise FileNotFoundError(f"No input files found in {data_dir}")

    daemon_result = _run_via_daemon()

    if daemon_result is not None:
        total = daemon_result.count(b'\n') + 1 if daemon_result else 0
        with open(OUTPUT_FILE, 'wb') as f:
            f.write(b'source_id,bp_min_flux,bp_max_flux,rp_min_flux,rp_max_flux,percentage_change\n')
            f.write(daemon_result)
            f.write(b'\n')
    else:
        chunks = _run_direct(file_paths)
        total = sum(c.count(b'\n') + 1 if c else 0 for c in chunks)
        with open(OUTPUT_FILE, 'wb') as f:
            f.write(b'source_id,bp_min_flux,bp_max_flux,rp_min_flux,rp_max_flux,percentage_change\n')
            for c in chunks:
                if c:
                    f.write(c)
                    f.write(b'\n')

    print(f"Objects with >100% flux change: {total}")
    print(f"Output written to: {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
