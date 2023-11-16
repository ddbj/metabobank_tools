#! /usr/bin/ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require 'pp'
require 'csv'
require 'fileutils'

#
# 生命情報・DDBJ センター
# 2022-06-15 児玉
# MetaboBank common methods
#

###
### 配列の次元を取得
###
# getting dimension of multidimensional array in ruby
# https://stackoverflow.com/questions/9545613/getting-dimension-of-multidimensional-array-in-ruby
def get_dimension a
	return 0 if a.class != Array
	result = 1
	a.each do |sub_a|
		if sub_a.class == Array
			dim = get_dimension(sub_a)
			result = dim + 1 if dim + 1 > result
		end
	end
	return result
end

###
### ファイルサイズを human readable に
###
def readable_file_size(size)
	case
		when size == 0
			"0"
		when size < 1000
			"%d bytes" % size
		when size < 1000000
			"%.1f KB" % (size.to_f/1000)
		when size < 1000000000
			"%.1f MB" % (size.to_f/1000000)
		when size < 1000000000000
			"%.1f GB" % (size.to_f/1000000000)
	else 
		"%.1f TB" % (size.to_f/1000000000000)
	end
end

###
### 連番をまとめる
###
def range_extraction(list, prefix, digit)
	list.map{|e| e.sub(/#{prefix}/, "").to_i}.chunk_while {|i, j| i + 1 == j }.map do |a|		
		if a.size > 1
			"#{prefix}#{a.first.to_s.rjust(digit, "0")}-#{prefix}#{a.last.to_s.rjust(digit, "0")}"
		else
			"#{prefix}#{a[0].to_s.rjust(digit, "0")}"  
		end
	end.join(',')
end

###
### IDF パース
###
# idf のファイルパスを渡す。
# IDF の内容、及び、Experimental Factor, Submitter, Protocol, Publication, Term Source はセットを個別に格納したものを返す。
# 格納するうえで必須の最低限のチェックを実施。
def idf_parse(idf)

	# セル内改行に対応するため csv パース
	# https://ddbj-dev.atlassian.net/wiki/spaces/validator/pages/2077917185/Excel+Validator
	# https://shinkufencer.hateblo.jp/entry/2021/10/09/235821
	# ruby 2.7.0 CSV の liberal_parsing オプションについて調査してみた https://qiita.com/yohm/items/c3dde4acf0781fa442ea
	# csv https://ruby-doc.org/stdlib-3.1.2/libdoc/csv/rdoc/CSV.html
	begin
		result = CSV.read(idf, col_sep: "\t", liberal_parsing: true, skip_blanks: true, skip_lines: /^#/, nil_value: "", universal_newline: true)
	rescue		
		raise "TSV parse error: #{idf}"
	end

	idf_h = {}
	idf_group_h = {}
	idf_a = []
	mtbks = ""
	warning = ""
	error = ""
	content_flag = false

	for line_a in result

		content_flag = true if line_a.join("") =~ /MAGE-TAB Version|Comment\[MetaboBank accession\]|Study Title/

		# trailing "" を削除し、値を strip 処理。
		line_trimmed_a = line_a.reverse.drop_while(&:empty?).reverse.map{|v| v.strip}
		
		if !line_trimmed_a.empty? && content_flag
			idf_h.store(line_trimmed_a[0], line_trimmed_a[1..-1].empty? ? [""] : line_trimmed_a[1..-1])
			idf_a.push(line_trimmed_a)
			mtbks = line_trimmed_a[1] if line_trimmed_a[0] == "Comment[MetaboBank accession]"
		end

	end

	## Experimental Factor
	if idf_h["Experimental Factor Name"] && idf_h["Experimental Factor Type"]
		if idf_h["Experimental Factor Name"].size != idf_h["Experimental Factor Type"].size
			message = "Warning: Numbers of experimental factor name and type are different: #{mtbks} Experimental Factor Name-#{idf_h["Experimental Factor Name"].size}, Experimental Factor Type-#{idf_h["Experimental Factor Type"].size}"
			warning += "#{message}\n"
		end	
	end

	experimental_factor_a = []
	if idf_h["Experimental Factor Name"]
		idf_h["Experimental Factor Name"].size.times{|i|
			experimental_factor_h = {}
			experimental_factor_h.store("Experimental Factor Name", idf_h["Experimental Factor Name"][i].nil? ? "" : idf_h["Experimental Factor Name"][i])
			experimental_factor_h.store("Experimental Factor Type", idf_h["Experimental Factor Type"][i].nil? ? "" : idf_h["Experimental Factor Type"][i])
			experimental_factor_a.push(experimental_factor_h)
		}

		idf_group_h.store("Experimental Factor", experimental_factor_a)

	end

	## Person
	if idf_h["Person Last Name"]
		
		unless (idf_h["Person First Name"] && idf_h["Person Affiliation"] && idf_h["Person Roles"]) || [idf_h["Person Last Name"].size, idf_h["Person First Name"].size, idf_h["Person Affiliation"].size, idf_h["Person Roles"].size].all?{|v| v == idf_h["Person Last Name"].size}
			message = "Warning: Numbers of person last name, first name, affiliation and role are different. #{mtbks}"
			warning += "#{message}\n"
		end	

		person_a = []
		idf_h["Person Last Name"].size.times{|i|
			person_h = {}
			person_h.store("Person Last Name", idf_h["Person Last Name"][i].nil? ? "" : idf_h["Person Last Name"][i]) if idf_h["Person Last Name"]
			person_h.store("Person Mid Initials", idf_h["Person Mid Initials"][i].nil? ? "" : idf_h["Person Mid Initials"][i]) if idf_h["Person Mid Initials"]
			person_h.store("Person First Name", idf_h["Person First Name"][i].nil? ? "" : idf_h["Person First Name"][i]) if idf_h["Person First Name"]
			person_h.store("Person Email", idf_h["Person Email"][i].nil? ? "" : idf_h["Person Email"][i]) if idf_h["Person Email"]
			person_h.store("Person Affiliation", idf_h["Person Affiliation"][i].nil? ? "" : idf_h["Person Affiliation"][i]) if idf_h["Person Affiliation"]
			person_h.store("Person Roles", idf_h["Person Roles"][i].nil? ? "" : idf_h["Person Roles"][i]) if idf_h["Person Roles"]
			person_a.push(person_h)
		}

		idf_group_h.store("Person", person_a)
	
	end

	## Publication
	if idf_h["Publication Title"]

		unless (idf_h["Publication Status"] && idf_h["Publication Author List"]) || [idf_h["Publication Title"].size, idf_h["Publication Status"].size, idf_h["Publication Author List"].size].all?{|v| v == idf_h["Publication Title"].size}
			message = "Warning: Numbers of publication title, status and author list are different. #{mtbks}"
			warning += "#{message}\n"
		end	

		publication_a = []
		idf_h["Publication Title"].size.times{|i|
			publication_h = {}
			publication_h.store("Publication Title", idf_h["Publication Title"][i].nil? ? "" : idf_h["Publication Title"][i])
			publication_h.store("Publication Author List", idf_h["Publication Author List"][i].nil? ? "" : idf_h["Publication Author List"][i])
			publication_h.store("Publication Status", idf_h["Publication Status"][i].nil? ? "" : idf_h["Publication Status"][i])
			publication_a.push(publication_h)
		}

		idf_group_h.store("Publication", publication_a)
	
	end

	## Protocol
	if idf_h["Protocol Name"] && idf_h["Protocol Name"].size != idf_h["Protocol Type"].size
		message = "Warning: Numbers of protocol name and type are different. #{mtbks} Protocol Name #{idf_h["Protocol Name"].size}, Protocol Type #{idf_h["Protocol Type"].size}"
		warning += "#{message}\n"
	end

	protocol_a = []
	sample_collection_protocol_a = []
	extraction_protocol_a = []
	chromatography_protocol_a = []
	mass_spectrometry_protocol_a = []
	data_processing_protocol_a = []
	metabolite_identification_protocol_a = []

	if idf_h["Protocol Name"] && idf_h["Protocol Name"].size

		idf_h["Protocol Name"].size.times{|i|

			protocol_h = {}
			protocol_h.store("Protocol Name", idf_h["Protocol Name"][i].nil? ? "" : idf_h["Protocol Name"][i]) if idf_h["Protocol Name"]
			protocol_h.store("Protocol Type", idf_h["Protocol Type"][i].nil? ? "" : idf_h["Protocol Type"][i]) if idf_h["Protocol Type"]
			protocol_h.store("Protocol Description", idf_h["Protocol Description"][i].nil? ? "" : idf_h["Protocol Description"][i]) if idf_h["Protocol Description"]
			protocol_h.store("Protocol Parameters", idf_h["Protocol Parameters"][i].nil? ? "" : idf_h["Protocol Parameters"][i]) if idf_h["Protocol Parameters"]
			protocol_h.store("Protocol Hardware", idf_h["Protocol Hardware"][i].nil? ? "" : idf_h["Protocol Hardware"][i]) if idf_h["Protocol Hardware"]
			protocol_h.store("Protocol Software", idf_h["Protocol Software"][i].nil? ? "" : idf_h["Protocol Software"][i]) if idf_h["Protocol Software"]
			protocol_a.push(protocol_h)

			case idf_h["Protocol Type"][i]

			when "Sample collection"
				
				sample_collection_protocol_h = {}
				sample_collection_protocol_h.store("Protocol Name", idf_h["Protocol Name"][i].nil? ? "" : idf_h["Protocol Name"][i]) if idf_h["Protocol Name"]
				sample_collection_protocol_h.store("Protocol Type", idf_h["Protocol Type"][i].nil? ? "" : idf_h["Protocol Type"][i]) if idf_h["Protocol Type"]
				sample_collection_protocol_h.store("Protocol Description", idf_h["Protocol Description"][i].nil? ? "" : idf_h["Protocol Description"][i]) if idf_h["Protocol Description"]
				sample_collection_protocol_h.store("Protocol Parameters", idf_h["Protocol Parameters"][i].nil? ? "" : idf_h["Protocol Parameters"][i]) if idf_h["Protocol Parameters"]
				sample_collection_protocol_h.store("Protocol Hardware", idf_h["Protocol Hardware"][i].nil? ? "" : idf_h["Protocol Hardware"][i]) if idf_h["Protocol Hardware"]
				sample_collection_protocol_h.store("Protocol Software", idf_h["Protocol Software"][i].nil? ? "" : idf_h["Protocol Software"][i]) if idf_h["Protocol Software"]
				sample_collection_protocol_a.push(sample_collection_protocol_h)

			when "Extraction"
				
				extraction_protocol_h = {}
				extraction_protocol_h.store("Protocol Name", idf_h["Protocol Name"][i].nil? ? "" : idf_h["Protocol Name"][i]) if idf_h["Protocol Name"]
				extraction_protocol_h.store("Protocol Type", idf_h["Protocol Type"][i].nil? ? "" : idf_h["Protocol Type"][i]) if idf_h["Protocol Type"]
				extraction_protocol_h.store("Protocol Description", idf_h["Protocol Description"][i].nil? ? "" : idf_h["Protocol Description"][i]) if idf_h["Protocol Description"]
				extraction_protocol_h.store("Protocol Parameters", idf_h["Protocol Parameters"][i].nil? ? "" : idf_h["Protocol Parameters"][i]) if idf_h["Protocol Parameters"]
				extraction_protocol_h.store("Protocol Hardware", idf_h["Protocol Hardware"][i].nil? ? "" : idf_h["Protocol Hardware"][i]) if idf_h["Protocol Hardware"]
				extraction_protocol_h.store("Protocol Software", idf_h["Protocol Software"][i].nil? ? "" : idf_h["Protocol Software"][i]) if idf_h["Protocol Software"]
				extraction_protocol_a.push(extraction_protocol_h)

			when "Chromatography"
				
				chromatography_protocol_h = {}
				chromatography_protocol_h.store("Protocol Name", idf_h["Protocol Name"][i].nil? ? "" : idf_h["Protocol Name"][i]) if idf_h["Protocol Name"]
				chromatography_protocol_h.store("Protocol Type", idf_h["Protocol Type"][i].nil? ? "" : idf_h["Protocol Type"][i]) if idf_h["Protocol Type"]
				chromatography_protocol_h.store("Protocol Description", idf_h["Protocol Description"][i].nil? ? "" : idf_h["Protocol Description"][i]) if idf_h["Protocol Description"]
				chromatography_protocol_h.store("Protocol Parameters", idf_h["Protocol Parameters"][i].nil? ? "" : idf_h["Protocol Parameters"][i]) if idf_h["Protocol Parameters"]
				chromatography_protocol_h.store("Protocol Hardware", idf_h["Protocol Hardware"][i].nil? ? "" : idf_h["Protocol Hardware"][i]) if idf_h["Protocol Hardware"]
				chromatography_protocol_h.store("Protocol Software", idf_h["Protocol Software"][i].nil? ? "" : idf_h["Protocol Software"][i]) if idf_h["Protocol Software"]
				chromatography_protocol_a.push(chromatography_protocol_h)		

			when "Mass spectrometry"
				
				mass_spectrometry_protocol_h = {}
				mass_spectrometry_protocol_h.store("Protocol Name", idf_h["Protocol Name"][i].nil? ? "" : idf_h["Protocol Name"][i]) if idf_h["Protocol Name"]
				mass_spectrometry_protocol_h.store("Protocol Type", idf_h["Protocol Type"][i].nil? ? "" : idf_h["Protocol Type"][i]) if idf_h["Protocol Type"]
				mass_spectrometry_protocol_h.store("Protocol Description", idf_h["Protocol Description"][i].nil? ? "" : idf_h["Protocol Description"][i]) if idf_h["Protocol Description"]
				mass_spectrometry_protocol_h.store("Protocol Parameters", idf_h["Protocol Parameters"][i].nil? ? "" : idf_h["Protocol Parameters"][i]) if idf_h["Protocol Parameters"]
				mass_spectrometry_protocol_h.store("Protocol Hardware", idf_h["Protocol Hardware"][i].nil? ? "" : idf_h["Protocol Hardware"][i]) if idf_h["Protocol Hardware"]
				mass_spectrometry_protocol_h.store("Protocol Software", idf_h["Protocol Software"][i].nil? ? "" : idf_h["Protocol Software"][i]) if idf_h["Protocol Software"]
				mass_spectrometry_protocol_a.push(mass_spectrometry_protocol_h)				

			when "Data processing"
				
				data_processing_protocol_h = {}
				data_processing_protocol_h.store("Protocol Name", idf_h["Protocol Name"][i].nil? ? "" : idf_h["Protocol Name"][i]) if idf_h["Protocol Name"]
				data_processing_protocol_h.store("Protocol Type", idf_h["Protocol Type"][i].nil? ? "" : idf_h["Protocol Type"][i]) if idf_h["Protocol Type"]
				data_processing_protocol_h.store("Protocol Description", idf_h["Protocol Description"][i].nil? ? "" : idf_h["Protocol Description"][i]) if idf_h["Protocol Description"]
				data_processing_protocol_h.store("Protocol Parameters", idf_h["Protocol Parameters"][i].nil? ? "" : idf_h["Protocol Parameters"][i]) if idf_h["Protocol Parameters"]
				data_processing_protocol_h.store("Protocol Hardware", idf_h["Protocol Hardware"][i].nil? ? "" : idf_h["Protocol Hardware"][i]) if idf_h["Protocol Hardware"]
				data_processing_protocol_h.store("Protocol Software", idf_h["Protocol Software"][i].nil? ? "" : idf_h["Protocol Software"][i]) if idf_h["Protocol Software"]
				data_processing_protocol_a.push(data_processing_protocol_h)		

			when "Metabolite identification"
				
				metabolite_identification_protocol_h = {}
				metabolite_identification_protocol_h.store("Protocol Name", idf_h["Protocol Name"][i].nil? ? "" : idf_h["Protocol Name"][i]) if idf_h["Protocol Name"]
				metabolite_identification_protocol_h.store("Protocol Type", idf_h["Protocol Type"][i].nil? ? "" : idf_h["Protocol Type"][i]) if idf_h["Protocol Type"]
				metabolite_identification_protocol_h.store("Protocol Description", idf_h["Protocol Description"][i].nil? ? "" : idf_h["Protocol Description"][i]) if idf_h["Protocol Description"]
				metabolite_identification_protocol_h.store("Protocol Parameters", idf_h["Protocol Parameters"][i].nil? ? "" : idf_h["Protocol Parameters"][i]) if idf_h["Protocol Parameters"]
				metabolite_identification_protocol_h.store("Protocol Hardware", idf_h["Protocol Hardware"][i].nil? ? "" : idf_h["Protocol Hardware"][i]) if idf_h["Protocol Hardware"]
				metabolite_identification_protocol_h.store("Protocol Software", idf_h["Protocol Software"][i].nil? ? "" : idf_h["Protocol Software"][i]) if idf_h["Protocol Software"]
				metabolite_identification_protocol_a.push(metabolite_identification_protocol_h)		

			end			

		}

		idf_group_h.store("Protocol", protocol_a)
		idf_group_h.store("Sample collection protocol", sample_collection_protocol_a)
		idf_group_h.store("Extraction protocol", extraction_protocol_a)
		idf_group_h.store("Chromatography protocol", chromatography_protocol_a)
		idf_group_h.store("Mass spectrometry protocol", mass_spectrometry_protocol_a)
		idf_group_h.store("Data processing protocol", data_processing_protocol_a)
		idf_group_h.store("Metabolite identification protocol", metabolite_identification_protocol_a)

	end

	## Term Source
	if idf_h["Term Source Name"]

		unless (idf_h["Term Source File"] && idf_h["Term Source Version"]) || [idf_h["Term Source Name"].size, idf_h["Term Source File"].size, idf_h["Term Source Version"].size].all?{|v| v == idf_h["Term Source Name"].size}
			message = "Warning: Numbers of term source name, file and version are different. #{mtbks}"
			warning += "#{message}\n"
		end	
	
		term_source_a = []
		idf_h["Term Source Name"].size.times{|i|
			term_source_h = {}
			term_source_h.store("Term Source Name", idf_h["Term Source Name"][i].nil? ? "" : idf_h["Term Source Name"][i])
			term_source_h.store("Term Source File", idf_h["Term Source File"][i].nil? ? "" : idf_h["Term Source File"][i])
			term_source_h.store("Term Source Version", idf_h["Term Source Version"][i].nil? ? "" : idf_h["Term Source Version"][i])
			term_source_a.push(term_source_h)
		}

		idf_group_h.store("Term Source", term_source_a)
	
	end

	# MTBKS アクセッション番号と idf ハッシュを返す
	return mtbks, idf_h, idf_a, idf_group_h, result, warning

end

###
### SDRF パース
###
# sdrf のファイルパスを渡す
def sdrf_parse(sdrf)

	sdrf_a = []
	sample_h = {}
	warning = ""
	error = ""

	# セル内改行に対応するため csv パース
	begin
		result = CSV.read(sdrf, col_sep: "\t", liberal_parsing: true, skip_blanks: true, skip_lines: /^#/, nil_value: "", universal_newline: true)
	rescue		
		raise "TSV parse error: #{sdrf}"
	end

	mtbks_file = ""
	if sdrf =~ /(MTBKS\d{1,})\.sdrf\.txt/
		mtbks_file = $1
	end

	i = 0
	l = 0
	header_a = []
	header_size = 0
	for line_a in result
		
		# Source Name がある行以降を格納
		content_flag = true if line_a.join("") =~ /^Source Name/

		# source name がない行で終了
		next "No Source Name at line #{l} #{sdrf}. Skip the line." if line_a[0].nil? || line_a[0].empty?

		# nil を "" に変換、値を strip
		line_trimmed_a = line_a.map{|v| v.strip}

		# ヘッダーを取得
		if i == 0 && content_flag
			header_a = line_a
			header_size = header_a.size
		end

		# ヘッダー以降はドロップ
		if content_flag

			sdrf_a.push(line_trimmed_a[0, header_size])
			
			biosample_accession = ""
			each_sample_h = {}
			j = 0		

			for item in line_trimmed_a
		
				# each sample
				if header_a[j] == "Comment[BioSample]"
					biosample_accession = item if item =~ /^SAMD\d{8}$/
				elsif header_a[j] == "Comment[sample_title]"
					each_sample_h.store("sample_title", item)
				elsif header_a[j] == "Comment[description]"
					each_sample_h.store("description", item)
				elsif header_a[j] =~ /Characteristics\[(.*)\]/
					each_sample_h.store($1, item)
				end

				j += 1

			end

			sample_h.store(biosample_accession, each_sample_h) if i > 0 && biosample_accession != ""
			
			i += 1

		end

		l += 1

	end
	
	## 転置
	sdrf_transpose_h = {}
	sdrf_transpose_a = []
	padding_size = 0

	begin
		sdrf_transpose_a = sdrf_a.transpose
	rescue
		sdrf_for_transpose_a = []
		for sdrf_line_a in sdrf_a
			
			if sdrf_line_a.size < header_size			
				(header_size - sdrf_line_a.size).times{|p|
					sdrf_line_a.push("")
				}			
				sdrf_for_transpose_a.push(sdrf_line_a)
				padding_size = header_size - sdrf_line_a.size
			else
				sdrf_for_transpose_a.push(sdrf_line_a)
			end

		end
		
		sdrf_transpose_a = sdrf_for_transpose_a.transpose
		puts "SDRF array transpose error: #{sdrf} #{padding_size} empty elements were added for transpose."	if padding_size > 0
	
	end


	for item in sdrf_transpose_a
		
		if sdrf_transpose_h.has_key?(item[0])			

			if get_dimension(sdrf_transpose_h[item[0]]) > 1
				sdrf_transpose_h.store(item[0], sdrf_transpose_h[item[0]].push(item[1..-1]))
			elsif get_dimension(sdrf_transpose_h[item[0]]) == 1
				sdrf_transpose_h.store(item[0], [sdrf_transpose_h[item[0]]].push(item[1..-1]))
			end

		else
			sdrf_transpose_h.store(item[0], item[1..-1])
		end
		
	end

	return mtbks_file, sdrf_a, sdrf_transpose_h, sample_h, warning

end

###
### BioSample tsv パース
###
# BioSample tsv のファイルパスを渡す。
def bs_parse(biosample)

	bs_h = {}

	result = CSV.read(biosample, col_sep: "\t", liberal_parsing: true, universal_newline: true)
		
	warning = ""
	error = ""

	bs_header_a = result[0].collect{|e| e.sub(/^\*/, "")}
	bs_accession_index = bs_header_a.index("biosample_accession")
	for line_a in result[1..-1]
	
		i = 0
		bs_record_h = {}
		for item in line_a
			bs_record_h.store(bs_header_a[i], item.nil? ? "" : item)
			i += 1
		end

		bs_h.store(line_a[bs_accession_index], bs_record_h)

	end

	return bs_h

end

