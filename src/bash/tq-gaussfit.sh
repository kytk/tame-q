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
        :
    fi
    jobs -pr | xargs -r kill 2>/dev/null || true
}

trap cleanup EXIT INT TERM

### Define functions
function display_usage() {
    echo "Usage: $0 <image> <--curves N> [--mask mask] [--norm mean_value] [--outfig filename] [--outtext filename] [--cache]"
}

### Read command line arguments
# Check the number of command line arguments
if [[ "$#" -lt 1 ]]; then
    display_usage
    exit 1
fi

image="$1"
shift 1

# Handle necessary arguments
mask_option=""
N_curve=""
M_norm_option=""
bin_width=0.025
paramset=""
outfig_option=""
outfigsize=4
outfigtype=1
outtext_option=""
outhist_option=""
cache=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --mask) mask_option="--mask $2"; shift 2 ;;
        --curves) N_curve="$2"; shift 2 ;;
        --norm) M_norm_option="--norm $2"; shift 2 ;;
        --binwidth) bin_width="$2"; shift 2 ;;
        --paramset) paramset="$2" ; shift 2 ;;
        --outfig) outfig_option="--outfig $2"; shift 2 ;;
        --outfigsize) outfigsize="$2"; shift 2 ;;
        --outfigtype) outfigtype="$2"; shift 2 ;;
        --outtext) outtext_option="--outtext $2"; shift 2 ;;
        --outhist) outhist_option="--outhist $2"; shift 2 ;;
	--fallback_without_bounds) fallback_option="--fallback_without_bounds"; shift 1 ;;
        --cache) cache=true; shift 1 ;;
        --debug) shift 1 ;;
        --*) echo "Unknown option: $1"; display_usage ; exit 1 ;;
        *) echo "Unknow option: $1"; display_usage ; exit 1 ;;
    esac
done

if [[ -z "${N_curve}" ]]; then
    display_usage
    exit 1
fi

# Set variable
TAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; cd ../.. ; pwd)
SCRIPTDIR=$(cd $(dirname $0); pwd)
source ${TAMEQDIR}/config.env

### Process
# Curve fit
python3 ${TAMEQDIR}/src/python/nifti_gmm.py \
    --input ${image} \
    --curves ${N_curve} \
    ${mask_option} \
    ${M_norm_option} \
    --bin_width ${bin_width} \
    --bin_min 0 \
    --paramset ${paramset} \
    ${outfig_option} \
    --outfigsize ${outfigsize} \
    --outfigtype ${outfigtype} \
    ${outtext_option} \
    ${outhist_option} \
    ${fallback_option}

