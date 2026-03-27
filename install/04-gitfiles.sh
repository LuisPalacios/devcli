#!/usr/bin/env bash
#
# 04-gitfiles.sh — Descarga binarios desde GitHub Releases
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
GITFILES_CONFIG="$REPO_DIR/install/04-gitfiles.json"

# Asegurar que existe el directorio de binarios
ensure_directory "$BIN_DIR"

# Contador de binarios instalados
BINS_INSTALLED=0

# Verificar que jq está disponible
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

# Determinar la clave de plataforma para seleccionar el asset correcto
get_platform_key() {
  local arch
  arch=$(detect_arch) || return 1

  case "${OS_TYPE:-}" in
    linux|wsl2) echo "linux-${arch}" ;;
    macos)      echo "macos-${arch}" ;;
    *)
      error "Plataforma no soportada: ${OS_TYPE:-desconocida}"
      return 1
      ;;
  esac
}

# Obtener la URL de descarga del último release de un repositorio GitHub
get_latest_release_url() {
  local repo="$1"
  local asset_name="$2"
  local api_url="https://api.github.com/repos/${repo}/releases/latest"

  # Obtener la URL de descarga del asset
  local download_url
  download_url=$(curl -fsSL "$api_url" | jq -r --arg name "$asset_name" '.assets[] | select(.name == $name) | .browser_download_url')

  if [[ -z "$download_url" || "$download_url" == "null" ]]; then
    error "No se encontró el asset '$asset_name' en $repo/releases/latest"
    return 1
  fi

  echo "$download_url"
}

# Descargar, extraer e instalar un binario desde un ZIP de GitHub Releases
install_release_binary() {
  local repo="$1"
  local binary_name="$2"
  local asset_name="$3"

  # Obtener URL de descarga
  local download_url
  download_url=$(get_latest_release_url "$repo" "$asset_name") || return 1

  # Crear directorio temporal
  local temp_dir="/tmp/gitfiles-$(date +%s)-$$"
  mkdir -p "$temp_dir"

  local zip_file="$temp_dir/$asset_name"

  # Descargar el ZIP
  log "Descargando $asset_name..."
  if ! curl -fsSL -o "$zip_file" "$download_url"; then
    error "No se pudo descargar: $download_url"
    rm -rf "$temp_dir"
    return 1
  fi

  # Extraer el ZIP
  if ! unzip -o -q "$zip_file" -d "$temp_dir"; then
    error "No se pudo extraer: $zip_file"
    rm -rf "$temp_dir"
    return 1
  fi

  # Buscar el binario dentro del directorio extraído
  local binary_path
  binary_path=$(find "$temp_dir" -name "$binary_name" -type f | head -1)

  if [[ -z "$binary_path" ]]; then
    error "Binario '$binary_name' no encontrado en $asset_name"
    rm -rf "$temp_dir"
    return 1
  fi

  # Copiar al directorio de binarios y dar permisos de ejecución
  cp -f "$binary_path" "$BIN_DIR/$binary_name"
  chmod 755 "$BIN_DIR/$binary_name"

  # En macOS eliminar el atributo de cuarentena para evitar el bloqueo de Gatekeeper
  if [[ "${OS_TYPE:-}" == "macos" ]]; then
    xattr -cr "$BIN_DIR/$binary_name"
  fi

  # Limpiar
  rm -rf "$temp_dir"
  return 0
}

# Función principal
main() {
  log "Instalando binarios desde GitHub Releases..."

  # Verificar dependencias
  if ! check_jq; then
    error "No se pudo instalar jq - abortando"
    exit 1
  fi

  # Validar archivo de configuración
  if [[ ! -f "$GITFILES_CONFIG" ]]; then
    error "Archivo de configuración no encontrado: $GITFILES_CONFIG"
    exit 1
  fi

  if ! jq empty "$GITFILES_CONFIG" 2>/dev/null; then
    error "Archivo JSON inválido: $GITFILES_CONFIG"
    exit 1
  fi

  # Determinar plataforma
  local platform_key
  platform_key=$(get_platform_key) || exit 1

  # Contar releases
  local release_count
  release_count=$(jq '.releases | length' "$GITFILES_CONFIG")

  if [[ "$release_count" -eq 0 ]]; then
    log "No hay releases configurados"
    return 0
  fi

  # Procesar cada release
  local idx=0
  while [[ $idx -lt $release_count ]]; do
    local repo binary asset_name

    repo=$(jq -r ".releases[$idx].repo" "$GITFILES_CONFIG")
    binary=$(jq -r ".releases[$idx].binary" "$GITFILES_CONFIG")
    asset_name=$(jq -r ".releases[$idx].assets[\"$platform_key\"]" "$GITFILES_CONFIG")

    if [[ -z "$asset_name" || "$asset_name" == "null" ]]; then
      warning "No hay asset para plataforma '$platform_key' en $repo - omitiendo"
      idx=$((idx + 1))
      continue
    fi

    if install_release_binary "$repo" "$binary" "$asset_name"; then
      BINS_INSTALLED=$((BINS_INSTALLED + 1))
      success "$binary instalado desde $repo"
    else
      warning "Error instalando $binary desde $repo"
    fi

    idx=$((idx + 1))
  done

  # Resumen final
  if [[ $BINS_INSTALLED -gt 0 ]]; then
    success "Binarios desde GitHub Releases instalados ($BINS_INSTALLED)"
  else
    log "No se instalaron binarios desde GitHub Releases"
  fi
}

# Ejecutar función principal
main "$@"
