#!/usr/bin/env bash

TAMEQDIR=$(cd $(dirname $0) ; cd .. ; pwd)

# Shell script
for f in $(find ${TAMEQDIR} -name "*.sh"); do
    if [[ $(cat ${f} | grep "$1" | wc -l) -gt 0 ]]; then
        echo ${f}
    fi
done

# Python script
for f in $(find ${TAMEQDIR} -name "*.py"); do
    if [[ $(cat ${f} | grep "$1" | wc -l) -gt 0 ]]; then
        echo ${f}
    fi
done

# MATLAB script
for f in $(find ${TAMEQDIR} -name "*.m"); do
    if [[ $(cat ${f} | grep "$1" | wc -l) -gt 0 ]]; then
        echo ${f}
    fi
done
