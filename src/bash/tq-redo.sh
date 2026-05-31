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
    if [[ "${status}" -eq 0 ]]; then
        echo "${TQID}: tq-redo.sh finished without errors."
        if [[ "${cache}" = false ]]; then
            rm -f ${subjectdir}/tmp*
            rm -f ${subjectdir}/tq-all_tmp*.nii.gz
            rm -f ${subjectdir}/pet_suvr_??ref_view.nii.gz
            rm -f ${subjectdir}/pet_f????.nii.gz
            rm -f ${subjectdir}/pet_f????_align.nii.gz
        fi
    else
        echo "${TQID}: tq-redo.sh finished with ERRORs."
    fi
    jobs -pr | xargs -r kill 2>/dev/null || true
}

trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

### Define functions
function display_usage() {
    echo "Usage: $0 <subjectdir> [--force number] [--run] [--cache] [--debug]"
}

function check_existence() {
    for f in "$@"; do
        if [[ ! -e ${f} ]]; then
            echo "Error: Unable to find ${f}" >&2
            exit 1
        fi
    done
}

# Load environment variable
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
force="99"
cache=false
debug_option=""
run_flag=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --force) force="$2"; shift 2 ;;
        --cache) cache=true; shift 1 ;;
        --debug) debug_option="--debug"; shift 1 ;;
        --run) run_flag=true; shift 1 ;;
        --*) echo "Unknown option: $1"; display_usage ; exit 1 ;;
        *) echo "Unknow option: $1"; display_usage ; exit 1 ;;
    esac
done

# Check license.txt
if [[ ! -e ${FS_LICENSE} ]]; then 
    echo "FreeSurfer license file must exist as ${FS_LICENSE}"
    exit 1
fi

### Initial preparation
logfile=${subjectdir}/tq-all.log
settingfile=${subjectdir}/tq-all-setting.env

check_existence ${logfile} ${settingfile}
source ${settingfile}

exec 3>&1
exec > >(
  tee >(awk -v lf="${logfile}" '{
        print strftime("[%F %T]"), $0 >> lf
        fflush(lf)
      }') >&3
) 2>&1

echo "tq-redo.sh starts."
step=$(${TAMEQDIR}/src/bash/tq-checkstep.sh ${subjectdir} --silent)
if [[ "${step}" -lt 10 ]]; then
    echo "Error: Unable to analyze the file structures"
    exit 1
fi

if [[ "${force}" -lt "${step}" ]]; then
    step=${force}
fi

if [[ "${step}" -ge 99 ]]; then
    echo "All tame-q processes have been done in ${subjectdir}."
    exit 0
fi

if [[ ${run_flag} = false ]]; then
    while true; do
        echo "Run scripts from tq_${step} onward in ${subjectdir}? [y/n]"
        read answer

        case $answer in
            [Yy]*) echo -e "Continue processing \n" ; break ;;
            [Nn]*) echo -e "Quit to process \n" ; exit 1 ;;
            *) echo -e "Type y or n \n" ;;
        esac
    done
fi

if [[ "${step}" -lt 20 ]]; then
    ${TAMEQDIR}/src/bash/tq_10_realign.sh ${subjectdir} --cache ${debug_option} --nolog
    ${TAMEQDIR}/src/bash/tq_11_qa_coreg.sh ${subjectdir} --cache ${debug_option} --nolog
    ${TAMEQDIR}/src/bash/tq_12_qa_report.sh ${subjectdir} --cache ${debug_option} --nolog
fi

if [[ "${step}" -lt 30 ]]; then
    ${TAMEQDIR}/src/bash/tq_20_segmentation.sh ${subjectdir} ${debug_option} --nolog
fi

if [[ "${step}" -lt 40 ]]; then
    ${TAMEQDIR}/src/bash/tq_30_suvr_im.sh ${subjectdir} --fallback_without_bounds --cache ${debug_option} --nolog
fi

if [[ "${step}" -lt 50 ]]; then
    ${TAMEQDIR}/src/bash/tq_40_overview.sh ${subjectdir} ${debug_option} --nolog
fi

if [[ "${step}" -lt 51 ]]; then
    ${TAMEQDIR}/src/bash/tq_50_recon-all.sh ${subjectdir} ${debug_option} --nolog
fi

if [[ "${step}" -lt 52 ]]; then
    ${TAMEQDIR}/src/bash/tq_51_segmentBS.sh ${subjectdir} ${debug_option} --nolog
fi

if [[ "${step}" -lt 53 ]]; then
    ${TAMEQDIR}/src/bash/tq_52_merge_wmparc.sh ${subjectdir} --cache ${debug_option} --nolog
fi

if [[ "${step}" -lt 54 ]]; then
    ${TAMEQDIR}/src/bash/tq_53_get_cbref.sh ${subjectdir} ${debug_option} --nolog
fi

if [[ "${step}" -lt 61 ]]; then
    ${TAMEQDIR}/src/bash/tq_60_gen_table_wmparc_gmref.sh ${subjectdir} ${debug_option} --nolog
fi

if [[ "${step}" -lt 62 ]]; then
    ${TAMEQDIR}/src/bash/tq_61_gen_table_wmparc_wmref.sh ${subjectdir} ${debug_option} --nolog
fi

if [[ "${step}" -lt 63 ]]; then
    ${TAMEQDIR}/src/bash/tq_62_gen_table_wmparc_cbref.sh ${subjectdir} ${debug_option} --nolog
fi

if [[ "${step}" -lt 64 ]]; then
    ${TAMEQDIR}/src/bash/tq_63_gen_table_merged_gmref.sh ${subjectdir} ${debug_option} --nolog
fi

if [[ "${step}" -lt 65 ]]; then
    ${TAMEQDIR}/src/bash/tq_64_gen_table_merged_wmref.sh ${subjectdir} ${debug_option} --nolog
fi

if [[ "${step}" -lt 66 ]]; then
    ${TAMEQDIR}/src/bash/tq_65_gen_table_merged_cbref.sh ${subjectdir} ${debug_option} --nolog
fi

exit 0
