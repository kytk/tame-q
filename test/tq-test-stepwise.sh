#!/usr/bin/env bash
# 8 Mar 2026 K.Nakayama and K.Nemoto

set -euo pipefail
for arg in "$@"; do
    if [[ "${arg}" = "--debug" ]]; then
        set -x
    fi
done

# Load environment variable
TAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; cd .. ; pwd)
source ${TAMEQDIR}/config.env

# If images are not given, command tq-batch.sh instead.
flag_mri_option="false"
flag_pet_option="false"
for arg in "$@"; do
    if [[ "${arg}" = "--mri" ]]; then
        flag_mri_option="true"
    elif [[ "${arg}" = "--pet" ]]; then
        flag_pet_option="true"
    fi
done
if [[ "${flag_mri_option}" = "false" ]] && [[ "${flag_pet_option}" = "false" ]]; then
    echo "tq-all.sh calls tq-batch.sh ..."
    ${TAMEQDIR}/src/bash/tq-batch.sh "$@"
    exit 0
fi

### Define functions
cleanup() {
    status=$?
    if [[ "${status}" -eq 0 ]] && [[ "${cache}" = false ]]; then
        rm -f ${subjectdir}/tq-all_tmp*.nii.gz
        rm -f mri_view.nii.gz
        rm -f ${subjectdir}/pet_suvr_?m_view.nii.gz
        rm -f pet_f????.nii.gz
        rm -f pet_f????_align.nii.gz
    fi
    jobs -pr | xargs -r kill 2>/dev/null || true
}

trap cleanup EXIT INT TERM

function display_usage() {
    echo "Usage: $0 --id <id> --mri <mri_input> --pet <pet_input> [options]"
    echo "Options:"
    echo "  --id <id>"
    echo "  --mri <mri_input>"
    echo "  --pet <pet_input>"
    echo "  --outdir <dirpath>"
    echo "  --set <settingfile>"
    echo "  --cache"
    echo "  --debug"
}

function check_existence() {
    for f in "$@"; do
        if [[ ! -e ${f} ]]; then
            echo "Error: Unable to find ${f}" >&2
            exit 1
        fi
    done
}

### Read command line arguments
# Handle necessary arguments
id=""
inmri=""
inpet=""
refpolicy=${TAMEQDIR}/src/python/reference_policy.py
settingfile=${TAMEQDIR}/env/tq-all-setting.env
outdir=$(pwd)
cache=false
debug_option=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --id) id="$2"; shift 2 ;;
        --mri) inmri="$2"; shift 2 ;;
        --pet) inpet="$2"; shift 2 ;;
        --set) settingfile="$2"; shift 2 ;;
        --refpolicy) refpolicy="$2"; shift 2 ;;
        --outdir) outdir="${2%/}"; shift 2 ;;
        --cache) cache=true; shift 1 ;;
        --debug) debug_option="--debug"; shift 1 ;;
        --*) echo "Unknown option: $1"; display_usage ; exit 1 ;;
        *) echo "Unknow option: $1"; display_usage ; exit 1 ;;
    esac
done

if [[ -z "${inmri}" ]] || [[ -z "${inpet}" ]]; then
    display_usage
    exit 1
fi

if [[ -z "${id}" ]]; then
    id=${pet%.nii*}
fi

# Initial check for the existence of input
check_existence ${inmri} ${inpet}
subjectdir=${outdir}/${id}

if [[ -e ${subjectdir} ]]; then
    echo "Error: ${subjectdir} has already existed."
    echo "Please use tq-redo.sh with the directory,"
    echo "Or change ID for processing the input images."
    exit 1
fi

# Check license.txt
if [[ ! -e ${FS_LICENSE} ]]; then 
    echo "Error: Unable to find FreeSurfer license file."
    echo "Please check license.txt exists as ${FS_LICENSE}"
    exit 1
fi

### Initial preparation
mkdir -p ${subjectdir}/orig
cp ${settingfile} ${subjectdir}/tq-all-setting.env
sed -i "0,/### Process setting/ s//### Individual setting\nTQID=${id}\n\n&/" ${subjectdir}/tq-all-setting.env
cp ${refpolicy} ${subjectdir}/reference_policy.py

logfile=${subjectdir}/tq-all.log
touch ${logfile}

exec 3>&1
exec > >(
  tee >(awk -v lf="${logfile}" '{
        print strftime("[%F %T]"), $0 >> lf
        fflush(lf)
      }') >&3
) 2>&1

${TAMEQDIR}/src/bash/tq-logo.sh
source ${subjectdir}/tq-all-setting.env

echo "tq-all.sh starts."
echo "ID: ${id}"
echo "PET: ${inpet}"
echo "MRI: ${inmri}"
echo "setting file: ${settingfile}"
echo "python file: ${refpolicy}"
echo -e "subject directory: ${subjectdir}\n"

# Prepare subject directory
echo "tq_00"
echo "Copy original images in ${subjectdir}/orig"
cp ${inmri} ${inpet} ${subjectdir}/orig

echo "Reorient MR image into LAS..."
fslreorient2std ${inmri} ${subjectdir}/mri.nii.gz
${TAMEQDIR}/src/python/reorient2LAS.py ${subjectdir}/mri.nii.gz ${subjectdir}/mri.nii.gz

echo "Reorient PET image into LAS..."
fslreorient2std ${inpet} ${subjectdir}/pet.nii.gz
${TAMEQDIR}/src/python/reorient2LAS.py ${subjectdir}/pet.nii.gz ${subjectdir}/pet.nii.gz

echo -e "Directory for tame-q: ${subjectdir}"

cp -rf ${subjectdir} ${outdir}/tq-test-00

### Process
echo -e "\ntq_10_realign.sh starts."
${TAMEQDIR}/src/bash/tq_10_realign.sh ${subjectdir} --cache ${debug_option}
cp -rf ${subjectdir} ${outdir}/tq-test-10

echo -e "\ntq_11_qa_coreg.sh starts."
${TAMEQDIR}/src/bash/tq_11_qa_coreg.sh ${subjectdir} --cache ${debug_option}
cp -rf ${subjectdir} ${outdir}/tq-test-11

echo -e "\ntq_12_qa_report.sh starts."
${TAMEQDIR}/src/bash/tq_12_qa_report.sh ${subjectdir} --cache ${debug_option}
cp -rf ${subjectdir} ${outdir}/tq-test-12

echo -e "\ntq_20_segmentation.sh starts."
${TAMEQDIR}/src/bash/tq_20_segmentation.sh ${subjectdir} ${debug_option}
cp -rf ${subjectdir} ${outdir}/tq-test-20

echo -e "\ntq_30_suvr_im.sh starts."
${TAMEQDIR}/src/bash/tq_30_suvr_im.sh ${subjectdir} --cache ${debug_option}
cp -rf ${subjectdir} ${outdir}/tq-test-30

echo -e "\ntq_40_overview.sh starts."
${TAMEQDIR}/src/bash/tq_40_overview.sh ${subjectdir} ${debug_option}
cp -rf ${subjectdir} ${outdir}/tq-test-40

echo -e "\ntq_50_recon-all.sh starts."
${TAMEQDIR}/src/bash/tq_50_recon-all.sh ${subjectdir} ${debug_option}
cp -rf ${subjectdir} ${outdir}/tq-test-50

echo -e "\ntq_51_segmentBS.sh starts."
${TAMEQDIR}/src/bash/tq_51_segmentBS.sh ${subjectdir} ${debug_option}
cp -rf ${subjectdir} ${outdir}/tq-test-51

echo -e "\ntq_52_merge_wmparc.sh starts."
${TAMEQDIR}/src/bash/tq_52_merge_wmparc.sh ${subjectdir} --cache ${debug_option}
cp -rf ${subjectdir} ${outdir}/tq-test-52

echo -e "\ntq_53_get_cbref.sh starts."
${TAMEQDIR}/src/bash/tq_53_get_cbref.sh ${subjectdir} ${debug_option}
cp -rf ${subjectdir} ${outdir}/tq-test-53

echo -e "\ntq_60_gen_table_wmparc_gmref.sh starts."
${TAMEQDIR}/src/bash/tq_60_gen_table_wmparc_gmref.sh ${subjectdir} ${debug_option}
cp -rf ${subjectdir} ${outdir}/tq-test-60

echo -e "\ntq_61_gen_table_wmparc_wmref.sh starts."
${TAMEQDIR}/src/bash/tq_61_gen_table_wmparc_wmref.sh ${subjectdir} ${debug_option}
cp -rf ${subjectdir} ${outdir}/tq-test-61

echo -e "\ntq_62_gen_table_wmparc_cbref.sh starts."
${TAMEQDIR}/src/bash/tq_62_gen_table_wmparc_cbref.sh ${subjectdir} ${debug_option}
cp -rf ${subjectdir} ${outdir}/tq-test-62

echo -e "\ntq_63_gen_table_merged_gmref.sh starts."
${TAMEQDIR}/src/bash/tq_63_gen_table_merged_gmref.sh ${subjectdir} ${debug_option}
cp -rf ${subjectdir} ${outdir}/tq-test-63

echo -e "\ntq_64_gen_table_merged_wmref.sh starts."
${TAMEQDIR}/src/bash/tq_64_gen_table_merged_wmref.sh ${subjectdir} ${debug_option}
cp -rf ${subjectdir} ${outdir}/tq-test-64

echo -e "\ntq_65_gen_table_merged_cbref.sh starts."
${TAMEQDIR}/src/bash/tq_65_gen_table_merged_cbref.sh ${subjectdir} ${debug_option}
cp -rf ${subjectdir} ${outdir}/tq-test-65

exit 0
