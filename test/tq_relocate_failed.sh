#!/bin/bash

# Relocate failed files into the original directory

# Usage: tq_relocate_failed.sh <ID>

# K. Nakayama 23 Apr 2025

# For debugging
#set -x

# Load environment variable
THAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; cd .. ; pwd)
source ${THAMEQDIR}/config.env

ID=$1
for d in $(find ./failed -maxdepth 2 -name "$ID" -type d); do
  mkdir -p histogram_GMref histogram_WMref subjects
  [[ -e ${d}/histogram_GMref ]] && find ${d}/histogram_GMref -type f -exec mv {} ./histogram_GMref \;
  [[ -e ${d}/histogram_WMref ]] && find ${d}/histogram_WMref -type f -exec mv {} ./histogram_WMref \;
  [[ -e ${d}/subjects/${ID} ]] && mv ${d}/subjects/${ID} ./subjects;
  find ${d} -maxdepth 1 -type f -exec mv {} . \;
  
  if ! find $d -type f | grep -q .; then
    find $d -depth -type d -exec rmdir {} \;
  fi
  rmdir --ignore-fail-on-non-empty histogram_GMref histogram_WMref subjects  
done

exit
