# /etc/cron.d/lnbackup-ng: crontab fragment for lnbackup-ng

# run default backup (localhost) every day
00 23   * * *   root if [ -x /usr/bin/lnbackup ]; then /usr/bin/lnbackup --backup >> /var/log/lnbackup_out 2>&1; fi
