# syntax=docker/dockerfile:1
ARG IMAGE=docker.iscinternal.com/docker-intersystems/intersystems/irishealth-community:2026.2.0AI.162.0
FROM $IMAGE

WORKDIR /home/irisowner/dev
COPY . .

ENV IRISUSERNAME="_SYSTEM"
ENV IRISPASSWORD="SYS"
ENV IRISNAMESPACE="USER"
ENV PYTHON_PATH=/usr/irissys/bin/
ENV PATH="/usr/irissys/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/irisowner/bin"
ENV PYTHONPATH=/home/irisowner/dev

RUN pip install isal --break-system-packages --quiet

RUN python3 /home/irisowner/dev/patch_csp.py

# Bind-mount data/in/ so the .csv.gz files are never written into a layer.
# Decompress into /tmp, load into IRIS, then clean up -- all in one RUN.
RUN --mount=type=bind,source=data/in,target=/mnt/gaia_in     python3 -c "import glob,os,isal.igzip as ig; os.makedirs('/tmp/gaia_data',exist_ok=True); [open('/tmp/gaia_data/'+os.path.basename(gz[:-3]),'wb').write(ig.decompress(open(gz,'rb').read())) for gz in glob.glob('/mnt/gaia_in/*.csv.gz')]" &&     iris start IRIS &&     iris merge IRIS merge.cpf &&     iris session IRIS < iris.script &&     iris stop IRIS quietly safely &&     rm -rf /tmp/gaia_data /tmp/g.csv
