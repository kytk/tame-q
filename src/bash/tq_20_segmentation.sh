#!/usr/bin/env bash

### TAME-Q tq_20_segmentation.sh

### License:
# This script is distributed under the GNU General Public License version 3.
# See LICENSE file for details.

# 8 Mar 2026 K.Nakayama and K.Nemoto

set -euo pipefail
for arg in "$@"; do
    if [[ "${arg}" = "--debug" ]]; then
        set -x
    fi
done

cleanup() {
    status=$?
    if [[ "${status}" -eq 0 ]]; then
        rm -f ${inmri%.gz} ${subjectdir}/segmentation.m
    fi
    jobs -pr | xargs -r kill 2>/dev/null || true
}
trap cleanup EXIT INT TERM

### Define functions
function display_usage() {
    echo "Usage: $0 <subject dir>"
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
cache=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --cache) cache=true; shift 1 ;;
        --debug) shift 1 ;;
        --*) echo "Unknown option: $1"; display_usage ; exit 1 ;;
        *) echo "Unknow option: $1"; display_usage ; exit 1 ;;
    esac
done

inmri=${subjectdir}/mri_mni.nii.gz

if [[ ! -e "${inmri}" ]]; then
    echo "Error: Unable to find ${outdir}"
    exit 1
fi

# Set variable
TAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; cd ../.. ; pwd)
source ${TAMEQDIR}/config.env
MCRVER=$(cat ${SPM12STANDALONEDIR}/readme.txt | grep run_spm12.sh | grep /mathworks/home/application | awk -F/ '{print $NF}')

### Process
# Gunzip input if necessary
flag_gz=false
if [[ "${inmri: -3}" = ".gz" ]]; then
    flag_gz=true
    gunzip -kf ${inmri}
fi

# Copy .m file to pwd
cp -f ${TAMEQDIR}/src/matlab/segmentation.m ${subjectdir}

# Replace MR_IMAGE_PATH with input MRI path in segmentation.m file
sed -i "/img/s#MR_IMAGE_PATH#${inmri%.gz}#g" ${subjectdir}/segmentation.m

# Run segmentation.m
${SPM12STANDALONEDIR}/run_spm12.sh ${MCRDIR}/${MCRVERSION} batch ${subjectdir}/segmentation.m > /dev/null

# Gzip SPM output
gzip -f ${subjectdir}/c1$(basename ${inmri%.gz})
gzip -f ${subjectdir}/c2$(basename ${inmri%.gz})

exit 0

