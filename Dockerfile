FROM ubuntu:latest

RUN apt-get update && \
    apt-get install -y ncftp cron && \
    apt-get install -y --no-install-recommends mysql-client && \
    mkdir /backup

ENV CRON_TIME="0 0 * * *"

RUN mkdir /scripts
ADD scripts/run.sh /scripts/run.sh
ADD scripts/backup.sh /backup.sh
RUN chmod 755 /scripts/run.sh && chmod 755 /backup.sh
VOLUME ["/backup"]
CMD ["/scripts/run.sh"]
