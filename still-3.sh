#!/bin/bash

SCRIPTPATH="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"
source "$SCRIPTPATH/common.sh"

# Creates stills from videos.
# The time code of the still is automatically chosen but might also be set manually.

# Usage:
# still.sh PATH/TO/VIDEO/OR/DIRECTORY
# still.sh -tc 03:00 PATH/TO/VIDEO

# default values
TIMECODE="450" # 450 seconds

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
            LOGLEVEL="$2" # convert to int?
            shift
            shift
            ;;
        -ow|--overwrite)
            OVERWRITE=YES
            shift
            ;;
        -tc|--timecode)
            TIMECODE="$2"
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
    echo "Usage: still.sh PATH/TO/VIDEO/OR/DIRECTORY"
    echo "It also offers the following optional parameters:"
    echo "-d/--dry                   : Only shows what the script would actually do."
    echo "-l/--loglevel              : 0 = no log, 1 = errors only, 2 = log everything"
    echo "-ow/--overwrite            : Overwrite existing file even if they are newer than the video."
    echo "-tc/--timecode             : Time code of the wanted still"
    echo "Example: still.sh -d -l 2 -ow -tc 01:02 PATH/TO/VIDEO"
    exit
fi

still() {
    SOURCE="$1"
    INTERMEDIARY="${SOURCE%.*}.png"
    TARGET="${SOURCE%.*}.tiff"
    # TODO: implement overwrite check
    # TODO: validate whether time code exists
    WIDTH=$(mediainfo "$VIDEO_PATH" | grep Width | tr -dc '0-9')
    HEIGHT=$(mediainfo "$VIDEO_PATH" | grep Height | tr -dc '0-9')
    # extract aspect ratio and calculate width for square pixel usage copy
    ASPECT_RATIO=$(mediainfo "$VIDEO_PATH" | grep 'isplay aspect ratio' | head -n1 | tr -dc '0-9:')
    ASPECT_RATIO=${ASPECT_RATIO:1} # cut the begining of the line
    ASPECT_RATIO=${ASPECT_RATIO/:/\/} # replace ':' with '/' for calculation
    ASPECT_RATIO=$(echo "scale=8; $ASPECT_RATIO" | bc)
    WIDTH_FLOAT=$(echo "scale=8; $HEIGHT*$ASPECT_RATIO" | bc)
    WIDTH=$(echo "scale=0; ($WIDTH_FLOAT+0.5)/1" | bc)
    FILTER_OPTIONS="scale=$WIDTH:$HEIGHT"
    # deinterlace?
    INTERLACED=$(mediainfo "$VIDEO_PATH" | grep 'Scan type' | grep 'Interlaced')
    if [ ! -z "$INTERLACED" ]; then
        FILTER_OPTIONS="yadif,scale=$WIDTH:$HEIGHT"
    fi
    # TODO: validate that the intermediary png is lossless
    ffmpeg -ss "$TIMECODE" -i "$SOURCE" -frames:v 1 -vf "$FILTER_OPTIONS" -f image2 "$INTERMEDIARY" > /dev/null 2>&1
    convert "$INTERMEDIARY" "$TARGET"
    rm "$INTERMEDIARY"
    # TODO: add meta data (like the time code) to tiff?
    # TODO: error handling and proper log messages
    log 1 "STILL $TARGET"
}

# loop through all given paths
for SEARCH_PATH in "${SEARCH_PATHS[@]}"; do
    # find video files
    find "$SEARCH_PATH" -iname "*.mkv" -o -iname "*.mov" -o -iname "*.mp4" -type f | while read VIDEO_PATH; do 
        still "$VIDEO_PATH"
    done
done
