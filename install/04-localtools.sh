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

# Contador de herramientas instaladas
TOOLS_INSTALLED=0

# Copiar herramientas al directorio de los binarios
log "Instalando herramientas locales..."
for tool in e confcat s; do
  src="$FILES_DIR/bin/$tool"
  dst="$BIN_DIR/$tool"

  if [[ -f "$src" ]]; then
    cp -f "$src" "$dst" >/dev/null 2>&1
    chmod 755 "$dst" >/dev/null 2>&1
    TOOLS_INSTALLED=$((TOOLS_INSTALLED + 1))
  fi
done

# Configuración y directorios dependientes del sistema operativo
case "${OS_TYPE:-}" in
  linux|wsl2)
    # Instalar configuración de nano (silencioso)
    if [[ -f "$FILES_DIR/etc/nanorc" ]]; then
      log "Configurando nano..."
      sudo cp -f "$FILES_DIR/etc/nanorc" /etc/nanorc >/dev/null 2>&1
    fi

    # Crear directorio /root/.nano (silencioso)
    sudo mkdir -p /root/.nano >/dev/null 2>&1
    ;;

  macos)
    log "macOS detectado: se omite configuración de /etc/nanorc y /root/.nano"
    ;;

  *)
    log "Sistema no soportado: omitiendo configuración específica de nano"
    ;;
esac

# Crear directorio local de nano (común a todos)
mkdir -p "$HOME/.nano" >/dev/null 2>&1

# Mostrar resumen final
success "Herramientas locales instaladas ($TOOLS_INSTALLED herramientas)"