#!/usr/bin/env bash
#
# Fase 01 — Paquetes base del sistema (phase="system" en tools.json) +
# configuración de locale en Linux nativo.
#
# Códigos de salida: 0=ok, 1=warn, 2=fail (error de configuración).

set -uo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

ux_init

[[ $IS_ROOT == false ]] && check_sudo_access
ensure_directory "$BIN_DIR"

# git es un prerrequisito para todo lo demás (incluido jq vía apt en algunos casos).
if ! command_exists git; then
  ux_run -- sudo apt install -y -qq git || ux_run -- brew install git || true
fi

# Actualización silenciosa del package manager (output a log, no a pantalla).
ux_run -- update_package_manager >/dev/null 2>&1 || true

TOOLS_JSON="$(dirname "${BASH_SOURCE[0]}")/tools.json"

# Construir la lista de herramientas de phase=system aplicables al OS actual.
# (Bash 3.2 compat: `while read` en vez de `mapfile`.)
SYSTEM_TOOLS=()
while IFS= read -r _line; do
  [[ -n "$_line" ]] && SYSTEM_TOOLS+=("$_line")
done < <(jq -r --arg os "$OS_TYPE" \
  '.tools[] | select(.phase == "system") | select(.[$os] != null) | .name' \
  "$TOOLS_JSON")

_install_one_system_tool() {
  install_tool "$1" "$TOOLS_JSON"
}

run_phase_items "$PHASE_NUM" "$PHASE_TOTAL" "Sistema base" SYSTEM_TOOLS _install_one_system_tool
phase_rc=$?

# Post-fase: locale (sólo Linux nativo).
SETUP_LOCALE_NAME="$(echo "$SETUP_LANG" | sed 's/UTF-8/utf8/I')"
if [[ "$OS_TYPE" == "linux" ]]; then
  if ! locale -a 2>/dev/null | grep -iq "^$SETUP_LOCALE_NAME$"; then
    ux_run -- sudo sed -i "s|^# *${SETUP_LANG}[[:space:]]\+UTF-8|${SETUP_LANG} UTF-8|" /etc/locale.gen >/dev/null 2>&1 || true
    ux_run -- sudo locale-gen "$SETUP_LANG" >/dev/null 2>&1 || true
    ux_run -- sudo update-locale LANG="$SETUP_LANG" >/dev/null 2>&1 || true
  fi
fi

exit $phase_rc
