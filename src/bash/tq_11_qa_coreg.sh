#!/usr/bin/env bash
# 8 Mar 2026 K.Nakayama and K.Nemoto

### TAME-Q tq_11_qa_coreg.sh

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
debug_option=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --ref) ref="$2"; shift 2 ;;
        --set) settingfile="$2"; shift 2 ;;
        --cache) cache=true ; shift 1 ;;
        --debug) debug_option="--debug"; shift 1 ;;
        --*) echo "Unknown option: $1"; display_usage ; exit 1 ;;
        *) echo "Unknow option: $1"; display_usage ; exit 1 ;;
    esac
done

source ${settingfile}

id=${TQID}
inmri=${subjectdir}/mri.nii.gz
inpet=${subjectdir}/pet.nii.gz

QCT1W=${subjectdir}/coregistration_results_t1w.csv
QCPET=${subjectdir}/coregistration_results_pet.csv

### Process
# 1. Evaluation of T1 coregistration
echo "Evaluation of T1 coregistration"
DICE_T1W=$(${TAMEQDIR}/src/bash/tq-dice.sh ${subjectdir}/$(basename ${inmri%.nii*}_mni_brainmask.nii.gz) ${FSLDIR}/data/standard/MNI152_T1_1mm_brain_mask.nii.gz | awk -F ': ' '{print $2}')
R_T1W=$(avscale --allparams ${subjectdir}/$(basename ${inmri%.nii*}2MNI.mat) | grep 'Rotation Angles' | awk -F '= ' '{print $2}' | sed 's/ /,/g')
echo "ID,Rx,Ry,Rz,Dice" > ${QCT1W}
echo "${id},${R_T1W%,},${DICE_T1W}" >> ${QCT1W}

# 2. Evaluation of PET coregistration
echo "Evaluation of PET coregistration"
Rf=""
fn_inpet=$(basename ${inpet})
for t_align in $(find ${subjectdir} -maxdepth 1 -name "${fn_inpet%.nii*}_f*_align.mat"); do
    Rf="${Rf} $(avscale --allparams ${t_align} | grep 'Rotation Angles' | awk -F '= ' '{print $2}' | sed 's/-//g')"
done

if [[ -n "$Rf" ]]; then
  Rmaxf=$(for v in $Rf; do echo $v; done | sort -nr | head -n1)
else
  Rmaxf="NaN"
fi

while [[ "$(pgrep -l -f mri_synthstrip -c)" -ge ${MAX_SYNTHSTRIP} ]]; do sleep 10s ; done
mri_synthstrip -i ${subjectdir}/$(basename ${inpet%.nii*}_mean.nii.gz) -m ${subjectdir}/$(basename ${inpet%.nii*}_mean_brainmask.nii.gz) > /dev/null

DICE_PET=$(${TAMEQDIR}/src/bash/tq-dice.sh ${subjectdir}/$(basename ${inmri%.nii*}_mni_brainmask.nii.gz) ${subjectdir}/$(basename ${inpet%.nii*}_mean_brainmask.nii.gz) | awk -F ': ' '{print $2}')
R_PET=$(avscale --allparams ${subjectdir}/$(basename ${inpet%.nii*}_align_mean2MRI.mat) | grep 'Rotation Angles' | awk -F '= ' '{print $2}' | sed 's/ /,/g' | sed 's/-//g')
echo "ID,Rmax_frame,Rx_mean,Ry_mean,Rz_mean,Dice" > ${QCPET}
echo "${id},${Rmaxf},${R_PET%,},${DICE_PET}" >> ${QCPET}

exit 0

