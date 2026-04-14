#!/usr/bin/env bash

### TAME-Q tq_30_suvr_im.sh

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
        rm -f ${pet_tuned_gm} ${pet_tuned_wm}
        #rm -f ${subjectdir}/${gmtmpimg}*
        #rm -f ${subjectdir}/${wmtmpimg}*
    fi
    jobs -pr | xargs -r kill 2>/dev/null || true
}

trap cleanup EXIT INT TERM

### Define functions
function display_usage() {
    echo "Usage: $0 <subject dir> [options]"
}

function randomphrase() {
    echo $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c ${1})
}

function check_existence() {
    for f in "$@"; do
        if [[ ! -e ${f} ]]; then
            echo "Error: Unable to find ${f}" >&2
            exit 1
        fi
    done
}

TAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; cd ../.. ; pwd)

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
debug_option=""
flag_nolog=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --set) settingfile="$2"; shift 2 ;;
        --cache) cache=true ; shift 1 ;;
        --debug) debug_option="--debug"; shift 1 ;;
        --nolog) flag_nolog=true ; shift 1 ;;
        --*) echo "Unknown option: $1"; display_usage ; exit 1 ;;
        *) echo "Unknow option: $1"; display_usage ; exit 1 ;;
    esac
done

# Set variable
source ${TAMEQDIR}/config.env
source ${settingfile}

pet=${subjectdir}/pet_mean.nii.gz
pet_tuned_gm=${pet/mean/tuned_by_gm}
pet_tuned_wm=${pet/mean/tuned_by_wm}
c1mask=${subjectdir}/c1mri_mni.nii.gz
c1mask_thr=${subjectdir}/c1mri_mni_thr.nii.gz
c2mask=${subjectdir}/c2mri_mni.nii.gz
c2mask_thr=${subjectdir}/c2mri_mni_thr.nii.gz
refpolicy=${subjectdir}/reference_policy.py
check_existence ${pet} ${c1mask} ${c2mask}

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

### Gray matter
# Threshold probability mask
fslmaths ${c1mask} -thr 0.9 ${c1mask_thr}

# Erosion for c1 mask image
echo "c1mask erosion (option: ${C1_EROSION_OPTION})"
${TAMEQDIR}/src/bash/tq-erode.sh ${c1mask_thr} ${subjectdir}/mask_gm_for_hist.nii.gz ${C1_EROSION_OPTION} ${debug_option}
fslmaths ${subjectdir}/mask_gm_for_hist.nii.gz -bin ${subjectdir}/mask_gm_for_hist.nii.gz

# Tune signal intensity for curve fit
echo "Tuning signals for curve fitting"
mean_signal=$(fslstats ${pet} -k ${subjectdir}/mask_gm_for_hist.nii.gz -M)
fslmaths ${pet} -div $(echo "scale=5; ${mean_signal}/${C1_TUNED_MEAN}" | bc) ${pet_tuned_gm}
echo "Mean signal in mask_gm_for_hist.nii.gz: ${mean_signal}  --> ${C1_TUNED_MEAN} (tuned)"

# Get reference value by gray matter signals
echo -e "\nCurve fit (GM)"
refgen_curve_option=""
for i_modal in $(seq ${N_MODAL}); do
    case "${i_modal}" in
        1) i_prefix="mono" ;;
        2) i_prefix="bi" ;;
        3) i_prefix="tri" ;;
        *) i_prefix="${i_modal}" ;;
    esac

    ${TAMEQDIR}/src/bash/tq-gaussfit.sh \
                    ${pet_tuned_gm} \
                    --mask ${subjectdir}/mask_gm_for_hist.nii.gz \
                    --curves ${i_modal} \
                    --paramset ${refpolicy} \
                    --outfig ${subjectdir}/result_gm_${i_prefix}modal_fit.png \
                    --outfigsize ${OUTFIGSIZE} \
                    --outfigtype ${OUTFIGTYPE} \
                    --outtext ${subjectdir}/result_gm_${i_prefix}modal_fit.txt \
                    --outhist ${subjectdir}/target_histogram_gm.npy \
                    ${debug_option}

    refgen_curve_option="${refgen_curve_option}--curve ${subjectdir}/result_gm_${i_prefix}modal_fit.txt ${i_prefix}modal "
done


# Create reference weight image
echo -e "\nReference determination (GM) ..."
${TAMEQDIR}/src/bash/tq-refgen.sh \
                    ${pet_tuned_gm} \
                    ${subjectdir}/reference_gm.nii.gz \
                    --mask ${subjectdir}/mask_gm_for_hist.nii.gz \
                    ${refgen_curve_option} \
                    --targethist ${subjectdir}/target_histogram_gm.npy \
                    --policy ${refpolicy} \
                    ${debug_option}

# Calculate reference value
echo -e "\nReference calculation (GM) ..."
#gmtmpimg=tq-all_tmp$(randomphrase 8)
#fslmaths ${pet_tuned_gm} -mul ${subjectdir}/reference_gm.nii.gz ${subjectdir}/${gmtmpimg}
#reference_value_gm=$(fslstats ${subjectdir}/${gmtmpimg} -M)
reference_value_gm=$(${TAMEQDIR}/src/python/nifti_wmean.py ${pet_tuned_gm} ${subjectdir}/reference_gm.nii.gz)
echo "Reference value = ${reference_value_gm}"

# Devide PET image by reference value for semi-quantification
fslmaths ${pet_tuned_gm} -div ${reference_value_gm} ${pet/mean/suvr_gmref}
echo "  --> Create SUVR image (${pet/mean/suvr_gmref})"

### White Matter
# Threshold probability mask
fslmaths ${c2mask} -thr 0.9 ${c2mask_thr}

# Erosion for c2 mask image
echo "c2mask erosion (option: ${C2_EROSION_OPTION})"
${TAMEQDIR}/src/bash/tq-erode.sh ${c2mask_thr} ${subjectdir}/mask_wm_for_hist.nii.gz ${C2_EROSION_OPTION} ${debug_option}
fslmaths ${subjectdir}/mask_gm_for_hist.nii.gz -bin ${subjectdir}/mask_gm_for_hist.nii.gz

# Tune signal intensity for curve fit
echo "Tuning signals for curve fitting"
mean_signal=$(fslstats ${pet} -k ${subjectdir}/mask_wm_for_hist.nii.gz -M)
fslmaths ${pet} -div $(echo "scale=5; ${mean_signal}/${C2_TUNED_MEAN}" | bc) ${pet_tuned_wm}
echo "Mean signal in mask_wm_for_hist.nii.gz: ${mean_signal}  --> ${C2_TUNED_MEAN} (tuned)"

# Get reference value by gray matter signals
echo -e "\nCurve fit (WM)"
refgen_curve_option=""
for i_modal in $(seq ${N_MODAL}); do
    case "${i_modal}" in
        1) i_prefix="mono" ;;
        2) i_prefix="bi" ;;
        3) i_prefix="tri" ;;
        *) i_prefix="${i_modal}" ;;
    esac

    ${TAMEQDIR}/src/bash/tq-gaussfit.sh \
                    ${pet_tuned_wm} \
                    --mask ${subjectdir}/mask_wm_for_hist.nii.gz \
                    --curves ${i_modal} \
                    --paramset ${refpolicy} \
                    --outfig ${subjectdir}/result_wm_${i_prefix}modal_fit.png \
                    --outfigsize ${OUTFIGSIZE} \
                    --outfigtype ${OUTFIGTYPE} \
                    --outtext ${subjectdir}/result_wm_${i_prefix}modal_fit.txt \
                    --outhist ${subjectdir}/target_histogram_wm.npy \
                    ${debug_option}

    refgen_curve_option="${refgen_curve_option}--curve ${subjectdir}/result_wm_${i_prefix}modal_fit.txt ${i_prefix}modal "
done

# Create reference weight image
echo -e "\nReference determination (WM) ..."
${TAMEQDIR}/src/bash/tq-refgen.sh \
                    ${pet_tuned_wm} \
                    ${subjectdir}/reference_wm.nii.gz \
                    --mask ${subjectdir}/mask_wm_for_hist.nii.gz \
                    ${refgen_curve_option} \
                    --targethist ${subjectdir}/target_histogram_wm.npy \
                    --policy ${refpolicy} \
                    ${debug_option}

# Calculate reference value
echo -e "\nReference calculation (WM) ..."
#wmtmpimg=tq-all_tmp$(randomphrase 8)
#fslmaths ${pet_tuned_wm} -mul ${subjectdir}/reference_wm.nii.gz ${subjectdir}/${wmtmpimg}
#reference_value_wm=$(fslstats ${subjectdir}/${wmtmpimg} -M)
reference_value_wm=$(${TAMEQDIR}/src/python/nifti_wmean.py ${pet_tuned_wm} ${subjectdir}/reference_wm.nii.gz)
echo "Reference value = ${reference_value_wm}"

# Devide PET image by reference value for semi-quantification
fslmaths ${pet_tuned_wm} -div ${reference_value_wm} ${pet/mean/suvr_wmref}
echo "  --> Create SUVR image (${pet/mean/suvr_wmref})"

exit 0

