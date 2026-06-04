#!/usr/bin/env bash

### TAME-Q tq_52_merge_wmparc.sh
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
        rm -f ${subjectdir}/wmparc_brainstem.nii.gz
        rm -f ${subjectdir}/wmparc_merged_wobrainstem.nii.gz
        rm -f ${subjectdir}/bsparc_in_wmparc.nii.gz
    fi
    jobs -pr | xargs -r kill 2>/dev/null || true
}

trap cleanup EXIT INT TERM

### Define functions
function display_usage() {
    echo "Usage: $0 <subject dir> [options]"
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
debug=false
flag_nolog=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --set) settingfile="$2"; shift 2 ;;
        --cache) cache=true ; shift 1 ;;
        --debug) debug=true ; shift 1 ;;
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

check_existence ${subjectdir}/freesurfer/${ID}/mri/wmparc.mgz

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
# Copy wmparc
mri_vol2vol \
    --mov ${subjectdir}/freesurfer/${ID}/mri/wmparc.mgz \
    --targ ${subjectdir}/mri_mni.nii.gz \
    --o ${subjectdir}/wmparc.nii.gz \
    --regheader \
    --no-save-reg \
    --interp nearest

# Copy brainstem atlas
if [[ "$(find ${subjectdir}/freesurfer/${ID}/mri -name "brainstemSsLabels.v??.FSvoxelSpace.mgz" | wc -l)" != 1 ]]; then
    echo "Error: ${ID} has irregular number of brainstem segmentation results"
    exit 1
fi

brainstemparc=$(find ${subjectdir}/freesurfer/${ID}/mri -name "brainstemSsLabels.v??.FSvoxelSpace.mgz")
mri_vol2vol \
    --mov  ${brainstemparc} \
    --targ ${subjectdir}/mri_mni.nii.gz \
    --o ${subjectdir}/bsparc.nii.gz \
    --regheader \
    --no-save-reg \
    --interp nearest 

${TAMEQDIR}/src/bash/tq-atlas.sh ${subjectdir}/wmparc.nii.gz ${subjectdir}/bsparc.nii.gz ${subjectdir}/wmparc_merged.nii.gz

exit 0
