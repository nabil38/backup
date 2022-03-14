FROM ubuntu:latest

RUN apt-get update && \
    apt-get install -y ncftp cron vim && \
    DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true apt-get -y install ntp && \
    apt-get install -y --no-install-recommends mysql-client && \
    mkdir /backup

ENV CRON_TIME="0 0 * * *"

RUN rm -f /etc/localtime && echo Europe/Paris | tee /etc/timezone && dpkg-reconfigure --frontend noninteractive tzdata && mkdir /scripts
ADD scripts/run.sh /scripts/run.sh
RUN chmod 755 /scripts/run.sh
VOLUME ["/backup"]
CMD ["/scripts/run.sh"]
