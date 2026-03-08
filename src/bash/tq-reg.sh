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
    fi
    jobs -pr | xargs -r kill 2>/dev/null || true
}

trap cleanup EXIT INT TERM

### Define functions
function display_usage() {
    echo "Usage: $0 <--inmri MRI> <--inpet PET> <--outmri filename> <--outpet filename> [options]"
}

### DEFAULT VALUE SETTING
REFIMG=${FSLDIR}/data/standard/MNI152_T1_1mm_brain.nii.gz

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
flirt -dof 6 -in ${outdir}/$(basename ${inpet%.nii*}_align_mean.nii.gz) -ref ${outdir}/${outmri} -searchcost ${COST3} -cost ${COST3} -omat ${outdir}/$(basename ${inpet%.nii*}_align_mean2MRI.mat) -out ${outdir}/${outpet}

# Check whether brain is in FOV
voxel_fov=$(fslstats ${outdir}/${outpet} -v | awk '{print $1}')
voxel_head=$(fslstats ${outdir}/${outpet} -V | awk '{print $1}')
if [[ $(echo "${voxel_head} < ${voxel_fov} * 0.2" | bc ) = 1 ]]; then
    echo "Warning: PET image coregistration might be failed."
#    echo "Please check the coregistration with ${outmri} and ${outpet}"
#    exit 1
fi

echo "Please check the below output files:"
echo "    Coregisterd MR image: ${outmri}"
echo "    Coregisterd PET iamge: ${outpet}"
