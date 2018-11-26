#!/bin/bash

# default parameters
THREADS=1

if [ ! -f "$SCRIPTPATH/config.sh" ]; then
    cp "$SCRIPTPATH/config-sample.sh" "$SCRIPTPATH/config.sh"
fi

source "$SCRIPTPATH/config.sh"

# check if all required binaries are installed
if [ -z $(command -v realpath) ]; then
    echo "realpath is required to run this script. Run 'brew install coreutils' to install."
    exit
fi
if [ -z $(command -v mediainfo) ]; then
    echo "mediainfo is required to run this script."
    exit
fi
if [ -z $(command -v ffmpeg) ]; then
    # TODO: check x265 support
    # brew install ffmpeg --with-x265 --with-tools --with-fdk-aac --with-freetype --with-fontconfig --with-libass --with-libvorbis --with-libvpx --with-opus
    echo "ffmpeg is required to run this script."
    exit
fi
if [ -z $(command -v convert) ]; then
    echo "imagemagick is required to run this script."
    exit
fi
# create directory for log files if it doesn't exist yet
if [ ! -z "$LOG_DIR" ] && [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
fi

log() {
    LEVEL="$1"
    MSG="$2"

    if [ ! -z "$LOG_DIR" ]; then
        LOG_FILE="$LOG_DIR/$(date +"%Y-%m-%d").txt"
        if [ ! -f "$LOG_FILE" ]; then
            echo "time" > "$LOG_FILE"
        fi
    fi 

    # TODO: check log level
    echo "LOG $LEVEL - $MSG"
    # TODO: write to log file
}