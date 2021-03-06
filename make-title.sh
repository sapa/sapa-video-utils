#!/bin/bash

# This script creates and optionally shows a title image.

# parameters:
# video signature/id
# width
# height

SCRIPTPATH="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"

SAPA_LOGO="$SCRIPTPATH/assets/SAPA_Logo_03_EDFI.png"
MEMORIAV_LOGO="$SCRIPTPATH/assets/Memoriav.png"

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
    -m|--MEMORIAV)
    MEMORIAV=YES
    shift # past argument
    ;;
    --default)
    DEFAULT=YES
    shift # past argument
    ;;
    *)    # unknown option
esac
done

# validate params
if [ -z "$SIGNATURE" ] || [ -z "$HEIGHT" ] || [ -z "$WIDTH" ]; then
	echo "Missing parameters. Usage: make-title.sh --signature ABC123 --width 1920 --height 1080"
	exit
fi

# calculate text size and positions
VIDEO_SIZE=${WIDTH}x${HEIGHT}

ASPECT_RATIO=$(echo "10*$WIDTH/$HEIGHT" | bc)
if [ $ASPECT_RATIO -gt 15 ]; then
    # wide screen
    REF_HEIGHT=1080
    SCALE=$(echo "scale=6; $HEIGHT/$REF_HEIGHT" | bc)
    MARGIN_LEFT_RIGHT=$(echo "$SCALE*192/1" | bc)
    MARGIN_TOP_BOTTOM=$(echo "$SCALE*108/1" | bc)
    SAPA_LOGO_HEIGHT=$(echo "$SCALE*218/1" | bc)
    MEMORIAV_LOGO_HEIGHT=$(echo "$SCALE*210/1" | bc)
    TEXT_SIZE=$(echo "$SCALE*38/1" | bc)
    SIGNATURE_POSITION="$((MARGIN_LEFT_RIGHT)),$(echo "$SCALE*276/1" | bc)"
    DONTCOPY_POSITION_1="$MARGIN_LEFT_RIGHT,$(echo "$SCALE*438/1" | bc)"
    DONTCOPY_POSITION_2="$MARGIN_LEFT_RIGHT,$(echo "$SCALE*487/1" | bc)"
    DONTCOPY_POSITION_3="$MARGIN_LEFT_RIGHT,$(echo "$SCALE*536/1" | bc)"
    DONTCOPY_POSITION_4="$MARGIN_LEFT_RIGHT,$(echo "$SCALE*585/1" | bc)"
else
    REF_HEIGHT=576    
    SCALE=$(echo "scale=6; $HEIGHT/$REF_HEIGHT" | bc)
    MARGIN_LEFT_RIGHT=$(echo "$SCALE*78/1" | bc)
    MARGIN_TOP_BOTTOM=$(echo "$SCALE*58/1" | bc)
    SAPA_LOGO_HEIGHT=$(echo "$SCALE*86/1" | bc)
    MEMORIAV_LOGO_HEIGHT=$(echo "$SCALE*88/1" | bc)
    TEXT_SIZE=$(echo "$SCALE*17/1" | bc)
    SIGNATURE_POSITION="$((MARGIN_LEFT_RIGHT)),$(echo "$SCALE*128/1" | bc)"
    DONTCOPY_POSITION_1="$MARGIN_LEFT_RIGHT,$(echo "$SCALE*240/1" | bc)"
    DONTCOPY_POSITION_2="$MARGIN_LEFT_RIGHT,$(echo "$SCALE*265/1" | bc)"
    DONTCOPY_POSITION_3="$MARGIN_LEFT_RIGHT,$(echo "$SCALE*290/1" | bc)"
    DONTCOPY_POSITION_4="$MARGIN_LEFT_RIGHT,$(echo "$SCALE*315/1" | bc)"
fi

SAPA_LOGO_SIZE_POSITION="$((10*SAPA_LOGO_HEIGHT))x$SAPA_LOGO_HEIGHT+$MARGIN_LEFT_RIGHT+$((HEIGHT-MARGIN_TOP_BOTTOM-SAPA_LOGO_HEIGHT))"
MEMORIAV_LOGO_SIZE_POSITION="$((4*MEMORIAV_LOGO_HEIGHT))x$MEMORIAV_LOGO_HEIGHT+$MARGIN_LEFT_RIGHT+$MARGIN_TOP_BOTTOM"

# create title still
TITLE_IMAGE="$(mktemp).png"
convert -size "$VIDEO_SIZE" xc:black -fill white -font ArialUnicode -pointsize "$TEXT_SIZE" -gravity Northeast \
    -draw "text $SIGNATURE_POSITION '$SIGNATURE'" \
    -draw "text $DONTCOPY_POSITION_1 'Jegliches Kopieren ist untersagt!'" \
    -draw "text $DONTCOPY_POSITION_2 'Toute copie est interdite!" \
    -draw "text $DONTCOPY_POSITION_3 'È vietata quasiasi riproduzione!'" \
    -draw "text $DONTCOPY_POSITION_4 'Any copying is prohibited!'" \
	"$TITLE_IMAGE"
# add logos
convert "$TITLE_IMAGE" "$SAPA_LOGO" -geometry "$SAPA_LOGO_SIZE_POSITION" -composite "$TITLE_IMAGE"
if [ ! -z "$MEMORIAV" ]; then
    convert "$TITLE_IMAGE" "$MEMORIAV_LOGO" -geometry "$MEMORIAV_LOGO_SIZE_POSITION" -composite "$TITLE_IMAGE"
fi

echo "$TITLE_IMAGE"