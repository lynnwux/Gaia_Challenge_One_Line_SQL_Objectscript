# syntax=docker/dockerfile:1
ARG IMAGE=docker.iscinternal.com/docker-intersystems/intersystems/irishealth-community:2026.2.0AI.162.0

# Build stage: load Gaia data into IRIS SQL table g
FROM $IMAGE AS builder

WORKDIR /home/irisowner/dev
COPY . .

ENV IRISUSERNAME="_SYSTEM"
ENV IRISPASSWORD="SYS"
ENV IRISNAMESPACE="USER"
ENV PYTHON_PATH=/usr/irissys/bin/
ENV PATH="/usr/irissys/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/irisowner/bin"
ENV PYTHONPATH=/home/irisowner/dev

RUN pip install isal --break-system-packages --quiet &&     python3 -c "import glob,os,isal.igzip as ig; os.makedirs('/tmp/gaia_data',exist_ok=True); [open('/tmp/gaia_data/'+os.path.basename(gz[:-3]),'wb').write(ig.decompress(open(gz,'rb').read())) for gz in glob.glob('/home/irisowner/dev/data/in/*.csv.gz')]" &&     iris start IRIS &&     iris merge IRIS merge.cpf &&     iris session IRIS < iris.script &&     iris stop IRIS quietly safely &&     rm -rf /tmp/gaia_data /tmp/g.csv /home/irisowner/dev/data/in/

RUN python3 /home/irisowner/dev/patch_csp.py

# Final stage: fresh base image + baked-in Gaia data + app source
# CSP app registrations are re-created on every startup via merge.cpf [Actions]
# calling GAIA.Setup.Run() -- avoids irissecurity being wiped by base image init.
FROM $IMAGE

WORKDIR /home/irisowner/dev

ENV IRISUSERNAME="_SYSTEM"
ENV IRISPASSWORD="SYS"
ENV IRISNAMESPACE="USER"
ENV PYTHON_PATH=/usr/irissys/bin/
ENV PATH="/usr/irissys/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/irisowner/bin"
ENV PYTHONPATH=/home/irisowner/dev

# Baked-in Gaia data (table g with 5.6M rows)
COPY --from=builder /usr/irissys/mgr/TEMP_DATA /usr/irissys/mgr/TEMP_DATA

# Patched CSP gateway config routing /api and /app
COPY --from=builder /usr/irissys/csp/bin/CSP.ini /usr/irissys/csp/bin/CSP.ini

# App source and config (merge.cpf re-loads classes and runs GAIA.Setup on every start)
COPY --from=builder /home/irisowner/dev/src /home/irisowner/dev/src
COPY --from=builder /home/irisowner/dev/www /home/irisowner/dev/www
COPY --from=builder /home/irisowner/dev/merge.cpf /home/irisowner/dev/merge.cpf
COPY --from=builder /home/irisowner/dev/iris.script /home/irisowner/dev/iris.script
