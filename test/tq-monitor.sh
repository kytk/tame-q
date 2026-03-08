#!/usr/bin/env bash
# 8 Mar 2026 K.Nakayama and K.Nemoto

#set -euo pipefail
for arg in "$@"; do
    if [[ "${arg}" = "--debug" ]]; then
        set -x
    fi
done

cleanup() {

    tput rc 2>/dev/null || printf '\033[u'
    tput cud 6 2>/dev/null || printf '\033[%dB' 6
    tput el 2>/dev/null || printf '\033[K'
    echo

    tput cnorm 2>/dev/null || true
}

trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

# Initial setting for display area
tput civis 2>/dev/null || true
printf "\n\n\n\n\n"
tput cuu 5 2>/dev/null || printf '\033[3A'
tput sc 2>/dev/null || printf '\033[s'

max_memory=0
max_tq_all=0
max_flirt=0
max_synth=0
max_recon_all=0

draw() {
    local n_memory="$1"
    local n_tq_all="$2"
    local n_flirt="$3"
    local n_synth="$4"
    local n_recon_all="$5"

    tput rc 2>/dev/null || printf '\033[u'

    if [[ "${max_memory}" -lt "${n_memory}" ]]; then max_memory=${n_memory} ; fi
    tput el 2>/dev/null || printf '\033[K'
    disp_n_memory=$(echo "scale=3;${n_memory}/1024/1024" | bc)
    disp_max_memory=$(echo "scale=3;${max_memory}/1024/1024" | bc)
    printf '%-6s %s\n' "Memory: ${disp_n_memory}GB (MAX: ${disp_max_memory}GB)"

    if [[ ${max_tq_all} -lt ${n_tq_all} ]]; then max_tq_all=${n_tq_all} ; fi
    tput el 2>/dev/null || printf '\033[K'
    printf '%-6s %s\n' "tq-all.sh: ${n_tq_all} (MAX: ${max_tq_all})"

    if [[ ${max_flirt} -lt ${n_flirt} ]]; then max_flirt=${n_flirt} ; fi
    tput el 2>/dev/null || printf '\033[K'
    printf '%-6s %s\n' "flirt: ${n_flirt} (MAX: ${max_flirt})"

    if [[ ${max_synth} -lt ${n_synth} ]]; then max_synth=${n_synth} ; fi
    tput el 2>/dev/null || printf '\033[K'
    printf '%-6s %s\n' "SynthStrip: ${n_synth} (MAX: ${max_synth})"

    if [[ ${max_recon_all} -lt ${n_recon_all} ]]; then max_recon_all=${n_recon_all} ; fi
    tput el 2>/dev/null || printf '\033[K'
    printf '%-6s %s\n' "recon-all: ${n_recon_all} (MAX: ${max_recon_all})"
}

n_memory=0
n_tq_all=0
n_flirt=0
n_synth=0
n_recon_all=0
draw $n_memory $n_tq_all $n_flirt $n_synth $n_recon_all

### Process
while true; do
    n_memory=$(echo "scale=3;$(free | grep "Mem" | awk '{print $3}')" | bc)
    n_tq_all=$(pgrep -f tq-all.sh -a | grep '\-\-id' | sort | uniq | wc -l)
    n_flirt=$(pgrep -x flirt -c)
    n_synth=$(pgrep -f mri_synthstrip -c)
    n_recon_all=$(pgrep -x recon-all -a | awk -F '-i' '{print $2}' | sort | uniq | wc -l)
    draw $n_memory $n_tq_all $n_flirt $n_synth $n_recon_all
    sleep 1s
done
