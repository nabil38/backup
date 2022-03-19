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

echo "=> Creating backup script"
rm -f /backup.sh
cat <<EOF >> /backup.sh
#!/bin/bash

echo "=> Backup started"
BACKUP_NAME=backup_\$(date +\%Y.\%m.\%d.\%H)

mkdir -p /backup/\${BACKUP_NAME}/MYSQL
mkdir -p /backup/\${BACKUP_NAME}/FILES

sleep \$(( \$RANDOM % 60 + 1 ))
EXIST=\$(ncftpls -u $FTP_USER -p "$FTP_PASS" -P $FTP_PORT ftp://$FTP_HOST$FTP_DIRECTORY)
if [ -z "\${EXIST}" ]; then
  echo "Creating root backup directory"
  echo "mkdir $FTP_DIRECTORY" | ncftp -u $FTP_USER -p "$FTP_PASS" -P $FTP_PORT $FTP_HOST; 
fi
EXIST=\$(ncftpls -u $FTP_USER -p "$FTP_PASS" -P $FTP_PORT ftp://$FTP_HOST$FTP_DIRECTORY\${BACKUP_NAME})
if [ -n "\${EXIST}" ]; then 
  ROLE=PASSIVE
  echo "   Backup Folder \${BACKUP_NAME} exists in remote location : Passive role"
else
  if ncftpput -R -v -u $FTP_USER -p "$FTP_PASS" -P $FTP_PORT $FTP_HOST $FTP_DIRECTORY /backup/\${BACKUP_NAME} ;then
      echo "   Creating backup folder \${BACKUP_NAME} : master role"
      ROLE=MASTER
  else
      echo "   FTP upload failed"
      ROLE=PASSIVE
  fi
fi

if [[ "\${ROLE}" == "MASTER" ]]; then
  echo "   Start DB dump..."
  for i in \$( echo "show databases;" | mysql -h$MYSQL_HOST -P$MYSQL_PORT -u$MYSQL_USER -p"$MYSQL_PASS" | grep -v 'Database\|information_schema\|mysql\|performance_schema'); do
    if mysqldump -h$MYSQL_HOST -P$MYSQL_PORT -u$MYSQL_USER -p"$MYSQL_PASS"  \${i} > /backup/\${BACKUP_NAME}/MYSQL/\${i}.sql ;then
        echo "   Dump Mysql \$i succeeded"
    else
        echo "   Dump Mysql \$i failed"
        rm -rf /backup/\${BACKUP_NAME}/MYSQL/\$i.sql
    fi
  done
fi

# On sauvegarde les image un jour sur 2
BACKIMG=\$((\$(date +\%d) % 2))
if [[ "\${BACKIMG}" == 0 ]]; then
  echo "   Start images dump..."
  for i in \$(ls /backup/\${BACKUP_NAME}/MYSQL -N1); do
    cd
    tar czf /backup/\${BACKUP_NAME}/MYSQL/\${i}.tar.gz -C /backup/\${BACKUP_NAME}/MYSQL \${i}
    rm -rf /backup/\${BACKUP_NAME}/MYSQL/\${i}
  done

  echo "Start images compression..."
  for i in \$(ls /exports/ -N1 | grep IMG); do
    if [ \$(ls /exports/\${i} | wc -l) -gt 1 ];then
      tar czf /backup/\${BACKUP_NAME}/FILES/\${i}.tar.gz -C /exports \${i}
    fi
  done
fi

if [[ "\${ROLE}" == "MASTER" ]]; then
  echo "   transfert des dumps DB"
  if ncftpput -R -v -u $FTP_USER -p "$FTP_PASS" -P $FTP_PORT $FTP_HOST $FTP_DIRECTORY\${BACKUP_NAME} /backup/\${BACKUP_NAME}/MYSQL ;then
      echo "   FTP upload succeeded"
  else
      echo "   FTP upload failed"
  fi
fi

echo "   transfert des images"
for i in \$(ls /backup/\${BACKUP_NAME}/FILES -N1); do
  ncftpput -R -v -u $FTP_USER -p "$FTP_PASS" -P $FTP_PORT $FTP_HOST $FTP_DIRECTORY\${BACKUP_NAME}/FILES /backup/\${BACKUP_NAME}/FILES/\${i}
done

if [ -n "${MAX_BACKUPS}" ] && [[ "\${ROLE}" == "MASTER" ]]; then
  BACKUP_TOTAL_DIR=\$(ncftpls -x "-N1t" -u $FTP_USER -p "$FTP_PASS" -P $FTP_PORT ftp://$FTP_HOST$FTP_DIRECTORY | wc -l)
  echo "  Total Backup : \${BACKUP_TOTAL_DIR}"

  if [ \${BACKUP_TOTAL_DIR} -gt ${MAX_BACKUPS} ];then
      BACKUP_TO_BE_DELETED=\$(ncftpls -x "-ltr" -u $FTP_USER -p "$FTP_PASS" -P $FTP_PORT ftp://$FTP_HOST$FTP_DIRECTORY | grep backup | head -1 | awk '{print \$9}')
      if [ -n "\${BACKUP_TO_BE_DELETED}" ] ;then
        i=0
        maxtrial=6
        while
          DELETED=\$(ncftpls -u $FTP_USER -p "$FTP_PASS" -P $FTP_PORT ftp://$FTP_HOST$FTP_DIRECTORY\${BACKUP_TO_BE_DELETED})
          if [ -z "\${DELETED}" ]; then  i=\$maxtrial
          else i="\$((i+1))"
          fi
          # some other commands      # needed for the loop
          [ "\$i" -lt "\$maxtrial" ]            # test the limit of the loop.
        do :
          echo "   Deleting backup \${BACKUP_TO_BE_DELETED} : \$i"
          echo "rm -rf $FTP_DIRECTORY\${BACKUP_TO_BE_DELETED}" | ncftp -u $FTP_USER -p "$FTP_PASS" -P $FTP_PORT $FTP_HOST;  
        done
        DELETED=\$(ncftpls -u $FTP_USER -p "$FTP_PASS" -P $FTP_PORT ftp://$FTP_HOST$FTP_DIRECTORY\${BACKUP_TO_BE_DELETED})
        if [ -z "\${DELETED}" ]; then
          echo "   \${BACKUP_TO_BE_DELETED} deleted"
        else
          echo "   enable to delete \${BACKUP_TO_BE_DELETED} !!!!"
        fi
      else
        echo "    No backup to delete..."
      fi
  else
    echo "    No backup to delete..."
  fi
fi

echo "=> Remove Backup Directory"
rm -rf /backup/\${BACKUP_NAME}

echo "=> Backup done"
EOF
chmod +x /backup.sh

touch /backup.log
tail -F /backup.log &

echo "=> Creating logrotate for backup.log"
cat <<EOF >> /etc/logrotate.d/backup
/backup.log
{ 
daily
maxsize 1M
rotate 4
}
EOF
chmod 644 backup ; chown root:root backup

if [ -n "${INIT_BACKUP}" ]; then
    echo "=> Create a backup on the startup"
    /backup.sh
fi

echo "${CRON_TIME} /backup.sh >> /backup.log 2>&1" > /crontab.conf
crontab  /crontab.conf
echo "=> Running cron job"
exec cron -f
