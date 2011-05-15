#!/bin/bash

. /usr/local/samba_backup/backup_setup.sh

echo -e "Content-type: text/html\n\n"
echo "<html><table>"


for HOST in $BACKUP_HOSTS; do
    res=$($LNBACKUP --nagios \
               --backup-name=windows \
               --status-file-pref=$STATUS_DIR/$HOST.status 2>/dev/null)
#    echo $res
    echo "<tr><td>$HOST<td>"
    if [ $? == 0 ]; then
        echo $res | sed -e "s/windows : //"
    else
        latest=$(cd $BACKUPS_ROOT/$HOST/backup/ 2>/dev/null && ls -d [0-9][0-9][0-9][0-9]/[0-9][0-9]/[0-9][0-9] 2>/dev/null | sort | tail -1)
        if [ -n "$latest" ]; then
           echo "has latest: $latest"
        else
           echo "has no backup"
        fi
    fi
done

echo "<table><html>"
