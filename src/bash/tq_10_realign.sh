#!/bin/bash

### THAME-Q tq_10_realign.sh
### Objectives:
# This script is designed to realign MRI (T1-weighted) and dynamic PET images to a standard brain template (MNI152).
# The process includes brain extraction, rigid body transformation, and realignment of individual PET frames.

### Prerequisites:
# - FSL: Required for brain extraction, image realignment, etc. in this script.

### Usage:
# 1. Ensure input files (${ID}_t1w.nii and ${ID}_pmpbb3_dyn.nii) are in the directory.
#    (The first character of ID must be capital.)
# 2. Run the script: tq_10_realign.sh

### Main Outputs:
# ${ID}_t1w_r.nii: t1w image in MNI space
# ${ID}_pmpbb3_dyn_mean.nii: static PET image in MNI space
# ${ID}_t1w2MNI.mat: Rigid transformation matrix from t1 native space to MNI space

### License:
# This script is distributed under the GNU General Public License version 3.
# See LICENSE file for details.

# K. Nemoto and K. Nakayama 11 Jul 2023

# For Debug
#set -x

# output type is .nii not .nii.gz
FSLOUTPUTTYPE=NIFTI

# Load environment variable
THAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; cd ../.. ; pwd)
source ${THAMEQDIR}/config.env

# Create a basis for coregistration QC
QCT1W=./coregistration_results_t1w.csv
echo "ID,Dice,Dx,Dy,Dz,Rx,Ry,Rz" > ${QCT1W}

QCPET=./coregistration_results_pet.csv
echo "ID,Rmax1,Rmax2,Rmax3,Rmax4,Rmax,Dice" > ${QCPET}

# Define util function
function calc_dice() {
  overlap=$(fslstats $1 -k $2 -V | awk -F ' ' '{print $1}')
  union=$(echo "$(fslstats $1 -V | awk -F ' ' '{print $1}') + $(fslstats $2 -V | awk -F ' ' '{print $1}')" | bc)
  echo "scale=3;$overlap*2/$union" | bc
}

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
  
  # Evaluation for T1 x MNI coregistratioin
  mri_synthstrip -i ${t1w}_r.nii -m ${t1w}_r_stripmask.nii.gz
  mri_synthstrip -i ${pad}.nii -m ${t1w%_t1w}_mnipad_stripmask.nii.gz
  DICE_T1W=$(calc_dice ${t1w}_r_stripmask.nii.gz ${t1w%_t1w}_mnipad_stripmask.nii.gz)
  Dx_T1W=$(avscale --allparams ${t1w}2MNI.mat | grep 'Translations' | awk -F ' ' '{print $5}')
  Dy_T1W=$(avscale --allparams ${t1w}2MNI.mat | grep 'Translations' | awk -F ' ' '{print $6}')
  Dz_T1W=$(avscale --allparams ${t1w}2MNI.mat | grep 'Translations' | awk -F ' ' '{print $7}')
  Rx_T1W=$(avscale --allparams ${t1w}2MNI.mat | grep 'Rotation Angles' | awk -F ' ' '{print $6}')
  Ry_T1W=$(avscale --allparams ${t1w}2MNI.mat | grep 'Rotation Angles' | awk -F ' ' '{print $7}')
  Rz_T1W=$(avscale --allparams ${t1w}2MNI.mat | grep 'Rotation Angles' | awk -F ' ' '{print $8}')
  
  echo "${t1w%_t1w},$DICE_T1W,$Dx_T1W,$Dy_T1W,$Dz_T1W,$Rx_T1W,$Ry_T1W,$Rz_T1W" >> ${QCT1W}

  # Define the reference image of PET
  #petref=${t1w}_r
  ###############################
  # This script creates PET Mean image by aligning each PET frame to the t1w image.
  # If you want PET Mean image created by the method written in K.Tagai(2022),
  # please revive the below commentout-commands
  
#<< COMMENTOUT
  # Calculate a mean image from first two images of PET
  echo "Calculate a mean image of PET"
  fslroi ${pet} ${pet}_two 0 2 
  fslmaths ${pet}_two -Tmean ${pet}_ref
  
  petref=${pet}_ref
#COMMENTOUT

  ###############################

  ## Split PET frames as ${pet}_f????.nii
  echo "Split PET frames"
  fslsplit ${pet} ${pet}_f
  
  ## Which PET frame shows the highest Dice coefficient in the coregistration to T1W
  echo "Realign each PET frame to reference image"
  #for t in ${pet}_f*.nii
  #do 
    #flirt -dof 6 -in $t -ref ${petref} -cost normmi -searchcost normmi -out ${t%.nii}_r
    #mri_synthstrip -i ${t%.nii}_r.nii -m ${t%.nii}_r_stripmask.nii
    #tmp_dice_value=$(calc_dice ${t1w}_r_stripmask.nii.gz ${t%.nii}_r_stripmask.nii)

    #if [[ -z "$min_dice_value" ]] || [[ $min_dice_value > $tmp_dice_value ]]; then
    #  min_dice_value=$tmp_dice_value
    #  min_dice_frame=$t
    #fi
  #done

  ## PET frames are realigned, averaged, and coregistered to T1W
  for t in ${pet}_f*.nii
  do 
    flirt -dof 6 -in $t -ref ${petref} -cost normmi -searchcost normmi -omat ${t%.nii}_align.mat -out ${t%.nii}_align
  done
    
  # Merge realigned frames
  echo "Merge realigned frames"
  fslmerge -t ${pet}_align ${pet}_f*_align.nii

  # Calculate mean of realigned PET images and
  # divide the image by voxel size to produce kbq/cc image
  pixdim1=$(fslval ${pet}_align pixdim1)
  pixdim2=$(fslval ${pet}_align pixdim2)
  pixdim3=$(fslval ${pet}_align pixdim3)
  voxsize=$(echo "scale=3;$pixdim1 * $pixdim2 * $pixdim3 * 1000" | bc)
  
  echo "Calculate mean of realigned PET images"
  fslmaths ${pet}_align -Tmean -div $voxsize ${pet%_cor}_align_mean

  flirt -dof 6 -in ${pet%_cor}_align_mean -ref ${t1w}_r -cost normmi -searchcost normmi -omat ${t1w%_t1w}_PET2T1W.mat -out ${pet%_cor}_mean
  
  mri_synthstrip -i ${pet%_cor}_mean.nii -m ${pet%_cor}_mean_stripmask.nii.gz
  DICE_PET=$(calc_dice ${t1w}_r_stripmask.nii.gz ${pet%_cor}_mean_stripmask.nii.gz)
  Dx_PET=$(avscale --allparams ${t1w%_t1w}_PET2T1W.mat | grep 'Translations' | awk -F ' ' '{print $5}')
  Dy_PET=$(avscale --allparams ${t1w%_t1w}_PET2T1W.mat | grep 'Translations' | awk -F ' ' '{print $6}')
  Dz_PET=$(avscale --allparams ${t1w%_t1w}_PET2T1W.mat | grep 'Translations' | awk -F ' ' '{print $7}')
  Rx_PET=$(avscale --allparams ${t1w%_t1w}_PET2T1W.mat | grep 'Rotation Angles' | awk -F ' ' '{print $6}')
  Ry_PET=$(avscale --allparams ${t1w%_t1w}_PET2T1W.mat | grep 'Rotation Angles' | awk -F ' ' '{print $7}')
  Rz_PET=$(avscale --allparams ${t1w%_t1w}_PET2T1W.mat | grep 'Rotation Angles' | awk -F ' ' '{print $8}')

  echo "${t1w%_t1w},$DICE_PET,$Dx_PET,$Dy_PET,$Dz_PET,$Rx_PET,$Ry_PET,$Rz_PET" >> ${QCPET}

  # Delete temporary files
  #rm -f ${t1w}_o.nii

  echo "Please check the registration of ${t1w}_r and ${pet%_cor}_mean"

done

exit
