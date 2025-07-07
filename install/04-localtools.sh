#!/usr/bin/env bash
#
set -euo pipefail

# Carga las variables de entorno
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

# Carga las utilidades compartidas
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# Función de log (usando la de utils.sh)
log() {
  log_simple "$*"
}

# Directorio de archivos
FILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../files" && pwd)"

# Asegurar que existe el directorio de binarios
ensure_directory "$BIN_DIR"

# Copiar herramientas al directorio de los binarios
for tool in e confcat s; do
  src="$FILES_DIR/bin/$tool"
  dst="$BIN_DIR/$tool"

  log "Instalando $tool en $dst"
  cp -f "$src" "$dst"
  chmod 755 "$dst"
done

# Configuración y directorios dependientes del sistema operativo
case "${OS_TYPE:-}" in
  linux|wsl2)
    log "Instalando configuración personalizada de nano en /etc/nanorc"
    sudo cp -f "$FILES_DIR/etc/nanorc" /etc/nanorc

    log "Creando /root/.nano"
    sudo mkdir -p /root/.nano
    ;;

  macos)
    log "macOS detectado: se omite configuración de /etc/nanorc y /root/.nano"
    ;;

  *)
    log "Sistema no soportado: omitiendo configuración específica de nano"
    ;;
esac

# Crear directorio local de nano (común a todos)
log "Creando ~/.nano"
mkdir -p "$HOME/.nano"

log "✅ Herramientas locales instaladas"