#!/bin/bash

echo "=> Backup started"
BACKUP_NAME=backup_$(date +\%Y.\%m.\%d.\%H)

mkdir -p /backup/$BACKUP_NAME/MYSQL
mkdir -p /backup/$BACKUP_NAME/FILES

sleep $(( $RANDOM % 60 + 1 ))

if ncftpls -u $FTP_USER -p $FTP_PASS -P $FTP_PORT ftp://$FTP_HOST$FTP_DIRECTORY/$BACKUP_NAME; then 
  ROLE=PASSIVE
  echo "   Backup Folder exists in remote location : Passive role"
else
  if ncftpput -R -v -u $FTP_USER -p $FTP_PASS -P $FTP_PORT $FTP_HOST $FTP_DIRECTORY /backup/$BACKUP_NAME ;then
      echo "   Creating backup folder $BACKUP_NAME : master role"
      ROLE=MASTER
  else
      echo "   FTP upload failed"
      ROLE=PASSIVE
  fi
fi

if [[ "$ROLE" == "MASTER" ]]; then
  echo "   Start DB dump..."
  for i in $( echo "show databases;" | mysql -h$MYSQL_HOST -P$MYSQL_PORT -u$MYSQL_USER -p$MYSQL_PASS | grep -v 'Database\|information_schema\|mysql\|performance_schema'); do
    if mysqldump -h$MYSQL_HOST -P$MYSQL_PORT -u$MYSQL_USER -p$MYSQL_PASS  ${i} > /backup/${BACKUP_NAME}/MYSQL/${i}.sql ;then
        echo "   Dump Mysql $i succeeded"
    else
        echo "   Dump Mysql $i failed"
        rm -rf /backup/${BACKUP_NAME}/MYSQL/$i.sql
    fi
  done
fi

# On sauvegarde les image un jour sur 2
if $(($(date +\%d) % 2)) 
  echo "   Start images dump..."
  for i in $(ls /backup/${BACKUP_NAME}/MYSQL -N1); do
    cd
    tar czvf /backup/${BACKUP_NAME}/MYSQL/${i}.tar.gz -C /backup/${BACKUP_NAME}/MYSQL ${i}
    rm -rf /backup/${BACKUP_NAME}/MYSQL/${i}
  done

  echo "Start images compression..."
  for i in $(ls /exports/ -N1 | grep IMG); do
    if [ $(ls /exports/${i} | wc -l) -gt 1 ];then
      tar czvf /backup/${BACKUP_NAME}/FILES/${i}.tar.gz -C /exports ${i}
    fi
  done
fi

if [[ "$ROLE" == "MASTER" ]]; then
  echo "   transfert des dumps DB"
  if ncftpput -R -v -u $FTP_USER -p $FTP_PASS -P $FTP_PORT $FTP_HOST $FTP_DIRECTORY/${BACKUP_NAME} /backup/${BACKUP_NAME}/MYSQL ;then
      echo "   FTP upload succeeded"
  else
      echo "   FTP upload failed"
  fi
fi

echo "   transfert des images"
for i in $(ls /backup/${BACKUP_NAME}/FILES -N1); do
  ncftpput -R -v -u $FTP_USER -p $FTP_PASS -P $FTP_PORT $FTP_HOST $FTP_DIRECTORY${BACKUP_NAME}/FILES /backup/${BACKUP_NAME}/FILES/${i}
done

if [ -n "${MAX_BACKUPS}" ] && [[ "$ROLE" == "MASTER" ]]; then
  BACKUP_TOTAL_DIR=$(ncftpls -x "-N1t" -u $FTP_USER -p $FTP_PASS -P $FTP_PORT ftp://$FTP_HOST$FTP_DIRECTORY/ | wc -l)
  echo "  Total Backup : ${BACKUP_TOTAL_DIR}"

  if [ ${BACKUP_TOTAL_DIR} -gt ${MAX_BACKUPS} ];then
      BACKUP_TO_BE_DELETED=$(ncftpls -x "-ltr" -u $FTP_USER -p $FTP_PASS -P $FTP_PORT ftp://$FTP_HOST$FTP_DIRECTORY/ | grep backup | head -1 | awk '{print $9}')
      if [ -n "${BACKUP_TO_BE_DELETED}" ] ;then
        i=0
        maxtrial=6
        while
          DELETED=$(ncftpls -u $FTP_USER -p $FTP_PASS -P $FTP_PORT ftp://$FTP_HOST$FTP_DIRECTORY/$BACKUP_TO_BE_DELETED)
          if [ -z "$DELETED" ]; then  i=$maxtrial
          else i="$((i+1))"
          fi
          # some other commands      # needed for the loop
          [ "$i" -lt "$maxtrial" ]            # test the limit of the loop.
        do :
          echo "   Deleting backup ${BACKUP_TO_BE_DELETED} : $i"
          echo "rm -rf $FTP_DIRECTORY/${BACKUP_TO_BE_DELETED}" | ncftp -u $FTP_USER -p $FTP_PASS -P $FTP_PORT $FTP_HOST;  
        done
        DELETED=$(ncftpls -u $FTP_USER -p $FTP_PASS -P $FTP_PORT ftp://$FTP_HOST$FTP_DIRECTORY/$BACKUP_TO_BE_DELETED)
        if [ -z "$DELETED" ]; then
          echo "   ${BACKUP_TO_BE_DELETED} deleted"
        else
          echo "   enable to delete ${BACKUP_TO_BE_DELETED} !!!!"
        fi
      else
        echo "    No backup to delete..."
      fi
  else
    echo "    No backup to delete..."
  fi
fi

echo "=> Remove Backup Directory"
rm -rf /backup/${BACKUP_NAME}

echo "=> Backup done"