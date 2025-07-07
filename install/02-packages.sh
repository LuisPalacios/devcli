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
check_sudo_access

# Define los paquetes comunes
# Future: lsd, nerd fonts, etc.
COMMON_PACKAGES=(
  htop
  tmux
  fzf
  bat
  ripgrep
  tree
  lsd
)

# Actualizar repositorios
log "Actualizando repositorios..."
update_package_manager

# Instalar paquetes comunes
log "Instalando herramientas de productividad..."
for pkg in "${COMMON_PACKAGES[@]}"; do
  if ! install_package "$pkg"; then
    warning "Falló la instalación de $pkg - continuando con el siguiente paquete"
  fi
done

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
PACKAGES_COUNT=$(count_installed_packages "${COMMON_PACKAGES[@]}")
success "Herramientas de productividad instaladas ($PACKAGES_COUNT paquetes verificados)"
