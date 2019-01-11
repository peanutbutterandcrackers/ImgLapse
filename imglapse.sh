#!/bin/bash

# A wrapper around ffmpeg to turn a directory of photos into video (timelapse/stopmotion)
# Author: github.com/peanutbutterandcrackers License: GPL-V3

##########
# ffmpeg -framerate 30 -pattern_type glob -i '*.JPG' -s hd1080 -c:v libx264 -crf 18 30fps_1080p_CRF18.mkv
# ffmpeg -framerate $fps -pattern_type glob -i $input_glob -s hd480 -vcodec libx264 -crf 28 adsf.mkv
# Usage: ilapse -fps 30 -test '*.img' -s hd480 -crf 29
#        ilapse -fps 30 -final '*.png'
# A. Perform sanity checks on the input image glob
# B. Perhaps an interactive mode that lists what images are going to be selected?
#	-custom : let the user specify the ffmpeg command to execute
#		- have var CUSTOM_COMMAND in the script for the user to edit
#		- or have a command supplied to the script from stdin, or files or whatevs
# if -s is not specified, don't use it
# if -crf is not specified, let it be 18
# 
# * Perhaps don't ignore multiple presets. Some presets might be regarding the codecs and all and it would
#   be nice to have something like '-test -fwebp' to test the output in webp format
#---------------------------
# set -o noglob
# 2 major running modes: 1. -test 2. -final
#	1. -test:
#		use hd480 (or lower) size and -crf 29, for speedy render
#	2. -final:
#		if size is specified, use it; else, export as-is
#		-crf 18 (for sanest, yet the best render)
###########


SCRIPT_NAME="${0##*/}"

### PRESETS:
# Presets are just associative arrays with pre-defined parameters
# apply_reset() will apply said preset
# The keys in the preset MUST BE the global variables in THIS SCRIPT
# The preset MUST BE 'registered' in the array PRESETS [see check_for_presets()]
# All presets must be defined before (above) the PRESETS array
# or else things won't work [see apply_preset() definition for more info]
# The associated command line argument for preset FOO is expected to be -foo
declare -A TEST=([RESOLUTION]=hd480 [CRF]=29)
declare -A FINAL=([RESOLUTION]=hd1080 [CRF]=18)
declare -A ORIGINAL=([RESOLUTION]=original [CRF]=18)
PRESETS=(TEST FINAL ORIGINAL)

apply_preset () {
	# takes the preset name
	# runs through all the parameters defined in the preset
	# for each key in the preset associative array, creates
	# or modifies a global variable (in this script) of the
	# same name with the same value of the key

	local PRESET="${1^^}"
	local PARAMS_DEFINED # Parameters defined in PRESET
	PARAMS_DEFINED=$(eval echo \$\{\!$PRESET\[\@\]\})
	for param in $PARAMS_DEFINED; do
		eval $param=\$\{$PRESET\[$param\]\}
	done
}

usage () {
	cat <<- _EOF_
	Usage: $SCRIPT_NAME -i 'PATTERN' [PRESETS] [OPTIONS]

	-i 'PATTERN'
	    Set input pattern to 'PATTERN'. PATTERN must be put inside single
	    quotes so as to prevent shell expansions. PATTERN will be interp-
	    reted by ffmpeg itself.
	
	-o DIR
	    Set DIR as the output location of the rendered video
	    (By default, the final video is rendered to the directory containing
	     the images being processed.)

	-crf N
	    Set the Constant Rate Factor to N
	    Valid CRF values are from 0 to 51. 51 is the worst, 0 is lossless.
	    18-27 is the sane value range. (Defaults to 18, if unspecified.)

	-res RESOLUTION
	    Set the output file resolution to RESOLUTION.
	    RESOLUTION should be in the form WxH where:
	        W = Width and H = Height
	    Standared ffmpeg size presets are also accepted. Some of these are:
	    hd480, hd720, hd1080
	    There is also a custom resolution 'original' which will set the output
	    resolution to be the same as the input resolution.
	    If unspecified, defaults to hd1080 

	-r, --reverse
	    Reverse the input stream (essentially gives a reversed video)

	-ifr N, --input-frame-rate N
	    Set frame-rate of the input stream to N

	-ofr N, --output-frame-rate N
	    Set the frame-rate of the output stream to N (Defaults to input frame rate)

	-h, --help
	    Display this help and exit
	
	PRESETS
	    PRESETS predefine the parameters of the script. Currently, two pre-
	    sets are available:
	    -test  : -s hd480 -crf 29
	    -final : -s hd1080 -crf 18
	    -original : -s original -crf 18

	    If more than one preset is specified, only applies the first one and
	    ignores the rest. Manual parameter setting over-rides the parameters
	    set by the presets. For eg: '-test -crf 27' changes the -crf to 27
	    despite the preset setting it to 29.

	    New preset definitions can be added in the script under the PRESETS
	    section as an associative array with keys corresponding to the global
	    variables used in the main ffmpeg call that the preset is meant to
	    change. All presets must be registered in the PRESETS array. A preset
	    named 'FOO' is called using the switch '-foo'.

	_EOF_

	return
}

check_for_presets () {
	# check all command-line arguments for any known presets
	# must be passed ALL of the command line arguments i.e. "$*"
	# only presets registered in PRESETS are known
	for preset in "${PRESETS[@]}"; do
 		# if the command line version (-foo) of preset (FOO) is in the
		# argument list, apply the preset and exit the function
		if [[ "$*" =~ \-${preset,,} ]]; then
			apply_preset $preset
			return
		fi
	done
}


# Start of actual execution
check_for_presets "$*" # First, check for, and apply, presets

while [[ -n "$1" ]]; do
	# if the argument is a preset, ignore it, as presets have already been applied
	if [[ $(echo ${PRESETS[@]} | sed 's/\([[:alpha:]]*\)/\L-\1/g' | sed 's/ / | /g ') =~ "$1" ]]; then
		shift
	fi

	case "$1" in
		-h | --help) usage | less
		             exit
			     ;;
		-crf)	shift
			CRF="$1"
			;;
		-r | --reverse)		REVERSE=TRUE
					;;
		-ifr | --input-frame-rate)	shift
						IFR="$1"
						;;
		-ofr | --output-frame-rate)	shift
						OFR="$1"
						;;
		-res)	shift
			RESOLUTION="$1"
			;;
		-i)	shift
			read INPUT_PATTERN < <(basename "$1") # To prevent wildcard-expansion
			read INPUT_LOCATION < <(dirname "$1") # If the user has specified a directory
			;;
		-o)	shift
			OUTPUT_LOCATION=$(realpath "$1")
			[[ -d "$OUTPUT_LOCATION" ]] || {
				echo "The specified output directory '$OUTPUT_LOCATION' does not exist." >&2
				exit 1
				}
			;;
		*)	echo "The argument '$1' was not understood." >&2
			echo "Please run $SCRIPT_NAME with '--help' switch for usage information." >&2
			exit 1
			;;
	esac
	shift
done

# Set Defaults
CRF=${CRF:-18} # If the CRF has not been set, set it to 18
RESOLUTION=${RESOLUTION:-"hd1080"} # If the resolution has not been set, set it to hd1080
OFR=${OFR:-$IFR} # If the output frame-rate isn't specified, make it the same as input frame-rate
OUTPUT_LOCATION="${OUTPUT_LOCATION:-$INPUT_LOCATION}" # If output location isn't specified, set it to input location

# Output name and location
OUTPUT_NAME=${IFR}_${OFR}FPS_${RESOLUTION}_CRF${CRF}${REVERSE:+"-REVERSE"}.mkv # Naming Scheme: x_yFPS_z_CRFn.mkv | x_yFPS_z_CRFn-REVERSE.mkv
OUTPUT="$OUTPUT_LOCATION/$OUTPUT_NAME"

# Apply Final Filters
RES_SLICE="-s $RESOLUTION" # The ffmpeg command slice dealing with the output resolution
if [[ $RESOLUTION == 'original' ]]; then
	RES_SLICE='' # This will cause ffmpeg to set the output resolution to the input resolution
fi

# Main Execution
cd "$INPUT_LOCATION"
eval cat \$\(ls ${REVERSE:+"-r"} $INPUT_PATTERN\) | ffmpeg -f image2pipe -framerate $IFR -i - -r ${OFR} $RES_SLICE -c:v libx264 -crf $CRF "$OUTPUT"

# Notify user about success or failure
if [[ "$?" == 0 ]]; then
	echo -e "\nFile '$OUTPUT_NAME' has been saved to '$OUTPUT_LOCATION'."
else
	echo -n # Don't output anything. ffmpeg will give the error messages.
fi
