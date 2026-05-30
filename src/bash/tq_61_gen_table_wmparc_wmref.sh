#!/usr/bin/env bash

### License:
# This script is distributed under the GNU General Public License version 3.
# See LICENSE file for details.

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
        rm ${subjectdir}/tmp_ROI-SUVR_wmparc_wmref.csv
        rm ${subjectdir}/tmp_wmparc_?000.nii.gz
        rm ${subjectdir}/tmp_pet_suvr_wmref_roi-suvr_?000
        rm ${subjectdir}/tmp_pet_suvr_wmref_roi-suvr_brainstem
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

suvr_wmref=${subjectdir}/pet_suvr_wmref.nii.gz
wmparc=${subjectdir}/wmparc.nii.gz
bsparc=${subjectdir}/bsparc.nii.gz
check_existence ${wmparc} ${bsparc}

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

# Make CSV
echo "${ID}" > ${subjectdir}/tmp_ROI-SUVR_wmparc_wmref.csv

# aseg
fslmaths ${wmparc} -uthr 999.5 ${subjectdir}/tmp_wmparc_0000.nii.gz
fslstats -K ${subjectdir}/tmp_wmparc_0000.nii.gz ${suvr_wmref} -M > ${subjectdir}/tmp_pet_suvr_wmref_roi-suvr_0000
cat ${subjectdir}/tmp_pet_suvr_wmref_roi-suvr_0000 | sed -n '7,8p;10,13p;16,18p;26p;28p;46,47p;49,54p;58p;60p;85p;251,255p' >> ${subjectdir}/tmp_ROI-SUVR_wmparc_wmref.csv

# Brainstem
fslstats -K ${bsparc} ${suvr_wmref} -M > ${subjectdir}/tmp_pet_suvr_wmref_roi-suvr_brainstem
cat ${subjectdir}/tmp_pet_suvr_wmref_roi-suvr_brainstem | sed -n '173,175p;178p' >> ${subjectdir}/tmp_ROI-SUVR_wmparc_wmref.csv

# aparc
# 1000: lt cortex; 2000: rt cotex 
# 3000: lt subcortical wm; 4000: rt subcortical wm
for num in 1000 2000 3000 4000; do
    lthr=$((num - 1))
    uthr=$((num + 999))
    fslmaths ${wmparc} -thr ${lthr}.5 -uthr ${uthr}.5 -sub ${num} ${subjectdir}/tmp_wmparc_${num}.nii.gz
    fslstats -K ${subjectdir}/tmp_wmparc_${num}.nii.gz ${suvr_wmref} -M > ${subjectdir}/tmp_pet_suvr_wmref_roi-suvr_${num}
    cat ${subjectdir}/tmp_pet_suvr_wmref_roi-suvr_${num} | sed -n '1,3p;5,35p' >> ${subjectdir}/tmp_ROI-SUVR_wmparc_wmref.csv
done

paste -d ',' ${TAMEQDIR}/lib/colheader_wmparc_bsparc.txt ${subjectdir}/tmp_ROI-SUVR_wmparc_wmref.csv > ${subjectdir}/ROI-SUVR_wmparc_wmref.csv

exit 0
