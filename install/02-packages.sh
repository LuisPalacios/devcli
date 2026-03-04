#!/usr/bin/env bash
#
set -euo pipefail

# Carga las variables de entorno
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

# Carga las utilidades compartidas
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# Función de log (usando la de utils.sh)
log() {
  log_simple "$*"
}

# Verificar permisos sudo
if [[ $IS_ROOT == false ]]; then
  check_sudo_access
fi

# Actualizar repositorios (silencioso)
update_package_manager

# Instalar herramientas de productividad desde tools.json (filtradas por perfil)
TOOLS_JSON="$(dirname "${BASH_SOURCE[0]}")/tools.json"

# Resolver perfil y tags permitidos
DEVCLI_PROFILE="${DEVCLI_PROFILE:-full}"
ALLOWED_TAGS_JSON=$(jq -c --arg p "$DEVCLI_PROFILE" '.profiles[$p] // ["core","dev","k8s","win"]' "$TOOLS_JSON")
log "Perfil: $DEVCLI_PROFILE (tags: $(echo "$ALLOWED_TAGS_JSON" | jq -r 'join(", ")'))"

log "Instalando herramientas de productividad..."
PACKAGES_INSTALLED=0
PACKAGES_FAILED=0

while IFS= read -r tool_name; do
  if [[ -n "$tool_name" ]]; then
    if install_tool "$tool_name" "$TOOLS_JSON"; then
      PACKAGES_INSTALLED=$((PACKAGES_INSTALLED + 1))
    else
      warning "Falló la instalación de $tool_name - continuando con el siguiente"
      PACKAGES_FAILED=$((PACKAGES_FAILED + 1))
    fi
  fi
done < <(jq -r --arg os "$OS_TYPE" --argjson tags "$ALLOWED_TAGS_JSON" \
  '.tools[] | select(.auto_install == null or .auto_install == true) | select(.[$os] != null) | select([.tags[] | . as $t | $tags | index($t)] | any) | .name' \
  "$TOOLS_JSON")

# Mostrar resumen final
if [[ $PACKAGES_INSTALLED -gt 0 ]]; then
  success "Herramientas de productividad instaladas ($PACKAGES_INSTALLED paquetes)"
  if [[ $PACKAGES_FAILED -gt 0 ]]; then
    warning "$PACKAGES_FAILED paquetes fallaron en la instalación"
  fi
else
  log "No se instalaron nuevos paquetes"
fi
