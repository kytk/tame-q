#!/usr/bin/env bash
# 8 Mar 2026 K.Nakayama and K.Nemoto

SCRIPTDIR=$(dirname $(realpath "$0"))

### Set PATH
if [[ -e ~/.bash_aliases ]]; then
    PATHFILE="${HOME}/.bash_aliases"
elif [[ -e ~/.bashrc ]]; then
    PATHFILE="${HOME}/.bashrc"
else
    echo "Error: Unable to find .bash_aliases and .bashrc"
    exit 1
fi

echo "" >> ${PATHFILE}
echo "# TAME-Q" >> ${PATHFILE}
echo "export PATH=\$PATH:${SCRIPTDIR}" >> ${PATHFILE}
echo "export PATH=\$PATH:${SCRIPTDIR}/src/bash" >> ${PATHFILE}
echo "export PATH=\$PATH:${SCRIPTDIR}/src/python" >> ${PATHFILE}
echo "" >> ${PATHFILE}
