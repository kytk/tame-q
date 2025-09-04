#!/bin/bash

### TAME-Q tq_42_suvr_cer.sh
### Objectives:
# This script performs semi-quantification of static PET images using cerebellum reference, generating SUVR images.

### Prerequisites:
# - FSL: Required for image processing.
# - FreeSurfer: Required for convertion from mgz to NIfTI.

### Usage:
# 1. Ensure the following files are present in the directory:
#    - ${ID}_pmpbb3_dyn_mean.nii
#    - subjects/${ID}/mri/wmparc.mgz
# 2. Run the script: tq_42_suvr_cer.sh

### Main Outputs:
# ${ID}_pmpbb3_suvr_cer.nii.gz: SUVR PET image based on the cerebellum cortex signal intensity.
# ${ID}_wmparc_r.nii.gz: Brain parcellation image.

### License:
# This script is distributed under the GNU General Public License version 3.
# See LICENSE file for details.

# K. Nakayama 21 Mar 2023

# For Debug
#set -x

# Load environment variable
TAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; cd ../.. ; pwd)
source ${TAMEQDIR}/config.env
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
