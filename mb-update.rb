#! /usr/bin/ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require 'pp'
require 'csv'
require 'fileutils'
require 'optparse'
require 'json'
require 'time'
require './lib/mb-method.rb'
#require '/usr/local/bin/lib/mb-method.rb'

#
# 生命情報・DDBJ センター
# 2022-06-29 児玉
# MetaboBank IDF and submission status update tool
#

###
### 設定
###
conf_path = "conf"
#conf_path = "/usr/local/bin/conf"

###
### 入力
###

## Options
idf_path = ""
last_update_date = Date.today.strftime("%Y-%m-%d")
status = ""
reviewer_access_flag = false
OptionParser.new{|opt|

	opt.on('-i [IDF file]', 'IDF file path'){|v|
		raise "usage: -i IDF file (MTBKS1.idf.txt)" if v.nil?
		idf_path = v		
	}

	opt.on('-d [last update date]', 'last update date'){|v|
		raise "usage: -d last update date (yyyy-mm-dd)" unless v =~ /20\d{2}-\d{2}-\d{2}/
		last_update_date = v		
	}

	opt.on('-s [status]', 'status'){|v|
		raise "usage: -s status (temporarily-suppressed, permanently-suppressed, cancelled, killed)" unless ["temporarily-suppressed", "permanently-suppressed", "cancelled", "killed"].include?(v)
		status = v
	}

	opt.on('-r [reviewer access flag]', 'reviewer access flag'){|v|
		reviewer_access_flag = true
	}

	begin

		opt.parse!

	rescue

		puts "Invalid option. #{opt}"

	end

}

## 設定出力
puts "IDF: #{idf_path}"
puts "Status: #{status}" if status != ""
puts "Last update date: #{last_update_date}"
puts "Reviewer access flag: #{reviewer_access_flag}" if reviewer_access_flag

## ファイル名
idf_file = File.basename(idf_path)

###
### parse
###

## IDF parse
mtbks_idf, idf_h, idf_a, idf_group_h, raw_idf_a, warning_idf_parse = idf_parse(idf_path)

# last update date
idf_corrected_h = {}
idf_corrected_h.store("Comment[Last Update Date]", [last_update_date])

idf_updated_file_path = "#{idf_path.sub(".idf.txt", ".updated.idf.txt")}"
idf_updated_file = open(idf_updated_file_path, "w")

# last update date を更新した IDF ファイルを作成。
# オリジナルファイルを上書き
# reviewer access は flag 変更なので日付は変更しない。

# IDF blank line before
blank_line_before_a = []
open("#{conf_path}/idf_blank_before.json"){|f|
	blank_line_before_a = JSON.load(f)
}

unless reviewer_access_flag

	for line_a in idf_a

		field_name = line_a[0]
		field_value_a = line_a[1..-1]

		# 空行挿入
		idf_updated_file.puts "" if blank_line_before_a.include?(field_name)

		# auto-correction
		if idf_corrected_h[field_name]
			idf_updated_file.puts "#{field_name}\t#{idf_corrected_h[field_name].collect{|e| e.match(/\n|\t/) ? '"' + e + '"' : e }.join("\t")}"
		else
			idf_updated_file.puts line_a.collect{|e| e.match(/\n|\t/) ? '"' + e + '"' : e }.join("\t")
		end

	end

	idf_updated_file.close

	`mv #{idf_updated_file_path} #{idf_path}`

end


# status file 設定
last_update_date_touch = Time.parse(last_update_date).strftime("%Y/%-m/%-d 12:00")
idf_dir = File.dirname(idf_path)
status_file_not_review_a = Dir.glob("#{idf_dir}/status-*").collect{|e| e.sub("#{idf_dir}/", "")}.reject{|e| e == "status-reviewer-access.txt"}
if status != ""

	puts "WARNING: status file already exist. #{mtbks_idf} #{status_file_not_review_a.join(",")}" if status_file_not_review_a.size > 0

	case status

	when "temporarily-suppressed"
		`touch --date="#{last_update_date_touch}" #{idf_dir}/status-temporarily-suppressed.txt`
	when "permanently-suppressed"
		`touch --date="#{last_update_date_touch}" #{idf_dir}/status-permanently-suppressed.txt`
	when "cancelled"
		`touch --date="#{last_update_date_touch}" #{idf_dir}/status-cancelled.txt`
	when "killed"
		`touch --date="#{last_update_date_touch}" #{idf_dir}/status-killed.txt`
	end

end

# reviewer access
review_file_exist = false
review_file_exist = true if File.exist?("#{idf_dir}/status-reviewer-access.txt")
if reviewer_access_flag
	
	puts "WARNING: Reviewer-access study has status files. #{mtbks_idf} #{status_file_not_review_a.join(",")}" if status_file_not_review_a.size > 0
	puts "WARNING: Set reviewer-access and status file at the same time. #{mtbks_idf} #{status_file_not_review_a.join(",")}" if status != ""
	puts "WARNING: Reviewer-access file already exist. #{mtbks_idf} #{status_file_not_review_a.join(",")}" if review_file_exist
		
	`touch --date="#{last_update_date_touch}" #{idf_dir}/status-reviewer-access.txt`

end