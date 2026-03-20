#!/usr/bin/env bash
# 8 Mar 2026 K.Nakayama and K.Nemoto

set -euo pipefail
for arg in "$@"; do
    if [[ "${arg}" = "--debug" ]]; then
        set -x
    fi
done

cleanup() {
    status=$?
    if [[ "${status}" -eq 1 ]]; then
        rm -f ${tmpimg}
    fi
    jobs -pr | xargs -r kill 2>/dev/null || true
}

trap cleanup EXIT INT TERM

### Define functions
function display_usage() {
    echo "Usage: $0 <mask> <output> [--x Lx] [--y Ly] [--z Lz] [--cube E]"
}

function randomphrase() {
    echo $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c ${1})
}

function erode_xaxis() {
    fslmaths ${inputfile} -bin -kernel boxv3 ${1} 1 1 -ero -mul ${tmpimg} ${tmpimg}
}

function erode_yaxis() {
    fslmaths ${inputfile} -bin -kernel boxv3 1 ${1} 1 -ero -mul ${tmpimg} ${tmpimg}
}

function erode_zaxis() {
    fslmaths ${inputfile} -bin -kernel boxv3 1 1 ${1} -ero -mul ${tmpimg} ${tmpimg}
}

function erode_cube() {
    fslmaths ${inputfile} -bin -kernel boxv3 ${1} ${1} ${1} -ero -mul ${tmpimg} ${tmpimg}
}

### DEFAULT VALUE SETTING

### Read command line arguments
# Check the number of command line arguments
if [[ "$#" -lt 2 ]]; then
    display_usage
    exit 1
fi

# Handle necessary arguments
inputfile="$1"
outputfile="$2"
shift 2

# Prepare temporary file for overwrite
tmpimg=tq-erode_tmp$(randomphrase 8).nii
if [[ "${inputfile: -3}" = ".gz" ]]; then
    tmpimg=${tmpimg}.gz
fi

cp ${inputfile} ${tmpimg}

# Read and Process command line arguments
while [ "$#" -gt 0 ]; do
    case "$1" in
        --x) Lx="$2"; erode_xaxis ${Lx} ; shift 2 ;;
        --y) Ly="$2"; erode_yaxis ${Ly} ; shift 2 ;;
        --z) Lz="$2"; erode_zaxis ${Lz} ; shift 2 ;;
        --cube) E="$2"; erode_cube ${E} ; shift 2 ;;
        --debug) shift 1 ;;
        --*) echo "Unknown option: $1"; display_usage ; exit 1 ;;
        *) echo "Unknow option: $1"; display_usage ; exit 1 ;;
    esac
done

mv ${tmpimg} ${outputfile}
exit 0