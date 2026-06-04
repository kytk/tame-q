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
        rm -f ${outdir}/${brain} ${outdir}/${brainmask}
        if ${flag_delete_outmat}; then
            rm -f ${outdir}/${outmatname}
        fi
    fi
    jobs -pr | xargs -r kill 2>/dev/null || true
}

trap cleanup EXIT INT TERM

### DEFAULT VALUE SETTING
REFIMG=${FSLDIR}/data/standard/MNI152_T1_1mm_brain.nii.gz

### Define functions
function display_usage() {
    echo "Usage: $0 <input> <output> [options]"
    echo "  --ref <reference image>"
    echo "  --outmat filename"
    echo "  --outdir directory"
    echo "  --cache"
}

### Read command line arguments
# Check the number of command line arguments
if [[ "$#" -lt 2 ]]; then
    display_usage
    exit 1
fi

# Handle necessary arguments
inputfile="$1"
outputfile="$2"
shift 2

# Check necessary arguments
if [[ "${inputfile:0:1}" = "-" ]] || [[ "${outputfile:0:1}" = "-" ]] || [[ -z ${inputfile} ]] || [[ -z ${outputfile} ]]; then
    display_usage
    exit 1
fi


# Set variable
TAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; cd ../.. ; pwd)
source ${TAMEQDIR}/config.env
SCRIPTDIR=$(cd $(dirname $0); pwd)

# Handle optional arguments
refimg=${REFIMG}
MAX_SYNTHSTRIP=9999
COST=corratio
outmatname=""
outdir=$(pwd)
flag_mask=false
cache=false
flag_delete_outmat=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --ref) refimg="$2"; shift 2 ;;
        --outmat) outmatname="$2"; shift 2 ;;
        --outdir) outdir="${2%/}"; shift 2 ;;
        --max_synthstrip) MAX_SYNTHSTRIP="$2"; shift 2 ;;
        --cost) COST="$2"; shift 2 ;;
        --cache) cache=true; shift 1 ;;
        --debug) shift 1 ;;
        --*) echo "Unknown option: $1"; display_usage ; exit 1 ;;
        *) echo "Unknow option: $1"; display_usage ; exit 1 ;;
    esac
done

if [[ -z "${outmatname}" ]]; then
    flag_delete_outmat=true
    outmatname=$(basename ${inputfile%.nii*}_to_MNI.mat)
fi

### Process
# 1. Skull strip
brain=${inputfile%.nii*}_brain.nii.gz
brainmask=${inputfile%.nii*}_brainmask.nii.gz
while [[ $(pgrep -f mri_synthstrip -c) -ge ${MAX_SYNTHSTRIP} ]]; do sleep 10s; done
mri_synthstrip -i ${inputfile} -o ${outdir}/$(basename ${brain}) -m ${outdir}/$(basename ${brainmask}) > /dev/null

# 2. Calculate conversion matrix from input space to MNI
flirt -dof 6 -in ${outdir}/$(basename ${brain}) -ref ${refimg} -searchcost ${COST} -cost ${COST} -omat ${outdir}/${outmatname} -out ${outdir}/$(basename ${outputfile%.nii*}_brain.nii.gz)

# 3. Convert input to MNI
flirt -dof 6 -in ${inputfile} -ref ${refimg} -applyxfm -init ${outdir}/${outmatname} -out ${outdir}/${outputfile}

# 4. Convert brainmask to MNI
flirt -dof 6 -in ${outdir}/$(basename ${brainmask}) -ref ${refimg} -interp nearestneighbour -applyxfm -init ${outdir}/${outmatname} -out ${outdir}/$(basename ${outputfile%.nii*}_brainmask.nii.gz)

exit