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

# Asegurar que existe el directorio de binarios
ensure_directory "$BIN_DIR"

# Paquetes esenciales obligatorios
COMMON_PACKAGES=(git curl wget nano zsh)

# Comprueba que git esté instalado o lo instala
if ! command_exists git; then
  log "Instalando git..."
  install_package git
fi

# Actualizar repositorios
log "Actualizando repositorios..."
update_package_manager

# Instalar paquetes comunes
log "Instalando paquetes base..."
for pkg in "${COMMON_PACKAGES[@]}"; do
  install_package "$pkg"
done

# Instala oh-my-posh en $BIN_DIR (ver env.sh)
if ! command -v "$BIN_DIR/oh-my-posh" &>/dev/null; then
  log "Instalando oh-my-posh..."
  curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$BIN_DIR" >/dev/null 2>&1

  # Validar que se instaló correctamente
  if ! command -v "$BIN_DIR/oh-my-posh" &>/dev/null; then
    error "oh-my-posh no se instaló correctamente"
    exit 1
  fi
fi

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
PACKAGES_COUNT=$(count_installed_packages "${COMMON_PACKAGES[@]}")
success "Configuración base completada ($PACKAGES_COUNT paquetes verificados)"

