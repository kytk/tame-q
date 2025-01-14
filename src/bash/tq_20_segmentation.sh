#!/bin/bash

### THAME-Q tq_20_segmentation.sh
### Objectives:
# This script generates probability maps for gray matter and white matter from T1-weighted images.

### Prerequisites:
# - FSL: Required for image processing.
# - SPM12: Required for generating probability maps.

### Usage:
# 1. Ensure that images (${ID}_t1w_r.nii) are in the directory.
# 2. Run the script: tq_20_segmentation.sh

### Main Outputs:
# c1${ID}_t1w_r.nii: probability map of gray matter
# c2${ID}_t1w_r.nii: probability map of white matter
# c1MABB_001_t1w_r_q.nii.gz: probability map of gray matter after being masked by white matter mask

### License:
# This script is distributed under the GNU General Public License version 3.
# See LICENSE file for details.

# K. Nemoto and K. Nakayama 11 Jul 2023

# For Debug
#set -x

# Load environment variable
THAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; cd ../.. ; pwd)
source ${THAMEQDIR}/config.env

# Prevent error
if [[ "${THAMEQDIR}" = $PWD ]] ; then
  echo "Don't run this script in this directory"
  exit 1
fi

# Copy .m file to pwd
cp ${THAMEQDIR}/src/matlab/segmentation.m $PWD

# Run segmentation.m
#/usr/local/spm12_standalone/run_spm12.sh /usr/local/MATLAB/MCR/v99 batch ./segmentation.m
#spm batch ./segmentation.m
${SPM12STANDALONEDIR}/run_spm12.sh ${MCRDIR}/v99 batch ./segmentation.m

if [ $? -ne 0 ]; then
  echo "SPM12 standalone does not work correctly."
  echo "Switching to use MATLAB."
  
  # Add 'run batch' to the .m file
  echo '' >> segmentation.m
  echo "spm_jobman('run',matlabbatch);" >> segmentation.m

  #Run segmentation.m
  matlab -nodesktop -nosplash -r 'segmentation; exit'
fi

# Delete .m file
rm segmentation.m

# Fill holes in c2 images, and mask out c1 from c2
for f in c1*_t1w_r.nii; do
  f=${f#c1}
  f=${f%.nii}
  fslmaths c2${f} -thr 0.3 -bin -fillh -binv c2${f}_invmask
  fslmaths c1${f} -mas c2${f}_invmask c1${f}_q
done

exit
