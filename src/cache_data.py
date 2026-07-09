import glob, os, shutil, socket, subprocess, time, isal.igzip as ig

SRC = "/home/irisowner/dev/data/in"
DST = "/tmp/gaia_data"

already_cached = os.path.isdir(DST) and len(os.listdir(DST)) >= 20

if not already_cached:
    os.makedirs(DST, exist_ok=True)
    for src in glob.glob(os.path.join(SRC, "**", "*.csv.gz"), recursive=True) + \
               glob.glob(os.path.join(SRC, "**", "*.csv"), recursive=True):
        name = os.path.basename(src)
        dst = os.path.join(DST, name[:-3] if name.endswith(".gz") else name)
        if src.endswith(".gz"):
            open(dst, "wb").write(ig.decompress(open(src, "rb").read()))
        else:
            shutil.copy2(src, dst)

DAEMON_SCRIPT = "/home/irisowner/dev/gaia_daemon.py"
SOCKET_PATH   = "/tmp/gaia_daemon.sock"
READY_FLAG    = "/tmp/gaia_daemon.ready"


def _daemon_alive():
    """Return True if the socket exists and accepts a connection."""
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(1)
        s.connect(SOCKET_PATH)
        s.close()
        return True
    except Exception:
        return False


def _start_daemon():
    # Clean up any stale socket/flag from a previous crashed run
    for p in (SOCKET_PATH, READY_FLAG):
        try:
            os.unlink(p)
        except FileNotFoundError:
            pass
    subprocess.Popen(
        ["python3", DAEMON_SCRIPT],
        stdout=open("/tmp/gaia_daemon.log", "w"),
        stderr=subprocess.STDOUT,
        close_fds=True,
    )
    deadline = time.time() + 60
    while not os.path.exists(READY_FLAG) and time.time() < deadline:
        time.sleep(0.2)


if not _daemon_alive():
    _start_daemon()
