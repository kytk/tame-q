#!/bin/bash

# Calculating SUVR of PMPBB3 PET
# Part 2. Segmentation based on SPM12

# This script does SPM12 segmentation of T1w images

# prerequisite: Install MATLAB and SPM12
# K. Nemoto 18 Mar 2023

# For Debugging
# set -x

# Load environment variable
THAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; cd ../.. ; pwd)
source ${THAMEQDIR}/config.env

# prevent error
if [[ "${THAMEQDIR}" = $PWD ]] ; then
  echo "Don't run this script in this directory"
  exit 1
fi

#copy .m file to pwd
cp ${THAMEQDIR}/src/matlab/segmentation.m $PWD

#run segmentation.m
#/usr/local/spm12_standalone/run_spm12.sh /usr/local/MATLAB/MCR/v99 batch ./segmentation.m
#spm batch ./segmentation.m
${SPM12STANDALONEDIR}/run_spm12.sh ${MCRDIR}/v99 batch ./segmentation.m

if [ $? -ne 0 ]; then
  echo "SPM12 standalone does not work correctly."
  echo "Switching to use MATLAB."
  
  # Add 'run batch' to the .m file
  echo '' >> segmentation.m
  echo "spm_jobman('run',matlabbatch);" >> segmentation.m

  #run segmentation.m
  matlab -nodesktop -nosplash -r 'segmentation; exit'
fi

#delete .m file
rm segmentation.m

#fill holes in c2 images, and mask out c1 from c2
for f in c1*_t1w_r.nii; do
  f=${f#c1}
  f=${f%.nii}
  fslmaths c2${f} -thr 0.3 -bin -fillh -binv c2${f}_invmask
  fslmaths c1${f} -mas c2${f}_invmask c1${f}_q
done

exit
