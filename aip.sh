#!/bin/bash

source ./common.sh

# Converts one or many videos to an archival format for long-term preservation.
# Optionally (and for single files only) videos can also be trimmed by providing in- 
# and out-points as parameters.

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
    SOURCE="$1"
    # TODO: what to do if the source video is already an mkv?
    TARGET="${SOURCE%.*}_.mkv"
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
            if [ ! -z "$START" ] && [ ! -z "$END" ]; then
                ffmpeg -y -loglevel error -i "$SOURCE" -ss "$START" -to "$END" -c:v ffv1 -level 3 -threads "$THREADS" \
                    -coder 1 -context 1 -g 1 -slices 24 -slicecrc 1 -c:a flac "$TARGET"
            elif [ ! -z "$START" ]; then
                ffmpeg -y -loglevel error -ss "$START" -i "$SOURCE" -c:v ffv1 -level 3 -threads "$THREADS" \
                    -coder 1 -context 1 -g 1 -slices 24 -slicecrc 1 -c:a flac "$TARGET"
            elif [ ! -z "$END" ]; then
                ffmpeg -y -loglevel error -i "$SOURCE" -to "$END" -c:v ffv1 -level 3 -threads "$THREADS" \
                    -coder 1 -context 1 -g 1 -slices 24 -slicecrc 1 -c:a flac "$TARGET"
            else
                ffmpeg -y -loglevel error -i "$SOURCE" -c:v ffv1 -level 3 -threads "$THREADS" \
                    -coder 1 -context 1 -g 1 -slices 24 -slicecrc 1 -c:a flac "$TARGET"
            fi
        fi
        # TODO: validate file and log results
        log "$SOURCE >>> $TARGET"
    fi
}

# loop through all given paths
for SEARCH_PATH in "${SEARCH_PATHS[@]}"; do
    # find all Matroska and QuickTime files
    find "$SEARCH_PATH" -name "*.mkv" -o -name "*.mov" -o -name "*.mp4" -type f | while read VIDEO_PATH; do
        convert "$VIDEO_PATH";
    done
done
