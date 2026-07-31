#!/usr/bin/env bash
# tq-mergeresult.sh resultdir

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 resultdir" >&2
    exit 1
fi

resultdir="$1"
shift 1

tmpdir=$(mktemp -d)

cleanup() {
    rm -rf "$tmpdir"
}
trap cleanup EXIT

for atlas in merged wmparc; do
    for ref in gmref wmref cbref; do
        echo "Aggegation: ROI-SUVR_${atlas}_${ref}.csv"
        i=0
	cols=()
        for file in $(find ${resultdir} -name "ROI-SUVR_${atlas}_${ref}.csv"); do
	    echo "Process ${i}: ${file}"
            awk -F',' '{print $2}' "${file}" > "${tmpdir}/col_${atlas}_${ref}_$i.txt"
	    cols+=("${tmpdir}/col_${atlas}_${ref}_$i.txt")
	    if [[ ! -e ${tmpdir}_colheader_${atlas}.csv ]]; then
	        awk -F',' '{print $1}' "${file}" > "${tmpdir}/colheader_${atlas}.txt"
	    fi
	    i=$((i + 1))
        done

        if [ "$i" -eq 0 ]; then
            echo "Error: no valid input files." >&2
	else
            paste -d',' ${tmpdir}/colheader_${atlas}.txt "${cols[@]}" > "${resultdir}/All_ROI-SUVR_${atlas}_${ref}.csv"
	fi
    done
done

