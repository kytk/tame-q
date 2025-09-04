#!/bin/bash

#set -x

# Load environment variable
TAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; pwd)
source ${TAMEQDIR}/config.env

# Check license.txt
if [[ ! -e ${FS_LICENSE} ]]; then 
  echo "${FS_LICENSE} is not found."
  while true; do
    echo "Enter the path to FreeSurfer license.txt"
    read answer
	if [[ -e $answer ]]; then
      echo "Detected: $answer"
	  export FS_LICENSE=${answer}
	  break
    else
      echo "${answer} is not found."
    fi
  done
fi

echo "TAME-Q Pipeline"
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

### Start TAME-Q Preprocess
timestamp=$(date +%Y%m%d_%H%M)
PROCESS_RESULT=Process_Status_${timestamp}.csv
echo "ID" > ${PROCESS_RESULT}
for ID in ${IDs[@]}; do echo ${ID} >> ${PROCESS_RESULT}; done

# Step 1. Realignment and Coregistration
${TAMEQDIR}/src/bash/tq_10_realign.sh
status_10=()
for ID in ${IDs[@]}; do
Rmax=$(cat coregistration_results_pet.csv | grep ${ID}, | awk -F , '{print $2}' | sed 's/^-//g')
Rx=$(cat coregistration_results_pet.csv | grep ${ID}, | awk -F , '{print $3}' | sed 's/^-//g')
Ry=$(cat coregistration_results_pet.csv | grep ${ID}, | awk -F , '{print $4}' | sed 's/^-//g')
Rz=$(cat coregistration_results_pet.csv | grep ${ID}, | awk -F , '{print $5}' | sed 's/^-//g')
Dice=0$(cat coregistration_results_pet.csv | grep ${ID}, | awk -F , '{print $6}')
  
  if [[ -e ${ID}_t1w_r.nii ]] && [[ -e ${ID}_pmpbb3_dyn_mean.nii ]]; then
    if (( $(echo "$Rmax < 1" | bc -l) )) && (( $(echo "$Rx < 1" | bc -l) )) && (( $(echo "$Ry < 1" | bc -l) )) && (( $(echo "$Rz < 1" | bc -l) )) && (( $(echo "$Dice > 0.94" | bc -l) )); then
      status_10+=("OK")
    else
      status_10+=("CHECK")
    fi
  else
    status_10+=("NA")
    mkdir -p failed/tq_10/${ID}
    mv *${ID}* failed/tq_10/${ID}/
  fi
done

PROCESS_RESULT_1=Process_Status1_$(date +%Y%m%d_%H%M).csv
echo "tq_10" > ${PROCESS_RESULT_1}
for flag in ${status_10[@]}; do echo ${flag} >> ${PROCESS_RESULT_1} ; done
paste -d "," ${PROCESS_RESULT} ${PROCESS_RESULT_1} > process_result_tmp.csv && mv process_result_tmp.csv ${PROCESS_RESULT}
rm ${PROCESS_RESULT_1}

# Step 2. Segmentation
${TAMEQDIR}/src/bash/tq_20_segmentation.sh
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

PROCESS_RESULT_2=Process_Status2_$(date +%Y%m%d_%H%M).csv
echo "tq_20" > ${PROCESS_RESULT_2}
for flag in ${status_20[@]}; do echo ${flag} >> ${PROCESS_RESULT_2} ; done
paste -d "," ${PROCESS_RESULT} ${PROCESS_RESULT_2} > process_result_tmp.csv && mv process_result_tmp.csv ${PROCESS_RESULT}
rm ${PROCESS_RESULT_2}

# Step 3. Semi-Quantification
# Gray Matter Reference
${TAMEQDIR}/src/bash/tq_30_suvr_im.sh
status_30=()
for ID in ${IDs[@]}; do
  if [[ -e ${ID}_pmpbb3_suvr.nii.gz ]]; then
    status_30+=("OK")
  else
    status_30+=("NA")
    if [[ $(find . -maxdepth 1 -name "*${ID}*" | wc -l) > 0 ]]; then
      mkdir -p failed/tq_30/${ID}/histogram_GM
      mv *${ID}* failed/tq_30/${ID}
      find ./histogram_GMref -name "${ID}*" -exec mv {} failed/tq_30/${ID}/histogram_GM
    fi
  fi
done

PROCESS_RESULT_3=Process_Status3_$(date +%Y%m%d_%H%M).csv
echo "tq_30" > ${PROCESS_RESULT_3}
for flag in ${status_30[@]}; do echo ${flag} >> ${PROCESS_RESULT_3} ; done
paste -d "," ${PROCESS_RESULT} ${PROCESS_RESULT_3} > process_result_tmp.csv && mv process_result_tmp.csv ${PROCESS_RESULT}
rm ${PROCESS_RESULT_3}

# White Matter Reference
${TAMEQDIR}/src/bash/tq_31_suvr_wm.sh
status_31=()
for ID in ${IDs[@]}; do
  if [[ -e ${ID}_pmpbb3_suvr_wm.nii.gz ]]; then
    status_31+=("OK")
  else
    status_31+=("NA")
    if [[ $(find . -maxdepth 1 -name "*${ID}*" | wc -l) > 0 ]]; then
      mkdir -p failed/tq_31/${ID}/histogram_GMref
      mkdir failed/tq_31/${ID}/histogram_WMref
      mv *${ID}* failed/tq_31/${ID}
      find ./histogram_GMref -name "${ID}*" -exec mv {} failed/tq_31/${ID}/histogram_GMref
      find ./histogram_WMref -name "${ID}*" -exec mv {} failed/tq_31/${ID}/histogram_WMref
    fi
  fi
done

PROCESS_RESULT_4=Process_Status4_$(date +%Y%m%d_%H%M).csv
echo "tq_31" > ${PROCESS_RESULT_4}
for flag in ${status_31[@]}; do echo ${flag} >> ${PROCESS_RESULT_4} ; done
paste -d "," ${PROCESS_RESULT} ${PROCESS_RESULT_4} > process_result_tmp.csv && mv process_result_tmp.csv ${PROCESS_RESULT}
rm ${PROCESS_RESULT_4}

# Step 4. FreeSurfer Segmentation
${TAMEQDIR}/src/bash/tq_40_recon-all.sh

status_40=()
for ID in ${IDs[@]}; do
  if [[ -e ./subjects/${ID}/mri/wmparc.mgz ]]; then
    status_40+=("OK")
  else
    status_40+=("NA")
    if [[ $(find . -maxdepth 1 -name "*${ID}*" | wc -l) > 0 ]]; then
      mkdir -p failed/tq_40/${ID}/subjects
      mkdir failed/tq_40/${ID}/histogram_GMref
      mkdir failed/tq_40/${ID}/histogram_WMref
      mv *${ID}* failed/tq_40/${ID}
      find ./histogram_GMref -name "${ID}*" -exec mv {} failed/tq_40/${ID}/histogram_GMref
      find ./histogram_WMref -name "${ID}*" -exec mv {} failed/tq_40/${ID}/histogram_WMref
      [[ -e subjects/${ID} ]] && mv subjects/${ID} failed/tq_40/${ID}/subjects/
    fi
  fi
done

PROCESS_RESULT_5=Process_Status5_$(date +%Y%m%d_%H%M).csv
echo "tq_40" > ${PROCESS_RESULT_5}
for flag in ${status_40[@]}; do echo ${flag} >> ${PROCESS_RESULT_5} ; done
paste -d "," ${PROCESS_RESULT} ${PROCESS_RESULT_5} > process_result_tmp.csv && mv process_result_tmp.csv ${PROCESS_RESULT}
rm ${PROCESS_RESULT_5}

${TAMEQDIR}/src/bash/tq_41_segmentBS.sh
status_41=()
for ID in ${IDs[@]}; do
  if [[ $(find subjects/${ID}/mri -name "brainstemSsLabels*mgz" | wc -l) > 0 ]]; then
    status_41+=("OK")
  else
    status_41+=("NA")
    if [[ $(find . -maxdepth 1 -name "*${ID}*" | wc -l) > 0 ]]; then
      mkdir -p failed/tq_41/${ID}/subjects
      mkdir failed/tq_41/${ID}/histogram_GMref
      mkdir failed/tq_41/${ID}/histogram_WMref
      mv *${ID}* failed/tq_41/${ID}
      find ./histogram_GMref -name "${ID}*" -exec mv {} failed/tq_41/${ID}/histogram_GMref
      find ./histogram_WMref -name "${ID}*" -exec mv {} failed/tq_41/${ID}/histogram_WMref
      [[ -e subjects/${ID} ]] && mv subjects/${ID} failed/tq_41/${ID}/subjects/
    fi
  fi
done

PROCESS_RESULT_6=Process_Status6_$(date +%Y%m%d_%H%M).csv
echo "tq_41" > ${PROCESS_RESULT_6}
for flag in ${status_41[@]}; do echo ${flag} >> ${PROCESS_RESULT_6} ; done
paste -d "," ${PROCESS_RESULT} ${PROCESS_RESULT_6} > process_result_tmp.csv && mv process_result_tmp.csv ${PROCESS_RESULT}
rm ${PROCESS_RESULT_6}

# Cerebellum Reference
${TAMEQDIR}/src/bash/tq_42_suvr_cer.sh
status_42=()
for ID in ${IDs[@]}; do
  if [[ -e ${ID}_pmpbb3_suvr_cer.nii.gz ]]; then
    status_42+=("OK")
  else
    status_42+=("NA")
    if [[ $(find . -maxdepth 1 -name "*${ID}*" | wc -l) > 0 ]]; then
      mkdir -p failed/tq_42/${ID}/subjects
      mkdir failed/tq_42/${ID}/histogram_GMref
      mkdir failed/tq_42/${ID}/histogram_WMref
      mv *${ID}* failed/tq_42/${ID}
      find ./histogram_GMref -name "${ID}*" -exec mv {} failed/tq_42/${ID}/histogram_GMref
      find ./histogram_WMref -name "${ID}*" -exec mv {} failed/tq_42/${ID}/histogram_WMref
      [[ -e subjects/${ID} ]] && mv subjects/${ID} failed/tq_42/${ID}/subjects/
    fi
  fi
done

PROCESS_RESULT_7=Process_Status7_$(date +%Y%m%d_%H%M).csv
echo "tq_42" > ${PROCESS_RESULT_7}
for flag in ${status_42[@]}; do echo ${flag} >> ${PROCESS_RESULT_7} ; done
paste -d "," ${PROCESS_RESULT} ${PROCESS_RESULT_7} > process_result_tmp.csv && mv process_result_tmp.csv ${PROCESS_RESULT}
rm ${PROCESS_RESULT_7}

# Step 5. Get Table Data
${TAMEQDIR}/src/bash/tq_50_gen_table_wmparc_gm.sh
${TAMEQDIR}/src/bash/tq_51_gen_table_wmparc_wm.sh
${TAMEQDIR}/src/bash/tq_52_gen_table_wmparc_cer.sh
${TAMEQDIR}/src/bash/tq_53_merge_wmparc.sh
${TAMEQDIR}/src/bash/tq_54_gen_table_merged_gm.sh
${TAMEQDIR}/src/bash/tq_55_gen_table_merged_wm.sh
${TAMEQDIR}/src/bash/tq_56_gen_table_merged_cer.sh

# Step 6. Get Overview
for ID in ${IDs[@]}; do
  ${TAMEQDIR}/src/bash/tq_60_overview_axi.sh -i ${ID} -a 1 -b 2
  ${TAMEQDIR}/src/bash/tq_61_overview_cor.sh -i ${ID} -a 1 -b 2
done
