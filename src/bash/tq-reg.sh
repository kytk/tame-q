#!/usr/bin/env bash
# 8 Mar 2026 K.Nakayama and K.Nemoto

set -euo pipefail
for arg in "$@"; do
    if [[ "${arg}" = "--debug" ]]; then
        set -x
    fi
done

cleanup() {
    status=$?
    if [[ "${status}" -eq 0 ]] && [[ "${cache}" = false ]]; then
        rm -f ${inpet%.nii*}_align_mean.nii.gz
        rm -f ${outdir}/tmp_normmi_$(basename ${inpet%.nii*}_align_mean2MRI.mat)
        rm -f ${outdir}/tmp_normmi_${outpet}
        rm -f ${outdir}/tmp_mutualinfo_$(basename ${inpet%.nii*}_align_mean2MRI.mat)
        rm -f ${outdir}/tmp_mutualinfo_${outpet}
    fi
    jobs -pr | xargs -r kill 2>/dev/null || true
}

trap cleanup EXIT INT TERM

### Define functions
function display_usage() {
    echo "Usage: $0 <--inmri MRI> <--inpet PET> <--outmri filename> <--outpet filename> [options]"
}

calc_nonzero () {
    voxel_fov=$(fslstats $1 -v | awk '{print $1}')
    voxel_head=$(fslstats $1 -V | awk '{print $1}')
    echo "${voxel_head} / ${voxel_fov}" | bc -l
}

### DEFAULT VALUE SETTING
REFIMG=${FSLDIR}/data/standard/MNI152_T1_1mm_brain.nii.gz
WARNINGTHR=0.2

### Read command line arguments
# Check the number of command line arguments
if [[ "$#" -lt 2 ]]; then
    display_usage
    exit 1
fi

# Set variable
TAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; cd ../.. ; pwd)
source ${TAMEQDIR}/config.env
SCRIPTDIR=$(cd $(dirname $0); pwd)

# Handle necessary arguments
inmri=""
inpet=""
outmri=""
outpet=""
cache=false
cacheoption=""
debug_option=""
refimg=${REFIMG}
MAX_SYNTHSTRIP=9999
COST1=corratio
COST2=normmi
COST3=normmi
outdir=$(pwd)
while [ "$#" -gt 0 ]; do
    case "$1" in
        --inmri) inmri="$2"; shift 2 ;;
        --inpet) inpet="$2"; shift 2 ;;
        --outmri) outmri="$2"; shift 2 ;;
        --outpet) outpet="$2"; shift 2 ;;
        --ref) refimg="$2"; shift 2 ;;
        --max_synthstrip) MAX_SYNTHSTRIP="$2"; shift 2 ;;
        --cost1) COST1="$2"; shift 2 ;;
        --cost2) COST2="$2"; shift 2 ;;
        --cost3) COST3="$2"; shift 2 ;;
        --cache) cache=true; cacheoption="--cache"; shift 1 ;;
        --outdir) outdir="$2"; shift 2 ;;
        --debug) debug_option="--debug"; shift 1 ;;
        --*) echo "Unknown option: $1"; display_usage ; exit 1 ;;
        *) echo "Unknow option: $1"; display_usage ; exit 1 ;;
    esac
done

if [[ -z "${inmri}" ]] || [[ -z "${inpet}" ]] || [[  -z "${outmri}" ]] || [[ -z "${outpet}" ]]; then
    display_usage
    exit 1
fi

### Process
# 1. Coregister MR image to MNI space
echo "Coregister MR image to MNI space..."
${SCRIPTDIR}/tq-mri2mni.sh ${inmri} ${outmri} --outmat $(basename ${inmri%.nii*}2MNI.mat) --outdir ${outdir} --max_synthstrip ${MAX_SYNTHSTRIP} --cost ${COST1} ${cacheoption} ${debug_option}

# 2. Realign PET image
echo "Realign PET image..."
${SCRIPTDIR}/tq-alignpet.sh ${inpet} ${outdir}/$(basename ${inpet%.nii*}_align.nii.gz) --cost ${COST2} ${cacheoption} ${debug_option}

# 3. Dynamic PET image to Static PET image
echo "Dynamic PET image to Static PET image..."
fslmaths ${outdir}/$(basename ${inpet%.nii*}_align.nii.gz) -Tmean ${outdir}/$(basename ${inpet%.nii*}_align_mean.nii.gz)

# 4. Coregister PET image to MR image
echo "Coregister PET image to MR image..."

# cost function: normmi
if [[ ${COST3} = "auto" ]] || [[ ${COST3} = "normmi" ]]; then
    flirt -dof 6 -in ${outdir}/$(basename ${inpet%.nii*}_align_mean.nii.gz) -ref ${outdir}/${outmri} -searchcost normmi -cost normmi -omat ${outdir}/tmp_normmi_$(basename ${inpet%.nii*}_align_mean2MRI.mat) -out ${outdir}/tmp_normmi_${outpet}
    
    # Check whether brain is in FOV
    nonzero_ratio_normmi=$(calc_nonzero ${outdir}/tmp_normmi_${outpet})
    flag_warn_normmi=$(echo "${nonzero_ratio_normmi} < ${WARNINGTHR}" | bc)
    if [[ ${flag_warn_normmi} = 1 ]]; then
        echo "Warning: PET image coregistration might be failed (normmi)."
        if [[ ${COST3} = "auto" ]]; then
        echo "Switch cost function: normmi --> mutualinfo"
        fi
    fi

    if [[ ${flag_warn_normmi} = 0 ]] || [[ ${COST3} = "normmi" ]] ; then
        mv ${outdir}/tmp_normmi_$(basename ${inpet%.nii*}_align_mean2MRI.mat) ${outdir}/$(basename ${inpet%.nii*}_align_mean2MRI.mat)
        mv ${outdir}/tmp_normmi_${outpet} ${outdir}/${outpet}
        exit 0
    fi
fi

# cost function: mutualinfo
flirt -dof 6 -in ${outdir}/$(basename ${inpet%.nii*}_align_mean.nii.gz) -ref ${outdir}/${outmri} -searchcost mutualinfo -cost mutualinfo -omat ${outdir}/tmp_mutualinfo_$(basename ${inpet%.nii*}_align_mean2MRI.mat) -out ${outdir}/tmp_mutualinfo_${outpet}

# Check whether brain is in FOV
nonzero_ratio_mutualinfo=$(calc_nonzero ${outdir}/tmp_mutualinfo_${outpet})
flag_warn_mutualinfo=$(echo "${nonzero_ratio_mutualinfo} < ${WARNINGTHR}" | bc)
if [[ ${flag_warn_mutualinfo} = 1 ]]; then
    echo "Warning: PET image coregistration might be failed (mutualinfo)."
fi

if [[ ${flag_warn_mutualinfo} = 0 ]] || [[ ${COST3} = "mutualinfo" ]] ; then
    mv ${outdir}/tmp_mutualinfo_$(basename ${inpet%.nii*}_align_mean2MRI.mat) ${outdir}/$(basename ${inpet%.nii*}_align_mean2MRI.mat)
    mv ${outdir}/tmp_mutualinfo_${outpet} ${outdir}/${outpet}
    exit 0
fi

# Both mutualinfo and normmi might not work well...
echo "Both mutualinfo and normmi might not work well in PET-to-MRI coregistration."
if [[ $(echo "${nonzero_ratio_normmi} > ${nonzero_ratio_mutualinfo}" | bc) = 1 ]]; then
    echo "Result with normmi is accepted."
    mv ${outdir}/tmp_normmi_$(basename ${inpet%.nii*}_align_mean2MRI.mat) ${outdir}/$(basename ${inpet%.nii*}_align_mean2MRI.mat)
    mv ${outdir}/tmp_normmi_${outpet} ${outdir}/${outpet}
else
    echo "Result with mutualinfo is accepted."
    mv ${outdir}/tmp_mutualinfo_$(basename ${inpet%.nii*}_align_mean2MRI.mat) ${outdir}/$(basename ${inpet%.nii*}_align_mean2MRI.mat)
    mv ${outdir}/tmp_mutualinfo_${outpet} ${outdir}/${outpet}
fi

echo "Please check the below output files:"
echo "    Coregisterd MR image: ${outmri}"
echo "    Coregisterd PET iamge: ${outpet}"
