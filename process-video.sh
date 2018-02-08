#!/bin/bash

# This script processes archival video files and creates md5 files, EBUCore XMLs, and usage copies.
# The usage copies start with archival title information that comes from a YAML files with the same name as the video file.
# Thus there should be a video ABC123.mkv or ABC123.mov and a description file ABC123.yml with the following syntax:
# Author:    Some Name
# Title:     "Title of the video: possibly a subtitle"
# Date:      01.01.1970
# Signature: ABC123
# Note that quotation marks are neeeded only when special characters (as here the colon) are used.
# There are several options available to change the behaviour of the script. Call it without parameters to see further instructions.

# check if all required binaries are installed
if [ -z $(command -v mediainfo) ]; then
	echo "mediainfo is required to run this script."
	exit
fi
if [ -z $(command -v ffmpeg) ]; then
	echo "ffmpeg is required to run this script."
	exit
fi
if [ -z $(command -v convert) ]; then
	echo "imagemagick is required to run this script."
	exit
fi

# default values
VIDEO_CODEC="libx264"
TITLE_DURATION=4

# parse parameters
SEARCH_PATHS=()
OPTIONS=()
while [[ $# > 0 ]]; do
	key="$1"
	case $key in
	    -vc|--video-codec)
	    	VIDEO_CODEC="$2"
	    	OPTIONS+=("video codec: $VIDEO_CODEC")
	    	shift
	    	shift
	    	;;
	    -d|--dry)
		    DRYRUN=YES
		    OPTIONS+=("dry run")
		    shift
		    ;;
	    -ow|--overwrite)
		    OVERWRITE=YES
		    OPTIONS+=("overwrite")
		    shift
		    ;;
	    -ao|--autoopen)
		    AUTOOPEN=YES
		    OPTIONS+=("auto open")
		    shift
		    ;;
	    -nuc|--no-usage-copy)
		    NO_USAGE_COPY=YES
		    OPTIONS+=("no usage copies")
		    shift
		    ;;
	    *)
		    SEARCH_PATHS+=("$1") # everything that is not an option is considered a search path
		    shift
		    ;;
	esac
done

# confirm selectec options
if [ ${#OPTIONS[@]} -gt 0 ]; then
	echo "Options selected: ${OPTIONS[@]}"
fi

# define directory for log files and make sure it exists
LOG_DIR="$HOME/video-logs"
mkdir -p "$LOG_DIR"

# define today's log file and create it if necessary
LOG_PATH="$LOG_DIR/$(date +"%Y-%m-%d").csv"
if [ ! -f "$LOG_PATH" ]; then
	echo "time, file, md5, xml, usage copy" > "$LOG_PATH"
fi

log_local() {
	echo "$1"
}

# validate that there is at least one search path
if [ ${#SEARCH_PATHS[@]} -lt 1 ]; then
	echo "This script expects at least one path to search for video files."
	echo "It also offers the following optional parameters:"
	echo "-vc/--video-codec libx264  : Select alternative video codec."
	echo "-d/--dry                   : Only shows what the script would actually do."
	echo "-ow/--overwrite            : Existing files are only overwritten with this option."
	echo "-ao/--autoopen             : Automatically open all usage copies for control."
	echo "-nuc/--no-usage-copy       : Skips usage copies."
	exit
fi

# loop through all given paths
for SEARCH_PATH in "${SEARCH_PATHS[@]}"; do

	# find all Matroska and QuickTime files
	find "$SEARCH_PATH" -name "*.mkv" -o -name "*.mov" -type f | while read VIDEO_PATH; do 

		# escape spaces
		# VIDEO_PATH=$(echo $VIDEO_PATH|sed 's/\ /\\ /g')

		# processing of single video file starts here
		log_local "-- $VIDEO_PATH --"

		# find height and width of source file
		HEIGHT=$(mediainfo "$VIDEO_PATH" | grep Height | tr -dc '0-9')
		WIDTH=$(mediainfo "$VIDEO_PATH" | grep Width | tr -dc '0-9')
		log_local "original size: $HEIGHT x $WIDTH"

		# extract aspect ratio and calculate width for square pixel usage copy
		ASPECT_RATIO=$(mediainfo "$VIDEO_PATH" | grep 'Original display aspect ratio' | tr -d ' ')
		ASPECT_RATIO=${ASPECT_RATIO:27} # cut the begining of the line
		ASPECT_RATIO=${ASPECT_RATIO/:/\/} # replace ':' with '/' for calculation
		ASPECT_RATIO=$(echo "scale=8; $ASPECT_RATIO" | bc)
		WIDTH=$(LC_NUMERIC="en_US.UTF-8" printf "%.0f" $(echo "scale=8; $HEIGHT*$ASPECT_RATIO" | bc))
		log_local "target size:   $HEIGHT x $WIDTH"

		# deinterlace?
		SCAN_TYPE=$(mediainfo "$VIDEO_PATH" | grep 'Scan type' | tr -d ' :')
		SCAN_TYPE=${SCAN_TYPE:8:10}
		if [ "$SCAN_TYPE" == "Interlaced" ]; then
			DEINTERLACE=YES
			log_local "deinterlace"
		fi

		# define path for md5, EBUCore, and usage copy
		INFO_PATH="${VIDEO_PATH%.*}.yml"
		MD5_PATH="${VIDEO_PATH%.*}.md5"
		XML_PATH="${VIDEO_PATH%.*}.xml"
		USAGECOPY_PATH="${VIDEO_PATH%.*}.mp4"

		### md5 ###
		
		# check if md5 file either doesn't exist or is older than the video file or overwrite option was chosen
		MD5_VALUE="-"
		if [ -f "$MD5_PATH" ]; then
			if [ $(stat -f "%c" "$MD5_PATH") -lt $(stat -f "%c" "$VIDEO_PATH") ]; then
				MD5_STATE="outdated"
			else
				MD5_STATE="current"
				MD5_VALUE=$(cat "$MD5_PATH"|sed "s|.* = ||g") 
			fi
		else
			MD5_STATE="missing"
		fi
		if [ ! -f "$MD5_PATH" ] || [ $(stat -f "%c" "$MD5_PATH") -lt $(stat -f "%c" "$VIDEO_PATH") ] || [ ! -z "$OVERWRITE" ]; then
			# create/overwrite md5 file and replace file path with file name
			VIDEO_FILE=$(basename "$VIDEO_PATH")
			MD5_VALUE=$(md5 "$VIDEO_PATH" | sed "s|$VIDEO_PATH|$VIDEO_FILE|g")
			if [ -z "$DRYRUN" ]; then
				echo "$MD5_VALUE" > "$MD5_PATH"
				MD5_STATE="written"
			fi
			MD5_VALUE="${MD5_VALUE: -32}"
		fi
		log_local "md5:           $MD5_STATE ($MD5_VALUE)"
		
		### EBUCore xml ###
		
		if [ -f "$XML_PATH" ]; then
			if [ $(stat -f "%c" "$XML_PATH") -lt $(stat -f "%c" "$VIDEO_PATH") ]; then
				XML_STATE="outdated"
			else
				XML_STATE="current"
			fi
		else
			XML_STATE="missing"
		fi
		# check if xml file either doesn't exist or is older than the video file or overwrite option was chosen
		if [ -z "$DRYRUN" ]; then
			if [ ! -f "$XML_PATH" ] || [ $(stat -f "%c" "$XML_PATH") -lt $(stat -f "%c" "$VIDEO_PATH") ] || [ ! -z "$OVERWRITE" ]; then
				# create/overwrite xml file
				mediainfo --Output=EBUCore "$VIDEO_PATH" > "$XML_PATH" 2>/dev/null
				# verify xml
				XML_SIZE="$(stat -f "%z" "$XML_PATH")"
				if [ "$XML_SIZE" != "0" ] && [ "$XML_SIZE" != "" ]; then
					XML_STATE="x"
					log_local "XML:           written"
				else
					log_local "XML:           error"
				fi
			else
				log_local "XML:           $XML_STATE"
			fi
		else
			# in dry run just check if XML exists and is current
			log_local "XML:           $XML_STATE"
		fi
		
		### usage copy ###

		USAGECOPY_STATE="-"
		# find YAML and create title image
		if [ ! -f "$INFO_PATH" ]; then
			log_local "Info file missing!"
		else
			if [ -f "$USAGECOPY_PATH" ]; then
				if [ $(stat -f "%c" "$USAGECOPY_PATH") -lt $(stat -f "%c" "$VIDEO_PATH") ]; then
					USAGECOPY_STATE="outdated"
				else
					USAGECOPY_STATE="current"
				fi
			else
				USAGECOPY_STATE="missing"
			fi
			if [ -z "$DRYRUN" ]; then
				# create title image
				TITLE_PATH=$(./make-title.sh -i "$INFO_PATH" -w "$WIDTH" -h "$HEIGHT")

				if [ ! -f "$USAGECOPY_PATH" ] || [ ! -z "$OVERWRITE" ]; then
					if [ -f "$USAGECOPY_PATH" ]; then
						log_local "overwrite usage copy $USAGECOPY_PATH"
					else
						log_local "create usage copy $USAGECOPY_PATH"
					fi
					
					# create title video
					TITLE_VIDEO="$(mktemp)_title.mkv"
					TITLE_DURATION_FADE=$(echo "$TITLE_DURATION-2" | bc)
					ffmpeg -loglevel error -loop 1 -i "$TITLE_PATH" -f lavfi -i aevalsrc=0:d=5 \
						-vf "scale=trunc(iw/2)*2:trunc(ih/2)*2,trim=duration=$TITLE_DURATION,fade=t=out:st=$TITLE_DURATION_FADE:d=1" \
						-pix_fmt yuv420p -c:v ffv1 -c:a pcm_s16le -r 25 -t "$TITLE_DURATION" "$TITLE_VIDEO"
					rm "$TITLE_PATH"

					# convert original video
					CONTENT_VIDEO="$(mktemp)_content.mkv"
					if [ -z "$DEINTERLACE" ]; then
						FILTER_OPTIONS="yadif,scale=$WIDTH:$HEIGHT"
					else
						FILTER_OPTIONS="scale=$WIDTH:$HEIGHT"
					fi
					ffmpeg -loglevel error -i "$VIDEO_PATH" -c:v ffv1 -c:a pcm_s16le -vf "$FILTER_OPTIONS" "$CONTENT_VIDEO"

					# concat title and original video
					ffmpeg -loglevel error -i "$TITLE_VIDEO" -i "$CONTENT_VIDEO" \
						-filter_complex "[0:v:0] [0:a:0] [1:v:0] [1:a:0] concat=n=2:v=1:a=1 [v] [a]" -map '[v]' -map '[a]' \
						-c:v "$VIDEO_CODEC" -b:v 6000k -c:a aac -b:a 256k -y "$USAGECOPY_PATH"
					rm "$TITLE_VIDEO"
					rm "$CONTENT_VIDEO"
					if [ -f "$USAGECOPY_PATH" ]; then
						USAGECOPY_STATE="x"
						if [ ! -z "$AUTOOPEN" ]; then
							open "$USAGECOPY_PATH"
						fi
					fi
				fi
			fi
			log_local "Usage copy:    $USAGECOPY_STATE"

			# write logs
			if [ ! -z "$DRYRUN" ]; then
				echo "$(date +"%H:%M:%S"),$VIDEO_PATH,$MD5_VALUE,$XML_STATE,$USAGECOPY_STATE" >> "$LOG_PATH"
			fi

		fi
	done
done