#! /usr/local/bin/ruby
# -*- coding: utf-8 -*-

# 最新リストの取得
latest_list = Dir.glob("/home/ykodama/mb/report/*txt").sort[-1]
latest_date = ""
if latest_list =~ /(\d{4}-\d{2}-\d{2})/
	latest_date = $1
end

if FileTest.exist?(latest_list)
	`mpack -s "#{latest_date} MetaboBank daily report" -d /home/ykodama/mb/cron/report-mail-body.txt #{latest_list} const@g.nig.ac.jp`
else
	`mpack -s "#{latest_date} MetaboBank daily report 失敗" -d /home/ykodama/mb/cron/report-mail-body-fail.txt ykodama@nig.ac.jp`
end
