#!/bin/bash

# Calculating SUVR of PMPBB3 PET
# Part 3. Generate SUVR image(s) of PMPBB3 PET

# This script does
# 1. estimate reference value based on Tagai et al. 2022
# 2. generate SUVR images of PMPBB3

# K. Nakayama 21 Mar 2023

# Load environment variable
THAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; cd ../.. ; pwd)
source ${THAMEQDIR}/config.env

echo "Calculate SUVR images."

output_directory=histogram_WMref
mkdir -p ${output_directory}

echo "Figures and histogram_parameters.txt are saved in ${PWD}/${output_directory}."
if [[ ! -e ${PWD}/${output_directory}/histogram_parameters.txt ]]; then
  echo -e "ID\tprobability map\tvoxel num\ta1\tb1\tc1\ta2\tb2\tc2\tFWHM_min\tFWHM_max\trefnum\trefval" > ${PWD}/${output_directory}/histogram_parameters.txt
fi

for f in *_pmpbb3_dyn_mean.nii*
do
  id=${f%.gz}
  id=${id%_pmpbb3_dyn_mean.nii}
  
  t1w_r=${id}_t1w_r
  t1w_brain_mask=${id}_t1w_brain_mask

  msk=c2${id}_t1w_r
  #msk_masked=${msk}_masked
  msk_thr=c2${id}_t1w_r_thr
  msk_thr_xero=c1${id}_t1w_r_thr_xero
  msk_thr_yero=c1${id}_t1w_r_thr_yero
  msk_eroded=c2${id}_t1w_r_eroded
  
  echo "Processing ${id} images."
  
  #bet ${t1w} ${t1w_brain} -R -B -f 0.40
  flirt -dof 6 -in ${t1w_brain_mask} -ref ${t1w_r} -applyxfm -init ${id}_t1w2MNI.mat -out ${t1w_brain_mask}_r
  
  #fslmaths ${msk} -mas ${t1w_brain_mask}_r ${msk_masked}
  #fslmaths ${msk_masked} -thr 0.9 ${msk_thr}
  
  fslmaths ${msk} -mas ${t1w_brain_mask}_r -thr 0.9 ${msk_thr}
  fslmaths ${msk_thr} -kernel boxv3 3 1 1 -ero ${msk_thr_xero}
  fslmaths ${msk_thr} -kernel boxv3 1 3 1 -ero ${msk_thr_yero}
  fslmaths ${msk_thr} -min ${msk_thr_xero} -min ${msk_thr_yero} -bin ${msk_eroded}
  rm ${msk_thr}.nii.gz ${msk_thr_xero}.nii.gz ${msk_thr_yero}.nii.gz
  
  # obtain reference value
  MEAN=$(fslstats ${f} -k ${msk_eroded} -M)
  if [[ $MEAN < 4 ]] ; then
    refval=$(python ${THAMEQDIR}/src/python/get_ref.py ${id} ${f} ${msk_eroded}.nii.gz ${output_directory})
    fslmaths ${f} -div ${refval} ${id}_pmpbb3_suvr_wm
  else
    # modulate excessive signal distribution as the MEAN == 2.
    fslmaths ${f} -div $(echo "scale=5; $MEAN/2" | bc) ${id}_pmpbb3_dyn_mean_mod.nii.gz
    refval=$(python ${THAMEQDIR}/src/python/get_ref.py ${id} ${id}_pmpbb3_dyn_mean_mod.nii.gz ${msk_eroded}.nii.gz ${output_directory})
    fslmaths ${id}_pmpbb3_dyn_mean_mod.nii.gz -div ${refval} ${id}_pmpbb3_suvr_wm
  fi
  
  echo "Reference value is ${refval}"
  
done
