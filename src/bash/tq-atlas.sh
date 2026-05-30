#!/usr/bin/env bash

### TAME-Q tq-atlas.sh
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
        rm -f ${tmp_image}
    fi
    jobs -pr | xargs -r kill 2>/dev/null || true
}

trap cleanup EXIT INT TERM

### Define functions
function display_usage() {
    echo "Usage: $0 <wmparc> <bsparc> <output> [options]"
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

### Read command line arguments
# Check the number of command line arguments
if [[ "$#" -lt 3 ]]; then
    display_usage
    exit 1
fi
wmparc="$1"
bsparc="$2"
output="$3"
shift 3

# Handle necessary arguments
cache=false
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --cache) cache=true ; shift 1 ;;
        --*) echo "Unknown option: $1"; display_usage ; exit 1 ;;
        *) echo "Unknow option: $1"; display_usage ; exit 1 ;;
    esac
done

# Set variable
TAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; cd ../.. ; pwd)
source ${TAMEQDIR}/config.env

outdir=$(dirname $(realpath ${output}))
outfn=$(basename ${output})
tmp_image=${outdir}/tq-atlas_cache_tmp$(randomphrase 8).nii.gz
tmp_output=${outdir}/tmp_${outfn}

if [[ "${wmparc: -4}" = ".mgz" ]]; then
    wmparc_nii=${outdir}/tq-atlas_wmparc_tmp$(randomphrase 8).nii.gz
    mri_vol2vol \
    --mov ${wmparc} \
    --o ${wmparc_nii} \
    --regheader \
    --no-save-reg \
    --interp nearest
else
    wmparc_nii=${wmparc}
fi

if [[ "${bsparc: -4}" = ".mgz" ]]; then
    bsparc_nii=${outdir}/tq-atlas_bsparc_tmp$(randomphrase 8).nii.gz
    mri_vol2vol \
    --mov ${bsparc} \
    --o ${bsparc_nii} \
    --regheader \
    --no-save-reg \
    --interp nearest
else
    bsparc_nii=${bsparc}
fi

### Process
# middlefrontal
fslmaths ${wmparc_nii} -thr 1000 -rem 1000 -thr 27 -uthr 27 -sub 3 -thr 0 ${tmp_image}
fslmaths ${wmparc_nii} -sub ${tmp_image} ${tmp_output}

# inferiorfrontal
fslmaths ${wmparc_nii} -thr 1000 -rem 1000 -thr 19 -uthr 20 -sub 18 -thr 0 ${tmp_image}
fslmaths ${tmp_output} -sub ${tmp_image} ${tmp_output}

# orbitofrontal (medialorbitofraonal)
fslmaths ${wmparc_nii} -thr 1000 -rem 1000 -thr 14 -uthr 14 -sub 12 -thr 0 ${tmp_image}
fslmaths ${tmp_output} -sub ${tmp_image} ${tmp_output}

# orbitofrontal (frontalpole)
fslmaths ${wmparc_nii} -thr 1000 -rem 1000 -thr 32 -uthr 32 -sub 12 -thr 0 ${tmp_image}
fslmaths ${tmp_output} -sub ${tmp_image} ${tmp_output}

# cingulate(isthmuscingulate)
fslmaths ${wmparc_nii} -thr 1000 -rem 1000 -thr 10 -uthr 10 -sub 2 -thr 0 ${tmp_image}
fslmaths ${tmp_output} -sub ${tmp_image} ${tmp_output}

# cingulate(posteriorcingulate)
fslmaths ${wmparc_nii} -thr 1000 -rem 1000 -thr 23 -uthr 23 -sub 2 -thr 0 ${tmp_image}
fslmaths ${tmp_output} -sub ${tmp_image} ${tmp_output}

# cingulate(rostralanteriorcingulate)
fslmaths ${wmparc_nii} -thr 1000 -rem 1000 -thr 26 -uthr 26 -sub 2 -thr 0 ${tmp_image}
fslmaths ${tmp_output} -sub ${tmp_image} ${tmp_output}

# Merge wmparc and bsseg (Brain-Stem (wmparc) segmented into Midbrain, Pons, and Brainstem (segmentBS))
fslmaths ${wmparc_nii} -thr 16 -uthr 16 ${tmp_image}  # Extract brainstem (wmparc)
fslmaths ${tmp_output} -sub ${tmp_image} ${tmp_output}  # Remove brainstem from output temporally
fslmaths ${bsparc_nii} -uthr 176 -mas ${tmp_image} ${tmp_image}  # Define the segmentation only in wmparc Brain-Stem region
fslmaths ${tmp_output} -add ${tmp_image} ${tmp_output}  # Add brainstem segmentation into output merged atlas

mv ${tmp_output} ${output}

exit