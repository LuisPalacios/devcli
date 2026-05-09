#!/usr/bin/env bash
#
# Fase 03 — Copia los dotfiles definidos en 03-dotfiles.json a $HOME y, en
# Linux/WSL2, cambia la shell por defecto a zsh.
#
# Sale con:
#   0  → todo OK
#   1  → algún archivo o el chsh falló (warning, no bloqueante)
#   2  → error de configuración (jq ausente, JSON corrupto, dir fuente no existe)

set -uo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

ux_init

# Validaciones de configuración (programación, no entorno de usuario)
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../dotfiles" && pwd)"
DOTFILES_CONFIG="$(dirname "${BASH_SOURCE[0]}")/03-dotfiles.json"

if [[ ! -d "$DOTFILES_DIR" ]]; then
  ux_phase_begin "${PHASE_NUM:-3}" "${PHASE_TOTAL:-5}" "Dotfiles"
  ux_error "directorio de dotfiles no encontrado: $DOTFILES_DIR"
  ux_phase_end fail
  exit 2
fi
if ! command -v jq &>/dev/null; then
  ux_phase_begin "${PHASE_NUM:-3}" "${PHASE_TOTAL:-5}" "Dotfiles"
  ux_error "jq es requerido pero no está instalado"
  ux_phase_end fail
  exit 2
fi
if [[ ! -f "$DOTFILES_CONFIG" ]]; then
  ux_phase_begin "${PHASE_NUM:-3}" "${PHASE_TOTAL:-5}" "Dotfiles"
  ux_error "configuración no encontrada: $DOTFILES_CONFIG"
  ux_phase_end fail
  exit 2
fi

# Construir la lista de items + dos arrays paralelos para el lookup file→dst.
# (Bash 3.2 compat: no `declare -A`, usamos arrays paralelos + helper.)
DOTFILE_KEYS=()
DOTFILE_VALUES=()
DOTFILES=()
while IFS='|' read -r f d; do
  [[ -n "$f" ]] || continue
  DOTFILE_KEYS+=("$f")
  DOTFILE_VALUES+=("$d")
  DOTFILES+=("$f")
done < <(jq -r --arg p "$OS_TYPE" \
  '.dotfiles[] | select(.platforms | index($p)) | "\(.file)|\(.dst)"' \
  "$DOTFILES_CONFIG")

_dotfile_dst() {
  local key="$1" i
  for i in "${!DOTFILE_KEYS[@]}"; do
    if [[ "${DOTFILE_KEYS[$i]}" == "$key" ]]; then
      printf "%s" "${DOTFILE_VALUES[$i]}"
      return 0
    fi
  done
  return 1
}

# Personaliza .zshrc (locale, backup) sin generar ruido visual.
customize_zshrc() {
  local zshrc_file="$1"
  [[ -w "$zshrc_file" ]] || return 0
  cp "$zshrc_file" "${zshrc_file}.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
  if [[ "${SETUP_LANG:-es_ES.UTF-8}" != "es_ES.UTF-8" ]]; then
    sed -i "s/export LANG=es_ES.UTF-8/export LANG=$SETUP_LANG/g" "$zshrc_file" 2>/dev/null || true
  fi
}

# Handler por archivo: copia src→dst. Devuelve 0/1.
_install_one_dotfile() {
  local file="$1"
  local dst_rel
  dst_rel="$(_dotfile_dst "$file")" || { ux_warn "$file: sin destino en JSON"; return 1; }
  [[ -n "$dst_rel" ]] || { ux_warn "$file: destino vacío"; return 1; }

  local src="$DOTFILES_DIR/$file"
  local dst="$HOME/$dst_rel"
  local dst_dir; dst_dir="$(dirname "$dst")"

  if [[ ! -f "$src" ]]; then
    ux_warn "$file: archivo fuente no encontrado"
    return 1
  fi

  if ! mkdir -p "$dst_dir" 2>/dev/null; then
    ux_warn "$file: no se pudo crear $dst_dir"
    return 1
  fi

  if ! cp -f "$src" "$dst" 2>/dev/null; then
    ux_warn "$file: error al copiar a $dst"
    return 1
  fi

  [[ "$file" == "zshrc" ]] && customize_zshrc "$dst"
  return 0
}

# Ejecutar la fase
run_phase_items "$PHASE_NUM" "$PHASE_TOTAL" "Dotfiles" DOTFILES _install_one_dotfile
phase_rc=$?

# Post-fase: cambiar shell a zsh en Linux/WSL2 (no aplica a macOS — ya es zsh).
chsh_failed=0
if command -v zsh &>/dev/null; then
  case "${OS_TYPE:-}" in
    linux|wsl2)
      zsh_path="$(command -v zsh)"
      current_shell="$(getent passwd "$CURRENT_USER" 2>/dev/null | cut -d: -f7)"
      if [[ -n "$current_shell" ]] && [[ "$current_shell" != "$zsh_path" ]]; then
        if ! sudo chsh -s "$zsh_path" "$CURRENT_USER" >/dev/null 2>&1; then
          ux_warn "no se pudo cambiar shell por defecto a zsh (puede requerir contraseña)"
          chsh_failed=1
        fi
      fi
      ;;
  esac
fi

# Si el chsh falló pero las copias fueron OK, devolvemos warn (1).
if [[ $chsh_failed -eq 1 ]] && [[ $phase_rc -eq 0 ]]; then
  exit 1
fi
exit $phase_rc
