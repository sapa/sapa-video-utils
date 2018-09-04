#!/bin/bash

source ./common.sh

# Converts one or many videos to a dissemination format.
# Optionally (and for single files only) videos can also be trimmed by providing in- 
# and out-points as parameters.

# Usage:
# dip.sh PATH/TO/VIDEO/OR/DIRECTORY
# dip.sh -d PATH/TO/VIDEO/OR/DIRECTORY
# dip.sh -l 2 PATH/TO/VIDEO/OR/DIRECTORY
# dip.sh -ow PATH/TO/VIDEO/OR/DIRECTORY
# dip.sh -s 01:00 -e 03:01.2 PATH/TO/VIDEO
# dip.sh -t 4 PATH/TO/VIDEO

# default values
VIDEO_CODEC="libx265"
AUDIO_CODEC="aac"
CONTAINER="mkv"
TITLE_DURATION=6

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
    echo "Usage: dip.sh PATH/TO/VIDEO/OR/DIRECTORY"
    echo "It also offers the following optional parameters:"
    echo "-d/--dry                   : Only shows what the script would actually do."
    echo "-ow/--overwrite            : Overwrite existing file even if they are newer than the video."
    echo "-l/--loglevel              : 0 = no log, 1 = errors only, 2 = log everything"
    echo "-t/--threads               : number of cores to be used"
    echo "-s/--start                 : Trim (single) video with in-point."
    echo "-e/--end                   : Trim (single) video with out-point."
    echo "Example: dip.sh -d -l 2 -ow -s 01:02 -e 04:12.5 -t 3 PATH/TO/VIDEO"
    exit
fi

# Verify that not start or end time code was given


convert() {
    SOURCE="$1"
    TARGET="${SOURCE%.*}_h265.$CONTAINER"

    # find height and width of source file
    HEIGHT=$(mediainfo "$SOURCE" | grep Height | tr -dc '0-9')
    WIDTH=$(mediainfo "$SOURCE" | grep Width | tr -dc '0-9')
    echo "original size: $HEIGHT x $WIDTH"

    # extract aspect ratio and calculate width for square pixel usage copy
    ASPECT_RATIO=$(mediainfo "$SOURCE" | grep 'isplay aspect ratio' | head -n1 | tr -dc '0-9:')
    ASPECT_RATIO=${ASPECT_RATIO:1} # cut the begining of the line
    ASPECT_RATIO=${ASPECT_RATIO/:/\/} # replace ':' with '/' for     echo "aspect ratio:   $ASPECT_RATIO"
    WIDTH_FLOAT=$(echo "scale=8; $HEIGHT*$ASPECT_RATIO" | bc)
    WIDTH=$(echo "scale=0; ($WIDTH_FLOAT+0.5)/1" | bc)
    echo "target size:   $HEIGHT x $WIDTH"

    # deinterlace?
    SCAN_TYPE=$(mediainfo "$SOURCE" | grep 'Scan type' | tr -d ' :')
    SCAN_TYPE=${SCAN_TYPE:8:10}
    if [ "$SCAN_TYPE" == "Interlaced" ]; then
        DEINTERLACE=YES
    fi

    if [ -f "$TARGET" ]; then
        if [ $(stat -f "%c" "$TARGET") -lt $(stat -f "%c" "$SOURCE") ]; then
            TARGET_STATE="outdated"
        else
            TARGET_STATE="current"
        fi
    else
        TARGET_STATE="missing"
    fi

    if [ -z "$DRYRUN" ]; then

        # create title image
        # TODO: find signature
        TITLE_PATH=$(./make-title.sh -s ABC123456 -w "$WIDTH" -h "$HEIGHT")

        if [ ! -f "$TARGET" ] || [ ! -z "$OVERWRITE" ]; then
            if [ -f "$TARGET" ]; then
                echo "overwrite usage copy $TARGET"
            else
                echo "create usage copy $TARGET"
            fi
            
            # create title video
            TITLE_VIDEO="$(mktemp)_title.mkv"
            # TITLE_DURATION_FADE=$(echo "$TITLE_DURATION-2" | bc)
            ffmpeg -loglevel error -threads "$THREADS" -loop 1 -i "$TITLE_PATH" -f lavfi -i aevalsrc=0:d="$TITLE_DURATION" \
                -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2,trim=duration=$TITLE_DURATION,fade=in:st=1:d=1" \
                -pix_fmt yuv420p -c:v ffv1 -c:a pcm_s16le -r 25 -t "$TITLE_DURATION" "$TITLE_VIDEO"
            rm "$TITLE_PATH"

            # convert original video
            CONTENT_VIDEO="$(mktemp)_content.mkv"
            if [ -z "$DEINTERLACE" ]; then
                FILTER_OPTIONS="yadif,scale=$WIDTH:$HEIGHT"
            else
                FILTER_OPTIONS="scale=$WIDTH:$HEIGHT"
            fi
            ffmpeg -loglevel error -threads "$THREADS" -i "$VIDEO_PATH" -c:v ffv1 -c:a pcm_s16le -vf "$FILTER_OPTIONS" "$CONTENT_VIDEO"

            # concat title and original video
            # ffmpeg -loglevel error -i "$TITLE_VIDEO" -i "$CONTENT_VIDEO" \
            #     -filter_complex "[0:v:0] [0:a:0] [1:v:0] [1:a:0] concat=n=2:v=1:a=1 [v] [a]" -map '[v]' -map '[a]' \
            #     -c:v "$VIDEO_CODEC" -b:v 6000k -c:a aac -b:a 256k -y "$TARGET"
            ffmpeg -loglevel error -threads "$THREADS" -i "$CONTENT_VIDEO" -i "$TITLE_VIDEO" \
                -filter_complex "[0:v:0] [0:a:0] [1:v:0] [1:a:0] concat=n=2:v=1:a=1 [v] [a]" -map '[v]' -map '[a]' \
                -c:v "$VIDEO_CODEC" -b:v 6000k -c:a aac -b:a 256k -y "$TARGET"
            rm "$TITLE_VIDEO"
            rm "$CONTENT_VIDEO"
            if [ -f "$TARGET" ]; then
                USAGECOPY_STATE="x"
                if [ ! -z "$AUTOOPEN" ]; then
                    open "$TARGET"
                fi
            fi
        fi

    fi


    # TODO: optimize - https://trac.ffmpeg.org/wiki/Encode/H.265
    # ffmpeg -y -loglevel error -i "$SOURCE" -c:v "$VIDEO_CODEC" -threads "$THREADS" \
    #     -c:a "$AUDIO_CODEC" "$TARGET"
}

# loop through all given paths
for SEARCH_PATH in "${SEARCH_PATHS[@]}"; do
    # find all Matroska files
    # TODO: Make sure that these are AIPs.
    find "$SEARCH_PATH" -name "*.mkv" -type f | while read VIDEO_PATH; do 
        convert "$VIDEO_PATH";
    done
done
