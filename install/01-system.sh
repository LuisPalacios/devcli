#!/bin/bash
set -euo pipefail

log() {
  echo "[01-system] $*"
}

# Actualiza repos si es necesario
log "Actualizando lista de paquetes..."
sudo apt-get update -y

# Paquetes base
PACKAGES=(git curl wget zsh)

for pkg in "${PACKAGES[@]}"; do
  if dpkg -s "$pkg" &>/dev/null; then
    log "$pkg ya está instalado"
  else
    log "Instalando $pkg..."
    sudo apt-get install -y "$pkg"
  fi
done

# oh-my-posh
if ! command -v oh-my-posh &>/dev/null; then
  log "Instalando oh-my-posh..."
  curl -s https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin
else
  log "oh-my-posh ya está instalado"
fi
