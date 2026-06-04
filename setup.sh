#!/usr/bin/env bash
# 20 Mar 2026 K.Nakayama and K.Nemoto
set -e

FREESURFER_DIR="/usr/local/freesurfer/7.4.1/bin"

exit_without_error () {
    echo 'TAME-Q is added to $PATH'
    echo 'To do TAME-Q, please command the below:'
    echo "    source ${PATHFILE}"
}
trap exit_without_error EXIT

SCRIPTDIR=$(dirname $(realpath "$0"))

### Set PATH
if [[ -e /home/brain/.bash_aliases ]]; then
    PATHFILE="/home/brain/.bash_aliases"
elif [[ -e /home/brain/.bashrc ]]; then
    PATHFILE="/home/brain/.bashrc"
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

### Replace "ln -s" in FreeSurfer scripts
cd ${FREESURFER_DIR}
FILES_WITH_LN=$(grep -l "ln -s" * 2>/dev/null || true)

for FILE in ${FILES_WITH_LN}; do
    FILEPATH="${FREESURFER_DIR}/${FILE}"

    if grep -q "ln -sf " "${FILEPATH}"; then
        sed -i 's/ln -sf /cp /g' "${FILEPATH}" || true
    fi

    if grep -q "ln -sfn " "${FILEPATH}"; then
        sed -i 's/ln -sfn /cp -r /g' "${FILEPATH}" || true
    fi

    if grep -q $'ln -s[^f]' "${FILEPATH}" || grep -q 'ln -s$' "${FILEPATH}"; then
        sed -i 's/\bln -s /cp /g' "${FILEPATH}" || true
    fi

    if grep -q '\$FREESURFER_HOME/subjects/fsaverage' "${FILEPATH}"; then
        sed -i 's|cp \$FREESURFER_HOME/subjects/fsaverage\b|cp -r \$FREESURFER_HOME/subjects/fsaverage \$SUBJECTS_DIR/|g' "${FILEPATH}" || true
    fi

    if grep -q '\${hemi}\.EC_average' "${FILEPATH}"; then
        sed -i 's|cp \$FREESURFER_HOME/subjects/\${hemi}\.EC_average\b|cp -r \$FREESURFER_HOME/subjects/\${hemi}.EC_average \$SUBJECTS_DIR/|g' "${FILEPATH}" || true
    fi

    if grep -q 'fsaverage_sym' "${FILEPATH}"; then
        sed -i 's|cp \$FREESURFER_HOME/subjects/fsaverage_sym\b|cp -r \$FREESURFER_HOME/subjects/fsaverage_sym \$SUBJECTS_DIR/|g' "${FILEPATH}" || true
    fi
done

