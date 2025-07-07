#!/usr/bin/env bash
#
set -euo pipefail

# Carga las variables de entorno
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

# Función de log
log() {
  echo "[01-system] $*"
}

# Asegura que sudo funcione sin contraseña
if ! sudo -n true 2>/dev/null; then
  echo "[ERROR] El usuario '$CURRENT_USER' no tiene acceso a sudo sin contraseña. Aborta."
  exit 1
fi

# Me aseguro de que existe el directorio de los binarios del
# usuario ($BIN_DIR definido en env.sh)
if [[ ! -d "$BIN_DIR" ]]; then
  log "Creando $BIN_DIR"
  mkdir -p "$BIN_DIR"
fi

# Paquetes base comunes
COMMON_PACKAGES=(git curl wget nano zsh)

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

# Instala paquetes según la plataforma
case "${OS_TYPE:-}" in
  linux|wsl2)
    log "Actualizando lista de paquetes (APT)..."
    sudo apt-get update -y -qq

    for pkg in "${COMMON_PACKAGES[@]}"; do
      if dpkg -s "$pkg" &>/dev/null; then
        log "$pkg ya está instalado"
      else
        log "Instalando $pkg..."
        sudo apt-get install -y -qq "$pkg"
      fi
    done
    ;;

  macos)
    if ! command -v brew &>/dev/null; then
      echo "[01-system] ❌ Homebrew no está instalado. Aborta."
      exit 1
    fi

    for pkg in "${COMMON_PACKAGES[@]}"; do
      if brew list --formula "$pkg" &>/dev/null; then
        log "$pkg ya está instalado"
      else
        log "Instalando $pkg..."
        brew install "$pkg"
      fi
    done
    ;;

  *)
    echo "[01-system] ❌ OS_TYPE desconocido o no soportado: $OS_TYPE"
    exit 1
    ;;
esac

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

