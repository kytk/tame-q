#!/bin/bash

# Calculating SUVR of PMPBB3 PET
# Part 5. Calculate SUVR for cortex regions

# This script does
# 1. generate cortical region of interests (ROIs) from aseg and DKT atlas
# 2. extract mean SUVRs for each ROI
# 3. generate a table with timestamp

# K. Nemoto and K. Nakayama 09 May 2023

# For debugging
#set -x

export SUBJECTS_DIR=$PWD/subjects

for f in *_pmpbb3_dyn_mean.nii
do
  fsid=${f%_pmpbb3_dyn_mean.nii}
  wmparc=${fsid}_wmparc
  
  # copy wmparc.mgz, add fsid, and convert to nii.gz
  if [[ ! -e ${wmparc}_r.nii.gz ]]; then
    echo "copy wmparc.mgz, add fsid, and convert to nii.gz"
    find $PWD/subjects/${fsid} -name 'wmparc.mgz' -exec cp {} ${wmparc}.mgz \;
    mri_label2vol --seg ${wmparc}.mgz --temp $f --o ${wmparc}_r.mgz --regheader ${wmparc}.mgz
    mri_convert ${wmparc}_r.{mgz,nii.gz} --out_orientation $(mri_info $f | grep Orientation | awk '{ print $3 }')
    rm *.mgz
  fi
  
  # SUVR images within Cerebellum-Cortex Reference 
  if [[ ! -e ${fsid}_pmpbb3_suvr_cer.nii.gz ]]; then
    # Left-Cerebellum-Cortex: 8, Right-Cerebellum-Cortex: 47 in FreeSurferColorLUT.txt
    fslmaths ${wmparc}_r.nii.gz -thr 7.5 -uthr 8.5 -bin ${fsid}_wmparc_r_8.nii.gz
    fslmaths ${wmparc}_r.nii.gz -thr 46.5 -uthr 47.5 -bin ${fsid}_wmparc_r_47.nii.gz
    fslmaths ${fsid}_wmparc_r_8.nii.gz -add ${fsid}_wmparc_r_47.nii.gz ${fsid}_cerebellum-cortex_mask.nii.gz
    
    ref=$(fslstats -K ${fsid}_cerebellum-cortex_mask.nii.gz ${fsid}_pmpbb3_dyn_mean.nii -m)
    fslmaths ${f} -div ${ref} ${fsid}_pmpbb3_suvr_cer.nii.gz
    rm ${fsid}_wmparc_r_8.nii.gz ${fsid}_wmparc_r_47.nii.gz
  fi
done

exit