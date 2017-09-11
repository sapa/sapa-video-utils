#!/bin/bash

# This script looks for Matroska files and generates md5 and EBUCore xml for them in the same location.
# Usage: ./mkvdoc.sh /PATH/TO/MATROSKA/FILES

# expects 'find'-compatible paths as arguments when called
paths="$@"

# if no paths was given, ask for it
if [ -z "$paths" ]; then
	read -p "Enter directory or file path: " paths
fi

# define directory for log files and make sure it exists
log_dir="~/mkv_logs"
mkdir -p "$log_dir"

# define today's log file and create it if necessary
log_file="$log_dir/$(date +"%Y-%m-%d").csv"
if [ ! -f "$log_file" ]; then
	echo "time, file, md5, xml" > "$log_file"
fi

# find all Matroska files
find "$paths" -name "*.mkv" -type f | while read video_path; do 

	# define file paths
	video_dir=$(dirname "$video_path")
	video_file=$(basename "$video_path")
	
	### md5 ###
	
	md5_file="${video_path%.*}.md5"
	
	# check if md5 file either doesn't exist or is older than the video file
	if [ ! -f "$md5_file" ] || [ $(stat -f "%c" "$md5_file") -lt $(stat -f "%c" "$video_path") ]; then
		# create/overwrite md5 file and replace file path with file name
		md5_value=$(md5 "$video_path" | sed "s|$video_path|$video_file|g")
		echo "$md5_value" > "$md5_file"
		md5_value="${md5_value: -32}"
	else
		md5_value="-"
	fi
	
	### EBUCore xml ###
	
	xml_file="${video_path%.*}.xml"

	# check if xml file either doesn't exist or is older than the video file
	if [ ! -f "$xml_file" ] || [ $(stat -f "%c" "$xml_file") -lt $(stat -f "%c" "$video_path") ]; then
		# create/overwrite xml file
		/usr/local/bin/mediainfo --Output=EBUCore "$video_path" > "$xml_file" 2>/dev/null
		# verify xml
		xml_size="$(stat -f "%z" "$xml_file")"
		if [ "$xml_size" == "0" ] || [ "$xml_size" == "" ]; then
			xml_size="-"
		fi
	else
		xml_size="-"
	fi

	# check if either md5 or mediainfo was executed
	if [ "$md5_value" != "-" ] || [ "$xml_size" != "-" ]; then
		echo "$(date +"%H:%M:%S"),$video_path,$md5_value,$xml_size" >> "$log_file"
	fi
		
done