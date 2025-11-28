#!/bin/bash

### TAME-Q tq_51_gen_table_wmparc_wm.sh
### Objectives:
# This script generates a table of SUVR values for each ROI in wmparc based on semi-quantification using the white matter reference.

### Prerequisites:
# - FSL: Required for image processing.
# - FreeSurfer: Required for conversion from mgz to NIfTI format.

### Usage:
# 1. Ensure the following files are present in the directory:
#    - ${ID}_pmpbb3_dyn_suvr_wm.nii.gz
#    - subjects/${ID}/mri/wmparc.mgz
#    - subjects/${ID}/mri/brainstemSsLabels.v??.FSvoxelSpace.mgz
# 2. Run the script: tq_51_gen_table_wmparc_wm.sh

### Main Outputs:
# - ${ID}_pmpbb3_suvr_wm_wmparc_mean.tsv: A table of SUVR values for each ROI in wmparc, based on the white matter reference for ${ID}.
# - suvr_wmparc_wm_mean_[timestamp].tsv: A consolidated table of SUVR values for wmparc ROIs across subjects, based on the white matter reference.

### License:
# This script is distributed under the GNU General Public License version 3.
# See LICENSE file for details.

# K. Nemoto and K. Nakayama 09 May 2023

# For Debug
#set -x

# Load environment variable
TAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; cd ../.. ; pwd)
source ${TAMEQDIR}/config.env
export SUBJECTS_DIR=$PWD/subjects

for f in *_pmpbb3_suvr_wm.nii.gz
do
  fsid=${f%_pmpbb3_suvr_wm.nii.gz}
  wmparc=${fsid}_wmparc
  
  # copy wmparc.mgz, add fsid, and convert to nii.gz
  if [[ ! -e ${wmparc}_r.nii.gz ]]; then
    echo "copy wmparc.mgz, add fsid, and convert to nii.gz"
    find $PWD/subjects/${fsid} -name 'wmparc.mgz' -exec cp {} ${wmparc}.mgz \;
    mri_label2vol --seg ${wmparc}.mgz --temp $f --o ${wmparc}_r.mgz --regheader ${wmparc}.mgz
    mri_convert ${wmparc}_r.{mgz,nii.gz} --out_orientation $(mri_info $f | grep Orientation | awk '{ print $3 }')
    rm *.mgz
  fi
  
  # copy brainstemSsLabels*.FSvoxelSpace.mgz, add fsid, and convert to nii.gz
  bsseg=${fsid}_bsseg
  if [[ ! -e ${bsseg}_r.nii.gz ]]; then
    echo "copy brainstemSsLabels.v??.FSvoxelSpace.mgz, add fsid, and convert to nii.gz"
    if [[ $(find $PWD/subjects/${fsid} -name 'brainstemSsLabels.v??.FSvoxelSpace.mgz' | wc -l) > 0 ]]; then
      find $PWD/subjects/${fsid} -name 'brainstemSsLabels.v??.FSvoxelSpace.mgz' -exec cp {} ${bsseg}.mgz \;
    elif [[ $(find $PWD/subjects/${fsid} -name 'brainstemSsLabels.FSvoxelSpace.mgz' | wc -l) > 0 ]]; then
      find $PWD/subjects/${fsid} -name 'brainstemSsLabels.FSvoxelSpace.mgz' -exec cp {} ${bsseg}.mgz \;
    fi
    mri_label2vol --seg ${bsseg}.mgz --temp $f --o ${bsseg}_r.mgz --regheader ${bsseg}.mgz
    mri_convert ${bsseg}_r.{mgz,nii.gz} --out_orientation $(mri_info $f | grep Orientation | awk '{ print $3 }')
    rm *.mgz
  fi

  echo "extract mean SUVR within White Matter Reference of ${fsid}"
  echo "${fsid}" > ${fsid}_pmpbb3_suvr_wm_wmparc_mean.tsv
  
  # aseg and brainstem
  fslmaths ${wmparc}_r.nii.gz -uthr 999.5 ${wmparc}_r_0000.nii.gz
  fslstats -K ${wmparc}_r_0000.nii.gz ${fsid}_pmpbb3_suvr_wm.nii.gz -M > tmp_${fsid}_suvr_wm_wmparc_mean_0000
  cat tmp_${fsid}_suvr_wm_wmparc_mean_0000 | sed -n '7,8p;10,13p;16,18p;26p;28p;46,47p;49,54p;58p;60p;85p;251,255p' >> ${fsid}_pmpbb3_suvr_wm_wmparc_mean.tsv
  
  fslstats -K ${bsseg}_r.nii.gz ${fsid}_pmpbb3_suvr_wm.nii.gz -M > tmp_${fsid}_suvr_wm_bsseg_mean
  cat tmp_${fsid}_suvr_wm_bsseg_mean | sed -n '173,175p;178p' >> ${fsid}_pmpbb3_suvr_wm_wmparc_mean.tsv
  
  # 1000: lt cortex; 2000: rt cotex 
  # 3000: lt subcortical wm; 4000: rt subcortical wm
  for num in 1000 2000 3000 4000
  do
    lthr=$((num - 1))
    uthr=$((num + 999))
    fslmaths ${wmparc}_r.nii.gz -thr ${lthr}.5 -uthr ${uthr}.5 -sub ${num} \
      ${wmparc}_r_${num}.nii.gz
    fslstats -K ${wmparc}_r_${num}.nii.gz ${fsid}_pmpbb3_suvr_wm.nii.gz -M >\
        tmp_${fsid}_suvr_wm_wmparc_mean_${num}
    cat tmp_${fsid}_suvr_wm_wmparc_mean_${num} |\
        sed -n '1,3p;5,35p' >> ${fsid}_pmpbb3_suvr_wm_wmparc_mean.tsv
  done
  
done

# Header
cat << EOS > colheader_wmparc.txt
Region                        
Lt-Cerebellum-White-Matter
Lt-Cerebellum-Cortex
Lt-Thalamus
Lt-Caudate
Lt-Putamen
Lt-Pallidum
Brain-Stem
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
Optic-Chiasm
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
Lt-caudalanteriorcingulate
Lt-caudalmiddlefrontal
Lt-cuneus
Lt-entorhinal
Lt-fusiform
Lt-inferiorparietal
Lt-inferiortemporal
Lt-isthmuscingulate
Lt-lateraloccipital
Lt-lateralorbitofrontal
Lt-lingual
Lt-medialorbitofrontal
Lt-middletemporal
Lt-parahippocampal
Lt-paracentral
Lt-parsopercularis
Lt-parsorbitalis
Lt-parstriangularis
Lt-pericalcarine
Lt-postcentral
Lt-posteriorcingulate
Lt-precentral
Lt-precuneus
Lt-rostralanteriorcingulate
Lt-rostralmiddlefrontal
Lt-superiorfrontal
Lt-superiorparietal
Lt-superiortemporal
Lt-supramarginal
Lt-frontalpole
Lt-temporalpole
Lt-transversetemporal
Lt-insula
Rt-bankssts
Rt-caudalanteriorcingulate
Rt-caudalmiddlefrontal
Rt-cuneus
Rt-entorhinal
Rt-fusiform
Rt-inferiorparietal
Rt-inferiortemporal
Rt-isthmuscingulate
Rt-lateraloccipital
Rt-lateralorbitofrontal
Rt-lingual
Rt-medialorbitofrontal
Rt-middletemporal
Rt-parahippocampal
Rt-paracentral
Rt-parsopercularis
Rt-parsorbitalis
Rt-parstriangularis
Rt-pericalcarine
Rt-postcentral
Rt-posteriorcingulate
Rt-precentral
Rt-precuneus
Rt-rostralanteriorcingulate
Rt-rostralmiddlefrontal
Rt-superiorfrontal
Rt-superiorparietal
Rt-superiortemporal
Rt-supramarginal
Rt-frontalpole
Rt-temporalpole
Rt-transversetemporal
Rt-insula
Lt-wm-bankssts
Lt-wm-caudalanteriorcingulate
Lt-wm-caudalmiddlefrontal
Lt-wm-cuneus
Lt-wm-entorhinal
Lt-wm-fusiform
Lt-wm-inferiorparietal
Lt-wm-inferiortemporal
Lt-wm-isthmuscingulate
Lt-wm-lateraloccipital
Lt-wm-lateralorbitofrontal
Lt-wm-lingual
Lt-wm-medialorbitofrontal
Lt-wm-middletemporal
Lt-wm-parahippocampal
Lt-wm-paracentral
Lt-wm-parsopercularis
Lt-wm-parsorbitalis
Lt-wm-parstriangularis
Lt-wm-pericalcarine
Lt-wm-postcentral
Lt-wm-posteriorcingulate
Lt-wm-precentral
Lt-wm-precuneus
Lt-wm-rostralanteriorcingulate
Lt-wm-rostralmiddlefrontal
Lt-wm-superiorfrontal
Lt-wm-superiorparietal
Lt-wm-superiortemporal
Lt-wm-supramarginal
Lt-wm-frontalpole
Lt-wm-temporalpole
Lt-wm-transversetemporal
Lt-wm-insula
Rt-wm-bankssts
Rt-wm-caudalanteriorcingulate
Rt-wm-caudalmiddlefrontal
Rt-wm-cuneus
Rt-wm-entorhinal
Rt-wm-fusiform
Rt-wm-inferiorparietal
Rt-wm-inferiortemporal
Rt-wm-isthmuscingulate
Rt-wm-lateraloccipital
Rt-wm-lateralorbitofrontal
Rt-wm-lingual
Rt-wm-medialorbitofrontal
Rt-wm-middletemporal
Rt-wm-parahippocampal
Rt-wm-paracentral
Rt-wm-parsopercularis
Rt-wm-parsorbitalis
Rt-wm-parstriangularis
Rt-wm-pericalcarine
Rt-wm-postcentral
Rt-wm-posteriorcingulate
Rt-wm-precentral
Rt-wm-precuneus
Rt-wm-rostralanteriorcingulate
Rt-wm-rostralmiddlefrontal
Rt-wm-superiorfrontal
Rt-wm-superiorparietal
Rt-wm-superiortemporal
Rt-wm-supramarginal
Rt-wm-frontalpole
Rt-wm-temporalpole
Rt-wm-transversetemporal
Rt-wm-insula
EOS

echo "generate table"
timestamp=$(date +%Y%m%d_%H%M)
paste colheader_wmparc.txt *_suvr_wm_wmparc_mean.tsv > suvr_wm_wmparc_mean_${timestamp}.tsv

rm colheader_wmparc.txt tmp_*_suvr_wm_wmparc_mean_?000 tmp_*_suvr_wm_bsseg_mean *_r_?000.nii.gz

echo "Done. Please check suvr_wm_wmparc_mean_${timestamp}.tsv"
