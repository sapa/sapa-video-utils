#!/bin/bash

SCRIPTPATH="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"
source "$SCRIPTPATH/common.sh"

# This script looks for video files and generates md5 and EBUCore xml for them in the same location.
# Usage: document.sh PATH/TO/VIDEO/OR/DIRECTORY

# expects 'find'-compatible paths as arguments when called
PATHS="$@"

# if no paths was given, ask for it
if [ -z "$PATHS" ]; then
    read -p "Enter directory or file path: " PATHS
fi

# find all Matroska files
find "$PATHS" -name "*.mkv" -type f | while read VIDEO_PATH; do 

    # define file paths
    VIDEO_FILE=$(basename "$VIDEO_PATH")
    
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

done