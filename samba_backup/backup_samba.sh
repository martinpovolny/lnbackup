#!/bin/bash

. /usr/local/samba_backup/backup_setup.sh

#BACKUP_HOSTS="ALES_FILKA"

echo -n 'starting at '
date

if [ -z "$1" ]; then
    echo "running in FULL mode"

    for HOST in $BACKUP_HOSTS; do
        umount   $MOUNTS_ROOT/$HOST >/dev/null 2>&1
        mkdir -p $MOUNTS_ROOT/$HOST
        echo -n "trying $HOST ... "

        if mount -t smb -o username=$BACKUP_USER,password=$BACKUP_PASSWORD,workgroup=$BACKUP_WORKGROUP //$HOST/$BACKUP_SHARE $MOUNTS_ROOT/$HOST >/dev/null 2>&1 &&
           ls /mnt/pc_backups/$HOST >/dev/null 2>&1; then

           echo "passed" 
           mkdir -p $BACKUPS_ROOT/$HOST/
           $LNBACKUP --backup -l $LOG_DIR/$HOST-lnbackup.log -v debug \
                   --source-prefix=$MOUNTS_ROOT/$HOST/ \
                   --force-target=$BACKUPS_ROOT/$HOST/ --backup-name=windows \
                   --status-file-pref=$STATUS_DIR/$HOST.status
        else
            echo "failed"
        fi
        umount $MOUNTS_ROOT/$HOST >/dev/null 2>&1
    done
else
#    echo "running in TEST mode"
#
#    for HOST in $BACKUP_HOSTS; do
#        echo -n "trying $HOST ... "
#        if mount -t smb -o username=backup,password=luroj3op,workgroup=is //$HOST/is /mnt/pc_backups/$HOST >/dev/null 2>&1 &&
#           ls /mnt/pc_backups/$HOST >/dev/null 2>&1; then
#            echo "passed"
#        else
#            echo "failed"
#        fi
#        umount /mnt/pc_backups/$HOST  >/dev/null 2>&1
#    done
#fi
    echo "running in TEST mode"

    for HOST in $BACKUP_HOSTS; do
        echo -n "trying $HOST ... "
        if smbclient -c '' -W $BACKUP_WORKGROUP //$HOST/$BACKUP_SHARE -U $BACKUP_USER%$BACKUP_PASSWORD 1>/dev/null 2>&1; then
            echo "passed"
        else
            echo "failed"
        fi
    done
fi


echo -n 'finished at '
date

