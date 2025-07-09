#!/bin/bash

# For debugging
#set -x

export SUBJECTS_DIR=$PWD

for fsid in *
do
  # Check whether ${fsid} is subject directory or not
  if [[ ! -e ${fsid}/mri/wmparc.mgz ]]; then
    continue
  fi

  # copy wmparc.mgz, add fsid, and convert to nii.gz
  echo "Convert wmparc into NIfTI"
  mri_convert ${fsid}/mri/wmparc.mgz ${fsid}_wmparc.nii.gz
  
  # copy brainstemSsLabels*.FSvoxelSpace.mgz, add fsid, and convert to nii.gz
  echo "Convert brainstemSsLabels.v??.FSvoxelSpace.mgz into NIfTI"
  mri_convert ${fsid}/mri/brainstemSsLabels.v??.FSvoxelSpace.mgz ${fsid}_bsseg.nii.gz

  echo "extract ROI volume"
  echo "${fsid}" > ${fsid}_wmparc+BS_vol.tsv
  
  # aseg and brainstem
  fslmaths ${fsid}_wmparc.nii.gz -uthr 999.5 ${fsid}_0000.nii.gz
  fslstats -K ${fsid}_0000.nii.gz ${fsid}_0000.nii.gz -V | awk -F ' ' '{print $1}' > tmp_${fsid}_0000
  cat tmp_${fsid}_0000 | sed -n '7,8p;10,13p;16,18p;26p;28p;46,47p;49,54p;58p;60p;85p;251,255p' >> ${fsid}_wmparc+BS_vol.tsv
  
  fslstats -K ${fsid}_bsseg.nii.gz ${fsid}_bsseg.nii.gz -V | awk -F ' ' '{print $1}' > tmp_${fsid}_bsseg
  cat tmp_${fsid}_bsseg | sed -n '173,175p;178p' >> ${fsid}_wmparc+BS_vol.tsv
  
  # 1000: lt cortex; 2000: rt cotex 
  # 3000: lt subcortical wm; 4000: rt subcortical wm
  for num in 1000 2000 3000 4000
  do
    lthr=$((num - 1))
    uthr=$((num + 999))
    fslmaths ${fsid}_wmparc.nii.gz -thr ${lthr}.5 -uthr ${uthr}.5 -sub ${num} \
      ${fsid}_${num}.nii.gz
    fslstats -K ${fsid}_${num}.nii.gz ${fsid}_${num}.nii.gz -V | awk -F ' ' '{print $1}' >\
        tmp_${fsid}_${num}
    cat tmp_${fsid}_${num} |\
        sed -n '1,3p;5,35p' >> ${fsid}_wmparc+BS_vol.tsv
  done
  
  rm ${fsid}_wmparc.nii.gz ${fsid}_bsseg.nii.gz
done

# Header
cat << EOS > colheader_wmparc+BS.txt
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
paste colheader_wmparc+BS.txt *_wmparc+BS_vol.tsv > volume_wmparc+BS_${timestamp}.tsv

rm colheader*.txt tmp* *000.nii.gz *_wmparc+BS_vol.tsv

