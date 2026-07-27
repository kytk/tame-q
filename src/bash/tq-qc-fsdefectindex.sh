#!/usr/bin/env bash
#Usage: tq-fsqc.sh resultdir

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 resultdir" >&2
    exit 1
fi

resultdir=${1%/}

initialflag=1
for f_lh in $(find ${resultdir} -name "lh.orig.nofix" | sort); do
    f_rh=${f_lh/lh.orig.nofix/rh.orig.nofix}
    ID=${f_lh#${resultdir}/}
    ID=${ID%/freesurfer*}

    defect_index_lh=$(mris_euler_number ${f_lh} | tail -n 1 | awk -F'= ' '{print $2}')
    defect_index_rh=$(mris_euler_number ${f_rh} | tail -n 1 | awk -F'= ' '{print $2}')
    defect_index_sum=$(( ${defect_index_lh} + ${defect_index_rh} ))
    
    if [[ ${initialflag} = 1 ]]; then
        initialflag=0
	echo "ID,lh,rh,sum"
    fi
    echo "${ID},${defect_index_lh},${defect_index_rh},${defect_index_sum}"
done
