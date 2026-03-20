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
    echo "Usage: $0 <input> <output> [--mask mask] [--curve curvefile1 label1 ] [--curve curvefile2 label2 ] [options]"
}

# Set variable
TAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; cd ../.. ; pwd)
SCRIPTDIR=$(cd $(dirname $0); pwd)
source ${TAMEQDIR}/config.env

### Read command line arguments
# Check the number of command line arguments
if [[ "$#" -lt 2 ]]; then
    display_usage
    exit 1
fi

image="$1"
outfilename="$2"
shift 2

# Handle necessary arguments
mask=""
curvefile=()
curvelabel=()
targethist=""
policyfile=${TAMEQDIR}/src/python/reference_policy.py
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --mask) mask="$2"; shift 2 ;;
        --curve) curvefile+=("$2"); curvelabel+=("$3"); shift 3 ;;
        --targethist) targethist="$2"; shift 2 ;;
        --policy) policyfile="$2"; shift 2 ;;
        --debug) shift 1 ;;
        --*) echo "Unknown option: $1"; display_usage ; exit 1 ;;
        *) echo "Unknow option: $1"; display_usage ; exit 1 ;;
    esac
done

if [[ "${#curvefile[@]}" = 0 ]]; then
    echo "No curvefiles are given."
    display_usage
    exit 1
fi

### Process
# Curve fit
python3 ${TAMEQDIR}/src/python/refderive.py \
    --input ${image} \
    --output ${outfilename} \
    --mask ${mask} \
    --curvefile ${curvefile[@]} \
    --curvelabel ${curvelabel[@]} \
    --policy ${policyfile} \
    --targethist ${targethist}
