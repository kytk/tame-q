#!/bin/bash

### THAME-Q tq_53_merge_wmparc.sh
### Objectives:
# This script creates a merged atlas, `wmparc_merged`, by combining smaller cortical areas in the wmparc into anatomically unified regions.
# This merging is intended to increase the sampling size for each ROI, contributing to more stable SUVR values across ROIs.

### Prerequisites:
# - FSL: Required for image processing.

### Usage:
# 1. Ensure the following file is present in the directory:
#    - ${ID}_pmpbb3_wmparc_r.nii.gz
# 2. Run the script: tq_53_merge_wmparc.sh

### Main Outputs:
# - ${ID}_wmparc_merged_r.nii.gz: The ROI map image of `wmparc_merged` with smaller regions merged into larger, anatomically unified areas.

### License:
# This script is distributed under the GNU General Public License version 3.
# See LICENSE file for details.

# K. Nakayama 08 Aug 2024

# For Debug
#set -x

# Load environment variable
THAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; cd ../.. ; pwd)
source ${THAMEQDIR}/config.env

for f in *_wmparc_r.nii.gz
do
  echo "Get merged wmparc from ${f} "

  # middlefrontal
  f_merged=${f/wmparc/wmparc_merged}
  fslmaths ${f} -thr 1000 -rem 1000 -thr 27 -uthr 27 -sub 3 -thr 0 tmp4sub
  fslmaths ${f} -sub tmp4sub ${f_merged}
  
  #inferiorfrontal
  fslmaths ${f} -thr 1000 -rem 1000 -thr 19 -uthr 20 -sub 18 -thr 0 tmp4sub
  fslmaths ${f_merged} -sub tmp4sub ${f_merged}
  
  #orbitofrontal (medialorbitofraonal)
  fslmaths ${f} -thr 1000 -rem 1000 -thr 14 -uthr 14 -sub 12 -thr 0 tmp4sub
  fslmaths ${f_merged} -sub tmp4sub ${f_merged}
  
  #orbitofrontal (frontalpole)
  fslmaths ${f} -thr 1000 -rem 1000 -thr 32 -uthr 32 -sub 12 -thr 0 tmp4sub
  fslmaths ${f_merged} -sub tmp4sub ${f_merged}
  
  #cingulate(isthmuscingulate)
  fslmaths ${f} -thr 1000 -rem 1000 -thr 10 -uthr 10 -sub 2 -thr 0 tmp4sub
  fslmaths ${f_merged} -sub tmp4sub ${f_merged}
  
  #cingulate(poasteriorcingulate)
  fslmaths ${f} -thr 1000 -rem 1000 -thr 23 -uthr 23 -sub 2 -thr 0 tmp4sub
  fslmaths ${f_merged} -sub tmp4sub ${f_merged}
  
  #cingulate(rostralanteriorcingulate)
  fslmaths ${f} -thr 1000 -rem 1000 -thr 26 -uthr 26 -sub 2 -thr 0 tmp4sub
  fslmaths ${f_merged} -sub tmp4sub ${f_merged}
  
  echo "Save ${f_merged}"
  
  rm tmp4sub.nii.gz
done

