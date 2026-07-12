ARG IMAGE=docker.iscinternal.com/docker-intersystems/intersystems/irishealth-community:2026.2.0AI.162.0
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

RUN pip install isal --break-system-packages --quiet

RUN iris start IRIS && \
    iris merge IRIS merge.cpf && \
    iris session IRIS < iris.script && \
    iris stop IRIS quietly safely
