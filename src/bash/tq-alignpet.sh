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
    if [[ "${status}" -eq 0 ]] && [[ "${cache}" = false ]]; then
        rm -f ${outdir}/${frame}[0-9][0-9][0-9][0-9].nii*
        rm -f ${outdir}/${frame}[0-9][0-9][0-9][0-9]_align.nii*
    fi
    jobs -pr | xargs -r kill 2>/dev/null || true
}

trap cleanup EXIT INT TERM

### Define functions
function display_usage() {
    echo "Usage: $0 <input> <output> [options]"
}

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

if [[ -z ${inputfile} ]] || [[ -z ${outputfile} ]]; then
    display_usage
    exit 1
fi

# Handle necessary arguments
cache=false
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --cost) COST="$2"; shift 2 ;;
        --cache) cache=true; shift 1 ;;
        --debug) shift 1 ;;
        --*) echo "Unknown option: $1"; display_usage ; exit 1 ;;
        *) echo "Unknow option: $1"; display_usage ; exit 1 ;;
    esac
done

# Define necessary variables
outdir=$(cd $(dirname ${outputfile}); pwd)    # All outputs will be saved in ${outdir}
frame=$(basename ${inputfile%.nii*}_f)    # Split frames will be saved as prefix "${frame}"

### Process
# 1. Split input images
fslsplit ${inputfile} ${outdir}/${frame}

# 2. Calculate conversion matrix from frame to reference
firstflag=true
for f in ${outdir}/${frame}[0-9][0-9][0-9][0-9].nii*; do
    # Threshold negative values in image
    fslmaths ${f} -thr 0 ${f}
    
    if ${firstflag} ; then
        cp ${f} ${f%.nii*}_align.nii.gz
        firstflag=false
    else
        flirt -dof 6 -in ${f} -ref ${outdir}/${frame}0000.nii.gz -cost ${COST} -searchcost ${COST} -omat ${f%.nii*}_align.mat -out ${f%.nii*}_align
    fi
done
wait

# 3. Merge aligned frames
fslmerge -t ${outputfile} ${outdir}/${frame}[0-9][0-9][0-9][0-9]_align.nii*
