FROM ubuntu

RUN apt-get update
RUN groupadd hafas
RUN useradd -d /home/hafas -c 'HAFAS user' -g hafas -m -s /bin/bash hafas
RUN mkdir -p /opt/hafas/script
RUN chown -R hafas:hafas /opt/hafas

RUN mkdir -p /opt/hafas/server
COPY management/script/ /opt/hafas/script
COPY hafasserver/main/server/ /opt/hafas/server
RUN /opt/hafas/script/bootstrap_hafas_environment.sh 
RUN /opt/hafas/script/create_server_wrapper.sh 
RUN cp -p /opt/hafas/server/server.???  /opt/hafas/prod/hafas/main/server
COPY /plan/ /opt/hafas/plan/5.20/hafas
RUN mkdir -p /opt/hafas/prod/hafas/hafas-proxy/
COPY /hafas-proxy/ /opt/hafas/prod/hafas/hafas-proxy/
RUN ln -sf /opt/hafas/prod/hafas/hafas-proxy/bin/server.sh /etc/init.d/hafas-restproxy
RUN chmod 0755 \
  /etc/init.d/hafas-* \
  /opt/hafas/prod/hafas/main/server/server.exe \
  /opt/hafas/prod/hafas/hafas-proxy/bin/* \
  /opt/hafas/script/* 
