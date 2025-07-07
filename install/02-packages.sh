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
update_package_manager

# Instalar paquetes comunes
for pkg in "${COMMON_PACKAGES[@]}"; do
  install_package "$pkg"
done

# Crear alias para herramientas con nombres diferentes en Debian/Ubuntu
case "${OS_TYPE:-}" in
  linux|wsl2)
    # batcat alias para bat en Debian/Ubuntu
    if command_exists batcat && ! command_exists bat; then
      log "Creando alias simbólico bat → batcat en ~/bin"
      ln -sf "$(command -v batcat)" "$BIN_DIR/bat"
    fi

    # fdfind alias para fd
    if command_exists fdfind && ! command_exists fd; then
      log "Creando alias simbólico fd → fdfind en ~/bin"
      ln -sf "$(command -v fdfind)" "$BIN_DIR/fd"
    fi
    ;;
esac
