ARG IMAGE=intersystemsdc/iris-community
FROM $IMAGE

WORKDIR /home/irisowner/dev
COPY --chown=irisowner:irisowner . .

ENV IRISUSERNAME="_SYSTEM"
ENV IRISPASSWORD="SYS"
ENV IRISNAMESPACE="USER"
ENV PYTHON_PATH=/usr/irissys/bin/
ENV PATH="/usr/irissys/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/irisowner/bin"
ENV PYTHONPATH=/home/irisowner/dev

RUN pip install isal --break-system-packages --quiet && \
    mkdir -p /home/irisowner/dev/data/out && \
    iris start IRIS && \
    iris merge IRIS merge.cpf && \
    iris session IRIS < iris.script && \
    iris stop IRIS quietly safely && \
    date > /usr/irissys/iris.init
