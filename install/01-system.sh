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

# Paquetes base comunes
COMMON_PACKAGES=(git curl wget nano zsh)

# Comprueba que git esté instalado o lo instala
if ! command_exists git; then
  log "git no está instalado. Intentando instalar..."
  install_package git
else
  log "git ya está instalado"
fi

# Actualizar repositorios
update_package_manager

# Instalar paquetes comunes
for pkg in "${COMMON_PACKAGES[@]}"; do
  install_package "$pkg"
done

# Instala oh-my-posh en $BIN_DIR (ver env.sh)
if ! command -v "$BIN_DIR/oh-my-posh" &>/dev/null; then
  log "Instalando oh-my-posh en $BIN_DIR"
  curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$BIN_DIR"

  # Validar que se instaló correctamente
  if ! command -v "$BIN_DIR/oh-my-posh" &>/dev/null; then
    log "❌ Error: oh-my-posh no se instaló correctamente"
    exit 1
  else
    log "✅ oh-my-posh instalado correctamente"
  fi
else
  log "oh-my-posh ya está instalado en $BIN_DIR"
fi

# Convertir LANG canónica, por ejemplo: es_ES.UTF-8 → nombre usado en locale -a (es_ES.utf8)
SETUP_LOCALE_NAME="$(echo "$SETUP_LANG" | sed 's/UTF-8/utf8/I')"

# Locale solo en Linux (no aplica a macOS ni WSL2 sin systemd completo)
if [[ "$OS_TYPE" == "linux" ]]; then
  if ! locale -a | grep -iq "^$SETUP_LOCALE_NAME$"; then
    log "Generando locale $SETUP_LANG..."
    sudo locale-gen "$SETUP_LANG"
    sudo update-locale LANG="$SETUP_LANG" LC_ALL="$SETUP_LANG"
  else
    log "Locale $SETUP_LANG ya disponible"
  fi
fi

