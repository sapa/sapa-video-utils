#!/bin/bash

# default parameters
THREADS=1

if [ ! -f ./config.sh ]; then
    cp ./config-sample.sh ./config.sh
fi

source ./config.sh

# check if all required binaries are installed
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
if [ -z $(command -v gsed) ]; then
    echo "gsed is required to run this script."
    exit
fi
# create directory for log files if it doesn't exist yet
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
fi

log() {
    LEVEL="$1"
    MSG="$2"

    LOG_FILE="$LOG_DIR/$(date +"%Y-%m-%d").txt"
    if [ ! -f "$LOG_FILE" ]; then
        echo "time" > "$LOG_FILE"
    fi

    # TODO: check log level
    echo "LOG $LEVEL - $MSG"
    # TODO: write to log file
}