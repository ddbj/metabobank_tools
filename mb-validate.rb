#! /usr/bin/ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require 'pp'
require 'csv'
require 'fileutils'
require 'optparse'
require 'json'
require './lib/mb-method.rb'
#require '/usr/local/bin/lib/mb-method.rb'

#
# 生命情報・DDBJ センター
# 2022-06-15 児玉
# MetaboBank IDF, SDRF validator
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
sdrf_path = ""
bs_path = ""
md_path = ""
corrected_dir = ""
data_file_validation_flag = false
auto_correction_flag = false
OptionParser.new{|opt|

	opt.on('-i [IDF file]', 'IDF file path'){|v|
		raise "usage: -i IDF file (MTBKS1.idf.txt)" if v.nil?
		idf_path = v
		puts "IDF: #{v}"
	}

	opt.on('-s [SDRF file]', 'SDRF file path'){|v|
		
		if v == ""
			sdrf_path = idf_path.sub(".idf.txt", ".sdrf.txt")
		else
			sdrf_path = v
		end

		puts "SDRF: #{v}"
	}

	opt.on('-t [BioSample tsv file]', 'BioSample tsv'){|v|
		
		if v != ""
			bs_path = v
			puts "BioSample tsv: #{v}"
		end

	}

	opt.on('-m [md5 checksum file]', 'md5sum file'){|v|
		
		if v != ""
			md_path = v
			puts "md5 checksum file: #{v}"
		end

	}

	opt.on('-d', 'Check data files'){|v|
		
		data_file_validation_flag = true

	}

	opt.on('-a', 'Auto-correction'){|v|
				
		auto_correction_flag = true

	}

	opt.on('-o [output corrected file]', 'output directory of corrected files'){|v|
		
		if v == ""
			corrected_dir = File.dirname(idf_path)
		else
			corrected_dir = v
		end

	}

	begin

		opt.parse!

		if sdrf_path.empty?
			sdrf_path = idf_path.sub(".idf.txt", ".sdrf.txt")
			puts "SDRF: #{sdrf_path}"
		end

		if corrected_dir.empty?
			corrected_dir = File.dirname(idf_path)
			puts "Auto-corrected files will be generated at #{corrected_dir}" if auto_correction_flag
		else		
			puts "Auto-corrected files will be generated at #{corrected_dir}" if auto_correction_flag
		end

	rescue

		puts "Invalid option. #{opt}"

	end

}

# data file validation on/off
if data_file_validation_flag
	puts "Validate data files."
else
	puts "No data file validation."
end

## ファイル名
idf_file = File.basename(idf_path)
sdrf_file = File.basename(sdrf_path)

idf_dir = File.dirname(idf_path)

###
### parse
###

## IDF parse
mtbks_idf, idf_h, idf_a, idf_group_h, raw_idf_a, warning_idf_parse = idf_parse(idf_path)

## SDRF parse
mtbks_sdrf, sdrf_a, sdrf_transpose_h, sdrf_bs_h, warning_sdrf_parse = sdrf_parse(sdrf_path)

## BioSample parse
if bs_path != ""
	bs_h = bs_parse(bs_path)
end

##
## md5 checksum file
##
md_h = {}
different_md_file_a = []
if md_path != ""

	md_f = open(md_path)
	for line in md_f.readlines
		if line =~ /^([A-Za-z0-9]{32})  (.*)$/
			different_md_file_a.push($2) if md_h[$2] && md_h[$2] != $1
			md_h.store($2, $1)			
		end
	end
	md_f.close

end

###
### validate
###

## IDF
# rules
# https://docs.google.com/spreadsheets/d/15pENGHA9hkl6QIueFb44fhQfQMThRB2tbvSE6hItHEU/edit#gid=831672616

warning_idf_a = []
error_ignore_idf_a = []
error_idf_a = []

## MB_IR0003 error Duplicated field names

#
# IDF フィールド名を取得。フィールド全体に対するチェックを実施。
#
idf_field_a = []
for line_a in idf_a
	idf_field_a.push(line_a[0]) if line_a && !line_a[0].empty?
end

if idf_field_a.select{|v| idf_field_a.count(v) > 1 }.uniq.size > 0
	error_idf_a.push(["MB_IR0003", "error", "Duplicated field names: #{idf_file}: #{idf_field_a.select{|v| idf_field_a.count(v) > 1 }.uniq.join(",")}"])
end


## MB_IR0004 error ignore Undefined field names
idf_fields_list_a = []
open("#{conf_path}/idf_fields_list.json"){|f|
	idf_fields_list_a = JSON.load(f)
}

# 定義リストにないフィールド名
if (idf_field_a.sort.uniq - idf_fields_list_a).size > 0
	error_ignore_idf_a.push(["MB_IR0004", "error_ignore", "Undefined field name: #{idf_file}: #{(idf_field_a.sort.uniq - idf_fields_list_a).join(",")}"])
end


### MB_IR0005 error Missing required field
idf_required_fields_error_a = []
open("#{conf_path}/idf_required_fields_error.json"){|f|
	idf_required_fields_error_a = JSON.load(f)
}

# 必須で値が無い項目
idf_missing_required_fields_error_a = []
for required_field in idf_required_fields_error_a
	idf_missing_required_fields_error_a.push(required_field) if idf_h[required_field].nil? || idf_h[required_field] == ""
end

if idf_missing_required_fields_error_a.size > 0
	error_idf_a.push(["MB_IR0005", "error", "Missing required field: #{idf_file}: #{idf_missing_required_fields_error_a.join(",")}"])
end


### MB_IR0006 warning Missing required field
idf_required_fields_warning_a = []
open("#{conf_path}/idf_required_fields_warning.json"){|f|
	idf_required_fields_warning_a = JSON.load(f)
}

# 必須で値が無い項目 warning
idf_missing_required_fields_warning_a = []
for required_field in idf_required_fields_warning_a
	idf_missing_required_fields_warning_a.push(required_field) if idf_h[required_field].empty?
end

if idf_missing_required_fields_warning_a.size > 0
	warning_idf_a.push(["MB_IR0006", "warning", "Missing required field: #{idf_file}: #{idf_missing_required_fields_warning_a.join(",")}"])
end


### MB_IR0007 error Null for required field
idf_required_fields_not_null_a = []
open("#{conf_path}/idf_required_fields_not_null.json"){|f|
	idf_required_fields_not_null_a = JSON.load(f)
}

# null values
null_values_a = []
open("#{conf_path}/null_accepted.json"){|f|
	null_values_a = JSON.load(f)
}

# 必須で null value error
idf_null_for_required_fields_not_null_a = []
for required_field in idf_required_fields_not_null_a
	if idf_h[required_field] && ( idf_h[required_field] == "" || (idf_h[required_field] - null_values_a).size == 0)
		idf_null_for_required_fields_not_null_a.push(required_field)
	end
end

if idf_null_for_required_fields_not_null_a.size > 0
	error_idf_a.push(["MB_IR0007", "error", "Missing or null value for required field: #{idf_file}: #{idf_null_for_required_fields_not_null_a.join(",")}"])
end


### MB_IR0008 error Missing required field in field group
idf_required_fields_group_error_h = {}
open("#{conf_path}/idf_required_group_error.json"){|f|
	idf_required_fields_group_error_h = JSON.load(f)
}

idf_missing_required_fields_group_error_a = []
for group_name, group_field_a in idf_required_fields_group_error_h
	# Publication etc が項目として存在し、かつメイン項目 (json 定義配列の最初の項目) が空ではないとき。全部空はあり得る
	if idf_group_h[group_name]
		for group_h in idf_group_h[group_name]		
			if group_h[group_field_a[0]] != ""
				for group_field in group_field_a
					if group_h[group_field].nil? || group_h[group_field].empty?
						idf_missing_required_fields_group_error_a.push(group_name)
					end
				end
			end
		end
	end
end

if idf_missing_required_fields_group_error_a.sort.uniq.size > 0
	error_idf_a.push(["MB_IR0008", "error", "Missing required field in field group: #{idf_file}: #{idf_missing_required_fields_group_error_a.sort.uniq.join(",")}"])
end

### MB_IR0009 warning Missing required field in field group
idf_required_fields_group_warning_h = {}
open("#{conf_path}/idf_required_group_warning.json"){|f|
	idf_required_fields_group_warning_h = JSON.load(f)
}

idf_missing_required_fields_group_warning_a = []
for group_name, group_field_a in idf_required_fields_group_warning_h
	# Publication etc が項目として存在する場合のみ
	if idf_group_h[group_name]
		for group_h in idf_group_h[group_name]		
			for group_field in group_field_a
				if group_h[group_field].nil? || group_h[group_field].empty?
					idf_missing_required_fields_group_warning_a.push(group_name)
				end
			end
		end
	end
end

if idf_missing_required_fields_group_warning_a.sort.uniq.size > 0
	warning_idf_a.push(["MB_IR0009", "warning", "Missing required field in field group: #{idf_file}: #{idf_missing_required_fields_group_warning_a.sort.uniq.join(",")}"])
end


### MB_IR0010 error Multiple values
idf_fields_single_value_a = []
open("#{conf_path}/idf_fields_single_value.json"){|f|
	idf_fields_single_value_a = JSON.load(f)
}

idf_multiple_values_error_a = []
for single_value_field in idf_fields_single_value_a
	# single value field の値が存在する場合、一つであること
	if idf_h[single_value_field]
 		idf_multiple_values_error_a.push(single_value_field) if idf_h[single_value_field].size > 1
	end
end

if idf_multiple_values_error_a.size > 0
	error_idf_a.push(["MB_IR0010", "error", "Multiple values are entered in fields which allow only single value: #{idf_file}: #{idf_multiple_values_error_a.join(",")}"])
end


### MB_IR0013 warning Invalid date format


### MB_IR0015 error Invalid value for controlled terms
idf_not_cv_error_h = {}
open("#{conf_path}/controlled_terms.json"){|f|
	idf_not_cv_error_h = JSON.load(f)["idf"]["error"]
}

idf_field_not_cv_error_h = {}
for field, cv_term_a in idf_not_cv_error_h	
	if idf_h[field]
		if (idf_h[field] - cv_term_a).size > 0			
			idf_field_not_cv_error_h.store(field, (idf_h[field] - cv_term_a).join(","))
		end
	end
end

if idf_field_not_cv_error_h.size > 0
	for key, value in idf_field_not_cv_error_h
		error_idf_a.push(["MB_IR0015", "error", "Value is not in controlled terms: #{idf_file} #{key}:#{value}"])	
	end
end


### MB_IR0016 warning Invalid value for controlled terms
idf_not_cv_warning_h = {}
open("#{conf_path}/controlled_terms.json"){|f|
	idf_not_cv_warning_h = JSON.load(f)["idf"]["warning"]
}

idf_field_not_cv_warning_h = {}
for field, cv_term_a in idf_not_cv_warning_h
	if idf_h[field]
		if (idf_h[field] - cv_term_a).size > 0
			idf_field_not_cv_warning_h.store(field, (idf_h[field] - cv_term_a).join(","))
		end
	end
end

if idf_field_not_cv_warning_h.size > 0
	for key, value in idf_field_not_cv_warning_h
		warning_idf_a.push(["MB_IR0016", "warning", "Value is not in controlled terms: #{idf_file} #{key}:#{value}"])	
	end
end

### MB_IR0017 error Missing protocol parameter for submission type
submission_type = ""
submission_type = idf_h["Comment[Submission type]"][0] if idf_h["Comment[Submission type]"] && idf_h["Comment[Submission type]"][0]

idf_required_protocol_types_error_h = {}
open("#{conf_path}/idf_required_protocol_types_error.json"){|f|
	idf_required_protocol_types_error_h = JSON.load(f)
}

if idf_required_protocol_types_error_h[submission_type] && idf_h["Protocol Type"] && (idf_required_protocol_types_error_h[submission_type] - idf_h["Protocol Type"]).size > 0
	error_idf_a.push(["MB_IR0017", "error", "Missing protocol type for submission type: #{idf_file} #{submission_type}:#{(idf_required_protocol_types_error_h[submission_type] - idf_h["Protocol Type"]).join(",")}"])	
end


### MB_IR0018 error Missing protocol parameter for submission type
idf_required_protocol_parameters_error_h = {}
open("#{conf_path}/idf_required_protocol_parameters_error.json"){|f|
	idf_required_protocol_parameters_error_h = JSON.load(f)
}

if idf_required_protocol_parameters_error_h[submission_type]
	for protocol_type, parameter_a in idf_required_protocol_parameters_error_h[submission_type]
		
		if idf_group_h["Protocol"]

			for protocol_h in idf_group_h["Protocol"]
				
				if protocol_h["Protocol Type"] && protocol_h["Protocol Type"] == protocol_type
					
					## missing
					if (parameter_a - protocol_h["Protocol Parameters"].split(";")).size > 0
						error_idf_a.push(["MB_IR0018", "error", "Missing protocol parameter for submission type: #{idf_file} #{submission_type} #{protocol_type}:#{(parameter_a - protocol_h["Protocol Parameters"].split(";")).join(",")}"])
					end
				
					## additional
					if (protocol_h["Protocol Parameters"].split(";") - parameter_a).size > 0
						warning_idf_a.push(["MB_IR0036", "warning", "Protocol parameter(s) is added by user besides default parameters for the submission type: #{idf_file} #{submission_type} #{protocol_type}:#{(protocol_h["Protocol Parameters"].split(";") - parameter_a).join(",")}"])
					end

				end
			end
		end
	end	
end


### MB_IR0020 error Misssing submitter
### MB_IR0037 error ignore Missing email address
submitter_number = 0
person_number = 0
person_without_email_a = []
if idf_group_h["Person"]
	for person_h in idf_group_h["Person"]
		
		person_number += 1
		
		if person_h["Person Roles"] == "submitter"
			submitter_number += 1
		end

		if person_h["Person Email"].nil? || person_h["Person Email"] == ""
			person_without_email_a.push("#{person_h["Person First Name"]} #{person_h["Person Last Name"]}")
		end

	end
end

if submitter_number == 0
	error_idf_a.push(["MB_IR0020", "error", "At least one submitter must be specified: #{idf_file}"])
end

if person_without_email_a.size > 0
	error_ignore_idf_a.push(["MB_IR0037", "error_ignore", "Every submitter should have an email address. The email address is not displayed publicly. If the persons are not appropriate for submitters, please list them in the Comment[Contributor] field as free-text.: #{person_without_email_a.join(",")}"])
end

### MB_IR0021 warning Invalid value for null
null_not_recommended_a = []
open("#{conf_path}/null_not_recommended.json"){|f|
	null_not_recommended_a = JSON.load(f)
}

# 必須以外の任意項目収集
idf_optional_field_a = []
open("#{conf_path}/idf_required_fields_error.json"){|f|
	idf_optional_field_a = JSON.load(f)
}

open("#{conf_path}/idf_required_fields_ignore_error.json"){|f|
	idf_optional_field_a += JSON.load(f)
}

open("#{conf_path}/idf_required_fields_not_null.json"){|f|
	idf_optional_field_a += JSON.load(f)
}

open("#{conf_path}/idf_required_fields_warning.json"){|f|
	idf_optional_field_a += JSON.load(f)
}

##
## IDF value validation & auto-correction
##


### MB_IR0034 error Missing experiment type for submission type
idf_required_experiment_types_error_h = {}
open("#{conf_path}/idf_required_experiment_types_error.json"){|f|
	idf_required_experiment_types_error_h = JSON.load(f)
}


# auto-correction 用
idf_corrected_a = []
idf_corrected_h = {}

### MB_IR0035 warning Experimental factor type unmatch
if idf_h["Experimental Factor Name"] != idf_h["Experimental Factor Type"]
	idf_corrected_h.store("Experimental Factor Type", idf_h["Experimental Factor Name"])
	warning_idf_a.push(["MB_IR0035", "warning", "Experimental factor name and type do not match: #{idf_file} #{(idf_h["Experimental Factor Name"] - idf_h["Experimental Factor Type"]).join(",")}, type is auto-corrected to corresponding name"])
end

re_analysis_study_idf_a = []
for field_name, field_value_a in idf_h

	## single value fields

	### MB_IR0011 error Short description
	if field_name == "Study Description" && field_value_a[0]
		if field_value_a[0].length < 100
			error_idf_a.push(["MB_IR0011", "error", "Study description is short. Please provide more than 100 characters: #{idf_file}"])
		end
	end


	### MB_IR0012 warning Short description


	### MB_IR0013 error Invalid date format
	if ["Public Release Date", "Comment[Submission Date]", "Comment[Last Update Date]"].include?(field_name)
		unless field_value_a[0] == "" || field_value_a[0] =~ /20\d{2}-\d{2}-\d{2}/
			if field_value_a[0] =~ %r@(\d{4})/(\d{1,2})/(\d{1,2})@
				error_idf_a.push(["MB_IR0013", "error", "Invalid date format: #{idf_file} #{field_name} #{field_value_a[0]} auto-corrected to: #{$1}-#{$2.rjust(2, "0")}-#{$3.rjust(2, "0")}"])			
				idf_corrected_h.store(field_name, ["#{$1}-#{$2.rjust(2, "0")}-#{$3.rjust(2, "0")}"])
			else
				error_idf_a.push(["MB_IR0013", "error", "Invalid date format: #{idf_file} #{field_name} #{field_value_a[0]}"])			
			end
		end
	end


	### MB_IR0033 MB_IR0034 error future date
	if ["Comment[Submission Date]", "Comment[Last Update Date]"].include?(field_name)
		if field_value_a[0] != "" && Date.parse(field_value_a[0]) > Date.today
			error_idf_a.push(["MB_IR0033", "error", "Future date: #{idf_file} #{field_name} #{field_value_a[0]}"])
		end
	end


	### MB_IR0034 error Missing experiment type for submission type
	if field_name == "Comment[Experiment type]" && idf_required_experiment_types_error_h[submission_type] && (idf_required_experiment_types_error_h[submission_type] - field_value_a).size > 0
		error_idf_a.push(["MB_IR0034", "error", "Missing experiment type for submission type: #{idf_file} #{submission_type}:#{(idf_required_experiment_types_error_h[submission_type] - field_value_a).join(",")} The experiment type is automatically added based on the submission type."])		
		
		# submission type で必要な experiment type を追加
		experiment_type_added_a = field_value_a
		idf_required_experiment_types_error_h[submission_type].each{|type|
			experiment_type_added_a.push(type)
		}
		idf_corrected_h.store(field_name, experiment_type_added_a)

	end


	# 各値の処理が必要な項目
	corrected_field_value_a = []
	corrected = false
	for field_value in field_value_a
	
		corrected_field_value = ""

		### MB_IR0021 warning Invalid value for null
		for regex in null_not_recommended_a
			if field_value =~ /^#{regex}$/
				warning_idf_a.push(["MB_IR0021", "warning", "Invalid value for null: #{idf_file} #{field_name}:#{field_value} auto-corrected to: missing"])
				corrected_field_value = field_value.sub(/^#{regex}$/, "missing")
			end
		end

		### MB_IR0022 warning Invalid data format
		for regex in ["\t"]
			warning_idf_a.push(["MB_IR0022", "warning", "Invalid data format: #{idf_file} #{field_name}:#{field_value}"]) if field_value =~ /#{regex}/
		end

		### MB_IR0023 warning Null values provided for optional fields
		unless idf_optional_field_a.include?(field_name)
			warning_idf_a.push(["MB_IR0023", "warning", "Null values provided for optional fields: #{idf_file} #{field_name}:#{field_value}"]) if null_values_a.include?(field_value)
		end

		### MB_IR0024 error Invalid characters
		unless field_value.ascii_only?
			
			if field_name == "Study Description" || field_name == "Protocol Description"

				replaced_char = ""
				invalid_char = false
				for char in field_value.chars						
					
					if char =~ /[^[:ascii:]]/ && char !~ /([\\x00-\\x7F]|\s|°|±|°|μ|\u2103|\u00D7|\u00B5|\u2266|\u2267|\u2253|≠|←|→|↑|↓|↔|Å|[Α-Ω]|[α-ω])/
						char = "#NG#"
						invalid_char = true
					end
					
					replaced_char += char

				end

				error_idf_a.push(["MB_IR0024", "error", "Invalid characters: #{idf_file} #{field_name}:#{replaced_char}"]) if invalid_char

			else
				error_idf_a.push(["MB_IR0024", "error", "Invalid characters: #{idf_file} #{field_name}:#{field_value.gsub(/[^[:ascii:]]/, "#NG#")}"])
			end

		end

		### MB_IR0025 warning Invalid publication identifier
		if field_name == "PubMed ID"
			unless field_value.nil? || field_value == "" || field_value =~ /^\d+$/ || null_values_a.include?(field_value)
				warning_idf_a.push(["MB_IR0025", "warning", "Invalid publication identifier: #{idf_file} #{field_name}:#{field_value}"])
			end

		end

		### MB_IR0038 warning Invalid accession for re-analysis
		if field_name == "Comment[Reanalysis of]"
			unless field_value.nil? || field_value == "" || field_value =~ /^MTBKS\d+$/ || null_values_a.include?(field_value)
				warning_idf_a.push(["MB_IR0038", "warning", "MetaboBank study accession(s) should be specified for re-analysis: #{idf_file} #{field_name}:#{field_value}"])
			else
				re_analysis_study_idf_a.push(field_value)
			end
		end

		### MB_IR0038 warning Invalid accession for re-analysis
		if field_name == "Comment[Reanalyzed by]"
			unless field_value.nil? || field_value == "" || field_value =~ /^MTBKS\d+$/ || null_values_a.include?(field_value)
				warning_idf_a.push(["MB_IR0038", "warning", "MetaboBank study accession(s) should be specified for re-analysis: #{idf_file} #{field_name}:#{field_value}"])
			end
		end

		# auto-correct された value		
		if corrected_field_value != ""
			corrected_field_value_a.push(corrected_field_value)
			corrected = true
		else
			corrected_field_value_a.push(field_value)
		end

	end # for field_value in field_value_a

	# 値が auto-correct されている場合
	if corrected
		idf_corrected_h.store(field_name, corrected_field_value_a)
	end

end


#
# IDF validation 結果出力
# 
puts ""
puts "IDF validation results"
puts "---------------------------------------------"
warning_idf_a.sort{|a,b| a[0] <=> b[0]}.each{|m| puts m.join(": ")}
error_ignore_idf_a.sort{|a,b| a[0] <=> b[0]}.each{|m| puts m.join(": ")}
error_idf_a.sort{|a,b| a[0] <=> b[0]}.each{|m| puts m.join(": ")}
puts "---------------------------------------------"


##
## SDRF
##

# SDRF validation rules
# https://docs.google.com/spreadsheets/d/15pENGHA9hkl6QIueFb44fhQfQMThRB2tbvSE6hItHEU/edit#gid=904619035

warning_sdrf = ""
error_sdrf = ""

warning_sdrf_a = []
error_ignore_sdrf_a = []
error_sdrf_a = []

sdrf_header_a = sdrf_a[0]

### MB_SR0003 error Duplicated columns

# SDRF 複数不許可カラム
sdrf_singleton_columns_a = []
open("#{conf_path}/sdrf_singleton_columns.json"){|f|
	sdrf_singleton_columns_a = JSON.load(f)
}

sdrf_duplicated_columns_a = []
sdrf_duplicated_columns_a = sdrf_singleton_columns_a.select{|e| sdrf_header_a.count(e) > 1}

if sdrf_duplicated_columns_a.size > 0
	error_sdrf_a.push(["MB_SR0003", "error", "Column names are duplicated: #{sdrf_file} #{sdrf_duplicated_columns_a.join(",")}"])
end


### MB_SR0004 error Missing required column
sdrf_required_columns_error_a = []
open("#{conf_path}/sdrf_required_columns_error.json"){|f|	
	sdrf_required_columns_error_a = JSON.load(f)

	# MSI は Extract Name がないので除外。
	sdrf_required_columns_error_a.delete("Extract Name") if submission_type == "MSI"
}

missing_sdrf_required_columns_error_a = []
all_null_sdrf_required_columns_error_a = []
## カラム、値がない
for sdrf_required_column in sdrf_required_columns_error_a
	
	# カラムがない
	if sdrf_transpose_h[sdrf_required_column].nil?
		missing_sdrf_required_columns_error_a.push(sdrf_required_column)
	## MB_SR0009 error Missing or null value for required column
	# 全て null value か空欄
	elsif (sdrf_transpose_h[sdrf_required_column] - null_values_a.push("")).size == 0		
		all_null_sdrf_required_columns_error_a.push(sdrf_required_column)
	end

end

### MB_SR0004 error Missing required column
if missing_sdrf_required_columns_error_a.size > 0
	error_sdrf_a.push(["MB_SR0004", "error", "Missing required column: #{sdrf_file} #{missing_sdrf_required_columns_error_a.join(",")}"])
end

## MB_SR0009 error Missing or null value for required column
if all_null_sdrf_required_columns_error_a.size > 0
	error_sdrf_a.push(["MB_SR0009", "error", "SDRF has missing mandatory column(s). Please provide value(s) other than null values, 'not collected', 'not applicable' or 'missing': #{sdrf_file} #{all_null_sdrf_required_columns_error_a.join(",")}"])
end


### MB_SR0005 warning Missing required column
sdrf_required_columns_warning_a = []
all_null_sdrf_required_columns_warning_a = []
open("#{conf_path}/sdrf_required_columns_warning.json"){|f|
	sdrf_required_columns_warning_a = JSON.load(f)
}

missing_sdrf_required_columns_warning_a = []
for sdrf_required_columns_warning in sdrf_required_columns_warning_a

	# カラムが無い
	exist = false
	all_missing = false
	sdrf_header_a.each{|sdrf_header|
		if sdrf_header =~ /#{sdrf_required_columns_warning}/
			
			exist = true
			
			# 値が全部空もしくは null value
			if (sdrf_transpose_h[sdrf_header] - null_values_a.push("")).size == 0
				all_null_sdrf_required_columns_warning_a.push(sdrf_header)
			end

		end
	}

	# 正規表現を表示用に直す
	if sdrf_required_columns_warning =~ /\[[-_ A-Za-z0-9.]+\]/
		sdrf_required_columns_warning = sdrf_required_columns_warning.sub("\\[[-_ A-Za-z0-9.]+\\]", "")
	end
	missing_sdrf_required_columns_warning_a.push(sdrf_required_columns_warning.gsub("\\", "")) unless exist

end

if missing_sdrf_required_columns_warning_a.size > 0
	warning_sdrf_a.push(["MB_SR0005", "warning", "Missing required column: #{sdrf_file} #{missing_sdrf_required_columns_warning_a.join(",")}"])
end

if all_null_sdrf_required_columns_warning_a.size > 0
	warning_sdrf_a.push(["MB_SR0010", "warning", "Missing or null value for required column: #{sdrf_file} #{all_null_sdrf_required_columns_warning_a.join(",")}"])
end

### MB_SR0006 error	ignore Undefined column
sdrf_fields_list_a = []
open("#{conf_path}/sdrf_fields_list.json"){|f|
	sdrf_fields_list_a = JSON.load(f)
}

undefined_sdrf_columns_a = []
for sdrf_header in sdrf_header_a

	exist = false
	sdrf_fields_list_a.each{|sdrf_field|
		if sdrf_header =~ /#{sdrf_field}/
			exist = true
		end
	}

	undefined_sdrf_columns_a.push(sdrf_header) unless exist

end

if undefined_sdrf_columns_a.size > 0
	error_ignore_sdrf_a.push(["MB_SR0006", "error_ignore", "Only pre-defined columns are allowed: #{sdrf_file} #{undefined_sdrf_columns_a.join(",")}"])
end


### MB_SR0012 warning Missing required column in column group
sdrf_required_group_warning_h = {}
open("#{conf_path}/sdrf_required_group_warning.json"){|f|
	sdrf_required_group_warning_h = JSON.load(f)
}

for group_name, group_field_a in sdrf_required_group_warning_h
	# Raw Data File etc が項目として存在する場合のみ
	if sdrf_header_a.include?(group_name)
		if (group_field_a - sdrf_header_a).size > 0
			warning_sdrf_a.push(["MB_SR0012", "warning", "Missing required column in column group: #{sdrf_file} #{(group_field_a - sdrf_header_a).join(",")}"])
		end
	end
end


### MB_SR0017 error ignore Constant factor value
factor_value_h = {}
for key, value_a in sdrf_transpose_h
	if key =~ /Factor Value\[([-_ \\A-Za-z0-9.]+)\]/
		factor_value_h.store(key, value_a)
	end
end

if factor_value_h.size == 1

	if factor_value_h.values[0].sort.uniq.size == 1
		error_ignore_sdrf_a.push(["MB_SR0017", "error_ignore", "Values of an experimental variable must vary, for compound+dose at least one must vary: #{sdrf_file} #{factor_value_h.keys[0]}"])
	end

else

	factor_value_combined_a = []	

	if factor_value_h.values[0]
		
		factor_value_h.values[0].size.times{|i|
			
			factor_value_combined_temp_a = []
			factor_value_h.values.each{|factor_value_a|
				factor_value_combined_temp_a.push(factor_value_a[i])
			}
			
			factor_value_combined_a.push(factor_value_combined_temp_a)

		}

		if factor_value_combined_a.sort.uniq.size == 1
			error_ignore_sdrf_a.push(["MB_SR0017", "error_ignore", "Values of an experimental variable must vary, for compound+dose at least one must vary: #{sdrf_file} #{factor_value_h.keys.join(",")}"])
		end

	end

end


### MB_SR0018 warning Less than 2 characteristic attributes
characteristics_a = []
characteristics_a = sdrf_header_a.select{|e| e =~ /Characteristics\[[-_ \/A-Za-z0-9.]+\]/}

if characteristics_a.size < 2
	warning_sdrf_a.push(["MB_SR0018", "warning", "A source should have more than 2 characteristic attributes: #{sdrf_file} #{characteristics_a.join(",")}"])
end


if bs_path != ""

###
### BioSample attributes and SDRF Characteristics check
###

warning_sdrf_bs_a = []
error_ignore_sdrf_bs_a = []
bs_not_found_a = []

## BioSample との一致チェック
diff_attr_h = {}
missing_in_sdrf_h = {}
missing_in_bs_h = {}
for biosample_accession, sdrf_sample_h in sdrf_bs_h

	if bs_h[biosample_accession]

		diff_attr_a = []
		missing_in_sdrf_a = []
		missing_in_bs_a = []
		sdrf_sample_h.each{|key, value|

			if bs_h[biosample_accession][key]
				
				if value != bs_h[biosample_accession][key]
					diff_attr_a.push(key)
				end
				
			# BioSample に属性がない
			else
				missing_in_bs_a.push(key) if value != ""
			end

		}

		diff_attr_h.store(biosample_accession, diff_attr_a) unless diff_attr_a.empty?
		missing_in_bs_h.store(biosample_accession, missing_in_bs_a) unless missing_in_bs_a.empty?

		bs_h[biosample_accession].each{|bskey, bsvalue|			
			if bsvalue != "" && !sdrf_sample_h.keys.include?(bskey) && !["biosample_accession", "bioproject_id", "sample_name"].include?(bskey)
				missing_in_sdrf_a.push(key)
			end
		}
		
		if missing_in_sdrf_a.size > 0
			missing_in_sdrf_h.store(biosample_accession, missing_in_sdrf_a) unless missing_in_sdrf_a.empty?
		end

	else # if bs_h[biosample_accession]
		bs_not_found_a.push(biosample_accession)
	end

end

if bs_not_found_a.size > 0
	warning_sdrf_bs_a.push(["MB_SR0000", "warning", "BioSample accession not found in tsv: #{sdrf_file} #{bs_not_found_a.sort.uniq.join(",")}"])
end


### MB_SR0021 warning Missing biosample attribute
if missing_in_sdrf_h.size > 0
	
	for biosample_accession, missing_in_sdrf_a in missing_in_sdrf_h
		warning_sdrf_bs_a.push(["MB_SR0021", "warning", "Missing biosample attribute: #{sdrf_file} #{biosample_accession}:#{missing_in_sdrf_a.join(",")}"])
	end

end

### MB_SR0022 warning No Biosample attribute
if missing_in_bs_h.size > 0
	
	for biosample_accession, missing_in_bs_a in missing_in_bs_h
		warning_sdrf_bs_a.push(["MB_SR0022", "warning", "SDRF characteristics are not in BioSample attributes: #{sdrf_file} #{biosample_accession}:#{missing_in_bs_a.join(",")}"])
	end

end

### MB_SR0023 error ignore Characteristics and BioSample attributes unmatch
if diff_attr_h.size > 0
	
	for biosample_accession, diff_attr_a in diff_attr_h
		error_ignore_sdrf_bs_a.push(["MB_SR0023", "error_ignore", "SDRF characteristics and BioSample attributes are different: #{sdrf_file} #{biosample_accession}:#{diff_attr_a.join(",")}"])
	end

end

end # if bs_path != ""


### MB_SR0019 error ignore Invalid value format
value_formats_h = {}
open("#{conf_path}/value_formats.json"){|f|
	value_formats_h = JSON.load(f)
}

re_analysis_study_sdrf_a = []
for sdrf_header, format in value_formats_h

	invalid_value_a = []
	if sdrf_transpose_h[sdrf_header]

		if get_dimension(sdrf_transpose_h[sdrf_header]) > 1
			for value_a in sdrf_transpose_h[sdrf_header]
				value_a.each{|v|
					if v != "" && v !~ /^#{format}$/
						invalid_value_a.push(v)
					elsif v =~ /^(MTBKS\d{1,}):[^:]+$/
						re_analysis_study_sdrf_a.push($1)
					end
				}
			end
		elsif get_dimension(sdrf_transpose_h[sdrf_header]) == 1
			sdrf_transpose_h[sdrf_header].each{|v|
				if v != "" && v !~ /^#{format}$/
					invalid_value_a.push(v)
				elsif v =~ /^(MTBKS\d{1,}):[^:]+$/
					re_analysis_study_sdrf_a.push($1)
				end
			}
		end

	end

	error_ignore_sdrf_a.push(["MB_SR0019", "error_ignore", "Invalid format value(s) is provided: #{sdrf_file} #{sdrf_header} #{invalid_value_a.join(",")}"]) if invalid_value_a.size > 0

end


### MB_SR0024 error ignore Column without name
name_regex_a = [
	"Characteristics\\[(.*)\\]",
	"Parameter Value\\[([-_ \/A-Za-z0-9.]*)\\]",
	"Comment\\[([-_ \/A-Za-z0-9.]*)\\]",
	"Factor Value\\[([-_ \/A-Za-z0-9.]*)\\]"
]

name_unspecified_a = []
for sdrf_header in sdrf_header_a
	
	name_regex_a.each{|regex|		
	
		if sdrf_header =~ /#{regex}/	
			name_unspecified_a.push(sdrf_header) if $1 == "" || $1 =~ /^ +$/
		end
	}

end

if name_unspecified_a.size > 0
	error_ignore_sdrf_a.push(["MB_SR0024", "error_ignore", "Each of Characteristic, Factor value, Parameter Value and Unit should have a name specified: #{sdrf_file} #{name_unspecified_a.sort.uniq.join(",")}"])
end


### MB_SR0026 error ignore Invalid column order
sdrf_column_order_h = {}
open("#{conf_path}/sdrf_column_order.json"){|f|
	sdrf_column_order_h = JSON.load(f)
}


### MB_SR0033 error ignore Missing protocol reference
idf_protocol_name_a = []
idf_protocol_name_a = idf_h["Protocol Name"]
idf_protocol_type_a = []
idf_protocol_type_a = idf_h["Protocol Type"]

idf_protocol_name_type_h = {}
if idf_protocol_name_a
	idf_protocol_name_a.size.times{|i|
		idf_protocol_name_type_h.store(idf_protocol_name_a[i], idf_protocol_type_a[i])
	}
end

## Protocol REF の name 参照チェック、及び、SDRF Protocol REF への type 結合
sdrf_protocol_ref_index_a = sdrf_header_a.each_index.select{|e| sdrf_header_a[e] == "Protocol REF"}
protocol_name_in_ref_a = []
protocol_type_in_ref_a = []
sdrf_protocol_ref_index_a.each{|i|

	protocol_types_in_ref_a = []

	protocol_ref_a = []
	for sdrf_line_a in sdrf_a[1..-1]		
		protocol_ref_a.push(sdrf_line_a[i])	
	end

	# Protocol REF に記載されている最初の IDF 定義 protocol name を取得
	type_found_flag = false
	for protocol_ref in protocol_ref_a

		# ref 中の name から type が引ける場合
		if idf_protocol_name_a && idf_protocol_name_a.include?(protocol_ref) && idf_protocol_name_type_h[protocol_ref]
			protocol_types_in_ref_a.push(idf_protocol_name_type_h[protocol_ref])
			protocol_name_in_ref_a.push(protocol_ref)
			type_found_flag = true
		end

	end

	if protocol_types_in_ref_a.sort.uniq.size > 1
		error_ignore_sdrf_a.push(["MB_SR0034", "error_ignore", "More than one protocol type are referenced in Protocol REF. Specify protocol name(s) of single type: #{sdrf_file} Protocol REF at column #{i}"])
	end

	# sort uniq した最初の type を代表として取得。
	protocol_type_in_ref_a.push(protocol_types_in_ref_a.sort.uniq[0])

	### MB_SR0033 error ignore Missing protocol reference
	
	if protocol_types_in_ref_a.sort.uniq.size == 0
		error_ignore_sdrf_a.push(["MB_SR0033", "error_ignore", "Protocol name is not referenced in Protocol REF: #{sdrf_file} Protocol REF at column #{i}"])
	end
}

# MB_SR0035 warning Protocol type reference from different columns
protocol_type_ref_from_columns_a = protocol_type_in_ref_a.select{|e| protocol_type_in_ref_a.count(e) > 1}
if protocol_type_ref_from_columns_a.size > 0
	warning_sdrf_a.push(["MB_SR0035", "warning", "Protocol type reference from different columns: #{sdrf_file} #{protocol_type_ref_from_columns_a.sort.uniq.join(",")}"])
end


# Protocol REF で指定されている name から全て type が回収できれば
sdrf_header_frame_a = []
sdrf_defined_comment_a = []
sdrf_defined_unit_a = []

if sdrf_protocol_ref_index_a.size == protocol_type_in_ref_a.size

	i = 0
	j = 0
	for sdrf_header in sdrf_header_a

		# Protocol REF に Protocol type を結合
		if sdrf_protocol_ref_index_a.include?(i)
			sdrf_header_frame_a.push("#{sdrf_header}:#{protocol_type_in_ref_a[j]}")
			j += 1
		# Protocol REF 以外
		else
			
			# 連続する Characteristics[] は一つにまとめる。name チェックは別でやっているのでカラムを拾うため正規表現は緩い
			if sdrf_header =~ /Characteristics\[.*\]/
				sdrf_header_frame_a.push("Characteristics[]")
			# 連続する Factor Value[] は一つにまとめる。name チェックは別でやっているのでカラムを拾うため正規表現は緩い
			elsif sdrf_header =~ /Factor Value\[.*\]/
				sdrf_header_frame_a.push("Factor Value[]")
			# Characteristics[] 以外
			else
				
				# Comment を除外
				unless sdrf_header =~ /Comment\[.*\]/ || sdrf_header =~ /Unit\[.*\]/
					sdrf_header_frame_a.push(sdrf_header)
				end

			end

		end
		
		i += 1

	end	

end

## SDRF order チェック
## MB_SR0026 error ignore Invalid column order 全 Comment を削除した順序骨格の比較
if sdrf_column_order_h[submission_type] && sdrf_header_frame_a.uniq != sdrf_column_order_h[submission_type].reject{|e| e =~ /Comment\[.*\]/ || e =~ /Unit\[.*\]/}
	error_ignore_sdrf_a.push(["MB_SR0026", "error_ignore", "SDRF column order is invalid: #{sdrf_file}"])
end


## MB_SR0030 error Invalid characters
for sdrf_header, sdrf_value_a in sdrf_transpose_h

	for sdrf_value in sdrf_value_a

		if get_dimension(sdrf_value) == 0

			unless sdrf_value.ascii_only?
							
				replaced_char = ""
				invalid_char = false
				for char in sdrf_value.chars						
					
					if char =~ /[^[:ascii:]]/
						char = "#NG#"
						invalid_char = true
					end
					
					replaced_char += char

				end

				error_sdrf_a.push(["MB_SR0030", "error", "Invalid characters: #{sdrf_file} #{sdrf_header}:#{replaced_char}"]) if invalid_char

			end

		else

			for sdrf_value_term in sdrf_value

				unless sdrf_value_term.ascii_only?
								
					replaced_char = ""
					invalid_char = false
					for char in sdrf_value_term.chars						
						
						if char =~ /[^[:ascii:]]/
							char = "#NG#"
							invalid_char = true
						end
						
						replaced_char += char

					end

					error_sdrf_a.push(["MB_SR0030", "error", "Invalid characters: #{sdrf_file} #{sdrf_header}:#{replaced_char}"]) if invalid_char

				end

			end
			
		end

	end

end


##
## md5 checksum and filename from SDRF
##
data_files_meta_h = {}

## raw, processed, maf
different_md_meta_a = []
file_column_a = [["Raw Data File", "Comment[Raw Data File md5]"], ["Processed Data File", "Comment[Processed Data File md5]"], ["Metabolite Assignment File", "Comment[Metabolite Assignment File md5]"]]
for file_column_name, file_column_name_md in file_column_a

	if sdrf_transpose_h[file_column_name] && sdrf_transpose_h[file_column_name_md]

		if get_dimension(sdrf_transpose_h[file_column_name]) > 1 && get_dimension(sdrf_transpose_h[file_column_name_md]) > 1
			i = 0
			for data_file_a in sdrf_transpose_h[file_column_name]
				data_file_a.size.times{|j|
					different_md_meta_a.push(data_file_a[j]) if data_files_meta_h[data_file_a[j]] && data_files_meta_h[data_file_a[j]] != sdrf_transpose_h[file_column_name_md][i][j]
					data_files_meta_h.store(data_file_a[j], sdrf_transpose_h[file_column_name_md][i][j])					
				}
				i += 1
			end
		elsif get_dimension(sdrf_transpose_h[file_column_name]) == 1 && get_dimension(sdrf_transpose_h[file_column_name_md]) == 1
			sdrf_transpose_h[file_column_name].size.times{|i|
				different_md_meta_a.push(sdrf_transpose_h[file_column_name][i]) if data_files_meta_h[sdrf_transpose_h[file_column_name][i]] && data_files_meta_h[sdrf_transpose_h[file_column_name][i]] != sdrf_transpose_h[file_column_name_md][i]
				data_files_meta_h.store(sdrf_transpose_h[file_column_name][i], sdrf_transpose_h[file_column_name_md][i])				
			}
		end

	elsif sdrf_transpose_h[file_column_name] && !sdrf_transpose_h[file_column_name_md]

		if get_dimension(sdrf_transpose_h[file_column_name]) > 1
			i = 0
			for data_file_a in sdrf_transpose_h[file_column_name]
				data_file_a.size.times{|j|
					data_files_meta_h.store(data_file_a[j], "")
				}
				i += 1
			end
		elsif get_dimension(sdrf_transpose_h[file_column_name]) == 1
			sdrf_transpose_h[file_column_name].size.times{|i|
				data_files_meta_h.store(sdrf_transpose_h[file_column_name][i], "")
			}
		end

	end

end

## MB_SR0041 warning Different checksum
if different_md_meta_a.size > 0 && md_h.size == 0
	warning_sdrf_a.push(["MB_SR0041", "warning", "Different checksum values are given for a file. Last value is used for subsequent validation: #{sdrf_file} #{different_md_meta_a.join(",")}"])
end

if different_md_file_a.size > 0
	warning_sdrf_a.push(["MB_SR0041", "warning", "Different checksum values are given for a file. Last value is used for subsequent validation: #{sdrf_file} #{different_md_file_a.join(",")}"])
end

## MB_SR0036 error Invalid character in file name
## MB_SR0037 error Invalid characters in directory name
invalid_filename_a = []
invalid_dirname_a = []
invalid_maf_a = []
subdir_meta_a = []
for data_filename in data_files_meta_h.keys

	if data_filename =~ /^\.?\/+/
		invalid_filename_a.push(data_filename)
	else
		if data_filename =~ /\/$/
			filename = ""
			dirname = data_filename
			subdir_meta_a.push(dirname.sub(/\/$/, ""))
		elsif data_filename =~ /\//
			filename = File.basename(data_filename)
			dirname = File.dirname(data_filename)
		else
			filename = File.basename(data_filename)
			dirname = ""
		end
	end

	# 2023-02-27 allow spaces
	invalid_filename_a.push(filename) if filename != "" && filename !~ /^[-_A-Za-z0-9. ]+$/
	invalid_dirname_a.push(dirname) if dirname != "" && dirname !~ /^[-_A-Za-z0-9.\/ ]+$/

	# maf
	if data_filename =~ /\.maf\.txt$/
		if data_filename =~ /\//
			invalid_maf_a.push(data_filename)
		end
	end

end

## MB_SR0036 error Invalid character in file name
if invalid_filename_a.size > 0
	error_sdrf_a.push(["MB_SR0036", "error", "Invalid character in file name. Use only alphanumerals [A-Z,a-z,0-9], underscores [_], hyphens [-], spaces and dots [.] for file name. #{sdrf_file} #{invalid_filename_a.join(",")}"])
end

## MB_SR0037 error Invalid characters in directory name
if invalid_dirname_a.size > 0
	error_sdrf_a.push(["MB_SR0037", "error", "Invalid character in directory name. Use only alphanumerals [A-Z,a-z,0-9], underscores [_], hyphens [-], spaces and dots [.] for directory name. #{sdrf_file} #{invalid_dirname_a.join(",")}"])
end

## MB_SR0039 error MAF in directory
if invalid_maf_a.size > 0
	error_sdrf_a.push(["MB_SR0039", "error", "MAF must not be in directory. #{sdrf_file} #{invalid_maf_a.join(",")}"])
end

##
## Data files validation
##
file_md_unmatch_a = []
if data_file_validation_flag

	# real files
	real_file_a = Dir.glob("#{idf_dir}/**/*").select{|f| File.file?(f) && f !~ /\.filelist\.txt$|\.idf\.txt$|\.sdrf\.txt$|\/audit|status-.*\.txt$/}.collect{|f| f.sub("#{idf_dir}/", "")}

	not_specified_file_a = []
	noexist_filename_a = []
	for data_filename in data_files_meta_h.keys
		
		if subdir_meta_a.include?(data_filename)		
			noexist_filename_a.push(data_filename) unless Dir.exist?("#{idf_dir}/#{data_filename}")
		else
			noexist_filename_a.push(data_filename) unless File.exist?("#{idf_dir}/#{data_filename}")
		end

	end

	## MB_SR0038 error File not exist
	if noexist_filename_a.size > 0
		error_sdrf_a.push(["MB_SR0038", "error", "File specified in SDRF do not exist. #{sdrf_file} #{noexist_filename_a.join(",")}"])
	end

	## MB_SR0040 warning Un-specified file	
	not_specified_file_a = []
	(real_file_a - data_files_meta_h.keys).select{|f|
		match = false
		subdir_meta_a.each{|subdir|
			unless subdir =~ /#{File.dirname(f)}/
				match = true
			end
		}

		not_specified_file_a.push(f) unless match

	}

	if not_specified_file_a.size > 0
		error_sdrf_a.push(["MB_SR0040", "error", "There are files not specified in SDRF. #{sdrf_file} #{not_specified_file_a.join(",")}"])
	end

	## md5 一致チェック
	real_file_md_h = {}
	for real_file in real_file_a
		checksum = `md5sum '#{idf_dir}/#{real_file}'`.sub(/  .*/, "").rstrip
		real_file_md_h.store(real_file.sub("#{idf_dir}/", ""), checksum)
	end
	
	## SDRF 記載ファイルの md5 一致をチェック	
	if md_h.size == 0
	
		for data_file, data_file_md in data_files_meta_h
			if real_file_md_h[data_file] && data_file_md != "" && data_file_md != real_file_md_h[data_file]
				file_md_unmatch_a.push([data_file, "meta:#{data_file_md}", "real:#{real_file_md_h[data_file]}"])
			end
		end

	else
		
		for data_file, data_file_md in md_h
			if real_file_md_h[data_file] && data_file_md != "" && data_file_md != real_file_md_h[data_file]
				file_md_unmatch_a.push([data_file, "meta:#{data_file_md}", "real:#{real_file_md_h[data_file]}"])
			end
		end

	end	

	## MB_SR0041 warning Different checksum
	if file_md_unmatch_a.size > 0
		
		file_md_unmatch_s = "\n"
		file_md_unmatch_a.each{|line_a|
			file_md_unmatch_s += "#{line_a.join("  ")}\n"
		}

		warning_sdrf_a.push(["MB_SR0041", "warning", "Different checksum: #{sdrf_file} #{file_md_unmatch_s}"])

	end

	## MAF file validation
	maf_a = []
	if sdrf_transpose_h["Metabolite Assignment File"]
		if get_dimension(sdrf_transpose_h["Metabolite Assignment File"]) == 1
			maf_a = sdrf_transpose_h["Metabolite Assignment File"].sort.uniq.reject{|e| e.empty?}.collect{|e| "#{idf_dir}/#{e}"} if sdrf_transpose_h["Metabolite Assignment File"]
		elsif get_dimension(sdrf_transpose_h["Metabolite Assignment File"]) > 1
			for maf_line_a in sdrf_transpose_h["Metabolite Assignment File"]
				maf_a += maf_line_a.sort.uniq.reject{|e| e.empty?}.collect{|e| "#{idf_dir}/#{e}"}
			end
		end
	end # if sdrf_transpose_h["Metabolite Assignment File"]

	# maf columns
	maf_column_h = {}
	open("#{conf_path}/maf.json"){|f|
		maf_column_h = JSON.load(f)
	}

	maf_header_a = []
	maf_header_assay_name_a = []
	if submission_type == "NMR"

		for maf in maf_a
			maf_f = open(maf)
			maf_header_a = maf_f.readlines[0].rstrip.split("\t")
		end

		## MB_SR0042 error ignore Invalid MAF format
		if maf_column_h["NMR"] != maf_header_a.slice(0, maf_column_h["MS"].size)
			error_ignore_sdrf_a.push(["MB_SR0042", "error_ignore", "Invalid MAF format: #{maf.sub("#{idf_dir}/", "")}, type NMR: #{(maf_column_h["MS"] - maf_header_a.slice(0, maf_column_h["MS"].size)).join(",")}"])
		end

	else

		for maf in maf_a
		
			maf_f = open(maf)
			maf_header_a = maf_f.readlines[0].rstrip.split("\t")

			## MB_SR0042 error ignore Invalid MAF format
			if maf_column_h["MS"] != maf_header_a.slice(0, maf_column_h["MS"].size)
				error_ignore_sdrf_a.push(["MB_SR0042", "error_ignore", "Invalid MAF format: #{maf.sub("#{idf_dir}/", "")}, type MS: Missing required fields: #{(maf_column_h["MS"] - maf_header_a.slice(0, maf_column_h["MS"].size)).join(",")}"]) if (maf_column_h["MS"] - maf_header_a.slice(0, maf_column_h["MS"].size)).size > 0
				error_ignore_sdrf_a.push(["MB_SR0042", "error_ignore", "Invalid MAF format: #{maf.sub("#{idf_dir}/", "")}, type MS: User-defined fields: #{(maf_header_a.slice(0, maf_column_h["MS"].size) - maf_column_h["MS"]).join(",")}"]) if (maf_header_a.slice(0, maf_column_h["MS"].size) - maf_column_h["MS"]).size > 0
			end

			## MB_SR0044 MB_SR0045 MAF assay name
			## 規定カラムが無いことを想定し、peak_identifier よりも後ろのカラムを assay section とする。
			if maf_header_a.index("peak_identifier")				
				
				maf_header_assay_name_a = maf_header_a.slice(maf_header_a.index("peak_identifier") + 1, maf_header_a.size - maf_header_a.index("peak_identifier"))
				
				## MB_SR0044 warning Undefined assay name in MAF
				if (maf_header_assay_name_a - sdrf_transpose_h["Assay Name"]).sort.uniq.size > 0
					warning_sdrf_a.push(["MB_SR0044", "warning", "Assay name(s) in MAF is not defined in SDRF: #{maf.sub("#{idf_dir}/", "")} #{(maf_header_assay_name_a - sdrf_transpose_h["Assay Name"]).sort.uniq.join(",")}"])
				end

			end

		end

	end

end # if data_file_validation_flag

#
# SDRF validation 結果出力
# 
puts ""
puts "SDRF validation results"
puts "---------------------------------------------"
warning_sdrf_a.sort{|a,b| a[0] <=> b[0]}.each{|m| puts m.join(": ")}
error_ignore_sdrf_a.sort{|a,b| a[0] <=> b[0]}.each{|m| puts m.join(": ")}
error_sdrf_a.sort{|a,b| a[0] <=> b[0]}.each{|m| puts m.join(": ")}
puts "---------------------------------------------"

## IDF and SDRF
# rules
# https://docs.google.com/spreadsheets/d/15pENGHA9hkl6QIueFb44fhQfQMThRB2tbvSE6hItHEU/edit#gid=935334215

warning_idf_sdrf = ""
error_idf_sdrf = ""

warning_idf_sdrf_a = []
error_ignore_idf_sdrf_a = []
error_idf_sdrf_a = []


### MB_CR0001 error ignore Experimental factor unmatch
### MB_SR0024 error ignore Column without name
### Experimental Factor and Factor Value
sdrf_factor_value_name_a = []
for sdrf_header in sdrf_header_a
	if sdrf_header =~ /Factor Value\[([-_ \/A-Za-z0-9.]+)\]/
		sdrf_factor_value_name_a.push($1)
	end
end


if idf_h["Experimental Factor Name"]
		
	if sdrf_factor_value_name_a.empty?
		idf_corrected_h.store("Experimental Factor Name", ["missing"])
		idf_corrected_h.store("Experimental Factor Type", ["missing"])		
	else
		
		diff_a = idf_h["Experimental Factor Name"] - sdrf_factor_value_name_a
		if diff_a.size > 0	

			error_ignore_idf_sdrf_a.push(["MB_CR0001", "error_ignore", "IDF Experimental Factor Name and SDRF Factor Value name do not match: #{idf_file} #{diff_a.join(",")}, auto-corrected to Factor Value names in SDRF"])
			idf_corrected_h.store("Experimental Factor Name", sdrf_factor_value_name_a)
			idf_corrected_h.store("Experimental Factor Type", sdrf_factor_value_name_a)

		end

	end

end

### MB_CR0002 error ignore Protocol unmatch
if idf_protocol_name_a && idf_protocol_name_a.sort.uniq != protocol_name_in_ref_a.sort.uniq
	idf_not_referenced_protocol_a = idf_protocol_name_a.sort.uniq - protocol_name_in_ref_a.sort.uniq
	sdrf_reference_to_undefined_protocol_a = protocol_name_in_ref_a.sort.uniq - idf_protocol_name_a.sort.uniq
	error_ignore_idf_sdrf_a.push(["MB_CR0002", "error_ignore", "IDF Protocol and SDRF Protocol REF do not match: #{idf_file} IDF protocols not referenced:#{idf_not_referenced_protocol_a.join(",")}"]) if idf_not_referenced_protocol_a.size > 0
	error_ignore_idf_sdrf_a.push(["MB_CR0002", "error_ignore", "IDF Protocol and SDRF Protocol REF do not match: #{idf_file} SDRF reference to un-defined protocols:#{idf_not_referenced_protocol_a.join(",")}, Reference to undefined protocols:#{sdrf_reference_to_undefined_protocol_a.join(",")}"]) if sdrf_reference_to_undefined_protocol_a.size > 0
end


## Protocol type に対する Parameter value を取得
protocol_type_parameter_h = {}
pre_protocol_type = ""
protocol_parameter_a = []
i = 1
for sdrf_header_in_frame in sdrf_header_frame_a

	if sdrf_header_in_frame =~ /Protocol REF:([-_ \/A-Za-z0-9.]+)/		
		protocol_type = $1
	end

	# REF されている protocol type が切り替わる時、及び、最後に格納
	if (protocol_type != pre_protocol_type && pre_protocol_type != "") || i == sdrf_header_frame_a.size
		protocol_type_parameter_h.store(pre_protocol_type, protocol_parameter_a)
		protocol_parameter_a = []
	end

	if sdrf_header_in_frame =~ /Parameter Value\[([-_ \/A-Za-z0-9.]+)\]/
		protocol_parameter_a.push($1)
	end

	pre_protocol_type = protocol_type
	i += 1

end


### MB_CR0003 warning Protocol Parameter unmatch
protocol_type_unmatch_parameter_h = {}
for protocol_type, protocol_type_parameter_a in protocol_type_parameter_h

	if idf_group_h["Protocol"]
	
		for protocol_h in idf_group_h["Protocol"]
			
			if protocol_h["Protocol Type"] == protocol_type
				unless protocol_h["Protocol Parameters"].split(";") == protocol_type_parameter_a
					protocol_type_unmatch_parameter_h.store(protocol_type, (protocol_h["Protocol Parameters"].split(";") - protocol_type_parameter_a | protocol_type_parameter_a - protocol_h["Protocol Parameters"].split(";")))
				end
			end

		end
	
	end

end

if protocol_type_unmatch_parameter_h.size > 0
	
	for protocol_type, protocol_type_unmatch_parameter_a in protocol_type_unmatch_parameter_h
		error_ignore_idf_sdrf_a.push(["MB_CR0003", "error_ignore", "Protocol Parameter unmatch: #{idf_file} #{protocol_type}:#{protocol_type_unmatch_parameter_a.join(",")}, auto-corrected to Protocol Parameters in SDRF"])
	end

	# auto-correction 用 Protocol Parameters 生成
	protocol_parameter_corrected_a = []
	idf_h["Protocol Type"].each{|protocol_type_idf|
		if protocol_type_parameter_h[protocol_type_idf]
			protocol_parameter_corrected_a.push(protocol_type_parameter_h[protocol_type_idf].join(";"))
		end
	}
	
	idf_corrected_h.store("Protocol Parameters", protocol_parameter_corrected_a)

end


## MB_CR0004 warning Different re-analysis accession
re_analysis_study_combined_a = re_analysis_study_idf_a.sort.uniq + re_analysis_study_sdrf_a.sort.uniq
re_analysis_study_diff_a = re_analysis_study_combined_a.select{|e| re_analysis_study_combined_a.count(e) != 2}

if re_analysis_study_diff_a.size > 0
	warning_idf_sdrf_a.push(["MB_CR0004", "warning", "Re-analysis MetaboBank study accessions are different between IDF and SDRF: #{idf_file} #{re_analysis_study_diff_a.join(",")}"])
end

##
## データファイル
##

#
# IDF & SDRF validation 結果出力
# 
puts ""
puts "IDF and SDRF validation results"
puts "---------------------------------------------"
warning_idf_sdrf_a.sort{|a,b| a[0] <=> b[0]}.each{|m| puts m.join(": ")}
error_ignore_idf_sdrf_a.sort{|a,b| a[0] <=> b[0]}.each{|m| puts m.join(": ")}
error_idf_sdrf_a.sort{|a,b| a[0] <=> b[0]}.each{|m| puts m.join(": ")}
puts "---------------------------------------------"


#
# IDF auto-correction
#

# IDF blank line before
blank_line_before_a = []
open("#{conf_path}/idf_blank_before.json"){|f|
	blank_line_before_a = JSON.load(f)
}

# fixed values
idf_corrected_h.store("MAGE-TAB Version", ["1.1"])
idf_corrected_h.store("Person Roles", Array.new(person_number, "submitter"))
idf_corrected_h.store("SDRF File", [sdrf_file])

if auto_correction_flag

	idf_corrected_file = open("#{corrected_dir}/#{idf_file.sub(".idf.txt", ".corrected.idf.txt")}", "w")

	# 無ければ IDF 固定二行を挿入
	magetab_version_flag = false
	mb_accession_flag = false
	for line_a in idf_a
		magetab_version_flag = true if line_a[0] == "MAGE-TAB Version"
		mb_accession_flag = true if line_a[0] == "Comment[MetaboBank accession]"
	end

	unless magetab_version_flag
		idf_corrected_file.puts "MAGE-TAB Version\t1.1"
	end

	unless mb_accession_flag
		idf_corrected_file.puts "Comment[MetaboBank accession]"
	end

	for line_a in idf_a

		field_name = line_a[0]
		field_value_a = line_a[1..-1]

		# 空行挿入
		idf_corrected_file.puts "" if blank_line_before_a.include?(field_name)

		# auto-correction
		if idf_corrected_h[field_name]
			idf_corrected_file.puts "#{field_name}\t#{idf_corrected_h[field_name].collect{|e| e.match(/\n|\t/) ? '"' + e + '"' : e }.join("\t")}"
		else
			idf_corrected_file.puts line_a.collect{|e| e.match(/\n|\t/) ? '"' + e + '"' : e }.join("\t")
		end

	end

end

#
# SDRF auto-correction
#

# 値の修正はせず、コメント行・空行の無視、値のトリミング
# 入出力を比較して変更がない場合は出力しない
if auto_correction_flag

	sdrf_corrected_file = open("#{corrected_dir}/#{sdrf_file.sub(".sdrf.txt", ".corrected.sdrf.txt")}", "w")

	for line_a in sdrf_a
		sdrf_corrected_file.puts line_a.join("\t")
	end

	sdrf_corrected_file.close

end


#
# SDRF & BioSample validation 結果出力
# 
if bs_path != ""
	puts ""
	puts "SDRF and BioSample validation results"
	puts "---------------------------------------------"
	error_ignore_sdrf_bs_a.sort{|a,b| a[0] <=> b[0]}.each{|m| puts m.join(": ")}
	warning_sdrf_bs_a.sort{|a,b| a[0] <=> b[0]}.each{|m| puts m.join(": ")}
	puts "---------------------------------------------"
end