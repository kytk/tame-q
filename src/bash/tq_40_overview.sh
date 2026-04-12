#!/usr/bin/env bash

# Generate a lightbox view of PMPBB3 superimposed on T1w images
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
        rm ${tmpmat}
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
ref=${FSLDIR}/data/standard/MNI152_T1_1mm.nii.gz

ID=${TQID}
mri_mni=${subjectdir}/mri_mni.nii.gz
mri_view=${subjectdir}/mri_view.nii.gz
pet_mni_gm=${subjectdir}/pet_suvr_gm.nii.gz
pet_view_gm=${subjectdir}/pet_suvr_gm_view.nii.gz
pet_mni_wm=${subjectdir}/pet_suvr_wm.nii.gz
pet_view_wm=${subjectdir}/pet_suvr_wm_view.nii.gz

tmpmat=${subjectdir}/mni_to_view.mat

check_existence ${mri_mni} ${pet_mni_gm} ${pet_mni_wm}

### Process
flirt -dof 9 -in ${mri_mni} -ref ${ref} -omat ${tmpmat} -out ${mri_view}
flirt -dof 9 -in ${pet_mni_gm} -ref ${ref} -applyxfm -init ${tmpmat} -out ${pet_view_gm}
flirt -dof 9 -in ${pet_mni_wm} -ref ${ref} -applyxfm -init ${tmpmat} -out ${pet_view_wm}

echo "Overlay SUVR image onto T1w image"
python ${TAMEQDIR}/src/python/overlay_view_axi.py ${ID} ${mri_view} ${pet_view_gm} ${OVERVIEW_THR} ${OVERVIEW_UTHR} ${subjectdir}/overview_mri_axial.png ${subjectdir}/overview_pet_gmref_axial.png
python ${TAMEQDIR}/src/python/overlay_view_cor.py ${ID} ${mri_view} ${pet_view_gm} ${OVERVIEW_THR} ${OVERVIEW_UTHR} ${subjectdir}/overview_mri_coronal.png ${subjectdir}/overview_pet_gmref_coronal.png

python ${TAMEQDIR}/src/python/overlay_view_axi.py ${ID} ${mri_view} ${pet_view_wm} ${OVERVIEW_THR} ${OVERVIEW_UTHR} ${subjectdir}/overview_mri_axial.png ${subjectdir}/overview_pet_wmref_axial.png
python ${TAMEQDIR}/src/python/overlay_view_cor.py ${ID} ${mri_view} ${pet_view_wm} ${OVERVIEW_THR} ${OVERVIEW_UTHR} ${subjectdir}/overview_mri_coronal.png ${subjectdir}/overview_pet_wmref_coronal.png

exit

