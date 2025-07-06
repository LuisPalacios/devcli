#!/usr/bin/env bash

set -euo pipefail

log() {
  echo "[02-packages] $*"
}

# Asegura que sudo funcione sin contraseña
if ! sudo -n true 2>/dev/null; then
  echo "[ERROR] El usuario '$USER' no tiene acceso a sudo sin contraseña. Aborta."
  exit 1
fi

# Define los paquetes comunes
COMMON_PACKAGES=(
  htop
  tmux
  fzf
  bat
  fd-find
  ripgrep
  tree
  lsd
)

# Instala paquetes según la plataforma
case "$OS_TYPE" in
  linux|wsl2)
    log "Actualizando índice de paquetes (APT)..."
    sudo apt-get update -y -qq

    for pkg in "${COMMON_PACKAGES[@]}"; do
      if dpkg -s "$pkg" &>/dev/null; then
        log "$pkg ya está instalado"
      else
        log "Instalando $pkg..."
        sudo apt-get install -y -qq "$pkg"
      fi
    done

    # batcat alias para bat en Debian/Ubuntu
    if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
      log "Creando alias simbólico bat → batcat en ~/bin"
      ln -sf "$(command -v batcat)" "$HOME/bin/bat"
    fi

    # fdfind alias para fd
    if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
      log "Creando alias simbólico fd → fdfind en ~/bin"
      ln -sf "$(command -v fdfind)" "$HOME/bin/fd"
    fi
    ;;

  macos)
    if ! command -v brew &>/dev/null; then
      echo "[02-packages] ❌ Homebrew no está instalado. Instálalo primero desde https://brew.sh"
      exit 1
    fi

    for pkg in "${COMMON_PACKAGES[@]}"; do
      if brew list "$pkg" &>/dev/null; then
        log "$pkg ya está instalado"
      else
        log "Instalando $pkg con Homebrew..."
        brew install "$pkg"
      fi
    done
    ;;

  *)
    echo "[02-packages] ❌ Plataforma no soportada: $OS_TYPE"
    exit 1
    ;;
esac
