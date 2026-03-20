#!/usr/bin/env bash
# 8 Mar 2026 K.Nakayama and K.Nemoto

### TAME-Q tq_12_qa_report.sh

### License:
# This script is distributed under the GNU General Public License version 3.
# See LICENSE file for details.

set -euo pipefail
for arg in "$@"; do
    if [[ "${arg}" = "--debug" ]]; then
        set -x
    fi
done

cleanup() {
    status=$?
    if [[ "${status}" -eq 0 ]] && [[ "${cache}" = false ]]; then
        rm -f ${subjectdir}/$(basename ${inpet%.nii*}_align_mean.nii.gz)
        rm -f ${subjectdir}/$(basename ${inpet%.nii*})_f[0-9][0-9][0-9][0-9].nii.gz
        rm -f ${subjectdir}/$(basename ${inpet%.nii*})_f[0-9][0-9][0-9][0-9]_align.nii.gz
        rm -f ${subjectdir}/$(basename ${inmri%.nii*})_brain.nii.gz ${subjectdir}/$(basename ${inmri%.nii*})_brainmask.nii.gz
        rm -f ${subjectdir}/$(basename ${inmri%.nii*})_mni_brainedge.nii.gz ${subjectdir}/$(basename ${inpet%.nii*})_brainedge4qa.nii.gz
        rm -f ${subjectdir}/$(basename ${inpet%.nii*})_mean_brainmask.nii.gz ${subjectdir}/$(basename ${inpet%.nii*})_mean_brainedge.nii.gz
    fi
    jobs -pr | xargs -r kill 2>/dev/null || true
}

trap cleanup EXIT INT TERM

### Define functions
function display_usage() {
    echo "Usage: $0 <subjectdir> [options]"
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
ref=${FSLDIR}/data/standard/MNI152_T1_1mm_brain.nii.gz
settingfile=${subjectdir}/tq-all-setting.env
cache=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --ref) ref="$2"; shift 2 ;;
        --set) settingfile="$2"; shift 2 ;;
        --cache) cache=true ; shift 1 ;;
        --debug) shift 1 ;;
        --*) echo "Unknown option: $1"; display_usage ; exit 1 ;;
        *) echo "Unknow option: $1"; display_usage ; exit 1 ;;
    esac
done

source ${settingfile}

id=${TQID}
inmri=${subjectdir}/mri.nii.gz
inpet=${subjectdir}/pet.nii.gz

if [[ -z "${inmri}" ]] || [[ -z "${inpet}" ]] || [[ -z "${id}" ]]; then
    display_usage
    exit 1
fi

### Process
# Create QA Report
echo "Create QA Report"
fslmaths ${subjectdir}/$(basename ${inmri%.nii*}_mni_brainmask.nii.gz) \
    -edge -bin ${subjectdir}/$(basename ${inmri%.nii*}_mni_brainedge.nii.gz)

fslmaths ${subjectdir}/$(basename ${inpet%.nii*}_mean_brainmask.nii.gz) \
    -edge -bin ${subjectdir}/$(basename ${inpet%.nii*}_mean_brainedge.nii.gz)

convert_xfm -omat ${subjectdir}/$(basename ${inpet%.nii*}_MNI2PET.mat) \
    -inverse ${subjectdir}/$(basename ${inpet%.nii*}_align_mean2MRI.mat)

flirt -dof 6 \
    -in ${subjectdir}/$(basename ${inmri%.nii*}_mni_brainedge.nii.gz) \
    -ref ${subjectdir}/$(basename ${inpet%.nii*}_align_mean.nii.gz) \
    -interp nearestneighbour \
    -applyxfm -init ${subjectdir}/$(basename ${inpet%.nii*}_MNI2PET.mat) \
    -out ${subjectdir}/$(basename ${inpet%.nii*}_brainedge4qa.nii.gz)

${TAMEQDIR}/src/python/qa_view.py ${id} \
                                ${subjectdir}/$(basename ${inmri%.nii*}_mni.nii.gz) \
                                ${subjectdir}/$(basename ${inpet%.nii*}_mean.nii.gz) \
                                ${subjectdir}/$(basename ${inpet%.nii*}_align.nii.gz) \
                                ${subjectdir}/$(basename ${inpet%.nii*}_f0000.nii.gz) \
                                ${subjectdir}/$(basename ${inmri%.nii*}_mni_brainedge.nii.gz) \
                                ${subjectdir}/$(basename ${inpet%.nii*}_brainedge4qa.nii.gz) \
                                ${subjectdir}

exit 0

