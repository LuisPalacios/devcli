#!/usr/bin/env bash
#
# Fase 04 — Binarios desde GitHub Releases (04-gitfiles.json).
#
# Códigos de salida: 0=ok, 1=warn, 2=fail (jq ausente, JSON inválido,
# arquitectura no soportada).

set -uo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

ux_init

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GITFILES_CONFIG="$REPO_DIR/install/04-gitfiles.json"

ensure_directory "$BIN_DIR"

# Asegurar jq antes de la fase visual (sin él no podemos ni leer el config).
if ! command_exists jq; then
  case "${OS_TYPE:-}" in
    linux|wsl2) ux_run -- sudo apt install -y -qq jq >/dev/null 2>&1 || true ;;
    macos)      ux_run -- brew install jq >/dev/null 2>&1 || true ;;
  esac
fi

if ! command_exists jq; then
  ux_phase_begin "${PHASE_NUM:-4}" "${PHASE_TOTAL:-5}" "Repos externos (GitHub Releases)"
  ux_error "jq es requerido pero no se pudo instalar"
  ux_phase_end fail
  exit 2
fi
if [[ ! -f "$GITFILES_CONFIG" ]] || ! jq empty "$GITFILES_CONFIG" 2>/dev/null; then
  ux_phase_begin "${PHASE_NUM:-4}" "${PHASE_TOTAL:-5}" "Repos externos (GitHub Releases)"
  ux_error "configuración inválida: $GITFILES_CONFIG"
  ux_phase_end fail
  exit 2
fi

# Determinar la clave de plataforma para seleccionar el asset adecuado.
arch=$(detect_arch) || {
  ux_phase_begin "${PHASE_NUM:-4}" "${PHASE_TOTAL:-5}" "Repos externos (GitHub Releases)"
  ux_error "arquitectura no soportada"
  ux_phase_end fail
  exit 2
}
case "${OS_TYPE:-}" in
  linux|wsl2) PLATFORM_KEY="linux-${arch}" ;;
  macos)      PLATFORM_KEY="macos-${arch}" ;;
  *)
    ux_phase_begin "${PHASE_NUM:-4}" "${PHASE_TOTAL:-5}" "Repos externos (GitHub Releases)"
    ux_error "plataforma no soportada: ${OS_TYPE:-?}"
    ux_phase_end fail
    exit 2
    ;;
esac

# Construir la lista de binarios + arrays paralelos para lookup repo/asset.
# (Bash 3.2 compat: no `declare -A`. Single jq stream con @tsv en vez de
# indexed access — antes hacía 3*N llamadas a jq.)
RELEASES=()
RELEASE_REPOS=()
RELEASE_ASSETS=()
while IFS=$'\t' read -r binary repo asset; do
  [[ -z "$binary" || -z "$asset" || "$asset" == "null" ]] && continue
  RELEASES+=("$binary")
  RELEASE_REPOS+=("$repo")
  RELEASE_ASSETS+=("$asset")
done < <(jq -r --arg p "$PLATFORM_KEY" \
  '.releases[] | [.binary, .repo, (.assets[$p] // "")] | @tsv' \
  "$GITFILES_CONFIG")

# Lookup: dado un binario, devuelve su repo o asset usando los arrays paralelos.
_release_lookup() {
  local key="$1" which="$2" i
  for i in "${!RELEASES[@]}"; do
    if [[ "${RELEASES[$i]}" == "$key" ]]; then
      case "$which" in
        repo)  printf "%s" "${RELEASE_REPOS[$i]}" ;;
        asset) printf "%s" "${RELEASE_ASSETS[$i]}" ;;
      esac
      return 0
    fi
  done
  return 1
}

# Obtiene la URL de descarga del último release de un asset (silencioso).
_get_latest_release_url() {
  local repo="$1" asset_name="$2"
  curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
    | jq -r --arg name "$asset_name" '.assets[] | select(.name == $name) | .browser_download_url'
}

_install_one_release() {
  local binary="$1"
  local repo asset
  repo="$(_release_lookup "$binary" repo)"
  asset="$(_release_lookup "$binary" asset)"
  local url temp_dir zip_file binary_path

  url="$(_get_latest_release_url "$repo" "$asset" 2>/dev/null)"
  if [[ -z "$url" ]] || [[ "$url" == "null" ]]; then
    ux_warn "$binary: asset '$asset' no encontrado en $repo"
    return 1
  fi

  temp_dir="/tmp/gitfiles-$(date +%s)-$$"
  mkdir -p "$temp_dir"
  zip_file="$temp_dir/$asset"

  if ! curl -fsSL -o "$zip_file" "$url"; then
    ux_warn "$binary: error de descarga"
    rm -rf "$temp_dir"
    return 1
  fi

  if ! unzip -o -q "$zip_file" -d "$temp_dir"; then
    ux_warn "$binary: error al extraer $asset"
    rm -rf "$temp_dir"
    return 1
  fi

  binary_path=$(find "$temp_dir" -name "$binary" -type f 2>/dev/null | head -1)
  if [[ -z "$binary_path" ]]; then
    ux_warn "$binary: no se encontró dentro de $asset"
    rm -rf "$temp_dir"
    return 1
  fi

  cp -f "$binary_path" "$BIN_DIR/$binary"
  chmod 755 "$BIN_DIR/$binary"
  if [[ "${OS_TYPE:-}" == "macos" ]]; then
    xattr -cr "$BIN_DIR/$binary" 2>/dev/null || true
  fi
  rm -rf "$temp_dir"
  return 0
}

run_phase_items "$PHASE_NUM" "$PHASE_TOTAL" "Repos externos (GitHub Releases)" RELEASES _install_one_release
exit $?
