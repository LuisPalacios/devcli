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

# Asegurar que existe el directorio de binarios
ensure_directory "$BIN_DIR"

# Comprueba que git esté instalado (necesario antes de todo)
if ! command_exists git; then
  log "Instalando git..."
  sudo apt install -y -qq git >/dev/null 2>&1 || brew install git >/dev/null 2>&1
fi

# Actualizar repositorios
log "Actualizando repositorios..."
update_package_manager

# Instalar herramientas del sistema desde tools.json (tag: system)
TOOLS_JSON="$(dirname "${BASH_SOURCE[0]}")/tools.json"

log "Instalando paquetes base..."
SYSTEM_INSTALLED=0
while IFS= read -r tool_name; do
  if [[ -n "$tool_name" ]] && install_tool "$tool_name" "$TOOLS_JSON"; then
    SYSTEM_INSTALLED=$((SYSTEM_INSTALLED + 1))
  fi
done < <(jq -r --arg os "$OS_TYPE" \
  '.tools[] | select(.tags | index("system")) | select(.[$os] != null) | .name' \
  "$TOOLS_JSON")

# Convertir LANG canónica, por ejemplo: es_ES.UTF-8 → nombre usado en locale -a (es_ES.utf8)
SETUP_LOCALE_NAME="$(echo "$SETUP_LANG" | sed 's/UTF-8/utf8/I')"

# Locale solo en Linux (no aplica a macOS ni WSL2 sin systemd completo)
if [[ "$OS_TYPE" == "linux" ]]; then
  if ! locale -a | grep -iq "^$SETUP_LOCALE_NAME$"; then
    log "Configurando locale..."

    # Descomentar la línea de locale en /etc/locale.gen
    sudo sed -i "s|^# *${SETUP_LANG}[[:space:]]\+UTF-8|${SETUP_LANG} UTF-8|" /etc/locale.gen

    # Generar el locale
    sudo locale-gen "$SETUP_LANG" >/dev/null 2>&1
    sudo update-locale LANG="$SETUP_LANG" >/dev/null 2>&1
  fi
fi

# Mostrar resumen final
success "Configuración base completada ($SYSTEM_INSTALLED herramientas del sistema)"
