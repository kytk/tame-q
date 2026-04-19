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
flag_nolog=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --cache) cache=true; shift 1 ;;
        --debug) shift 1 ;;
        --nolog) flag_nolog=true ; shift 1 ;;
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

if [[ ${flag_nolog} = "false" ]]; then
    logfile=${subjectdir}/tq-all.log
    exec 3>&1
    exec > >(
    tee >(awk -v lf="${logfile}" '{
            print strftime("[%F %T]"), $0 >> lf
            fflush(lf)
        }') >&3
    ) 2>&1

    echo -e "\ntq_20_segmentation.sh starts."
fi

### Process
# Gunzip input if necessary
flag_gz=false
if [[ "${inmri: -3}" = ".gz" ]]; then
    flag_gz=true
    TMPDIR1=$(mktemp -d)
    cp ${inmri} ${TMPDIR1}
    gunzip ${TMPDIR1}/$(basename ${inmri})
    mv ${TMPDIR1}/$(basename ${inmri%.gz}) ${subjectdir}
    rm -rf ${TMPDIR1}
fi

# Replace MR_IMAGE_PATH with input MRI path in segmentation.m file and place it in subjectdir
sed "/img/s#MR_IMAGE_PATH#${inmri%.gz}#g" ${TAMEQDIR}/src/matlab/segmentation.m > ${subjectdir}/segmentation.m

# Run segmentation.m
${SPM12STANDALONEDIR}/run_spm12.sh ${MCRDIR}/${MCRVERSION} batch ${subjectdir}/segmentation.m > /dev/null

# Gzip SPM output
TMPDIR2=$(mktemp -d)
cp ${subjectdir}/c1$(basename ${inmri%.gz}) ${subjectdir}/c2$(basename ${inmri%.gz}) ${TMPDIR2}
gzip -f ${TMPDIR2}/c1$(basename ${inmri%.gz})
gzip -f ${TMPDIR2}/c2$(basename ${inmri%.gz})
mv ${TMPDIR2}/c1$(basename ${inmri}) ${TMPDIR2}/c2$(basename ${inmri}) ${subjectdir}
rm -rf ${TMPDIR2}

exit 0