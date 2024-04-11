#! /usr/local/bin/ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require 'roo'
require 'pp'
require 'builder'
require 'optparse'

#
# Bioinformation and DDBJ Center
# Kodama Yuichi
#

# 変更履歴
# 2024-03-19 metadata excel から tsv ファイルを生成
# 2024-04-11 デフォルトはエクセルファイル名をベース名に使用

### Options
inputs = ""
filename = ""
OptionParser.new{|opt|

	opt.on('-i [excel file(s)]', 'excel file(s)'){|v|
		raise "usage: -i excel file(s), wildcard can be used (e.g. JGA*xlsx)" if v.nil?
		inputs = v
		puts "Excel file(s): #{v}"
	}

	opt.on('-f [filename]', 'base filename for tsv'){|v|
		raise "usage: -f base filename for tsv" if v.nil?
		filename = v		
}

	begin
		opt.parse!
	rescue
		puts "Invalid option. #{opt}"
	end

}

## Base filename
# ファイル名指定ない場合はエクセルファイル名を使用
if filename.empty? && !inputs.empty? && File.basename(inputs) && !File.basename(inputs).empty?
	filename = File.basename(inputs).sub(/\.xlsx$/, "")	
end

puts "Base filename: #{filename}\n\n"

### Read excel file(s)

# open xlsx file
begin
	s = Roo::Excelx.new(inputs)
rescue
	raise "No such file to open."
end

# sheets
meta_object = ['MB_Study_IDF', 'MB_Assay_SDRF']

# array for metadata objects
idf_a = Array.new
sdrf_a = Array.new

# open a sheet and put data into an array with line number
for meta in meta_object

	s.default_sheet = meta

	i = 1 # line number
	for line in s

		case meta

		when "MB_Study_IDF" then
			idf_a.push(line)
		when "MB_Assay_SDRF" then
			sdrf_a.push(line)
		end

		i += 1
	end

end

## content to tsv
# IDF
unless idf_a.empty?

	idf_f = open("#{filename}.idf.txt", "w")

	idf_content_f = false
	idf_a.each{|line|

		line = line.reverse.drop_while(&:nil?).reverse
	
		idf_content_f = true if line.join("\t") =~ /^MAGE-TAB Version/
		
		if idf_content_f
			idf_f.puts line.join("\t")
		end
		
	}
	
	idf_f.close
	
end

# SDRF
unless sdrf_a.empty?

	sdrf_f = open("#{filename}.sdrf.txt", "w")

	sdrf_content_f = false
	sdrf_a.each{|line|

		line = line.reverse.drop_while(&:nil?).reverse
		
		sdrf_content_f = true if line.join("\t") =~ /^Source Name/
		
		if sdrf_content_f
			sdrf_f.puts line.join("\t")
		end
		
	}
	
	sdrf_f.close
	
end