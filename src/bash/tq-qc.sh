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
    if [[ "${status}" -eq 1 ]]; then
        :
    fi
    jobs -pr | xargs -r kill 2>/dev/null || true
}

trap cleanup EXIT INT TERM

### Define functions
function display_usage() {
    echo "Usage: $0 <resultdir>"
}

### DEFAULT VALUE SETTING
TAMEQDIR=$(cd $(dirname $(realpath "$0")); cd ../../ ; pwd)

### Read command line arguments
# Check the number of command line arguments
if [[ "$#" -lt 1 ]]; then
    display_usage
    exit 1
fi

# Handle necessary arguments
resultdir="$1"
shift 1

# Read and Process command line arguments
while [ "$#" -gt 0 ]; do
    case "$1" in
        --debug) shift 1 ;;
        --*) echo "Unknown option: $1"; display_usage ; exit 1 ;;
        *) echo "Unknow option: $1"; display_usage ; exit 1 ;;
    esac
done

### Process
# 1. Merge t1w coregistration parameters
${TAMEQDIR}/src/bash/tq-qc-t1wcoreg.sh ${resultdir} > ${resultdir}/qc_t1wcoreg.csv

# 2. Merge pet coregistration parameters
${TAMEQDIR}/src/bash/tq-qc-petcoreg.sh ${resultdir} > ${resultdir}/qc_petcoreg.csv

# 3. Get FS defect index
${TAMEQDIR}/src/bash/tq-qc-fsdefectindex.sh ${resultdir} > ${resultdir}/qc_defectindex.csv

exit 0
