#!/usr/bin/env bash
# -------------------------------------------------------------------
# env.sh - Variables y entorno compartido para scripts de instalación
# -------------------------------------------------------------------

# URL del repositorio
export REPO_URL="https://github.com/LuisPalacios/devcli.git"

# Rama del repositorio
export BRANCH="main"

# Usuario actual
export CURRENT_USER="$(id -un)"

# Directorio de instalación
export SETUP_DIR="$HOME/.devcli"

# Binarios de usuario
export BIN_DIR="$HOME/bin"

# Idioma y locale
export SETUP_LANG="es_ES.UTF-8"

# Configuración de Nerd Fonts
export NERD_FONT_NAME="FiraCode"
export NERD_FONT_FULL_NAME="FiraCode Nerd Font"

# Función para detectar el usuario actual de forma dinámica
detect_current_user() {
  # Priorizar variables de entorno comunes
  if [[ -n "${SUDO_USER:-}" ]]; then
    export CURRENT_USER="$SUDO_USER"
  elif [[ -n "${USER:-}" ]]; then
    export CURRENT_USER="$USER"
  else
    export CURRENT_USER="$(id -un)"
  fi
}

# Detección de sistema operativo compatible
# Establece OS_TYPE: macos, wsl2, linux, other
# Aborta si no es compatible
detect_os_type() {
  if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
    export OS_TYPE="wsl2"
  elif [[ "$OSTYPE" == darwin* ]]; then
    export OS_TYPE="macos"
  elif [[ "$OSTYPE" == linux* ]]; then
    export OS_TYPE="linux"
  else
    echo "[env.sh] ❌ Sistema operativo no soportado: $OSTYPE"
    export OS_TYPE="other"
    exit 1
  fi
}

# Detección de usuario root
detect_root_user() {
  if [[ $EUID -eq 0 ]]; then
    IS_ROOT=true
  else
    IS_ROOT=false
  fi
}

# Función para validar entorno mínimo
validate_environment() {
  # Verificar que estamos en un entorno interactivo
  if [[ ! -t 0 ]]; then
    echo "[env.sh] ❌ No se detecta un terminal interactivo"
    exit 1
  fi

  # Verificar permisos de escritura en HOME
  if [[ ! -w "$HOME" ]]; then
    echo "[env.sh] ❌ No hay permisos de escritura en $HOME"
    exit 1
  fi
}

# Ejecutar detecciones al cargar
detect_current_user
detect_os_type
detect_root_user
validate_environment
