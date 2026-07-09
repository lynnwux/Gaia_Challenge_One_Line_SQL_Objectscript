ARG IMAGE=intersystems/iris-community:latest-em
FROM $IMAGE

WORKDIR /home/irisowner/dev
COPY . .

## Embedded Python environment
ENV IRISUSERNAME="_SYSTEM"
ENV IRISPASSWORD="SYS"
ENV IRISNAMESPACE="USER"
ENV PYTHON_PATH=/usr/irissys/bin/
ENV PATH="/usr/irissys/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/irisowner/bin"
ENV PYTHONPATH=/home/irisowner/dev

RUN pip install isal numpy --break-system-packages --quiet && \
    cp /home/irisowner/dev/wqm_bootstrap.py /usr/irissys/bin/wqm_bootstrap.py

# Pre-decompress input files into /tmp/gaia_data so they survive the docker-compose volume mount.
# /home/irisowner/dev is bind-mounted at runtime (shadowing the image layer), but /tmp is not.
RUN python3 -c "import glob,os,isal.igzip as ig; os.makedirs('/tmp/gaia_data',exist_ok=True); [open('/tmp/gaia_data/'+os.path.basename(gz[:-3]),'wb').write(ig.decompress(open(gz,'rb').read())) for gz in glob.glob('/home/irisowner/dev/data/in/**/*.csv.gz',recursive=True)]"

RUN iris start IRIS && \
    iris merge IRIS merge.cpf && \
    iris session IRIS < iris.script && \
    iris stop IRIS quietly safely