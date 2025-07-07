#!/usr/bin/env bash
# -------------------------------------------------------------------
# utils.sh - Utilidades compartidas para scripts de instalación
# -------------------------------------------------------------------

# Función de log con timestamp
log() {
  local script_name="${BASH_SOURCE[1]##*/}"
  script_name="${script_name%.sh}"
  echo "[$(date '+%H:%M:%S')] [$script_name] $*"
}

# Función de log simple (para compatibilidad)
log_simple() {
  local script_name="${BASH_SOURCE[1]##*/}"
  script_name="${script_name%.sh}"
  echo "[$script_name] $*"
}

# Función para verificar si un comando existe
command_exists() {
  command -v "$1" &>/dev/null
}

# Función para verificar si un paquete está instalado (Linux/WSL2)
package_installed_apt() {
  dpkg -s "$1" &>/dev/null
}

# Función para verificar si un paquete está instalado (macOS)
package_installed_brew() {
  brew list --formula "$1" &>/dev/null
}

# Función para instalar paquete según OS
install_package() {
  local pkg="$1"

  case "${OS_TYPE:-}" in
    linux|wsl2)
      if package_installed_apt "$pkg"; then
        log "$pkg ya está instalado"
      else
        log "Instalando $pkg..."
        sudo apt-get install -y -qq "$pkg"
      fi
      ;;
    macos)
      if package_installed_brew "$pkg"; then
        log "$pkg ya está instalado"
      else
        log "Instalando $pkg..."
        brew install "$pkg"
      fi
      ;;
    *)
      log "❌ OS_TYPE no soportado para instalación: $OS_TYPE"
      return 1
      ;;
  esac
}

# Función para crear directorio si no existe
ensure_directory() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    log "Creando directorio: $dir"
    mkdir -p "$dir"
  fi
}

# Función para verificar permisos sudo
check_sudo_access() {
  if ! sudo -n true 2>/dev/null; then
    echo "[ERROR] El usuario '$CURRENT_USER' no tiene acceso a sudo sin contraseña. Aborta."
    exit 1
  fi
}

# Función para actualizar repositorios según OS
update_package_manager() {
  case "${OS_TYPE:-}" in
    linux|wsl2)
      log "Actualizando lista de paquetes (APT)..."
      sudo apt-get update -y -qq
      ;;
    macos)
      # Homebrew se actualiza automáticamente
      ;;
    *)
      log "❌ OS_TYPE no soportado para actualización: $OS_TYPE"
      return 1
      ;;
  esac
}
