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

# Archivo de configuración
PACKAGES_CONFIG="$(dirname "${BASH_SOURCE[0]}")/02-packages.json"

# Actualizar repositorios
log "Actualizando repositorios..."
update_package_manager

# Instalar paquetes desde JSON
log "Instalando herramientas de productividad..."
PACKAGES_INSTALLED=0
PACKAGES_FAILED=0

while IFS= read -r pkg; do
  if [[ -n "$pkg" ]]; then
    if install_package "$pkg"; then
      PACKAGES_INSTALLED=$((PACKAGES_INSTALLED + 1))
    else
      warning "Falló la instalación de $pkg - continuando con el siguiente paquete"
      PACKAGES_FAILED=$((PACKAGES_FAILED + 1))
    fi
  fi
done < <(read_packages_with_os_names "$PACKAGES_CONFIG" "packages")

# Instalar Nerd Fonts si lsd está en la lista
if read_packages_with_os_names "$PACKAGES_CONFIG" "packages" | grep -q "lsd"; then
  install_nerd_fonts
fi

# Crear alias para herramientas con nombres diferentes en Debian/Ubuntu
case "${OS_TYPE:-}" in
  linux|wsl2)
    # batcat alias para bat en Debian/Ubuntu
    if command_exists batcat && ! command_exists bat; then
      ln -sf "$(command -v batcat)" "$BIN_DIR/bat" >/dev/null 2>&1
    fi

    # fdfind alias para fd
    if command_exists fdfind && ! command_exists fd; then
      ln -sf "$(command -v fdfind)" "$BIN_DIR/fd" >/dev/null 2>&1
    fi
    ;;
esac

# Mostrar resumen final
if [[ $PACKAGES_INSTALLED -gt 0 ]]; then
  success "Herramientas de productividad instaladas ($PACKAGES_INSTALLED paquetes)"
  if [[ $PACKAGES_FAILED -gt 0 ]]; then
    warning "$PACKAGES_FAILED paquetes fallaron en la instalación"
  fi
else
  log "No se instalaron nuevos paquetes"
fi
