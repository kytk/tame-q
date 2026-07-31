#!/usr/bin/env bash
#Usage: tq-qc-petcoreg.sh  > output.csv

if [ "$#" -eq 0 ]; then
    echo "Usage: $0 resultdir" >&2
    exit 1
fi

echo "ID,Rmax_frame,Rx_mean,Ry_mean,Rz_mean,Dice"
for file in $(find $1 -name "coregistration_results_pet.csv"); do
    sed -n '2p' "$file"
done
