#!/usr/bin/env bash
# 8 Mar 2026 K.Nakayama and K.Nemoto

set -euo pipefail
for arg in "$@"; do
    if [[ "${arg}" = "--debug" ]]; then
        set -x
    fi
done

### Define functions
function display_usage() {
    echo "Usage: $0 [options]"
    echo "  --suffix <t1w_suffix> (default: _t1w)"
    echo "  --outdir <outdir> (default: current directory)"
    echo "  --parallel <N> (default: 1)"
    echo "  --refpolicy <refpolicyfile>"
    echo "  --set <settingfile>"
    echo "  --half"
    echo "  --cache"
    echo "  --debug"
    echo "  --help"
}

# Load environment variable
TAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; cd ../.. ; pwd)
source ${TAMEQDIR}/config.env

### Read command line arguments
# Handle necessary arguments
if [[ "$#" -lt 1 ]] || [[ "$1" = "-"* ]]; then
    datadir="."
else
    datadir="$1"
    shift 1
fi

t1w_suffix="_t1w"
outdir=${datadir}/tq_result_$(date +%Y%m%d_%H%M)
n_parallel=""
refpolicy=${TAMEQDIR}/src/python/reference_policy.py
settingfile=${TAMEQDIR}/env/tq-all-setting.env
half_option=""
cache_option=""
debug_option=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --suffix) t1w_suffix="${2%.nii*}"; shift 2 ;;
        --outdir) outdir="$2"; shift 2 ;;
        --parallel) n_parallel="$2"; shift 2 ;;
        --refpolicy) refpolicy="$2"; shift 2 ;;
        --set) settingfile="$2"; shift 2 ;;
        --half) half_option="--half"; shift 1 ;;
        --cache) cache_option="--cache"; shift 1 ;;
        --debug) debug_option="--debug"; shift 1 ;;
        --help) display_usage ; exit 1 ;;
        --*) echo "Unknown option: $1"; display_usage ; exit 1 ;;
        *) echo "Unknow option: $1"; display_usage ; exit 1 ;;
    esac
done

source ${settingfile}
if [[ -n "${n_parallel}" ]]; then
    MAX_TQALL=${n_parallel}
fi


# Check license.txt
if [[ ! -e ${FS_LICENSE} ]]; then 
    echo "FreeSurfer license file must exist as ${FS_LICENSE}"
    exit 1
fi

### Process
echo "tq-batch.sh starts."

# Detect images
IDs=()
MRIs=()
PETs=()
subjlist="T1\tPET\n"
for f in ${datadir}/*${t1w_suffix}.nii*; do
    prefix=${f%${t1w_suffix}.nii*}
    id=$(basename ${prefix})
    if [[ $(find ${datadir} -maxdepth 1 -type f -name "${id}*[.nii,.nii.gz]" | grep -v ${t1w_suffix}.nii | wc -l) -eq 1 ]]; then
        g=$(find ${datadir} -maxdepth 1 -type f -name "${id}*[.nii,.nii.gz]" | grep -v ${t1w_suffix}.nii)
        IDs+=("${id}")
        MRIs+=("${f}")
        PETs+=("${g}")
        subjlist="${subjlist}${f}\t${g}\n"
    fi
done

if [[ ${#IDs[@]} > 1 ]]; then
    echo -e "The below ${#IDs[@]} IDs are detected:\n\n${subjlist}" | expand -t ${#g}
elif [[ ${#IDs[@]} = 1 ]]; then
    echo -e "The below ID is detected:\n\n${subjlist}" | expand -t ${#g}
else
    echo -e "No IDs were found.\nFilenames must follow these rules:\n- Start with an ID that begins with an uppercase letter.\n- Use the suffix _t1w.nii.gz for T1-weighted images.\n- Use the suffix _pmpbb3_dyn.nii.gz for PET images.\nExamples:\n- ID001_t1w.nii.gz\n- ID001_pmpbb3_dyn.nii.gz- Please check the image locations and filenames you want to process.\n"
    exit 1
fi

while true; do
    echo "Is the list correct? [y/n]"
    read answer

    case $answer in
    	[Yy]*) echo -e "Continue processing \n" ; break ;;
      	[Nn]*) echo -e "Quit to process \n" ; exit 1 ;;
      	*) echo -e "Type y or n \n" ;;
    esac
done

${TAMEQDIR}/src/bash/tq-logo.sh

cleanup() {
    tput rc 2>/dev/null || printf '\033[u'
    tput cud $(( ${#IDs[@]} + 2 )) 2>/dev/null || printf '\033[%dB' $(( ${#IDs[@]} + 2 ))
    tput el 2>/dev/null || printf '\033[K'
    echo

    tput cnorm 2>/dev/null || true
}

cleanup_quit() {
    tput rc 2>/dev/null || printf '\033[u'
    tput cud $(( ${#IDs[@]} + 2 )) 2>/dev/null || printf '\033[%dB' $(( ${#IDs[@]} + 2 ))
    tput el 2>/dev/null || printf '\033[K'
    echo

    tput cnorm 2>/dev/null || true

    echo "Quit all processes..."

    for pid in ${PIDS[@]:-}; do
        kill -TERM -- "-$pid" 2>/dev/null || true
    done

    sleep 1s
    for pid in "${PIDS[@]:-}"; do
        kill -KILL -- "-$pid" 2>/dev/null || true
    done
}

trap cleanup EXIT
trap 'cleanup_quit; exit 130' INT
trap 'cleanup_quit; exit 143' TERM

# Initial setting for display area
tput civis 2>/dev/null || true
printf "\n\n\n\n"
tput cuu 4 2>/dev/null || printf '\033[3A'
tput sc 2>/dev/null || printf '\033[s'

markers=('/' '-' '\' '|')
markerindex=0
draw() {
    local n_input="$1"
    local n_running="$2"
    local n_finished="$3"

    tput rc 2>/dev/null || printf '\033[u'

    tput el 2>/dev/null || printf '\033[K'
    printf '%-6s %s\n' "Input: ${n_input} pairs"

    tput el 2>/dev/null || printf '\033[K'
    printf '%-6s %s\n' "Running: ${n_running} lines"

    tput el 2>/dev/null || printf '\033[K'
    printf '%-6s %s\n' "Finished: ${n_finished} lines"

    tput el 2>/dev/null || printf '\033[K]'
    printf '%-6s %s\n' "Please wait... ${markers[${markerindex}]}"

    markerindex=$(( ( markerindex + 1 ) % 4 ))
}

draw ${#IDs[@]} 0 0

### Process
PIDS=()
for i in "${!IDs[@]}"; do
    name="${IDs[$i]}"
    mri="${MRIs[$i]}"
    pet="${PETs[$i]}"

    while true; do
        n_running=0
        n_finished=0
        for pid in "${PIDS[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                n_running=$(( n_running + 1 ))
            else
                n_finished=$(( n_finished + 1 ))
            fi
        done

        draw ${#IDs[@]} ${n_running} ${n_finished}

        if [[ "${n_running}" -lt "${MAX_TQALL}" ]]; then
            break
        fi

        sleep 1s
    done

    (${TAMEQDIR}/src/bash/tq-all.sh --id ${name} --mri ${mri} --pet ${pet} --outdir ${outdir} --refpolicy ${refpolicy} --set ${settingfile} ${half_option} ${cache_option} ${debug_option} >/dev/null ) &
    PIDS+=("$!")
done

while true; do
    n_running=0
    n_finished=0
    for pid in "${PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            n_running=$(( n_running + 1 ))
        else
            n_finished=$(( n_finished + 1 ))
        fi
    done

    draw ${#IDs[@]} ${n_running} ${n_finished}

    if [[ "${n_finished}" -eq "${#IDs[@]}" ]]; then
        break
    fi

    sleep 1s
done

echo "Merge ROI-SUVR table."
${TAMEQDIR}/src/bash/tq-mergeresult.sh ${outdir}

echo "Run QC scripts."
${TAMEQDIR}/src/bash/tq-qc.sh ${outdir}

echo "All jobs finished."
exit 0
