# /bin/sh

# $1: local mb home
# $2: sc node
# $3: sc mb home
# $4: to email address
# $5: error to email address

# move
cd $1/cron

# scp report from sc
scp $2:$3/report/*txt $1/report
scp $2:$3/log/*txt $1/log

# send the report by email
ruby $1/cron/email-mb-list.rb -c $1 -t $4 -e $5
