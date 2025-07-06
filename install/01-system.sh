#!/usr/bin/env bash

set -euo pipefail

log() {
  echo "[01-system] $*"
}

# Asegura que sudo funcione sin contraseña
if ! sudo -n true 2>/dev/null; then
  echo "[ERROR] El usuario '$USER' no tiene acceso a sudo sin contraseña. Aborta."
  exit 1
fi

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
sudo apt-get update -y -qq

PACKAGES=(git curl wget nano zsh)

for pkg in "${PACKAGES[@]}"; do
  if dpkg -s "$pkg" &>/dev/null; then
    log "$pkg ya está instalado"
  else
    log "Instalando $pkg..."
    sudo apt-get install -y -qq "$pkg"
  fi
done

# Instala oh-my-posh en ~/bin
if ! command -v "$BIN_DIR/oh-my-posh" &>/dev/null; then
  log "Instalando oh-my-posh en $BIN_DIR"
  curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$BIN_DIR"
else
  log "oh-my-posh ya está instalado en $BIN_DIR"
fi

# Asegura que locale es_ES.UTF-8 esté generada
if ! locale -a | grep -q 'es_ES.utf8'; then
  log "Generando locale es_ES.UTF-8..."
  sudo locale-gen es_ES.UTF-8
  sudo update-locale LANG=es_ES.UTF-8 LC_ALL=es_ES.UTF-8
else
  log "Locale es_ES.UTF-8 ya disponible"
fi

