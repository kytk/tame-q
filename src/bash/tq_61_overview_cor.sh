#!/bin/bash

# Generate a lightbox view of PMPBB3 superimposed on T1w images

# Usage: tau_6_overview.sh -i <ID>  -a [lower threshold] -b [upperthreshold]
# If thresholds are omitted, thresholds are set to 0 and 6

# K. Nakayama 18 Mar 2023

# For debugging
#set -x

# Load environment variable
TAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; cd ../.. ; pwd)
source ${TAMEQDIR}/config.env

while getopts "i:a:b:" OPT; do
  case $OPT in
    i) ID=$OPTARG;;
    a) THR=$OPTARG;;
    b) UTHR=$OPTARG;;
    ?) exit 1;;
  esac
done

if [ -z "$THR" ]; then
  THR=1
fi

if [ -z "$UTHR" ]; then
  UTHR=2
fi

t1w=${ID}_t1w_r.nii
t1w_l=${t1w%.nii}_l.nii.gz
pet=${ID}_pmpbb3_suvr.nii.gz
pet_l=${pet%.nii.gz}_l.nii.gz
ref=${FSLDIR}/data/standard/MNI152_T1_1mm.nii.gz
mat=tmp_affine.mat

if [[ ! -e ${pet_l} ]]; then
  echo "Affine transform of $ID"
  flirt -dof 9 -in ${t1w} -ref ${ref} -omat ${mat} -out ${t1w_l}
  flirt -dof 9 -in ${pet} -ref ${ref} -applyxfm -init ${mat} -out ${pet_l}
  rm ${mat} 
else
  echo "Affine transform of $ID is already done"
fi
 
echo "Overlay SUVR image onto T1w image"
python ${TAMEQDIR}/src/python/overlay_view_cor.py ${ID} ${t1w_l} ${pet_l} ${THR} ${UTHR} ${ID}_overview_cor_t1.png ${ID}_overview_cor_${THR}_${UTHR}.png
# rm ${t1w_l} ${pet_l}

exit
