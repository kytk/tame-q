#!/usr/bin/env bash
# 8 Mar 2026 K.Nakayama and K.Nemoto

### TAME-Q tq_10_realign.sh

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
        rm -f ${subjectdir}/$(basename ${inpet%.nii*})_f[0-9][0-9][0-9][0-9]_align.nii.gz
        rm -f ${subjectdir}/$(basename ${inmri%.nii*})_brain.nii.gz ${subjectdir}/$(basename ${inmri%.nii*})_brainmask.nii.gz
        rm -f ${subjectdir}/$(basename ${inmri%.nii*})_mni_brainedge.nii.gz
        rm -f ${subjectdir}/$(basename ${inpet%.nii*})_mean_brainmask.nii.gz
        rm -f ${subjectdir}/tmp_normmi_pet_align_mean2MRI.mat
        rm -f ${subjectdir}/tmp_normmi_pet_mean.nii.gz
        rm -f ${subjectdir}/tmp_mutualinfo_pet_align_mean2MRI.mat
        rm -f ${subjectdir}/tmp_mutualinfo_pet_mean.nii.gz
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
flag_nolog=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --ref) ref="$2"; shift 2 ;;
        --set) settingfile="$2"; shift 2 ;;
        --cache) cache=true ; shift 1 ;;
        --debug) debug_option="--debug"; shift 1 ;;
        --nolog) flag_nolog=true ; shift 1 ;;
        --*) echo "Unknown option: $1"; display_usage ; exit 1 ;;
        *) echo "Unknow option: $1"; display_usage ; exit 1 ;;
    esac
done

source ${settingfile}

id=${TQID}
inmri=${subjectdir}/mri.nii.gz
inpet=${subjectdir}/pet.nii.gz

if [[ -z "${inmri}" ]] || [[ -z "${inpet}" ]]; then
    display_usage
    exit 1
fi

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
# 1. Coregistration of MR and PET images with MNI standard image
echo "Coregistration of MR and PET images with MNI standard image"
${TAMEQDIR}/src/bash/tq-reg.sh \
                            --inmri ${inmri} \
                            --inpet ${inpet} \
                            --ref ${ref} \
                            --outmri $(basename ${inmri%.nii*}_mni.nii.gz) \
                            --outpet $(basename ${inpet%.nii*}_mean.nii.gz) \
                            --outdir ${subjectdir} \
                            --max_synthstrip ${MAX_SYNTHSTRIP} \
                            --cost1 ${COST1} \
                            --cost2 ${COST2} \
                            --cost3 ${COST3} \
                            --cache \
                            ${debug_option}


exit 0
