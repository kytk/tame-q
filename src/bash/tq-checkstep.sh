#!/usr/bin/env bash
# 15 Mar 2026 K.Nakayama and K.Nemoto

set -euo pipefail
for arg in "$@"; do
    if [[ "${arg}" = "--debug" ]]; then
        set -x
    fi
done

cleanup() {
    status=$?
    if [[ "${status}" -eq 0 ]] && [[ "${cache}" = false ]]; then
        rm -f ${subjectdir}/tmp_tq-checkstep.mgz
    fi
}

trap cleanup EXIT INT TERM

### Define functions
function display_usage() {
    echo "Usage: $0 <subjectdir> [options]"
    echo "  --quick"
    echo "  --silent"
    echo "  --cache"
    echo "  --debug"
}

# Set variable
TAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; cd ../.. ; pwd)
source ${TAMEQDIR}/config.env

### Read command line arguments
# Check the number of command line arguments
if [[ "$#" -lt 1 ]]; then
    display_usage
    exit 1
fi
subjectdir="$1"
shift 1

# Handle necessary arguments
quick=false
silent=false
settingfile=${subjectdir}/tq-all-setting.env
debug_option=""
cache=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --quick) quick=true; silent=true ; shift 1 ;;
        --silent) silent=true; shift 1 ;;
        --cache) cache=true; shift 1 ;;
        --debug) debug_option="--debug"; shift 1 ;;
        --*) echo "Unknown option: $1"; display_usage ; exit 1 ;;
        *) echo "Unknow option: $1"; display_usage ; exit 1 ;;
    esac
done

if [[ "${silent}" = "false" ]]; then echo "Analyzing..."; fi

### Process
# tq-all-preproc
if [[ ! -e ${settingfile} ]] || [[ ! -e ${subjectdir}/mri.nii.gz ]] || [[ ! -e ${subjectdir}/pet.nii.gz ]]; then
    echo "00"
    exit 0
fi
source ${settingfile}
id=${TQID}

# tq_10
if [[ ! -e ${subjectdir}/mri_mni.nii.gz ]] || [[ ! -e ${subjectdir}/pet_mean.nii.gz ]]; then
    echo "10"
    exit 0
fi

# tq_20
if [[ ! -e ${subjectdir}/c1mri_mni.nii.gz ]] || [[ ! -e ${subjectdir}/c2mri_mni.nii.gz ]]; then
    echo "20"
    exit 0
fi

# tq_30
if [[ ! -e ${subjectdir}/pet_suvr_gmref.nii.gz ]] || [[ ! -e ${subjectdir}/pet_suvr_wmref.nii.gz ]]; then
    echo "30"
    exit 0
fi

# tq_40
if [[ ! -e ${subjectdir}/overview_pet_gmref_axial.png ]] || [[ ! -e ${subjectdir}/overview_pet_gmref_coronal.png ]] || [[ ! -e ${subjectdir}/overview_pet_wmref_axial.png ]] || [[ ! -e ${subjectdir}/overview_pet_wmref_coronal.png ]]; then
    echo "40"
    exit 0
fi

# tq_50, 51
if [[ -e ${subjectdir}/freesurfer/${id}/mri/orig/001.mgz ]] && [[ -e ${subjectdir}/freesurfer/${id}/mri/wmparc.mgz ]]; then
    if [[ "${quick}" = "false" ]]; then
        mri_convert ${subjectdir}/mri_mni.nii.gz ${subjectdir}/tmp_tq-checkstep.mgz > /dev/null
        diff=$(mri_diff ${subjectdir}/tmp_tq-checkstep.mgz ${subjectdir}/freesurfer/${id}/mri/orig/001.mgz)
        if [[ "${diff}" != "diffcount 0" ]]; then
            echo "50"
            exit 0
        fi
    fi
else
    echo "50"
    exit 0
fi

if [[ ! -e ${subjectdir}/freesurfer/${id}/mri/brainstemSsLabels.v13.FSvoxelSpace.mgz ]]; then
    echo "51"
    exit 0
fi

# tq_52
if [[ ! -e ${subjectdir}/wmparc.nii.gz ]] || [[ ! -e ${subjectdir}/bsparc.nii.gz ]] || [[ ! -e ${subjectdir}/wmparc_merged.nii.gz ]]; then
    echo "52"
    exit 0
fi

# tq_53
if [[ ! -e ${subjectdir}/pet_suvr_cbref.nii.gz ]]; then
    echo "53"
    exit 0
fi

# tq_60
if [[ ! -e ${subjectdir}/ROI-SUVR_wmparc_gmref.csv ]]; then
    echo "60"
    exit 0
fi

# tq_61
if [[ ! -e ${subjectdir}/ROI-SUVR_wmparc_wmref.csv ]]; then
    echo "61"
    exit 0
fi

# tq_62
if [[ ! -e ${subjectdir}/ROI-SUVR_wmparc_cbref.csv ]]; then
    echo "62"
    exit 0
fi

# tq_63
if [[ ! -e ${subjectdir}/ROI-SUVR_merged_gmref.csv ]]; then
    echo "63"
    exit 0
fi

# tq_64
if [[ ! -e ${subjectdir}/ROI-SUVR_merged_wmref.csv ]]; then
    echo "64"
    exit 0
fi

# tq_65
if [[ ! -e ${subjectdir}/ROI-SUVR_merged_cbref.csv ]]; then
    echo "65"
    exit 0
fi

echo "99"
exit