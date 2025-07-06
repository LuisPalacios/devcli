#!/bin/bash
set -euo pipefail

log() {
  echo "[01-system] $*"
}

# Asegura que ~/bin exista y esté en PATH
BIN_DIR="$HOME/bin"
if [[ ! -d "$BIN_DIR" ]]; then
  log "Creando $BIN_DIR"
  mkdir -p "$BIN_DIR"
else
  log "$BIN_DIR ya existe"
fi

# Paquetes base
log "Actualizando lista de paquetes..."
sudo apt-get update -y

PACKAGES=(git curl wget zsh)

for pkg in "${PACKAGES[@]}"; do
  if dpkg -s "$pkg" &>/dev/null; then
    log "$pkg ya está instalado"
  else
    log "Instalando $pkg..."
    sudo apt-get install -y "$pkg"
  fi
done

# Instala oh-my-posh en ~/bin
if ! command -v "$BIN_DIR/oh-my-posh" &>/dev/null; then
  log "Instalando oh-my-posh en $BIN_DIR"
  curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$BIN_DIR"
else
  log "oh-my-posh ya está instalado en $BIN_DIR"
fi
