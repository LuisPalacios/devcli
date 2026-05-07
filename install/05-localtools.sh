#!/usr/bin/env bash
#
# Fase 05 — Scripts auxiliares en ~/bin (05-localtools.json) + nano + check
# de Nerd Fonts.
#
# Códigos de salida: 0=ok, 1=warn, 2=fail.

set -uo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

ux_init

[[ $IS_ROOT == false ]] && check_sudo_access

FILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../files" && pwd)"
LOCAL_TOOLS_CONFIG="$(dirname "${BASH_SOURCE[0]}")/05-localtools.json"

ensure_directory "$BIN_DIR"

# Patcher de variables Nerd Font en scripts copiados. Auto-detecta si el
# script destino tiene `export NERD_FONT_NAME=` para no perder ciclos en
# scripts que no lo necesitan. Antes había una whitelist hardcoded
# (nerd-setup.sh|nerd-verify.sh) — ahora cualquier futuro local-tool con
# esas variables se patchea automáticamente.
_update_nerd_font_variables() {
  local script_file="$1"
  [[ -f "$script_file" ]] || return 0
  grep -q '^export NERD_FONT_NAME=' "$script_file" 2>/dev/null || return 0
  local tmp; tmp="$(mktemp)"
  sed "s/export NERD_FONT_NAME=\"[^\"]*\"/export NERD_FONT_NAME=\"${NERD_FONT_NAME:-FiraCode}\"/g" "$script_file" > "$tmp"
  sed "s/export NERD_FONT_FULL_NAME=\"[^\"]*\"/export NERD_FONT_FULL_NAME=\"${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}\"/g" "$tmp" > "$script_file"
  rm -f "$tmp" 2>/dev/null || true
}

# Construir lista de tools del JSON filtradas por plataforma.
# (Bash 3.2 compat: `while read` en vez de `mapfile`.)
LOCAL_TOOLS=()
while IFS= read -r _line; do
  [[ -n "$_line" ]] && LOCAL_TOOLS+=("$_line")
done < <(jq -r --arg p "$OS_TYPE" \
  '.tools[] | select(.platforms | index($p)) | .name' \
  "$LOCAL_TOOLS_CONFIG" 2>/dev/null)

_install_one_local_tool() {
  local tool="$1"
  local src="$FILES_DIR/bin/$tool"
  local dst="$BIN_DIR/$tool"

  if [[ ! -f "$src" ]]; then
    ux_warn "$tool: fuente no encontrada en $FILES_DIR/bin"
    return 1
  fi
  if ! cp -f "$src" "$dst" 2>/dev/null; then
    ux_warn "$tool: error al copiar a $dst"
    return 1
  fi
  chmod 755 "$dst" 2>/dev/null || true

  # El patcher se auto-detecta vía grep: no hace falta whitelist por nombre.
  _update_nerd_font_variables "$dst"
  return 0
}

run_phase_items "$PHASE_NUM" "$PHASE_TOTAL" "Herramientas locales" LOCAL_TOOLS _install_one_local_tool
phase_rc=$?

# Post-fase: nano + check de Nerd Fonts.
case "${OS_TYPE:-}" in
  linux|wsl2)
    [[ -f "$FILES_DIR/etc/nanorc" ]] && \
      ux_run -- sudo cp -f "$FILES_DIR/etc/nanorc" /etc/nanorc >/dev/null 2>&1 || true
    ux_run -- sudo mkdir -p /root/.nano >/dev/null 2>&1 || true
    ;;
esac
mkdir -p "$HOME/.nano" >/dev/null 2>&1 || true

# Check no-bloqueante de Nerd Fonts. Sólo emitimos warn si no se detecta;
# no afecta al phase_rc (los scripts están instalados, las fuentes son aparte).
# Helper `_nerd_font_installed` definido en utils.sh.
if ! _nerd_font_installed; then
  ux_warn "Nerd Font no detectada — ejecuta nerd-setup.sh para instalarla"
  if [[ $phase_rc -eq 0 ]]; then phase_rc=1; fi
fi

exit $phase_rc
