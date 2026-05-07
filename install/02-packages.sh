#!/usr/bin/env bash
#
# Fase 02 — Herramientas de productividad (filtradas por perfil).
#
# Códigos de salida: 0=ok, 1=warn (algún paquete falló), 2=fail.

set -uo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

ux_init

[[ $IS_ROOT == false ]] && check_sudo_access
ux_run -- update_package_manager >/dev/null 2>&1 || true

TOOLS_JSON="$(dirname "${BASH_SOURCE[0]}")/tools.json"
DEVCLI_PROFILE="${DEVCLI_PROFILE:-full}"

# Resolver los tags permitidos para el perfil actual.
ALLOWED_TAGS_JSON=$(jq -c --arg p "$DEVCLI_PROFILE" \
  '.profiles[$p] // ["core","dev","k8s","win"]' "$TOOLS_JSON")

# Construir la lista de herramientas filtradas por perfil + auto_install + plataforma.
# (Bash 3.2 compat: `while read` en vez de `mapfile`.)
PROD_TOOLS=()
while IFS= read -r _line; do
  [[ -n "$_line" ]] && PROD_TOOLS+=("$_line")
done < <(jq -r --arg os "$OS_TYPE" --argjson tags "$ALLOWED_TAGS_JSON" \
  '.tools[] | select(.phase != "system") | select(.auto_install == null or .auto_install == true) | select(.[$os] != null) | select([.tags[] | . as $t | $tags | index($t)] | any) | .name' \
  "$TOOLS_JSON")

_install_one_package_tool() {
  install_tool "$1" "$TOOLS_JSON"
}

run_phase_items "$PHASE_NUM" "$PHASE_TOTAL" "Herramientas de productividad" PROD_TOOLS _install_one_package_tool
exit $?
