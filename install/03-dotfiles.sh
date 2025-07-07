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

# Directorio de dotfiles
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../dotfiles" && pwd)"
TARGET_HOME="$HOME"

# Validar que el directorio de dotfiles existe
if [[ ! -d "$DOTFILES_DIR" ]]; then
  error "Directorio de dotfiles no encontrado: $DOTFILES_DIR"
  exit 1
fi

# Contador de dotfiles instalados
INSTALLED_COUNT=0

# Instala los dotfiles
log "Instalando dotfiles..."
for file in "${DOTFILES_LIST[@]}"; do
  src="$DOTFILES_DIR/$file"
  dst="$TARGET_HOME/$file"

  # Validar que el archivo fuente existe
  if [[ ! -f "$src" ]]; then
    warning "Dotfile no encontrado: $src"
    continue
  fi

  # Copiar archivo (silencioso pero capturando errores)
  if cp -f "$src" "$dst" >/dev/null 2>&1; then
    INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
    
    # Modificar .zshrc dinámicamente si es necesario
    if [[ "$file" == ".zshrc" ]]; then
      log "Personalizando .zshrc..."
      customize_zshrc "$dst"
    fi
  else
    warning "No se pudo copiar $file"
  fi
done

# Función para personalizar .zshrc
customize_zshrc() {
  local zshrc_file="$1"
  
  # Validar que el archivo existe y es escribible
  if [[ ! -w "$zshrc_file" ]]; then
    warning "No se puede escribir en $zshrc_file"
    return 1
  fi
  
  # Crear backup del archivo original
  local backup_file="${zshrc_file}.backup.$(date +%Y%m%d_%H%M%S)"
  cp "$zshrc_file" "$backup_file"
  
  # Reemplazar usuario hardcodeado
  sed -i "s/SOY=\"luis\"/SOY=\"$CURRENT_USER\"/g" "$zshrc_file"
  
  # Reemplazar locale hardcodeado (solo si es diferente del default)
  if [[ "$SETUP_LANG" != "es_ES.UTF-8" ]]; then
    sed -i "s/export LANG=es_ES.UTF-8/export LANG=$SETUP_LANG/g" "$zshrc_file"
    sed -i "s/export LC_CTYPE=\"es_ES.UTF-8\"/export LC_CTYPE=\"$SETUP_LANG\"/g" "$zshrc_file"
    sed -i "s/export LC_NUMERIC=\"es_ES.UTF-8\"/export LC_NUMERIC=\"$SETUP_LANG\"/g" "$zshrc_file"
    sed -i "s/export LC_TIME=\"es_ES.UTF-8\"/export LC_TIME=\"$SETUP_LANG\"/g" "$zshrc_file"
    sed -i "s/export LC_COLLATE=\"es_ES.UTF-8\"/export LC_COLLATE=\"$SETUP_LANG\"/g" "$zshrc_file"
    sed -i "s/export LC_MONETARY=\"es_ES.UTF-8\"/export LC_MONETARY=\"$SETUP_LANG\"/g" "$zshrc_file"
    sed -i "s/export LC_MESSAGES=\"es_ES.UTF-8\"/export LC_MESSAGES=\"$SETUP_LANG\"/g" "$zshrc_file"
    sed -i "s/export LC_PAPER=\"es_ES.UTF-8\"/export LC_PAPER=\"$SETUP_LANG\"/g" "$zshrc_file"
    sed -i "s/export LC_NAME=\"es_ES.UTF-8\"/export LC_NAME=\"$SETUP_LANG\"/g" "$zshrc_file"
    sed -i "s/export LC_ADDRESS=\"es_ES.UTF-8\"/export LC_ADDRESS=\"$SETUP_LANG\"/g" "$zshrc_file"
    sed -i "s/export LC_TELEPHONE=\"es_ES.UTF-8\"/export LC_TELEPHONE=\"$SETUP_LANG\"/g" "$zshrc_file"
    sed -i "s/export LC_MEASUREMENT=\"es_ES.UTF-8\"/export LC_MEASUREMENT=\"$SETUP_LANG\"/g" "$zshrc_file"
    sed -i "s/export LC_IDENTIFICATION=\"es_ES.UTF-8\"/export LC_IDENTIFICATION=\"$SETUP_LANG\"/g" "$zshrc_file"
    sed -i "s/export LC_ALL=\"es_ES.UTF-8\"/export LC_ALL=\"$SETUP_LANG\"/g" "$zshrc_file"
  fi
  
  # Comentar rutas hardcodeadas que no existen (solo si no están ya comentadas)
  sed -i '/^[[:space:]]*alias t="exec ~\/Nextcloud\/priv\/bin\/t"/s/^/# /' "$zshrc_file"
  sed -i '/^[[:space:]]*alias tt="~/Nextcloud\/priv\/bin\/t"/s/^/# /' "$zshrc_file"
  
  # Comentar rutas específicas de WSL2 que pueden no existir
  sed -i '/^[[:space:]]*"\/mnt\/c\/Users\/${SOY}\/Nextcloud\/priv\/bin"/s/^/# /' "$zshrc_file"
  sed -i '/^[[:space:]]*"\/mnt\/c\/Users\/${SOY}\/Nextcloud\/priv\/bin\/win"/s/^/# /' "$zshrc_file"
  sed -i '/^[[:space:]]*"\/mnt\/c\/Users\/${SOY}\/dev-tools\/kombine.win"/s/^/# /' "$zshrc_file"
  sed -i '/^[[:space:]]*"\/mnt\/c\/Users\/${SOY}\/AppData\/Local\/Programs\/Microsoft VS Code\/bin"/s/^/# /' "$zshrc_file"
  
  # Comentar rutas específicas de macOS que pueden no existir
  sed -i '/^[[:space:]]*"${HOME}\/Nextcloud\/priv\/bin"/s/^/# /' "$zshrc_file"
  sed -i '/^[[:space:]]*"${HOME}\/dev-tools\/kombine.osx"/s/^/# /' "$zshrc_file"
  sed -i '/^[[:space:]]*alias e="\/usr\/local\/bin\/code"/s/^/# /' "$zshrc_file"
  
  # Comentar alias git.exe específico de WSL2
  sed -i '/^[[:space:]]*alias git="git.exe"/s/^/# /' "$zshrc_file"
  
  # Comentar alias c específico de WSL2
  sed -i '/^[[:space:]]*alias c="cd \/mnt\/c\/Users\/${SOY}"/s/^/# /' "$zshrc_file"
  
  success "Personalización de .zshrc completada (backup: $backup_file)"
}

# Cambiar shell a zsh si está disponible y el sistema lo requiere
SHELL_CHANGED=false
if command -v zsh &>/dev/null; then
  ZSH_PATH="$(command -v zsh)"

  case "${OS_TYPE:-}" in
    macos)
      # macOS usa zsh por defecto desde Catalina
      ;;
    linux|wsl2)
      CURRENT_SHELL="$(getent passwd "$CURRENT_USER" | cut -d: -f7)"

      if [[ "$CURRENT_SHELL" != "$ZSH_PATH" ]]; then
        log "Cambiando shell por defecto a zsh..."
        if chsh -s "$ZSH_PATH" >/dev/null 2>&1; then
          SHELL_CHANGED=true
        else
          warning "No se pudo cambiar la shell por defecto (puede requerir contraseña)"
        fi
      fi
      ;;
  esac
fi

# Mostrar resumen final
if [[ "$SHELL_CHANGED" == "true" ]]; then
  success "Dotfiles instalados ($INSTALLED_COUNT archivos) y shell cambiada a zsh"
else
  success "Dotfiles instalados ($INSTALLED_COUNT archivos)"
fi
