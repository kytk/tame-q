#!/usr/bin/env bash

### Objectives:
# This script performs cortical parcellation on T1-weighted images using FreeSurfer.

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
    if [[ "${status}" -eq 0 ]]; then
        :
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

# Set variable
TAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; cd ../.. ; pwd)
source ${TAMEQDIR}/config.env

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

source ${settingfile}
ID=${TQID}
export SUBJECTS_DIR=${subjectdir}/freesurfer
mkdir -p ${SUBJECTS_DIR}

check_existence ${subjectdir}/mri_mni.nii.gz

### Process
if [[ ! -e ${subjectdir}/freesurfer/${ID}/mri/wmparc.mgz ]]; then
    recon-all -i ${subjectdir}/mri_mni.nii.gz -s ${ID} -all -qcache > /dev/null &
    echo "RUN > recon-all -i ${subjectdir}/mri_mni.nii.gz -s ${ID} -all -qcache"
fi
wait

exit 0


