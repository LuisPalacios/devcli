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

# Directorio del repositorio
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Archivo de configuración
GITFILES_CONFIG="$REPO_DIR/gitfiles.json"

# Asegurar que existe el directorio de binarios
ensure_directory "$BIN_DIR"

# Contador de archivos copiados
FILES_COPIED=0

# Función para verificar si jq está disponible
check_jq() {
  if ! command_exists jq; then
    log "Instalando jq para procesar JSON..."
    case "${OS_TYPE:-}" in
      linux|wsl2)
        if ! sudo apt install -y -qq jq >/dev/null 2>&1; then
          error "No se pudo instalar jq"
          return 1
        fi
        ;;
      macos)
        if ! brew install jq >/dev/null 2>&1; then
          error "No se pudo instalar jq"
          return 1
        fi
        ;;
      *)
        error "OS_TYPE no soportado para instalar jq: $OS_TYPE"
        return 1
        ;;
    esac
  fi
}

# Función para verificar si git está disponible
check_git() {
  if ! command_exists git; then
    error "git no está disponible"
    return 1
  fi
}

# Función para validar archivo JSON
validate_json() {
  local json_file="$1"

  if [[ ! -f "$json_file" ]]; then
    error "Archivo de configuración no encontrado: $json_file"
    return 1
  fi

  if ! jq empty "$json_file" 2>/dev/null; then
    error "Archivo JSON inválido: $json_file"

    return 1
  fi

  # Verificar estructura básica
  if ! jq -e '.repositories' "$json_file" >/dev/null 2>&1; then
    error "Estructura JSON inválida: falta 'repositories'"
    return 1
  fi
}

# Función para clonar repositorio temporalmente
clone_repo_temp() {
  local repo_url="$1"
  local temp_dir="$2"

  # Clonar repositorio directamente en el directorio temporal
  if ! git clone --depth 1 --quiet "$repo_url" "$temp_dir" >/dev/null 2>&1; then
    error "No se pudo clonar repositorio: $repo_url"
    return 1
  fi

  # Verificar que el directorio se creó correctamente
  if [[ ! -d "$temp_dir" ]]; then
    error "Directorio clonado no encontrado: $temp_dir"
    return 1
  fi

  return 0
}

# Función para copiar archivo con permisos apropiados
copy_file_with_permissions() {
  local src_file="$1"
  local dst_file="$2"

  # Verificar que el archivo fuente existe
  if [[ ! -f "$src_file" ]]; then
    warning "Archivo no encontrado: $src_file"
    return 1
  fi

  # Copiar archivo
  if ! cp -f "$src_file" "$dst_file" >/dev/null 2>&1; then
    error "No se pudo copiar: $src_file -> $dst_file"
    return 1
  fi

  # Aplicar permisos según extensión
  local filename=$(basename "$src_file")
  if [[ "$filename" != *.ps1 ]]; then
    # Aplicar permisos 755 para archivos ejecutables
    chmod 755 "$dst_file" >/dev/null 2>&1
#     log "Copiado: $filename (755)"
#   else
#     # Mantener permisos originales para archivos .ps1
#     log "Copiado: $filename (original)"
  fi
  return 0

}

# Función para procesar un repositorio
process_repository() {
  local repo_url="$1"
  local files_array="$2"

  log "Procesando repositorio: $repo_url"

  # Crear directorio temporal único
  local temp_dir="/tmp/gitfiles-$(date +%s)-$$"

  # Clonar repositorio
  if ! clone_repo_temp "$repo_url" "$temp_dir"; then
    rm -rf "$temp_dir" >/dev/null 2>&1 || true
    return 1
  fi

  # Contador de archivos copiados en este repositorio
  local repo_files_copied=0

  # Procesar cada archivo
  while IFS= read -r file_path; do
    # Limpiar path (remover ./ si existe)
    local clean_path="${file_path#./}"
    local src_file="$temp_dir/$clean_path"
    local filename=$(basename "$clean_path")
    local dst_file="$BIN_DIR/$filename"

    if copy_file_with_permissions "$src_file" "$dst_file"; then
      repo_files_copied=$((repo_files_copied + 1))
      FILES_COPIED=$((FILES_COPIED + 1))
    fi
  done < <(echo "$files_array" | jq -r '.[]')

  # Limpiar directorio temporal
  rm -rf "$temp_dir" >/dev/null 2>&1 || true

  log "Repositorio procesado: $repo_files_copied archivos copiados"
}

# Función principal
main() {
  log "Iniciando instalación de archivos desde repositorios Git..."

  # Verificar dependencias
  if ! check_jq; then
    error "No se pudo instalar jq - abortando"
    exit 1
  fi

  if ! check_git; then
    error "git no está disponible - abortando"
    exit 1
  fi

  # Validar archivo de configuración
  if ! validate_json "$GITFILES_CONFIG"; then
    error "Configuración inválida - abortando"
    exit 1
  fi

  # Contar repositorios
  local repo_count
  repo_count=$(jq '.repositories | length' "$GITFILES_CONFIG")

  if [[ "$repo_count" -eq 0 ]]; then
    log "No hay repositorios configurados"
    return 0
  fi

  # Procesar cada repositorio
  local repo_index=0
  while [[ $repo_index -lt $repo_count ]]; do
    local repo_url
    local files_array

    repo_url=$(jq -r ".repositories[$repo_index].url" "$GITFILES_CONFIG")
    files_array=$(jq -c ".repositories[$repo_index].files" "$GITFILES_CONFIG")

    if ! process_repository "$repo_url" "$files_array"; then
      warning "Error procesando repositorio: $repo_url"
    fi

    repo_index=$((repo_index + 1))
  done

  # Mostrar resumen final
  if [[ $FILES_COPIED -gt 0 ]]; then
    success "Archivos desde repositorios Git instalados ($FILES_COPIED archivos)"
  else
    log "No se copiaron archivos desde repositorios Git"
  fi
}

# Ejecutar función principal
main "$@"