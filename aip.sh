#!/bin/bash

SCRIPTPATH="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"
source "$SCRIPTPATH/common.sh"

# Converts one or many videos to an archival format for long-term preservation.
# Optionally (and for single files only) videos can also be trimmed by providing in- 
# and out-points as parameters.
# Source videos are expected have filenames containing 'DIG-MAS' and ending with either mkv, mov or mp4.
# Target videos with be replace 'DIG-MAS' with 'DIG-SKD' and be MKVs.

# Usage:
# aip.sh PATH/TO/VIDEO/OR/DIRECTORY
# aip.sh -d PATH/TO/VIDEO/OR/DIRECTORY
# aip.sh -l 2 PATH/TO/VIDEO/OR/DIRECTORY
# aip.sh -ow PATH/TO/VIDEO/OR/DIRECTORY
# aip.sh -s 01:00 -e 03:01.2 PATH/TO/VIDEO
# aip.sh -t 4 PATH/TO/VIDEO

# parse parameters
SEARCH_PATHS=()
while [[ $# > 0 ]]; do
    key="$1"
    case $key in
        -d|--dry)
            DRYRUN=YES
            shift
            ;;
        -l|--loglevel)
            LOG_LEVEL="$2" # convert to int?
            shift
            shift
            ;;
        -ow|--overwrite)
            OVERWRITE=YES
            shift
            ;;
        -s|--start)
            START="$2"
            shift
            shift
            ;;
        -e|--end)
            END="$2"
            shift
            shift
            ;;
        -t|--threads)
            THREADS="$2"
            shift
            shift
            ;;
        *)
            SEARCH_PATHS+=("$1") # everything that is not an option is considered a search path
            shift
            ;;
    esac
done

# validate that there is at least one search path
if [ ${#SEARCH_PATHS[@]} -lt 1 ]; then
    echo "This script expects at least one path to search for video files."
    echo "Usage: aip.sh PATH/TO/VIDEO/OR/DIRECTORY"
    echo "It also offers the following optional parameters:"
    echo "-d/--dry                   : Only shows what the script would actually do."
    echo "-ow/--overwrite            : Overwrite existing file even if they are newer than the video."
    echo "-l/--loglevel              : 0 = no log, 1 = errors only, 2 = log everything"
    echo "-t/--threads               : number of cores to be used"
    echo "-s/--start                 : Trim (single) video with in-point."
    echo "-e/--end                   : Trim (single) video with out-point."
    echo "Example: aip.sh -d -l 2 -t 2 -ow -s 01:02 -e 04:12.5 PATH/TO/VIDEO"
    exit
fi

convert() {
    SOURCE=$(realpath "$1")
    TARGET=$(echo "$SOURCE" | sed -Ee 's/DIG-MAS.[a-z0-9]+/DIG-SKD.mkv/g')
    LOGFILE="${TARGET%.*}.log"
    echo "convert video $SOURCE ..."
    # check state of target file
    if [ -f "$TARGET" ]; then
        if [ $(stat -f "%c" "$TARGET") -lt $(stat -f "%c" "$SOURCE") ]; then
            TARGET_STATE="outdated"
        else
            TARGET_STATE="current"
        fi
    else
        TARGET_STATE="missing"
    fi
    if [ ! -z "$DRYRUN" ]; then
        echo "dry run: $SOURCE >>> $TARGET"
    else
        # check if target is either missing, outdated or should be overwritten anyway
        if [ "$TARGET_STATE" == 'missing' ] || [ "$TARGET_STATE" == 'outdated' ] || [ ! -z "$OVERWRITE" ]; then
            # check various options for in and out points
            # TODO: validate that in and out points are valid
            if [ ! -z "$START" ] && [ ! -z "$END" ]; then
                < /dev/null ffmpeg -y -loglevel info -i "$SOURCE" -ss "$START" -to "$END" -c:v ffv1 -level 3 -threads "$THREADS" \
                    -coder 1 -context 1 -g 1 -slices 24 -slicecrc 1 -c:a flac "$TARGET" 2>&1 | tee "$LOGFILE"
            elif [ ! -z "$START" ]; then
                < /dev/null ffmpeg -y -loglevel info -ss "$START" -i "$SOURCE" -c:v ffv1 -level 3 -threads "$THREADS" \
                    -coder 1 -context 1 -g 1 -slices 24 -slicecrc 1 -c:a flac "$TARGET" 2>&1 | tee "$LOGFILE"
            elif [ ! -z "$END" ]; then
                < /dev/null ffmpeg -y -loglevel info -i "$SOURCE" -to "$END" -c:v ffv1 -level 3 -threads "$THREADS" \
                    -coder 1 -context 1 -g 1 -slices 24 -slicecrc 1 -c:a flac "$TARGET" 2>&1 | tee "$LOGFILE"
            else
                < /dev/null ffmpeg -y -loglevel info -i "$SOURCE" -c:v ffv1 -level 3 -threads "$THREADS" \
                    -coder 1 -context 1 -g 1 -slices 24 -slicecrc 1 -c:a flac "$TARGET" 2>&1 | tee "$LOGFILE"
            fi
        fi
        # TODO: validate file and log results
        log "$SOURCE >>> $TARGET"
        document "$TARGET";
    fi
}

document() {
    VIDEO_PATH="$1"

    ### md5 ###
    MD5_FILE="${VIDEO_PATH%.*}.md5"
    
    # check if md5 file either doesn't exist or is older than the video file
    if [ ! -f "$MD5_FILE" ] || [ $(stat -f "%c" "$MD5_FILE") -lt $(stat -f "%c" "$VIDEO_PATH") ]; then
        # create/overwrite md5 file and replace file path with file name
        MD5_VALUE=$(md5 "$VIDEO_PATH" | sed "s|$VIDEO_PATH|$VIDEO_FILE|g")
        echo "$MD5_VALUE" > "$MD5_FILE"
        MD5_VALUE="${MD5_VALUE: -32}"
    else
        MD5_VALUE="-"
    fi
    
    ### mediainfo text file ###
    MEDIAINFO_FILE="${VIDEO_PATH%.*}.txt"

    # check if text file either doesn't exist or is older than the video file
    if [ ! -f "$MEDIAINFO_FILE" ] || [ $(stat -f "%c" "$MEDIAINFO_FILE") -lt $(stat -f "%c" "$VIDEO_PATH") ]; then
        # create/overwrite mediainfo file
        # TODO: find a better way to determine the mediainfo path
        /usr/local/bin/mediainfo "$VIDEO_PATH" > "$MEDIAINFO_FILE"
        # verify file
        MEDIAINFO_SIZE="$(stat -f "%z" "$MEDIAINFO_FILE")"
        if [ "$MEDIAINFO_SIZE" == "0" ] || [ "$MEDIAINFO_SIZE" == "" ]; then
            MEDIAINFO_SIZE="-"
            rm "$MEDIAINFO_FILE"
        fi
    else
        MEDIAINFO_SIZE="-"
    fi

    ### EBUCore xml ###    
    XML_FILE="${VIDEO_PATH%.*}.xml"

    # check if xml file either doesn't exist or is older than the video file
    if [ ! -f "$XML_FILE" ] || [ $(stat -f "%c" "$XML_FILE") -lt $(stat -f "%c" "$VIDEO_PATH") ]; then
        # create/overwrite xml file
        # TODO: find a better way to determine the mediainfo path
        /usr/local/bin/mediainfo --Output=EBUCore "$VIDEO_PATH" > "$XML_FILE"
        # verify file
        XML_SIZE="$(stat -f "%z" "$XML_FILE")"
        if [ "$XML_SIZE" == "0" ] || [ "$XML_SIZE" == "" ]; then
            XML_SIZE="-"
            rm "$XML_FILE"
        fi
    else
        XML_SIZE="-"
    fi

    # TODO: create log messages
    # check if either md5 or mediainfo was executed
    # if [ "$MD5_VALUE" != "-" ] || [ "$XML_SIZE" != "-" ]; then
    #     log "$(date +"%H:%M:%S"),$VIDEO_PATH,$MD5_VALUE,$XML_SIZE"
    # fi    
}

# loop through all given paths
for SEARCH_PATH in "${SEARCH_PATHS[@]}"; do
    # find all Matroska and QuickTime files
    find "$SEARCH_PATH" -name "*-DIG-MAS.mkv" -o -name "*-DIG-MAS.mov" -o -name "*-DIG-MAS.mp4" -type f | while read VIDEO_PATH; do
        convert "$VIDEO_PATH";
    done
done
