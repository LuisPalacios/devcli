#!/usr/bin/env bash
#
set -euo pipefail

# Variables básicas para bootstrap (sin cargar env.sh)
REPO_URL="https://github.com/LuisPalacios/linux-setup.git"
BRANCH="main"
CURRENT_USER="$(id -un)"
SETUP_DIR="$HOME/.linux-setup"

# Función de log minimalista
log() {
  echo "[bootstrap] $*"
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
    echo "[bootstrap] ❌ Sistema operativo no soportado: $OSTYPE"
    exit 1
  fi
}

# Ejecutar detección
detect_os_type

# Preparación del entorno
log "Preparando entorno en $OS_TYPE..."

# Verificar permisos sudo
if ! sudo -n true 2>/dev/null; then
  echo "[ERROR] El usuario '$CURRENT_USER' no tiene acceso a sudo sin contraseña. Aborta."
  exit 1
fi

# Instalar git si es necesario (silencioso)
if ! command -v git &>/dev/null; then
  log "Instalando git..."
  case "${OS_TYPE:-}" in
    linux|wsl2)
      sudo apt-get update -y -qq >/dev/null 2>&1
      sudo apt-get install -y -qq git >/dev/null 2>&1
      ;;
    macos)
      if ! command -v brew &>/dev/null; then
        echo "[bootstrap] ❌ Homebrew no está instalado. Instálalo primero desde https://brew.sh"
        exit 1
      fi
      brew install git >/dev/null 2>&1
      ;;
    *)
      log "❌ No se pudo instalar git automáticamente."
      exit 1
      ;;
  esac
fi

# Clona o actualiza el repo (completamente silencioso)
if [[ -d "$SETUP_DIR" ]]; then
  git -C "$SETUP_DIR" reset --hard HEAD >/dev/null 2>&1
  git -C "$SETUP_DIR" clean -fd >/dev/null 2>&1
  git -C "$SETUP_DIR" pull >/dev/null 2>&1
else
  git clone --branch "$BRANCH" "$REPO_URL" "$SETUP_DIR" >/dev/null 2>&1
fi

# Dar permisos de ejecución a todos los scripts de instalación
chmod +x "$SETUP_DIR/install"/*.sh >/dev/null 2>&1

# Ejecutar scripts de instalación
cd "$SETUP_DIR/install"

# Ejecuta la instalación por fases (silenciosa)
log "Ejecutando scripts de instalación:"
for f in [0-9][0-9]-*.sh; do
  if [[ -f "$f" ]]; then
    log "▶ Ejecutando $f"
    "./$f"
  fi
done

log "✅ Instalación completada exitosamente"
