#!/bin/bash

[ -z "${MYSQL_HOST}" ] && { echo "=> MYSQL_HOST cannot be empty" && exit 1; }
[ -z "${MYSQL_PORT}" ] && { echo "=> MYSQL_PORT cannot be empty" && exit 1; }
[ -z "${MYSQL_USER}" ] && { echo "=> MYSQL_USER cannot be empty" && exit 1; }
[ -z "${MYSQL_PASS}" ] && { echo "=> MYSQL_PASS cannot be empty" && exit 1; }

[ -z "${FTP_HOST}" ] && { echo "=> FTP_HOST cannot be empty" && exit 1; }
[ -z "${FTP_PORT}" ] && { echo "=> FTP_PORT cannot be empty" && exit 1; }
[ -z "${FTP_USER}" ] && { echo "=> FTP_USER cannot be empty" && exit 1; }
[ -z "${FTP_PASS}" ] && { echo "=> FTP_PASS cannot be empty" && exit 1; }
[ -z "${FTP_DIRECTORY}" ] && { echo "=> FTP_DIRECTORY cannot be empty" && exit 1; }


BACKUP_MYSQL_CMD="mysqldump -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASS} ${EXTRA_OPTS} \${i} > /backup/\${BACKUP_NAME}/MYSQL/\${i}.sql"

BACKUP_FTP="ncftpput -R -v -u ${FTP_USER} -p ${FTP_PASS} -P ${FTP_PORT} ${FTP_HOST} ${FTP_DIRECTORY} /backup/\${BACKUP_NAME}"

touch /backup.log
tail -F /backup.log &

if [ -n "${INIT_BACKUP}" ]; then
    echo "=> Create a backup on the startup"
    /backup.sh
fi

echo "${CRON_TIME} /backup.sh >> /backup.log 2>&1" > /crontab.conf
crontab  /crontab.conf
echo "=> Running cron job"
exec cron -f
