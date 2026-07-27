#!/usr/bin/env bash
#Usage: tq-qc-t1wcoreg.sh  > output.csv

if [ "$#" -eq 0 ]; then
    echo "Usage: $0 resultdir" >&2
    exit 1
fi

echo "ID,Rx,Ry,Rz,Dice"
for file in $(find $1 -name "coregistration_results_t1w.csv"); do
    sed -n '2p' "$file"
done
