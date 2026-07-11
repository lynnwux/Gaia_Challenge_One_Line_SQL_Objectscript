import glob, re, sys
sys.path.insert(0, '/usr/irissys/lib/python')
import iris

_BSKIP = rb'"[^"]*",'
_BCAP  = rb'"(\[[^\]]*\])"'
LINE_RE = re.compile(rb'^\d+,(\d+),\d+,' + _BSKIP*8 + _BCAP + rb',' + _BSKIP*4 + _BCAP)

with open('/tmp/g.csv', 'w') as out:
    for path in sorted(glob.glob("/tmp/gaia_data/*.csv")):
        with open(path, 'rb') as f: data = f.read()
        for line in data.split(b'\n'):
            if not line or line[0:1] in (b'#', b's', b'n'): continue
            m = LINE_RE.match(line)
            if not m: continue
            sid = m.group(1).decode()
            for b, arr in ((0, m.group(2)), (1, m.group(3))):
                for v in arr[1:-1].split(b','):
                    v = v.strip()
                    if v:
                        val = '' if v == b'NaN' else v.decode()
                        out.write(f"{sid},{b},{val}\n")

try: iris.sql.exec("DROP TABLE g")
except: pass
iris.sql.exec("CREATE TABLE g(id BIGINT,b TINYINT,f FLOAT)")
iris.sql.exec("LOAD DATA FROM FILE '/tmp/g.csv' INTO g(id,b,f)")
