#!/bin/bash

#set -x

# Load environment variable
# THAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; pwd)
THAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; cd .. ; pwd)
source ${THAMEQDIR}/config.env

echo "THAME-Q Pipeline"
IDs=()
subjlist="T1\tPET\n"
for f in [A-Z]*_t1w.nii*; do
  id=${f%.gz}
  id=${id%_t1w.nii}
  g=${id}_pmpbb3_dyn.nii.gz
  if [[ -e  ${g} ]]; then
    IDs+=("${id}")
    subjlist="${subjlist}${f}\t${g}\n"
  fi
done

if [[ ${#IDs[@]} > 1 ]]; then
  echo -e "The below ${#IDs[@]} IDs are detected:\n\n${subjlist}" | expand -t ${#g}
elif [[ ${#IDs[@]} = 1 ]]; then
  echo -e "The below ID is detected:\n\n${subjlist}" | expand -t ${#g}
else
  echo -e "No IDs are found.\nPlease check the image locations and filenames you would like to process."
  exit
fi

while true; do
    echo "Is the list correct? [y/n]"

    read answer

    case $answer in
	[Yy]*)
		echo -e "Continue processing \n"
		break
		;;
	[Nn]*)
		echo -e "Quit to process \n"
		exit
		;;
	*)
		echo -e "Type y or n \n"
		;;
    esac
done

### Start THAME-Q Preprocess
# Step 1. Realignment and Coregistration
${THAMEQDIR}/src/bash/tq_10_realign.sh
rm ${IDs[0]}_t1w_r.nii

status_10=()
for ID in ${IDs[@]}; do
  if [[ -e ${ID}_t1w_r.nii ]] && [[ -e ${ID}_pmpbb3_dyn_mean.nii ]]; then
    status_10+=("OK")
  else
    status_10+=("NA")
    mkdir -p failed/tq_10/${ID}
    mv *${ID}* failed/tq_10/${ID}/
  fi
done

# Step 2. Segmentation
${THAMEQDIR}/src/bash/tq_20_segmentation.sh
rm c1${IDs[1]}_t1w_r.nii

status_20=()
for ID in ${IDs[@]}; do
  if [[ -e c1${ID}_t1w_r.nii ]] && [[ -e c2${ID}_t1w_r.nii ]]; then
    status_20+=("OK")
  else
    status_20+=("NA")
    if [[ $(find . -maxdepth 1 -name "*${ID}*" | wc -l) > 0 ]]; then
      mkdir -p failed/tq_20/${ID}
      mv *${ID}* failed/tq_20/${ID}
    fi
  fi
done

# Step 3. Semi-Quantification
# Gray Matter Reference
${THAMEQDIR}/src/bash/tq_30_suvr_im.sh
rm ${IDs[2]}_pmpbb3_suvr.nii.gz

status_30=()
for ID in ${IDs[@]}; do
  if [[ -e ${ID}_pmpbb3_suvr.nii.gz ]]; then
    status_30+=("OK")
  else
    status_30+=("NA")
    if [[ $(find . -maxdepth 1 -name "*${ID}* | wc -l") > 0 ]]; then
      mkdir -p failed/tq_30/${ID}
      mv *${ID}* failed/tq_30/${ID}
    fi
  fi
done

# White Matter Reference
${THAMEQDIR}/src/bash/tq_31_suvr_wm.sh
rm ${IDs[3]}_pmpbb3_suvr_wm.nii.gz

status_31=()
for ID in ${IDs[@]}; do
  if [[ -e ${ID}_pmpbb3_suvr_wm.nii.gz ]]; then
    status_31+=("OK")
  else
    status_31+=("NA")
    if [[ $(find . -maxdepth 1 -name "*${ID}* | wc -l") > 0 ]]; then
      mkdir -p failed/tq_31/${ID}
      mv *${ID}* failed/tq_31/${ID}
    fi
  fi
done

# Step 4. FreeSurfer Segmentation
${THAMEQDIR}/src/bash/tq_40_recon-all.sh
rm subjects/${IDs[4]}/mri/wmparc.mgz

status_40=()
for ID in ${IDs[@]}; do
  if [[ -e ./subjects/${ID}/mri/wmparc.mgz ]]; then
    status_40+=("OK")
  else
    status_40+=("NA")
    if [[ $(find . -maxdepth 1 -name "*${ID}* | wc -l") > 0 ]]; then
      mkdir -p failed/tq_40/${ID}/subjects
      mv *${ID}* failed/tq_40/${ID}
      [[ -e subjects/${ID} ]] && mv subjects/${ID} failed/tq_40/${ID}/subjects/
    fi
  fi
done

${THAMEQDIR}/src/bash/tq_41_segmentBS.sh
rm subjects/${IDs[5]}/mri/brainstemSsLabels*.mgz
status_41=()
for ID in ${IDs[@]}; do
  if [[ $(find subjects/${ID}/mri -name "brainstemSsLabels*mgz" | wc -l) > 0 ]]; then
    status_41+=("OK")
  else
    status_41+=("NA")
    if [[ $(find . -name "*${ID}* | wc -l") > 0 ]]; then
      mkdir -p failed/tq_41/${ID}/subjects
      mv *${ID}* failed/tq_41/${ID}
      [[ -e subjects/${ID} ]] && mv subjects/${ID} failed/tq_41/${ID}/subjects/
    fi
  fi
done

# Cerebellum Reference
${THAMEQDIR}/src/bash/tq_42_suvr_cer.sh
rm ${IDs[6]}_pmpbb3_suvr_cer.nii.gz

status_42=()
for ID in ${IDs[@]}; do
  if [[ -e ${ID}_pmpbb3_suvr_cer.nii.gz ]]; then
    status_42+=("OK")
  else
    status_42+=("NA")
    if [[ $(find . -name "*${ID}* | wc -l") > 0 ]]; then
      mkdir -p failed/tq_42/${ID}/subjects
      mv *${ID}* failed/tq_42/${ID}
      [[ -e subjects/${ID} ]] && mv subjects/${ID} failed/tq_42/${ID}/subjects/
    fi
  fi
done

# Step 5. Get Table Data
${THAMEQDIR}/src/bash/tq_50_gen_table_wmparc_gm.sh
${THAMEQDIR}/src/bash/tq_51_gen_table_wmparc_wm.sh
${THAMEQDIR}/src/bash/tq_52_gen_table_wmparc_cer.sh
${THAMEQDIR}/src/bash/tq_53_merge_wmparc.sh
${THAMEQDIR}/src/bash/tq_54_gen_table_merged_gm.sh
${THAMEQDIR}/src/bash/tq_55_gen_table_merged_wm.sh
${THAMEQDIR}/src/bash/tq_56_gen_table_merged_cer.sh

timestamp=$(date +%Y%m%d_%H%M)
echo "ID,tq_10,tq_20,tq_30,tq_31,tq_40,tq_41,tq_42" > Process_Status_${timestamp}.csv
for ((i=0; i<${#IDs[@]}; i++)); do
  echo "${IDs[$i]},${status_10[$i]},${status_20[$i]},${status_30[$i]},${status_31[$i]},${status_40[$i]},${status_41[$i]},${status_42[$i]}" >> Process_Status_${timestamp}.csv
done


