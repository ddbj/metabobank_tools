# /bin/sh

# move
cd /home/ykodama/mb/cron

# scp report from at128
scp at128:/home/mbadmin/report/*txt /home/ykodama/mb/report
scp at128:/home/mbadmin/log/*txt /home/ykodama/mb/log

# send the report by email
ruby /home/ykodama/mb/cron/email-mb-list.rb


