#!/usr/bin/env bash

### TAME-Q tq_53_get_cbref.sh
# 8 Mar 2026 K.Nakayama and K.Nemoto

# For Debug
set -euo pipefail
for arg in "$@"; do
    if [[ "${arg}" = "--debug" ]]; then
        set -x
    fi
done

cleanup() {
    status=$?
    if [[ "${status}" -eq 0 ]] && [[ "${cache}" = false ]]; then
        rm ${subjectdir}/tmp_wmparc_8.nii.gz ${subjectdir}/tmp_wmparc_47.nii.gz
    fi
    jobs -pr | xargs -r kill 2>/dev/null || true
}

trap cleanup EXIT INT TERM

### Define functions
function display_usage() {
    echo "Usage: $0 <subject dir>"
}

function check_existence() {
    for f in "$@"; do
        if [[ ! -e ${f} ]]; then
            echo "Error: Unable to find ${f}" >&2
            exit 1
        fi
    done
}

### Read command line arguments
# Check the number of command line arguments
if [[ "$#" -lt 1 ]]; then
    display_usage
    exit 1
fi
subjectdir="$1"
shift 1

# Handle necessary arguments
settingfile=${subjectdir}/tq-all-setting.env
cache=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --set) settingfile="$2"; shift 2 ;;
        --cache) cache=true ; shift 1 ;;
        --debug) shift 1 ;;
        --*) echo "Unknown option: $1"; display_usage ; exit 1 ;;
        *) echo "Unknow option: $1"; display_usage ; exit 1 ;;
    esac
done

# Set variable
TAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; cd ../.. ; pwd)
source ${TAMEQDIR}/config.env
source ${settingfile}
ID=${TQID}

check_existence ${subjectdir}/wmparc.nii.gz
wmparc=${subjectdir}/wmparc.nii.gz

### Process
# Create cerebellum-reference mask
# Left-Cerebellum-Cortex: 8, Right-Cerebellum-Cortex: 47 in FreeSurferColorLUT.txt
fslmaths ${wmparc} -thr 7.5 -uthr 8.5 -bin ${subjectdir}/tmp_wmparc_8.nii.gz
fslmaths ${wmparc} -thr 46.5 -uthr 47.5 -bin ${subjectdir}/tmp_wmparc_47.nii.gz
fslmaths ${subjectdir}/tmp_wmparc_8.nii.gz -add ${subjectdir}/tmp_wmparc_47.nii.gz ${subjectdir}/cbmask.nii.gz

# Semi-quantification by cerebellum reference
refval=$(fslstats -K ${subjectdir}/cbmask.nii.gz ${subjectdir}/pet_mean.nii.gz -m)
fslmaths ${subjectdir}/pet_mean.nii.gz -div ${refval} ${subjectdir}/pet_suvr_cbref.nii.gz

exit 0
