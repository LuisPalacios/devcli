#!/usr/bin/env bash
#
# Script de prueba para verificar bootstrap.sh
# Simula la ejecución remota sin clonar realmente

set -euo pipefail

echo "🧪 Probando bootstrap.sh..."

# Variables básicas para bootstrap (sin cargar env.sh)
REPO_URL="https://github.com/LuisPalacios/linux-setup.git"
BRANCH="main"
CURRENT_USER="$(id -un)"
SETUP_DIR="$HOME/.linux-setup"

# Función de log
log() {
  echo "[test-bootstrap] $*"
}

# Detección básica de sistema operativo (sin env.sh)
detect_os_type() {
  if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
    OS_TYPE="wsl2"
  elif [[ "$OSTYPE" == darwin* ]]; then
    OS_TYPE="macos"
  elif [[ "$OSTYPE" == linux* ]]; then
    OS_TYPE="linux"
  else
    echo "[test-bootstrap] ❌ Sistema operativo no soportado: $OSTYPE"
    exit 1
  fi
}

# Ejecutar detección
detect_os_type

# Log de detección de sistema operativo
log "Sistema detectado: $OS_TYPE"
log "Usuario actual: $CURRENT_USER"
log "Directorio de setup: $SETUP_DIR"

# Verificar permisos sudo
if ! sudo -n true 2>/dev/null; then
  echo "[ERROR] El usuario '$CURRENT_USER' no tiene acceso a sudo sin contraseña."
  echo "Para configurar sudo sin contraseña:"
  echo "1. sudo usermod -aG sudo $CURRENT_USER"
  echo "2. sudo visudo"
  echo "3. Añadir línea: $CURRENT_USER ALL=(ALL) NOPASSWD:ALL"
  exit 1
fi

log "✅ Permisos sudo verificados"

# Verificar git
if ! command -v git &>/dev/null; then
  log "git no está instalado. Intentando instalar..."
  
  case "${OS_TYPE:-}" in
    linux|wsl2)
      sudo apt-get update -y -qq
      sudo apt-get install -y -qq git
      ;;
    macos)
      if ! command -v brew &>/dev/null; then
        echo "[test-bootstrap] ❌ Homebrew no está instalado. Instálalo primero desde https://brew.sh"
        exit 1
      fi
      brew install git
      ;;
    *)
      log "❌ No se pudo instalar git automáticamente."
      exit 1
      ;;
  esac
else
  log "✅ git ya está instalado"
fi

log "✅ Todas las verificaciones pasaron"
log "🚀 El bootstrap.sh debería funcionar correctamente" 