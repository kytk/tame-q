#!/bin/bash

#set -x

# Load environment variable
THAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; pwd)
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
  echo -e "The below ${subjnum} IDs are detected:\n\n${subjlist}" | expand -t ${#g}
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
qa_10=()
for ID in ${IDs[@]}; do
  if [[ -e ${ID}_t1w_r.nii ]] && [[ -e ${ID}_pmpbb3_dyn_mean.nii ]]; then
    qa_10+=("OK")
  else
    qa_10+=("NA")
    mkdir -p failed/tq_10/${ID}
    mv *${ID}* failed/tq_10/${ID}/
  fi
done

# Step 2. Segmentation
${THAMEQDIR}/src/bash/tq_20_segmentation.sh
qa_20=()
for ID in ${IDs[@]}; do
  if [[ -e c1${ID}_t1w_r.nii ]] && [[ -e c2${ID}_t1w_r.nii ]]; then
    qa_20+=("OK")
  else
    qa_20+=("NA")
    if [[ $(find . -name "*${ID}*" | wc -l) > 0 ]]; then
      mkdir -p failed/tq_20/${ID}
      mv *${ID}* failed/tq_20/${ID}
    fi
  fi
done

# Step 3. Semi-Quantification
# Gray Matter Reference
${THAMEQDIR}/src/bash/tq_30_suvr_im.sh
qa_30=()
for ID in ${IDs[@]}; do
  if [[ -e ${ID}_pmpbb3_suvr_gm.nii.gz ]]; then
    qa_30+=("OK")
  else
    qa_30+=("NA")
    if [[ $(find . -name "*${ID}* | wc -l") > 0 ]]; then
      mkdir -p failed/tq_30/${ID}
      mv *${ID}* failed/tq_30/${ID}
    fi
  fi
done

# White Matter Reference
${THAMEQDIR}/src/bash/tq_31_suvr_wm.sh
qa_31=()
for ID in ${IDs[@]}; do
  if [[ -e ${ID}_pmpbb3_suvr_wm.nii.gz ]]; then
    qa_31+=("OK")
  else
    qa_31+=("NA")
    if [[ $(find . -name "*${ID}* | wc -l") > 0 ]]; then
      mkdir -p failed/tq_31/${ID}
      mv *${ID}* failed/tq_31/${ID}
    fi
  fi
done

# Step 4. FreeSurfer Segmentation
${THAMEQDIR}/src/bash/tq_40_recon-all.sh

qa_40=()
for ID in ${IDs[@]}; do
  if [[ -e ./subjects/${ID}/mri/wmparc.mgz ]]; then
    qa_40+=("OK")
  else
    qa_40+=("NA")
    if [[ $(find . -name "*${ID}* | wc -l") > 0 ]]; then
      mkdir -p failed/tq_40/${ID}/subjects
      mv *${ID}* failed/tq_40/${ID}
      mv subjects/${ID} failed/tq_40/${ID}/subjects
    fi
  fi
done

${THAMEQDIR}/src/bash/tq_41_segmentBS.sh
qa_41=()
for ID in ${IDs[@]}; do
  if [[ $(find subjects/${ID}/mri/brainstemSslabels*mgz | wc -l) > 0 ]]; then
    qa_41+=("OK")
  else
    qa_41+=("NA")
    if [[ $(find . -name "*${ID}* | wc -l") > 0 ]]; then
      mkdir -p failed/tq_41/${ID}/subjects
      mv *${ID}* failed/tq_41/${ID}
      mv subjects/${ID} failed/tq_41/${ID}/subjects
    fi
  fi
done

# Cerebellum Reference
${THAMEQDIR}/src/bash/tq_42_suvr_cer.sh
qa_42=()
for ID in ${IDs[@]}; do
  if [[ -e ${ID}_pmpbb3_suvr_cer.nii.gz ]]; then
    qa_42+=("OK")
  else
    qa_42+=("NA")
    if [[ $(find . -name "*${ID}* | wc -l") > 0 ]]; then
      mkdir -p failed/tq_42/${ID}/subjects
      mv *${ID}* failed/tq_42/${ID}
      mv subjects/${ID} failed/tq_42/${ID}/subjects
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

exit