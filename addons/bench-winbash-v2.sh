#!/usr/bin/env bash
# =============================================================================
# bench-winbash-v2.sh — variante diagnóstica del bench canónico
# =============================================================================
# Diferencia frente a bench-winbash.sh:
#   - Si PROMPT_COMMAND es un array de Bash, mide todos sus elementos.
#
# No sustituye al bench canónico ni al HEADLINE del informe. Existe sólo para
# validar costes que el bench original no ve al expandir `$PROMPT_COMMAND`.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BASHRC="${BENCH_BASHRC:-$REPO_ROOT/dotfiles/win.gitbash.bashrc}"
SAMPLES="${BENCH_SAMPLES:-10}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bashrc) BASHRC="$2"; shift 2 ;;
        --samples|-n) SAMPLES="$2"; shift 2 ;;
        --help|-h)
            sed -n '2,/^# ====/p' "${BASH_SOURCE[0]}" | sed 's/^# \?//' | head -n 20
            exit 0
            ;;
        *) echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
done

[[ -f "$BASHRC" ]] || { echo "ERROR: bashrc no encontrado en $BASHRC" >&2; exit 1; }
[[ "$SAMPLES" =~ ^[0-9]+$ ]] && [[ "$SAMPLES" -gt 0 ]] \
    || { echo "ERROR: samples debe ser entero positivo, got '$SAMPLES'" >&2; exit 1; }

median() {
    sort -n | awk '
        { a[NR] = $1 }
        END {
            n = NR
            if (n == 0) { print ""; exit }
            if (n % 2 == 0) print (a[n/2] + a[n/2 + 1]) / 2
            else print a[int((n + 1) / 2)]
        }'
}

to_ms() { awk -v v="$1" 'BEGIN { printf "%.0f", v * 1000 }'; }

startup_samples=$(mktemp)
prompt_samples=$(mktemp)
trap 'rm -f "$startup_samples" "$prompt_samples" 2>/dev/null' EXIT

cat <<EOF
==[ bench-winbash-v2 ]=======================================================
  bashrc:  $BASHRC
  samples: $SAMPLES
  date:    $(date)
  host:    $(hostname)
  bash:    $BASH_VERSION
=============================================================================
EOF
echo ""

echo "[1/2] Bash startup ('bash --rcfile <bashrc> -ic exit')"
for ((i = 1; i <= SAMPLES; i++)); do
    t=$(TIMEFORMAT='%R'
        { time \
            TERM=xterm-256color \
            WEZTERM_PANE=bench \
            DEVCLI_SSH_REGISTRY_FIX=false \
            bash --rcfile "$BASHRC" -ic 'exit' >/dev/null 2>&1
        } 2>&1)
    printf "  %2d/%d: %s s\n" "$i" "$SAMPLES" "$t"
    echo "$t" >> "$startup_samples"
done

startup_median=$(median < "$startup_samples")
startup_min=$(sort -n "$startup_samples" | head -1)
startup_max=$(sort -n "$startup_samples" | tail -1)

echo ""
echo "[2/2] PROMPT_COMMAND completo ($SAMPLES iteraciones en un único shell ya cargado)"

raw=$(TERM=xterm-256color \
      WEZTERM_PANE=bench \
      DEVCLI_SSH_REGISTRY_FIX=false \
      SAMPLES="$SAMPLES" \
      bash --rcfile "$BASHRC" -i 2>&1 <<'BASH_EOF'
TIMEFORMAT='%R'
if [[ "$(declare -p PROMPT_COMMAND 2>/dev/null)" == declare\ -a* ]]; then
    __bench_prompt_is_array=1
else
    __bench_prompt_is_array=0
fi
__bench_run_prompt_command() {
    local cmd
    if [[ $__bench_prompt_is_array == 1 ]]; then
        for cmd in "${PROMPT_COMMAND[@]}"; do
            eval "$cmd"
        done
    elif [[ -n "${PROMPT_COMMAND:-}" ]]; then
        eval "$PROMPT_COMMAND"
    fi
}
__bench_run_prompt_command >/dev/null 2>&1 || true
for i in $(seq 1 ${SAMPLES:-10}); do
    t=$( { time __bench_run_prompt_command >/dev/null 2>&1; } 2>&1 )
    echo "S:$t"
done
exit
BASH_EOF
)

echo "$raw" | grep -E '^S:' | sed 's/^S://' > "$prompt_samples"
prompt_count=$(wc -l < "$prompt_samples" | tr -d ' ')

if [[ $prompt_count -eq 0 ]]; then
    echo "  ERROR: no se extrajeron muestras de PROMPT_COMMAND." >&2
    echo "$raw" | sed 's/^/    /' >&2
    exit 1
fi

while read -r t; do printf "  - %s s\n" "$t"; done < "$prompt_samples"

prompt_median=$(median < "$prompt_samples")
prompt_min=$(sort -n "$prompt_samples" | head -1)
prompt_max=$(sort -n "$prompt_samples" | tail -1)

cat <<EOF

=============================================================================
  Resumen
=============================================================================
  Bash startup       median=${startup_median} s   (min=${startup_min}, max=${startup_max}, n=${SAMPLES})
  Prompt completo    median=${prompt_median} s   (min=${prompt_min}, max=${prompt_max}, n=${prompt_count})

EOF

echo "STARTUP_MS_MEDIAN=$(to_ms "$startup_median")"
echo "PROMPT_MS_MEDIAN=$(to_ms "$prompt_median")"
