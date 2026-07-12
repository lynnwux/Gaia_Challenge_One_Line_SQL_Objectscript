import re, pathlib
ini = pathlib.Path('/usr/irissys/csp/bin/CSP.ini')
txt = ini.read_text()
txt = re.sub(r'(\[APP_PATH_INDEX\])', r'\1\n/api=Enabled\n/app=Enabled', txt)
txt += '\n[APP_PATH:/api]\nDefault_Server=LOCAL\nAlternative_Server_0=1~~~~~~LOCAL\n'
txt += '\n[APP_PATH:/app]\nDefault_Server=LOCAL\nAlternative_Server_0=1~~~~~~LOCAL\n'
ini.write_text(txt)
print('CSP.ini patched')
