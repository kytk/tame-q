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
echo "ID,Rx,Ry,Rz,Dice" > ${QCT1W}

QCPET=./coregistration_results_pet.csv
echo "ID,Rmax_frame,Rx_mean,Ry_mean,Rz_mean,Dice" > ${QCPET}

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
  #bet ${t1w}_o ${t1w}_brain -R -B -f 0.20 # Brain Extraction
  mri_synthstrip -i ${t1w}_o.nii -o ${t1w}_brain.nii -m ${t1w}_brain_mask.nii
  flirt -dof 6 -in ${t1w}_brain -ref ${pad} -omat ${t1w}2MNI.mat # Conversion matrix from native space to MNI
  flirt -dof 6 -in ${t1w}_o -ref ${pad} -applyxfm -init ${t1w}2MNI.mat -out ${t1w}_r # Realign T1 image to MNI template
  flirt -dof 6 -in ${t1w}_brain_mask.nii -ref ${pad} -interp nearestneighbour -applyxfm -init ${t1w}2MNI.mat -out ${t1w}_brain_mask_r.nii
  
  # Evaluation for T1 x MNI coregistratioin
  mri_synthstrip -i ${pad}.nii -m ${t1w%_t1w}_mnipad_stripmask.nii.gz
  DICE_T1W=$(calc_dice ${t1w}_brain_mask_r.nii ${t1w%_t1w}_mnipad_stripmask.nii.gz)
  R_T1W=$(avscale --allparams ${t1w}2MNI.mat | grep 'Rotation Angles' | awk -F '= ' '{print $2}' | sed 's/ /,/g')
  echo "${t1w%_t1w},${R_T1W%,},$DICE_T1W" >> ${QCT1W}

  ## Split PET frames as ${pet}_f????.nii
  echo "Split PET frames"
  fslsplit ${pet} ${pet}_f

    # Calculate a mean image from first two images of PET
  echo "Calculate a mean image of PET as target"
  if [[ $(ls | grep ${pet}_f) >2 ]]; then
    fslroi ${pet} ${pet}_two 0 2 
    fslmaths ${pet}_two -Tmean ${pet}_ref  
    petref=${pet}_ref
  else
    petref=${pet}_f0000.nii
  fi

    ## PET frames are realigned, averaged, and coregistered to T1W
  echo "Realign each PET frame to target image"
  for t in ${pet}_f*.nii
  do 
    flirt -dof 6 -in $t -ref ${petref} -cost normmi -searchcost normmi -omat ${t%.nii}_align.mat -out ${t%.nii}_align
    Rf="${Rf} $(avscale --allparams ${t%.nii}_align.mat | grep 'Rotation Angles' | awk -F '= ' '{print $2}')"
  done
  Rmaxf=$(for v in $Rf; do echo $v; done | sort -nr | head -n1)

  # Merge realigned frames and mean them
  echo "Merge realigned frames"
  fslmerge -t ${pet}_align ${pet}_f*_align.nii
  fslmaths ${pet}_align -Tmean ${pet}_align_mean
  #flirt -dof 6 -in ${pet}_align_mean -ref ${t1w}_r -cost normmi -searchcost normmi -omat ${t1w%_t1w}_PET2T1W.mat -out ${pet%_cor}_mean
  ${THAMEQDIR}/src/python/cen2cen.py ${pet}_align_mean.nii ${t1w}_r.nii ${pet}_align_mean_trans.nii
  flirt -dof 6 -in ${pet}_align_mean_trans -ref ${t1w}_r -cost normmi -searchcost normmi -omat ${t1w%_t1w}_PET2T1W.mat -out ${pet%_cor}_mean

  # Calculate mean of realigned PET images and
  # divide the image by voxel size to produce kbq/cc image
  pixdim1=$(fslval ${pet%_cor}_mean pixdim1)
  pixdim2=$(fslval ${pet%_cor}_mean pixdim2)
  pixdim3=$(fslval ${pet%_cor}_mean pixdim3)
  voxsize=$(echo "scale=3;$pixdim1 * $pixdim2 * $pixdim3" | bc)
  fslmaths ${pet%_cor}_mean -div $voxsize -div 1000 ${pet%_cor}_mean
  
  mri_synthstrip -i ${pet%_cor}_mean.nii -m ${pet%_cor}_mean_stripmask.nii.gz
  DICE_PET=$(calc_dice ${t1w}_brain_mask_r.nii ${pet%_cor}_mean_stripmask.nii.gz)
  R_PET=$(avscale --allparams ${t1w%_t1w}_PET2T1W.mat | grep 'Rotation Angles' | awk -F '= ' '{print $2}' | sed 's/ /,/g')

  echo "${t1w%_t1w},$Rmaxf,${R_PET%,},$DICE_PET" >> ${QCPET}

  # Create QA Report
  fslmaths ${pet%_cor}_mean_stripmask -ero tmpmask
  fslmaths ${pet%_cor}_mean_stripmask -sub tmpmask ${pet%_cor}_mean_outline

  mri_synthstrip -i ${petref}.nii -m ${petref}_stripmask.nii.gz
  fslmaths ${petref}_stripmask -ero tmpmask
  fslmaths ${petref}_stripmask -sub tmpmask ${petref}_outline
  rm tmpmask.nii

  ${THAMEQDIR}/src/python/qa_view.py ${t1w%_t1w} ${t1w}_r.nii ${pet%_cor}_mean.nii ${pet%_cor}_align.nii ${petref}.nii

  # Delete temporary files
  #rm -f ${t1w}_o.nii

  echo "Please check the registration of ${t1w}_r and ${pet%_cor}_mean"

done

exit
