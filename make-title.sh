#!/bin/bash

# This script creates and optionally shows a title image.

# parameters:
# video signature/id
# width
# height

LOGO='assets/SAPA_Logo_03_EDFI.png'

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -s|--signature)
    SIGNATURE="$2"
    shift # past argument
    shift # past value
    ;;
    -h|--height)
    HEIGHT="$2"
    shift # past argument
    shift # past value
    ;;
    -w|--width)
    WIDTH="$2"
    shift # past argument
    shift # past value
    ;;
    --default)
    DEFAULT=YES
    shift # past argument
    ;;
    *)    # unknown option
esac
done

# echo "SIGNATURE: $SIGNATURE"
# echo "HEIGHT: $HEIGHT"
# echo "WIDTH: $WIDTH"

# validate params
if [ -z "$SIGNATURE" ] || [ -z "$HEIGHT" ] || [ -z "$WIDTH" ]; then
	echo "Missing parameters. Usage: make-title.sh --signature ABC123 --width 1920 --height 1080"
	exit
fi

# calculate text size and positions
VIDEO_SIZE=${WIDTH}x${HEIGHT}
REF_HEIGHT=1080
SCALE=$(echo "scale=6; $HEIGHT/$REF_HEIGHT" | bc)
MARGIN_LEFT=$(echo "$SCALE*180/1" | bc)
MARGIN_TOP_BOTTOM=$(echo "$SCALE*120/1" | bc)

LOGO_HEIGHT=$(echo "$SCALE*200/1" | bc)
LOGO_SIZE_POSITION="$((3*LOGO_HEIGHT))x$LOGO_HEIGHT+$MARGIN_LEFT+$MARGIN_TOP_BOTTOM"

TEXT_SIZE=$(echo "$SCALE*48/1" | bc)
# LINE_HEIGHT=$(echo "$SCALE*80/1" | bc)
LINE_HEIGHT=80

SIGNATURE_POSITION="$MARGIN_LEFT,930"
SIGNATURE_POSITION="$MARGIN_LEFT,$(echo "$SCALE*($REF_HEIGHT-150)/1" | bc)"

DONTCOPY_POSITION="$MARGIN_LEFT,600"

# create title still
TITLE_IMAGE="$(mktemp).png"
convert -size "$VIDEO_SIZE" xc:white -fill black -font ArialUnicode -pointsize "$TEXT_SIZE" \
    -draw "text $SIGNATURE_POSITION '$SIGNATURE'" \
    -draw "text $DONTCOPY_POSITION 'DONT COPY'" \
	"$TITLE_IMAGE"
# add logo
convert "$TITLE_IMAGE" "$LOGO" -geometry "$LOGO_SIZE_POSITION" -composite "$TITLE_IMAGE"

# open "$TITLE_IMAGE"

# print image file path
echo "$TITLE_IMAGE"
