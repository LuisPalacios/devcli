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

  # Reemplazar locale hardcodeado (solo si es diferente del default)
  if [[ "$SETUP_LANG" != "es_ES.UTF-8" ]]; then
    sed -i "s/export LANG=es_ES.UTF-8/export LANG=$SETUP_LANG/g" "$zshrc_file"
  fi

  success "Personalización de .zshrc completada (backup: $backup_file)"
}

# Función principal
main() {
  log "Iniciando instalación de dotfiles..."
  log "Usuario: $CURRENT_USER | Idioma: $SETUP_LANG"
  log "Sistema: $OS_TYPE"

  # Directorio de dotfiles
  local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../dotfiles" && pwd)"
  local target_home="$HOME"

  # Validar que el directorio de dotfiles existe
  if [[ ! -d "$dotfiles_dir" ]]; then
    error "Directorio de dotfiles no encontrado: $dotfiles_dir"
    exit 1
  fi

  # Archivo de configuración JSON
  local dotfiles_config="$(dirname "${BASH_SOURCE[0]}")/03-dotfiles.json"

  # Verificar que jq está disponible
  if ! command -v jq &>/dev/null; then
    error "jq es requerido para procesar la configuración JSON"
    exit 1
  fi

  # Verificar que el archivo JSON existe
  if [[ ! -f "$dotfiles_config" ]]; then
    error "Archivo de configuración no encontrado: $dotfiles_config"
    exit 1
  fi

  # Leer dotfiles desde JSON
  local dotfiles_data
  if ! dotfiles_data=$(jq -r '.dotfiles[] | @base64' "$dotfiles_config" 2>/dev/null); then
    error "Error procesando configuración JSON: $dotfiles_config"
    exit 1
  fi

  local installed_count=0
  local failed_count=0

  log "Copiando dotfiles según configuración..."

  # Procesar cada dotfile del JSON
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue

    local dotfile_info
    if ! dotfile_info=$(echo "$line" | base64 --decode 2>/dev/null); then
      warning "Error decodificando entrada JSON"
      ((failed_count++))
      continue
    fi

    local file dst_relative
    file=$(echo "$dotfile_info" | jq -r '.file // empty' 2>/dev/null)
    dst_relative=$(echo "$dotfile_info" | jq -r '.dst // "./"' 2>/dev/null)

    if [[ -z "$file" ]]; then
      warning "Dotfile con configuración incompleta omitido"
      ((failed_count++))
      continue
    fi

    local src="$dotfiles_dir/$file"

    # Construir ruta de destino
    local dst_dir
    if [[ "$dst_relative" == "./" || "$dst_relative" == "." ]]; then
      dst_dir="$target_home"
    else
      dst_dir="$target_home/${dst_relative%/}"
    fi

    local dst="$dst_dir/$file"

    # Validar que el archivo fuente existe
    if [[ ! -f "$src" ]]; then
      warning "Archivo fuente no encontrado: $src"
      ((failed_count++))
      continue
    fi

    # Crear directorio de destino si no existe
    if [[ ! -d "$dst_dir" ]]; then
      if mkdir -p "$dst_dir" 2>/dev/null; then
        log "Directorio creado: $dst_dir"
      else
        warning "No se pudo crear directorio: $dst_dir"
        ((failed_count++))
        continue
      fi
    fi

    # Crear backup si el archivo ya existe
    # if [[ -f "$dst" ]]; then
    #   local timestamp=$(date +%Y%m%d_%H%M%S)
    #   local backup_file="${dst}.backup.${timestamp}"
    #   if cp "$dst" "$backup_file" 2>/dev/null; then
    #     log "Backup creado: $backup_file"
    #   fi
    # fi

    # Copiar archivo
    echo "Copiando $src a $dst"
    if cp -f "$src" "$dst" 2>/dev/null; then
      local dst_display="${dst_relative%/}"
      [[ "$dst_display" == "./" || "$dst_display" == "." ]] && dst_display="(home)"
      success "✅ Copiado: $file → $dst_display"
      ((installed_count++))

      # Personalizar .zshrc si es necesario
      if [[ "$file" == ".zshrc" ]]; then
        log "Personalizando .zshrc..."
        customize_zshrc "$dst"
      fi
    else
      warning "Error copiando $file"
      ((failed_count++))
    fi

  done <<< "$dotfiles_data"

  # Cambiar shell a zsh si está disponible y el sistema lo requiere
  local shell_changed=false
  if command -v zsh &>/dev/null; then
    local zsh_path
    zsh_path="$(command -v zsh)"

    case "${OS_TYPE:-}" in
      macos)
        # macOS usa zsh por defecto desde Catalina
        ;;
      linux|wsl2)
        local current_shell
        current_shell="$(getent passwd "$CURRENT_USER" | cut -d: -f7)"

        if [[ "$current_shell" != "$zsh_path" ]]; then
          log "Cambiando shell por defecto a zsh..."
          if chsh -s "$zsh_path" >/dev/null 2>&1; then
            shell_changed=true
          else
            warning "No se pudo cambiar la shell por defecto (puede requerir contraseña)"
          fi
        fi
        ;;
    esac
  fi

  # Verificar archivos críticos instalados
  local critical_files=(".zshrc" ".luispa.omp.json")
  local missing_files=()

  for file in "${critical_files[@]}"; do
    if [[ ! -f "$target_home/$file" ]]; then
      missing_files+=("$file")
    fi
  done

  # Mostrar resumen final
  if [[ $installed_count -gt 0 ]]; then
    if [[ "$shell_changed" == "true" ]]; then
      success "✅ Dotfiles instalados ($installed_count archivos) y shell cambiada a zsh"
    else
      success "✅ Dotfiles instalados ($installed_count archivos)"
    fi

    if [[ $failed_count -gt 0 ]]; then
      warning "$failed_count archivos fallaron en la copia"
    fi
  else
    log "No se instalaron dotfiles nuevos"
  fi

  if [[ ${#missing_files[@]} -gt 0 ]]; then
    warning "❌ Archivos críticos no disponibles: ${missing_files[*]}"
  fi
}

# Ejecutar función principal
main "$@"
