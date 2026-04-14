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
flag_nolog=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --set) settingfile="$2"; shift 2 ;;
        --cache) cache=true ; shift 1 ;;
        --debug) shift 1 ;;
        --nolog) flag_nolog=true ; shift 1 ;;
        --*) echo "Unknown option: $1"; display_usage ; exit 1 ;;
        *) echo "Unknow option: $1"; display_usage ; exit 1 ;;
    esac
done

# Set variable
TAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; cd ../.. ; pwd)
source ${TAMEQDIR}/config.env
source ${settingfile}
ID=${TQID}

export SUBJECTS_DIR=${subjectdir}/freesurfer
mkdir -p ${SUBJECTS_DIR}

check_existence ${subjectdir}/mri_mni.nii.gz

if [[ ${flag_nolog} = "false" ]]; then
    logfile=${subjectdir}/tq-all.log
    exec 3>&1
    exec > >(
    tee >(awk -v lf="${logfile}" '{
            print strftime("[%F %T]"), $0 >> lf
            fflush(lf)
        }') >&3
    ) 2>&1

    echo -e "\n$0 starts."
fi

### Process
if [[ $(find ${subjectdir}/freesurfer/${ID}/mri -name "brainstemSsLabels.v??.FSvoxelSpace.mgz" | wc -l) -lt 1 ]]; then
    while [[ "$(pgrep -x segmentBS.sh -c)" -ge ${MAX_SEGMENTBS} ]]; do sleep 10s ; done
    segmentBS.sh ${ID} ${SUBJECTS_DIR} > /dev/null &
    echo "Run > segmentBS.sh ${ID} ${SUBJECTS_DIR}"
    wait
fi

exit 0

