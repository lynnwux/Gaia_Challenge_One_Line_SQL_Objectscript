import glob, re, sys, isal.igzip as ig
sys.path.insert(0, '/usr/irissys/lib/python')
import iris

_BSKIP = rb'"[^"]*",'
_BCAP  = rb'"(\[[^\]]*\])"'
LINE_RE = re.compile(rb'^\d+,(\d+),\d+,' + _BSKIP*8 + _BCAP + rb',' + _BSKIP*4 + _BCAP)
NaN = b'NaN'

a = {}
for path in sorted(glob.glob("/home/irisowner/dev/data/in/*.csv.gz")):
    for line in ig.decompress(open(path, 'rb').read()).split(b'\n'):
        if not line or line[0:1] in (b'#', b's', b'n'): continue
        m = LINE_RE.match(line)
        if not m: continue
        k = int(m.group(1))
        r = a.setdefault(k, [None, None, None, None])
        for j, arr in ((0, m.group(2)), (1, m.group(3))):
            for v in arr[1:-1].split(b','):
                v = v.strip()
                if v and v != NaN:
                    f = float(v)
                    if r[j*2] is None or f < r[j*2]: r[j*2] = f
                    if r[j*2+1] is None or f > r[j*2+1]: r[j*2+1] = f

e = lambda v: '' if v is None else str(v)
with open('/tmp/g.csv', 'w') as out:
    for k, r in a.items():
        out.write(f"{k},{e(r[0])},{e(r[1])},{e(r[2])},{e(r[3])}\n")

try: iris.sql.exec("DROP TABLE g")
except: pass
iris.sql.exec("CREATE TABLE g(id BIGINT,n FLOAT,x FLOAT,p FLOAT,q FLOAT)")
iris.sql.exec("LOAD DATA FROM FILE '/tmp/g.csv' INTO g(id,n,x,p,q)")
