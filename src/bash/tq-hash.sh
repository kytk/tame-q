#!/usr/bin/env bash
# 8 Mar 2026 K.Nakayama and K.Nemoto

for arg in "$@"; do
    if [[ "${arg}" = "--debug" ]]; then
        set -x
    fi
done

alternative () {
    chars=$(cat ${TAMEQDIR}/.git/HEAD | sed 's/^ref: //')
    if [[ -e ${TAMEQDIR}/.git/${chars} ]]; then
        cat ${TAMEQDIR}/.git/${chars}
    elif [[ ${chars} =~ ^[0-9a-f]{7,64}$ ]]; then
        echo ${chars}
    else
        echo "UNAVAILABLE"
    fi
}

trap "alternative; exit 0" ERR

# Set variable
TAMEQDIR=$(cd $(dirname "$(realpath "$0")") ; cd ../.. ; pwd)

### Process
cd ${TAMEQDIR} ; git rev-parse HEAD 2>/dev/null
exit 0
