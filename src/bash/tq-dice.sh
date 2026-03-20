#!/usr/bin/env bash
# 8 Mar 2026 K.Nakayama and K.Nemoto

set -euo pipefail
for arg in "$@"; do
    if [[ "${arg}" = "--debug" ]]; then
        set -x
    fi
done

### DEFAULT VARIABLES
SCALE=5

### Define functions
function display_usage() {
    echo "Usage: $0 < mask1 > < mask2 >"
}

### Read command line arguments
# Check the number of command line arguments
if [[ "$#" -lt 2 ]]; then
    display_usage
    exit 1
fi

# Handle arguments
mask1="$1"
mask2="$2"

### Process
# 1. Calculate total volume
mask1vol=$(fslstats ${mask1} -V | awk -F ' ' '{print $2}')
mask2vol=$(fslstats ${mask2} -V | awk -F ' ' '{print $2}')
totalvol=$(echo "scale=${SCALE}; ${mask1vol} + ${mask2vol}" | bc)

# 2. Calculate overlap volume
overlapvol=$(fslstats ${mask1} -k ${mask2} -V | awk -F ' ' '{print $2}')

# 3. Calculate Dice coefficient
DSC=$(echo "scale=${SCALE}; 2*${overlapvol}/${totalvol}" | bc)

# 4. Return Dice coefficent
echo "Dice coefficient: ${DSC}"