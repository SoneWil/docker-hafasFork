FROM ubuntu

RUN apt-get update
RUN groupadd hafas
RUN useradd -d /home/hafas -c 'HAFAS user' -g hafas -m -s /bin/bash hafas
#CMD mkdir -p /dev/log
#RUN touch /dev/log/root.log
#RUN chgrp /dev/log/root.log
#RUN chmod 775 /dev/log/root.log
RUN apt-get -y install rsyslog
#RUN echo "# Save local0 to an own log file (used by HAFAS)" >> etc/rsyslog.conf
#RUN echo "local0.* /dev/log/root.log" >> etc/rsyslog.conf
#RUN echo "local0.* /dev/log/hafas.log" >> etc/rsyslog.conf
#RUN echo "local0.* /dev/log/main.log" >> etc/rsyslog.conf
RUN mkdir -p /opt/hafas/script
RUN chown -R hafas:hafas /opt/hafas

RUN mkdir -p /opt/hafas/server
COPY management/script/ /opt/hafas/script
COPY hafasserver/main/server/ /opt/hafas/server
RUN /opt/hafas/script/bootstrap_hafas_environment.sh 
RUN /opt/hafas/script/create_server_wrapper.sh 
RUN cp -p /opt/hafas/server/server.???  /opt/hafas/prod/hafas/main/server
COPY /plan/ /opt/hafas/plan/5.20/hafas
#RUN /opt/hafas/prod/hafas/main/server/server.sh start
