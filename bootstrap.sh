#!/usr/bin/env bash

set -euo pipefail

REPO_URL="https://github.com/LuisPalacios/linux-setup.git"
SETUP_DIR="$HOME/.linux-setup"
BRANCH="main"

log() {
  echo "[bootstrap] $*"
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
    echo "[bootstrap] ❌ Sistema operativo no soportado: $OSTYPE"
    export OS_TYPE="other"
    exit 1
  fi
}

# Invoca detección
detect_os_type
log "Sistema detectado: $OS_TYPE"

# Asegura que sudo funcione sin contraseña
if ! sudo -n true 2>/dev/null; then
  echo "[ERROR] El usuario '$USER' no tiene acceso a sudo sin contraseña. Aborta."
  exit 1
fi

# Comprueba que git esté instalado o lo instala
if ! command -v git &>/dev/null; then
  log "git no está instalado. Intentando instalar..."

  case "$OS_TYPE" in
    linux|wsl2)
      sudo apt-get update -y -qq
      sudo apt-get install -y -qq git
      ;;
    macos)
      if ! command -v brew &>/dev/null; then
        echo "[bootstrap] ❌ Homebrew no está instalado. Instálalo primero desde https://brew.sh"
        exit 1
      fi
      brew install git
      ;;
    *)
      log "❌ No se pudo instalar git automáticamente. Instálalo manualmente e intenta de nuevo."
      exit 1
      ;;
  esac
else
  log "git ya está instalado"
fi

# Clona o actualiza el repo
if [[ -d "$SETUP_DIR" ]]; then
  log "Actualizando repo en $SETUP_DIR"
  git -C "$SETUP_DIR" reset --hard HEAD
  git -C "$SETUP_DIR" clean -fd
  git -C "$SETUP_DIR" pull
else
  log "Clonando repo en $SETUP_DIR"
  git clone --branch "$BRANCH" "$REPO_URL" "$SETUP_DIR"
fi

cd "$SETUP_DIR/install"

# Ejecuta la instalación por fases
log "Ejecutando scripts de instalación"
for f in 0*.sh; do
  chmod +x "$f"
  log "▶ Ejecutando $f"
  "./$f"
done

log "✅ Instalación completada"
