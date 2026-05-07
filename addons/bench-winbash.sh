#!/usr/bin/env bash
# =============================================================================
# bench-winbash.sh — Bench canónico de Git Bash + oh-my-posh en Windows
# =============================================================================
# Mide dos métricas reproducibles:
#
#   1. Bash startup: tiempo de arrancar un shell interactivo cargando el
#      bashrc completo (`bash --rcfile <bashrc> -ic exit`).
#   2. Per-Enter PROMPT_COMMAND: tiempo de una iteración del PROMPT_COMMAND
#      dentro de un shell ya arrancado (proxy fiel del retardo que percibe
#      el usuario al pulsar Enter).
#
# Uso:
#   ./addons/bench-winbash.sh                  # bashrc del repo, 10 muestras
#   ./addons/bench-winbash.sh --samples 20     # más muestras
#   ./addons/bench-winbash.sh --bashrc PATH    # otro bashrc
#
# Variables de entorno equivalentes:
#   BENCH_BASHRC, BENCH_SAMPLES
#
# Output: dos líneas parseables al final, además del detalle humano:
#   STARTUP_MS_MEDIAN=<entero>
#   PROMPT_MS_MEDIAN=<entero>
#
# Por qué se setean TERM, WEZTERM_PANE y DEVCLI_SSH_REGISTRY_FIX:
#   - TERM=xterm-256color: evita que wezterm.sh se autoreturn por TERM=dumb
#     y registre los hooks `precmd_functions` que sí queremos medir.
#   - WEZTERM_PANE=bench: emula sesión dentro de WezTerm (el caso normal
#     del usuario) para que el bashrc sourcee wezterm.sh.
#   - DEVCLI_SSH_REGISTRY_FIX=false: silencia el aviso de RedirectionGuard
#     (irrelevante para el bench y ensucia stderr).
#
# El script NO modifica `~/.bashrc` ni ningún estado persistente.
# =============================================================================

set -euo pipefail

# --- Defaults ---------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BASHRC="${BENCH_BASHRC:-$REPO_ROOT/dotfiles/win.gitbash.bashrc}"
SAMPLES="${BENCH_SAMPLES:-10}"

# --- Args -------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --bashrc)        BASHRC="$2"; shift 2 ;;
        --samples|-n)    SAMPLES="$2"; shift 2 ;;
        --help|-h)
            sed -n '2,/^# ====/p' "${BASH_SOURCE[0]}" | sed 's/^# \?//' | head -n 30
            exit 0
            ;;
        *) echo "Unknown arg: $1" >&2; echo "Try --help" >&2; exit 2 ;;
    esac
done

# --- Sanity -----------------------------------------------------------------
[[ -f "$BASHRC" ]] || { echo "ERROR: bashrc no encontrado en $BASHRC" >&2; exit 1; }
[[ "$SAMPLES" =~ ^[0-9]+$ ]] && [[ "$SAMPLES" -gt 0 ]] \
    || { echo "ERROR: samples debe ser entero positivo, got '$SAMPLES'" >&2; exit 1; }

# --- Helpers ----------------------------------------------------------------
# median: lee floats por stdin, escribe la mediana
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

# to_ms: float (segundos) -> entero (milisegundos)
to_ms() { awk -v v="$1" 'BEGIN { printf "%.0f", v * 1000 }'; }

# --- Cleanup ----------------------------------------------------------------
startup_samples=$(mktemp)
prompt_samples=$(mktemp)
trap 'rm -f "$startup_samples" "$prompt_samples" 2>/dev/null' EXIT

# --- Header -----------------------------------------------------------------
cat <<EOF
==[ bench-winbash ]==========================================================
  bashrc:  $BASHRC
  samples: $SAMPLES
  date:    $(date)
  host:    $(hostname)
  bash:    $BASH_VERSION
=============================================================================
EOF
echo ""

# --- 1. Bash startup --------------------------------------------------------
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

# --- 2. Per-Enter PROMPT_COMMAND --------------------------------------------
echo ""
echo "[2/2] Per-Enter PROMPT_COMMAND ($SAMPLES iteraciones en un único shell ya cargado)"

raw=$(TERM=xterm-256color \
      WEZTERM_PANE=bench \
      DEVCLI_SSH_REGISTRY_FIX=false \
      SAMPLES="$SAMPLES" \
      bash --rcfile "$BASHRC" -i 2>&1 <<'BASH_EOF'
TIMEFORMAT='%R'
# Warm-up (oh-my-posh tiene un par de inicializaciones la primera vez)
eval "$PROMPT_COMMAND" >/dev/null 2>&1 || true
# Mediciones
for i in $(seq 1 ${SAMPLES:-10}); do
    t=$( { time eval "$PROMPT_COMMAND" >/dev/null 2>&1; } 2>&1 )
    echo "S:$t"
done
exit
BASH_EOF
)

# Extraer las muestras (líneas "S:0.062")
echo "$raw" | grep -E '^S:' | sed 's/^S://' > "$prompt_samples"
prompt_count=$(wc -l < "$prompt_samples" | tr -d ' ')

if [[ $prompt_count -eq 0 ]]; then
    echo "  ERROR: no se extrajeron muestras de PROMPT_COMMAND." >&2
    echo "  Output completo del subshell:" >&2
    echo "$raw" | sed 's/^/    /' >&2
    exit 1
fi

while read -r t; do printf "  - %s s\n" "$t"; done < "$prompt_samples"

prompt_median=$(median < "$prompt_samples")
prompt_min=$(sort -n "$prompt_samples" | head -1)
prompt_max=$(sort -n "$prompt_samples" | tail -1)

# --- Summary ----------------------------------------------------------------
cat <<EOF

=============================================================================
  Resumen
=============================================================================
  Bash startup       median=${startup_median} s   (min=${startup_min}, max=${startup_max}, n=${SAMPLES})
  Per-Enter prompt   median=${prompt_median} s   (min=${prompt_min}, max=${prompt_max}, n=${prompt_count})

EOF

# --- Líneas parseables (formato fijo, no tocar) -----------------------------
echo "STARTUP_MS_MEDIAN=$(to_ms "$startup_median")"
echo "PROMPT_MS_MEDIAN=$(to_ms "$prompt_median")"
