#!/bin/bash

# This script creates and optionally shows a title image.

# parameters:
# width
# height
# content

LOGO='assets/logo-sapa.png'

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -i|--info)
    INFO="$2"
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

# validate params
if [ -z "$INFO" ] || [ -z "$HEIGHT" ] || [ -z "$WIDTH" ]; then
	echo "Missing parameters. Usage: make-title.sh --info path/to/info.yml --width 1920 --height 1080"
	exit
fi

parse_yaml() {
	# source: https://gist.github.com/pkuczynski/8665367
	local prefix=$2
	local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
	sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
		-e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
	awk -F$fs '{
		indent = length($1)/2;
		vname[indent] = $2;
		for (i in vname) {if (i > indent) {delete vname[i]}}
		if (length($3) > 0) {
			vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
			printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
		}
	}'
}

# read and parse info yaml
eval $(parse_yaml "$INFO" "INFO_")

# echo "Author:     $INFO_Author"
# echo "Title:      $INFO_Title"
# echo "Date:       $INFO_Date"
# echo "Signature:  $INFO_Signature"

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
DATE_POSITION="$MARGIN_LEFT,850"
DATE_POSITION="$MARGIN_LEFT,$(echo "$SCALE*($REF_HEIGHT-150-$LINE_HEIGHT)/1" | bc)"
AUTHOR_POSITION="$MARGIN_LEFT,690"
AUTHOR_POSITION="$MARGIN_LEFT,$(echo "$SCALE*($REF_HEIGHT-150-(2*$LINE_HEIGHT))/1" | bc)"
TITLE_POSITION="$MARGIN_LEFT,770"
TITLE_POSITION="$MARGIN_LEFT,$(echo "$SCALE*($REF_HEIGHT-150-(3*$LINE_HEIGHT))/1" | bc)"

# create title still
TITLE_IMAGE="$(mktemp).png"
convert -size "$VIDEO_SIZE" xc:white -fill black -font ArialUnicode -pointsize "$TEXT_SIZE" \
	-draw "text $AUTHOR_POSITION '$INFO_Author'" \
	-draw "text $TITLE_POSITION '$INFO_Title'" \
	-draw "text $DATE_POSITION '$INFO_Date'" \
	-draw "text $SIGNATURE_POSITION '$INFO_Signature'" \
	"$TITLE_IMAGE"
# add logo
convert "$TITLE_IMAGE" "$LOGO" -geometry "$LOGO_SIZE_POSITION" -composite "$TITLE_IMAGE"

# open "$TITLE_IMAGE"

# print image file path
echo "$TITLE_IMAGE"
