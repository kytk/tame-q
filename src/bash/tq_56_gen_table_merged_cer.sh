#!/bin/bash

### THAME-Q tq_56_gen_table_merged_cer.sh
### Objectives:
# This script generates a table of SUVR values for each ROI in merged wmparc based on semi-quantification using the cerebellum cortex reference

### Prerequisites:
# - FSL: Required for image processing.
# - FreeSurfer: Required for conversion from mgz to NIfTI format.

### Usage:
# 1. Ensure the following files are present in the directory:
#    - ${ID}_pmpbb3_suvr_cer.nii.gz
#    - ${ID}_wmparc_r.nii.gz
#    - subjects/${ID}/mri/brainstemSsLabels.v??.FSvoxelSpace.mgz
# 2. Run the script: tq_56_gen_table_merged_cer.sh

### Main Outputs:
# - ${ID}_pmpbb3_suvr_cer_wmparc_merged_mean.tsv: A table of SUVR values for each ROI in merged wmparc, based on the cerebellum cortex reference for ${ID}.
# - suvr_cer_wmparc_merged_mean_[timestamp].tsv: A consolidated table of SUVR values for merged wmparc ROIs across subjects, based on the cerebellum cortex reference.

### License:
# This script is distributed under the GNU General Public License version 3.
# See LICENSE file for details.

# K. Nakayama 08 Aug 2024

# For Debug
#set -x

# Load environment variable
THAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; cd ../.. ; pwd)
source ${THAMEQDIR}/config.env
export SUBJECTS_DIR=$PWD/subjects

for f in *_pmpbb3_suvr_cer.nii.gz
do
  fsid=${f%_pmpbb3_suvr_cer.nii.gz}
  wmparc=${fsid}_wmparc_merged
  
  if [[ ! -e ${wmparc}_r.nii.gz ]]; then
    echo "Not found: ${wmparc}_r"
    continue
  fi
  
  # copy brainstemSsLabels*.FSvoxelSpace.mgz, add fsid, and convert to nii.gz
  bsseg=${fsid}_bsseg
  if [[ ! -e ${bsseg}_r.nii.gz ]]; then
    echo "copy brainstemSsLabels.v??.FSvoxelSpace.mgz, add fsid, and convert to nii.gz"
    find $PWD/subjects/${fsid} -name 'brainstemSsLabels.v??.FSvoxelSpace.mgz' -exec cp {} ${bsseg}.mgz \;
    mri_label2vol --seg ${bsseg}.mgz --temp $f --o ${bsseg}_r.mgz --regheader ${bsseg}.mgz
    mri_convert ${bsseg}_r.{mgz,nii.gz} --out_orientation $(mri_info $f | grep Orientation | awk '{ print $3 }')
    rm *.mgz
  fi

  echo "extract mean SUVR within merged wmparc rois of ${fsid}"
  echo "${fsid}" > ${fsid}_pmpbb3_suvr_cer_wmparc_merged_mean.tsv
  
  # divide wmparc_merged.nii.gz into five subregions and calc mean for each region
  # aseg and brainstem
  fslmaths ${wmparc}_r.nii.gz -uthr 999.5 ${wmparc}_r_0000.nii.gz
  fslstats -K ${wmparc}_r_0000.nii.gz $f -M > tmp_${fsid}_suvr_cer_wmparc_merged_mean_0000
  cat tmp_${fsid}_suvr_cer_wmparc_merged_mean_0000 | sed -n '7,8p;10,13p;17,18p;26p;28p;46,47p;49,54p;58p;60p;251,255p' >> ${fsid}_pmpbb3_suvr_cer_wmparc_merged_mean.tsv
  
  fslstats -K ${bsseg}_r.nii.gz $f -M > tmp_${fsid}_suvr_cer_bsseg_mean
  cat tmp_${fsid}_suvr_cer_bsseg_mean | sed -n '173,175p;178p' >> ${fsid}_pmpbb3_suvr_cer_wmparc_merged_mean.tsv
  
  # 1000: lt cortex; 2000: rt cotex 
  # 3000: lt subcortical wm; 4000: rt subcortical wm
  for num in 1000 2000 3000 4000
  do
    lthr=$((num - 1))
    uthr=$((num + 999))
    fslmaths ${wmparc}_r.nii.gz -thr ${lthr}.5 -uthr ${uthr}.5 -sub ${num} \
      ${wmparc}_r_${num}.nii.gz
    fslstats -K ${wmparc}_r_${num}.nii.gz $f -M >\
        tmp_${fsid}_suvr_cer_wmparc_merged_mean_${num}
    cat tmp_${fsid}_suvr_cer_wmparc_merged_mean_${num} |\
        sed -n '1,3p;5,9p;11,13p;15,18p;21,22p;24,25p;28,31p;33,35p' >> ${fsid}_pmpbb3_suvr_cer_wmparc_merged_mean.tsv
  done
  
done

# Header
cat << EOS > colheader_merged.txt
Region                        
Lt-Cerebellum-White-Matter
Lt-Cerebellum-Cortex
Lt-Thalamus
Lt-Caudate
Lt-Putamen
Lt-Pallidum
Lt-Hippocampus
Lt-Amygdala
Lt-Accumbens-area
Lt-VentralDC
Rt-Cerebellum-White-Matter
Rt-Cerebellum-Cortex
Rt-Thalamus
Rt-Caudate
Rt-Putamen
Rt-Pallidum
Rt-Hippocampus
Rt-Amygdala
Rt-Accumbens-area
Rt-VentralDC
CC_Posterior
CC_Mid_Posterior
CC_Central
CC_Mid_Anterior
CC_Anterior
Midbrain
Pons
Medulla
SCP
Lt-bankssts
Lt-cingulate
Lt-middlefrontal
Lt-cuneus
Lt-entorhinal
Lt-fusiform
Lt-inferiorparietal
Lt-inferiortemporal
Lt-lateraloccipital
Lt-orbitofrontal
Lt-lingual
Lt-middletemporal
Lt-parahippocampal
Lt-paracentral
Lt-inferiorfrontal
Lt-pericalcarine
Lt-postcentral
Lt-precentral
Lt-precuneus
Lt-superiorfrontal
Lt-superiorparietal
Lt-superiortemporal
Lt-supramarginal
Lt-temporalpole
Lt-transversetemporal
Lt-insula
Rt-bankssts
Rt-cingulate
Rt-middlefrontal
Rt-cuneus
Rt-entorhinal
Rt-fusiform
Rt-inferiorparietal
Rt-inferiortemporal
Rt-lateraloccipital
Rt-orbitofrontal
Rt-lingual
Rt-middletemporal
Rt-parahippocampal
Rt-paracentral
Rt-inferiorfrontal
Rt-pericalcarine
Rt-postcentral
Rt-precentral
Rt-precuneus
Rt-superiorfrontal
Rt-superiorparietal
Rt-superiortemporal
Rt-supramarginal
Rt-temporalpole
Rt-transversetemporal
Rt-insula
Lt-wm-bankssts
Lt-wm-cingulate
Lt-wm-middlefrontal
Lt-wm-cuneus
Lt-wm-entorhinal
Lt-wm-fusiform
Lt-wm-inferiorparietal
Lt-wm-inferiortemporal
Lt-wm-lateraloccipital
Lt-wm-orbitofrontal
Lt-wm-lingual
Lt-wm-middletemporal
Lt-wm-parahippocampal
Lt-wm-paracentral
Lt-wm-inferiorfrontal
Lt-wm-pericalcarine
Lt-wm-postcentral
Lt-wm-precentral
Lt-wm-precuneus
Lt-wm-superiorfrontal
Lt-wm-superiorparietal
Lt-wm-superiortemporal
Lt-wm-supramarginal
Lt-wm-temporalpole
Lt-wm-transversetemporal
Lt-wm-insula
Rt-wm-bankssts
Rt-wm-cingulate
Rt-wm-middlefrontal
Rt-wm-cuneus
Rt-wm-entorhinal
Rt-wm-fusiform
Rt-wm-inferiorparietal
Rt-wm-inferiortemporal
Rt-wm-lateraloccipital
Rt-wm-orbitofrontal
Rt-wm-lingual
Rt-wm-middletemporal
Rt-wm-parahippocampal
Rt-wm-paracentral
Rt-wm-inferiorfrontal
Rt-wm-pericalcarine
Rt-wm-postcentral
Rt-wm-precentral
Rt-wm-precuneus
Rt-wm-superiorfrontal
Rt-wm-superiorparietal
Rt-wm-superiortemporal
Rt-wm-supramarginal
Rt-wm-temporalpole
Rt-wm-transversetemporal
Rt-wm-insula
EOS

echo "generate table"
timestamp=$(date +%Y%m%d_%H%M)
paste colheader_merged.txt *_suvr_cer_wmparc_merged_mean.tsv > suvr_cer_wmparc_merged_mean_${timestamp}.tsv

rm colheader_merged.txt tmp_*_suvr_cer_wmparc_merged_mean_?000 tmp_*_suvr_cer_bsseg_mean *_r_?000.nii.gz

echo "Done. Please check suvr_cer_wmparc_merged_mean_${timestamp}.tsv"
