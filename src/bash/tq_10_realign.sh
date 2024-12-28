#!/bin/bash

# Part 1. Realign PMPBB3 PET to MRI
# This script does
# 1. realign T1 image to MNI152_T1_1mm_brain
# 2. realign PMPBB3 dynamic PET image to T1

# Prerequisites
# The first character of ID must be capital.
# T1w: ${ID}_t1w.nii*
# dynamic PET: ${ID}_pmpbb3_dyn.nii*

# Outputs
# T1w: ${ID}_t1w_r.nii
# dynamic PET: ${ID}_pmpbb3_dyn_mean.nii

# K. Nemoto and K. Nakayama 11 Jul 2023

# For Debug
#set -x

# output type is .nii not .nii.gz
FSLOUTPUTTYPE=NIFTI

# Load environment variable
THAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; cd ../.. ; pwd)
source ${THAMEQDIR}/config.env

for f in [A-Z]*_pmpbb3_dyn.nii*
do
  pet=$(imglob $f) # PET filename
  t1w=${pet/pmpbb3_dyn/t1w} # T1 filename
  ref=${FSLDIR}/data/standard/MNI152_T1_1mm_brain # Template path
  pad=MNI152_T1_1mm_pad # padded images
  
  # If ${ID}_pmpbb3_dyn_cor.nii.gz exists, it takes priority over ${ID}_pmpbb3_dyn.nii.gz.
  # Save manual edits as ${ID}_pmpbb3_dyn_cor.nii.gz.
  if [ -e ${pet}_cor.nii* ] ; then
    pet=${pet}_cor
  fi
  
  ### Create MNI152_T1_1mm_pad with the same FOV of the T1 image.
  # Calculate the required number of voxels for each side.
  xsize=$( echo "$(fslval ${t1w} dim1) * $(fslval ${t1w} pixdim1)" | bc )
  ysize=$( echo "$(fslval ${t1w} dim2) * $(fslval ${t1w} pixdim2)" | bc )
  zsize=$( echo "$(fslval ${t1w} dim3) * $(fslval ${t1w} pixdim3)" | bc )
  
  # Determine the starting position to ensure the padding is even in each direction.
  xmin=$(echo "($(fslval ${ref} dim1) - ${xsize})/2" | bc)
  ymin=$(echo "($(fslval ${ref} dim2) - ${ysize})/2" | bc)
  zmin=$(echo "($(fslval ${ref} dim3) - ${zsize})/2" | bc)
  
  # Get the image
  fslroi ${ref} ${pad} ${xmin} ${xsize} ${ymin} ${ysize} ${zmin} ${zsize}
  
  # Reorient T1
  echo "Reorient ${t1w}"
  fslreorient2std ${t1w} ${t1w}_o
  
  # Rigid body transform of T1 to MNI
  echo "Rigid body transform of ${t1w} to MNI"
  bet ${t1w}_o ${t1w}_brain -R -B -f 0.20 # Brain Extraction
  flirt -dof 6 -in ${t1w}_brain -ref ${pad} -omat ${t1w}2MNI.mat # Conversion matrix from native space to MNI
  flirt -in ${t1w}_o -ref ${pad} -applyxfm -init ${t1w}2MNI.mat -out ${t1w}_r # Realign T1 image to MNI template
   
  # Define the reference image of PET
  petref=${t1w}_r
  ###############################
  # This script creates PET Mean image by aligning each PET frame to the t1w image.
  # If you want PET Mean image created by the method written in K.Tagai(2022),
  # please revive the below commentout-commands
  
<< COMMENTOUT
  # Calculate a mean image from first two images of PET
  echo "Calculate a mean image of PET"
  fslroi ${pet} ${pet}_two 0 2 
  fslmaths ${pet}_two -Tmean ${pet}_m
  
  # Realign mean PET to realigned T1
  echo "Realign mean PET to realigned T1"
  flirt -dof 6 -in ${pet}_m -ref ${t1w}_r -out ${pet}_mr
  petref=${pet}_mr
COMMENTOUT

  ###############################

  ## Split PET frames as tmp????.nii
  echo "Split PET frames"
  fslsplit ${pet} tmp
  
  ## Realign each PET frame to T1 image
  echo "Realign each PET frame to reference image"
  for t in tmp*.nii
  do 
    flirt -dof 6 -in $t -ref ${petref} -out ${t%.nii}_r
  done
  
  # Merge realigned frames
  echo "Merge realigned frames"
  fslmerge -t ${pet}_r tmp*r.nii

  # Calculate mean of realigned PET images and
  # divide the image by voxel size to produce kbq/cc image
  pixdim1=$(fslval ${pet}_r pixdim1)
  pixdim2=$(fslval ${pet}_r pixdim2)
  pixdim3=$(fslval ${pet}_r pixdim3)
  voxsize=$(echo "$pixdim1 * $pixdim2 * $pixdim3 * 1000" | bc)
  
  echo "Calculate mean of realigned PET images"
  fslmaths ${pet}_r -Tmean -div $voxsize ${pet%_cor}_mean
  
  # Delete temporary files
  rm -f ${t1w}_o.nii tmp*.nii ${pad}.nii

  echo "Please check the registration of ${t1w}_r and ${pet%_cor}_mean"

done

exit
