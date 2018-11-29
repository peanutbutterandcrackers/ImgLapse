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
#		- or have a command supplied to the script from stdout, or files or whatevs
# if -s is not specified, don't use it
# if -crf is not specified, let it be 18
# 2 major running modes: 1. -test 2. -final
#	1. -test:
#		use hd480 (or lower) size and -crf 29, for speedy render
#	2. -final:
#		if size is specified, use it; else, export as-is
#		-crf 18 (for sanest, yet the best render)
###########

# TO-DO: Make sure user specification over-ride presets

PROGNAME="${0##*/}"

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
PRESETS=(TEST FINAL)

CRF=''
FPS=''
RESOLUTION=''
INPUT_PATTERN=''

apply_preset () {
	# takes the preset name
	# runs through all the parameters defined in the preset
	# for each key in the preset associative array, creates
	# or modifies a global variable (in this script) of the
	# same name with the same value of the key

	local PRESET="${1^^}"
	local PARAMS_DEFINED # Parameters defined in PRESET
	eval PARAMS_DEFINED=\$\{\!PRESET\[\@\]\}

	for param in $PARAMS_DEFINED; do
		eval $param=\$\{$PRESET\[$param\]\}
	done
}

usage () {
	# if more than one preset has been applied, only applies the first one
	# ignores all the rest
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
	case "$1" in
		# if the argument is a preset, ignore it
		# applied already
		-h | --help) usage
		             exit
			     ;;
		-crf)	shift
			CRF="$1"
			;;
		-fps)	shift
			FPS="$1"
			;;
		-res)	shift
			RESOLUTION="$1"
			;;
		-i)	shift
			read INPUT_PATTERN < <(echo "$1") # To prevent wildcard-expansion
			;;
		*)	usage >&2 exit 1 ;;
	esac
	shift
done
