#! /usr/local/bin/ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require 'pp'
require 'optparse'

mb_path, to, eto = "", "", ""
OptionParser.new{|opt|

	opt.on('-c PATH', 'path to mb directory') {|v|
    mb_path = v
  }

  opt.on('-t EMAIL ADDRESS', 'daily report is sent to this email address') {|v|
    to = v
  }

	opt.on('-e EMAIL ADDRESS', 'error report is sent to this email address') {|v|
    eto = v
  }

  begin
    opt.parse!
  rescue
		puts "Invalid option. #{opt}"
	end
}

# 最新リストの取得
latest_list = Dir.glob("#{mb_path}/report/*txt").sort[-1]
latest_date = ""
if latest_list =~ /(\d{4}-\d{2}-\d{2})/
	latest_date = $1
end

if FileTest.exist?(latest_list)
	`mpack -s "#{latest_date} MetaboBank daily report" -d #{mb_path}/cron/report-mail-body.txt #{latest_list} #{to}`
else
	`mpack -s "#{latest_date} MetaboBank daily report 失敗" -d #{mb_path}/cron/report-mail-body-fail.txt #{eto}`
end
