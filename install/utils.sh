#!/usr/bin/env bash
# -------------------------------------------------------------------
# utils.sh - Utilidades compartidas para scripts de instalación
# -------------------------------------------------------------------
#
# Error / control-flow contract (post-UX layer):
#
#   - method_* (apt, brew, curl-sh, github-deb, github-binary, github-zip):
#       return 0 en éxito, 1 en fallo de instalación. NUNCA `exit` ni `throw`.
#       Usar `warning` para mensajes al usuario (se enruta a ux_warn cuando
#       la capa UX está activa, a stderr en otro caso).
#
#   - run_phase_items: devuelve 0=ok, 1=warn (algún tool falló pero hubo
#       éxitos), 2=fail (todos fallaron). Los phase scripts capturan ese
#       código y hacen `exit $rc` para que bootstrap haga la contabilidad.
#
#   - Phase scripts: NO llamar `exit` a media fase — dejar que run_phase_items
#       cierre la fase y salir con su código en la última línea.
#
#   - Prerrequisitos duros (jq ausente, config inválida): emitir
#       `ux_phase_begin/error/end fail` y `exit 2` directamente. Bootstrap
#       cuenta la fase como FAIL.
#
# -------------------------------------------------------------------

# Bridge a la capa UX. Bootstrap llama `ux_init` antes de cualquier phase
# script y los phase scripts también llaman `ux_init` al arrancar — así que
# `_DEVCLI_UX_ACTIVE=1` siempre está set cuando se invocan estas funciones.
# `log`/`success` van al log file, `warning`/`error` se enrutan a las
# sub-líneas amarillas/rojas de la fase activa.
log() {
  [[ -n "${_DEVCLI_UX_LOG_FILE:-}" ]] && echo "[$(date '+%H:%M:%S')] $*" >>"$_DEVCLI_UX_LOG_FILE"
  return 0
}

error()   { ux_error "$*"; }
warning() { ux_warn  "$*"; }

success() {
  [[ -n "${_DEVCLI_UX_LOG_FILE:-}" ]] && echo "[OK] $*" >>"$_DEVCLI_UX_LOG_FILE"
  return 0
}

# Función para verificar si un comando existe
command_exists() {
  command -v "$1" &>/dev/null
}

# -------------------------------------------------------------------
# Modo simulación (DEVCLI_DRY_RUN=1, `bootstrap.sh -n`)
# -------------------------------------------------------------------
# Cada punto que escribe algo (gestor de paquetes, descargas, ficheros,
# cambios de sistema) comprueba `dry_run_active` y, en lugar de actuar,
# anota lo que haría con `dry_note`. Las fases son subprocesos, así que las
# notas van a un fichero ($DEVCLI_DRY_RUN_FILE, lo crea bootstrap) y
# ux_summary las imprime agrupadas al final.
#
# Categorías: apt, apt-terceros, repo, descarga, brew, sistema, home,
# aviso, presente (ya instalado, no se haría nada).

dry_run_active() {
  [[ "${DEVCLI_DRY_RUN:-0}" == "1" ]]
}

# Args: $1 = categoría, $2 = detalle
dry_note() {
  if [[ -n "${DEVCLI_DRY_RUN_FILE:-}" ]]; then
    printf '%s\t%s\n' "$1" "$2" >>"$DEVCLI_DRY_RUN_FILE"
  else
    printf '[simulación] %s: %s\n' "$1" "$2" >&2
  fi
}

# Ruta con $HOME abreviado a ~ (sólo para mostrar).
_tilde() {
  local p="$1"
  [[ "$p" == "$HOME"* ]] && p="~${p#"$HOME"}"
  printf '%s' "$p"
}

# Función para verificar si un paquete está instalado (Linux/WSL2)
package_installed_apt() {
  dpkg -s "$1" &>/dev/null
}

# Función para verificar si un paquete está instalado (macOS)
package_installed_brew() {
  brew list --formula "$1" &>/dev/null
}

# Claude Code sin coautoría ni atribución en commits y PRs.
# ~/.claude/settings.json es por máquina: sin la clave "attribution", el
# harness añade "Co-Authored-By" a cada commit aunque el CLAUDE.md global lo
# prohíba. Sólo se toca esa clave (y se quita la antigua includeCoAuthoredBy);
# el resto del fichero se respeta. Idempotente: si ya está, no escribe nada.
# Si tiene que escribir, deja antes un backup <settings.json>.backup.<fecha>.
# Requiere jq. Args: $1 = ruta (opcional, por defecto ~/.claude/settings.json).
# Devuelve 0 si queda bien, 1 si no pudo (con aviso).
DEVCLI_CLAUDE_ATTRIBUTION='{"commit":"","pr":"","sessionUrl":false}'

ensure_claude_attribution() {
  local f="${1:-$HOME/.claude/settings.json}" tmp
  local filter='.attribution = $a | del(.includeCoAuthoredBy)'

  if [[ -s "$f" ]]; then
    if ! jq -e 'type == "object"' "$f" >/dev/null 2>&1; then
      ux_warn "$f: no es un objeto JSON válido; no se toca (añade a mano \"attribution\": $DEVCLI_CLAUDE_ATTRIBUTION)"
      return 1
    fi
    if jq -e --argjson a "$DEVCLI_CLAUDE_ATTRIBUTION" \
      '.attribution == $a and (has("includeCoAuthoredBy") | not)' "$f" >/dev/null 2>&1; then
      return 0
    fi
  fi

  # Modo simulación, si esta versión de utils.sh lo trae: anotar y no escribir.
  if declare -F dry_run_active >/dev/null 2>&1 && dry_run_active; then
    declare -F dry_note >/dev/null 2>&1 &&
      dry_note home "$f: \"attribution\" vacío (Claude Code sin coautor en commits ni PRs)"
    return 0
  fi

  mkdir -p "$(dirname "$f")" 2>/dev/null || { ux_warn "no se pudo crear $(dirname "$f")"; return 1; }
  tmp="$f.devcli-tmp.$$"
  if [[ -s "$f" ]]; then
    cp -p "$f" "$f.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || { ux_warn "$f: no se pudo hacer backup; no se toca"; return 1; }
    jq --argjson a "$DEVCLI_CLAUDE_ATTRIBUTION" "$filter" "$f" >"$tmp" 2>/dev/null
  else
    jq -n --argjson a "$DEVCLI_CLAUDE_ATTRIBUTION" "{} | $filter" >"$tmp" 2>/dev/null
  fi
  if [[ $? -ne 0 ]] || [[ ! -s "$tmp" ]] || ! mv -f "$tmp" "$f" 2>/dev/null; then
    rm -f "$tmp"
    ux_warn "$f: no se pudo escribir \"attribution\""
    return 1
  fi
  return 0
}


# -------------------------------------------------------------------
# Method Dispatchers — catalog-driven tool installation from tools.json
# -------------------------------------------------------------------

# Detect system architecture (amd64/arm64)
detect_arch() {
  case "$(uname -m)" in
    x86_64)       echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *)
      warning "Arquitectura no soportada: $(uname -m)"
      return 1
      ;;
  esac
}

# Expand shell variables in a JSON string value (${HOME}, ${BIN_DIR}, etc.)
expand_vars() {
  eval echo "$1"
}

# Note: los handlers method_* devuelven 0 en éxito y 1 en fallo. NO escriben
# a la pantalla — toda la salida bruta de los gestores (apt/brew/curl/...) va
# al log file vía ux_run_silent. Las advertencias se emiten con `warning`,
# que cuando la capa UX está activa se redirige a ux_warn (sub-línea bajo
# la fase actual).
#
# Contrato unificado de idempotencia (follow-up #2):
#   - Methods con package manager (apt, brew): usan package_installed_apt /
#     package_installed_brew internamente — el nombre del paquete no siempre
#     coincide con un comando (p.ej. libnss3-tools).
#   - Methods sin package manager (curl-sh, github-deb, github-binary): usan
#     `_check_cmd_present <check_cmd>` antes de instalar y como verificación
#     post-install. El campo `check_cmd` en tools.json es opcional pero
#     recomendado.
#   - github-zip: detección especial (multi-fuente: fc-list, find, atsutil)
#     porque las fonts no son un comando sino archivos .ttf/.otf.

# Extract a single JSON field from a tools.json block, with optional default.
# Reduces noise y unifica el idiom "field con default vacío" usado por todos
# los method_*. Args: $1 = block JSON, $2 = jq path (.field), $3 = default.
_block_field() {
  local block="$1" path="$2" default="${3:-}"
  echo "$block" | jq -r "${path} // \"${default}\""
}

# Idempotency check basado en check_cmd. Devuelve 0 si el comando ya está
# disponible (en PATH o como ejecutable bajo $BIN_DIR), 1 en caso contrario.
# check_cmd vacío → 1 (sin opinión: el handler debe usar otro mecanismo).
#
# Usado por curl-sh, github-deb y github-binary tanto para skip-if-installed
# como para verificación post-install.
_check_cmd_present() {
  local check_cmd="$1"
  [[ -z "$check_cmd" ]] && return 1
  command_exists "$check_cmd" && return 0
  [[ -n "${BIN_DIR:-}" ]] && [[ -x "${BIN_DIR}/${check_cmd}" ]] && return 0
  return 1
}

# --- Method: apt ---
method_apt() {
  local pkg
  pkg=$(_block_field "$1" .package)

  if package_installed_apt "$pkg"; then
    dry_run_active && dry_note presente "$pkg"
    return 0
  fi

  if dry_run_active; then
    if [[ -n "${_DEVCLI_APT_ORIGIN:-}" ]]; then
      dry_note apt-terceros "$pkg (repositorio ${_DEVCLI_APT_ORIGIN})"
    else
      dry_note apt "$pkg"
    fi
    return 0
  fi

  # Perfil server: sin paquetes recomendados (menos superficie) y sin
  # preguntas de debconf (la salida va al log; una pregunta colgaría la fase).
  if [[ "${DEVCLI_PROFILE:-}" == "server" ]]; then
    if ! ux_run_silent sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends "$pkg"; then
      warning "$pkg: apt-get falló"
      return 1
    fi
    return 0
  fi

  if ! ux_run_silent sudo apt install -y -qq "$pkg"; then
    warning "$pkg: apt-get falló"
    return 1
  fi
}

# --- Method: brew (formula or, with cask:true, GUI app vía --cask) ---
method_brew() {
  local block="$1" pkg cask
  pkg=$(_block_field "$block" .package)
  cask=$(_block_field "$block" .cask false)

  if dry_run_active; then
    if [[ "$cask" == "true" ]]; then
      if brew list --cask "$pkg" &>/dev/null; then dry_note presente "$pkg"; else dry_note brew "$pkg (--cask)"; fi
    else
      if package_installed_brew "$pkg"; then dry_note presente "$pkg"; else dry_note brew "$pkg"; fi
    fi
    return 0
  fi

  if [[ "$cask" == "true" ]]; then
    brew list --cask "$pkg" &>/dev/null && return 0
    if ! ux_run_silent brew install --cask "$pkg"; then
      warning "$pkg: brew --cask falló"
      return 1
    fi
  else
    package_installed_brew "$pkg" && return 0
    if ! ux_run_silent brew install "$pkg"; then
      warning "$pkg: brew falló"
      return 1
    fi
  fi
}

# --- Method: curl-sh (curl URL | sh) ---
method_curl_sh() {
  local block="$1" url args bin_path check_cmd

  url=$(_block_field "$block" .url)
  args=$(_block_field "$block" .args)
  bin_path=$(_block_field "$block" .bin_path)
  check_cmd=$(_block_field "$block" .check_cmd)

  url=$(expand_vars "$url")
  args=$(expand_vars "$args")
  bin_path=$(expand_vars "$bin_path")

  if _check_cmd_present "$check_cmd"; then
    dry_run_active && dry_note presente "$check_cmd"
    return 0
  fi

  if dry_run_active; then
    if [[ -n "$args" ]]; then
      dry_note descarga "${check_cmd}: curl -fsSL $url | bash -s -- $args"
    else
      dry_note descarga "${check_cmd}: curl -fsSL $url | sh -${bin_path:+  → $(_tilde "$bin_path")}"
    fi
    return 0
  fi

  if [[ -n "$args" ]]; then
    # shellcheck disable=SC2086
    ux_run_silent bash -c "curl -fsSL '$url' | bash -s -- $args"
  else
    ux_run_silent bash -c "curl -fsSL '$url' | sh -"
  fi

  [[ -n "$bin_path" ]] && export PATH="$bin_path:$PATH"

  if [[ -n "$check_cmd" ]] && ! _check_cmd_present "$check_cmd"; then
    warning "$check_cmd: instalación no verificable tras curl-sh"
    return 1
  fi

  return 0
}

# --- Method: github-deb (download .deb from GitHub releases) ---
method_github_deb() {
  local block="$1" repo version deb_pattern check_cmd arch tag_prefix

  repo=$(_block_field "$block" .repo)
  version=$(_block_field "$block" .version)
  deb_pattern=$(_block_field "$block" .deb_pattern)
  check_cmd=$(_block_field "$block" .check_cmd)
  # La mayoría de proyectos taggean releases como "v${version}" (default). Algunos
  # como wezterm taggean con la versión cruda — esas entradas usan tag_prefix "".
  tag_prefix=$(_block_field "$block" .tag_prefix v)

  if _check_cmd_present "$check_cmd"; then
    dry_run_active && dry_note presente "$check_cmd"
    return 0
  fi

  arch=$(detect_arch) || return 1

  local deb_file
  deb_file=$(echo "$deb_pattern" | sed "s/\${version}/$version/g; s/\${arch}/$arch/g")
  local download_url="https://github.com/${repo}/releases/download/${tag_prefix}${version}/${deb_file}"
  local temp_file="/tmp/${deb_file}"

  if dry_run_active; then
    dry_note descarga "${check_cmd}: $download_url  → sudo dpkg -i (fuera de cualquier repositorio apt)"
    return 0
  fi

  if ! ux_run_silent curl -fsSL -o "$temp_file" "$download_url"; then
    warning "${repo}: descarga falló"
    return 1
  fi

  if ! ux_run_silent sudo dpkg -i "$temp_file"; then
    warning "${repo}: dpkg -i falló"
    rm -f "$temp_file"
    return 1
  fi

  rm -f "$temp_file"

  if [[ -n "$check_cmd" ]] && ! _check_cmd_present "$check_cmd"; then
    warning "$check_cmd: instalado pero no en PATH"
    return 1
  fi

  return 0
}

# --- Method: github-binary (download pre-compiled binary) ---
method_github_binary() {
  local block="$1" url bin_name check_cmd arch

  url=$(_block_field "$block" .url)
  bin_name=$(_block_field "$block" .bin_name)
  check_cmd=$(_block_field "$block" .check_cmd)

  # Asegurar $BIN_DIR existe y está en PATH ANTES del check de idempotencia,
  # para detectar binarios ya copiados de runs previos. Fix del bug histórico:
  # antes el `export PATH` venía DESPUÉS del check, así que `command_exists`
  # nunca veía el binario en $BIN_DIR y se redescargaba en cada run.
  ensure_directory "$BIN_DIR"
  case ":$PATH:" in *":$BIN_DIR:"*) ;; *) export PATH="$BIN_DIR:$PATH" ;; esac

  if _check_cmd_present "$check_cmd"; then
    dry_run_active && dry_note presente "$check_cmd"
    return 0
  fi

  arch=$(detect_arch) || return 1

  local expanded_url
  expanded_url=$(echo "$url" | sed "s/\${arch}/$arch/g")

  if dry_run_active; then
    dry_note descarga "${bin_name}: $expanded_url  → $(_tilde "$BIN_DIR/$bin_name")"
    return 0
  fi

  local temp_file="/tmp/${bin_name}-download"

  if ! ux_run_silent curl -JLo "$temp_file" "$expanded_url"; then
    warning "${bin_name}: descarga falló"
    return 1
  fi

  chmod +x "$temp_file" 2>/dev/null
  mv "$temp_file" "$BIN_DIR/$bin_name" 2>/dev/null

  if [[ -n "$check_cmd" ]] && ! _check_cmd_present "$check_cmd"; then
    warning "${bin_name}: instalado pero no en PATH"
    return 1
  fi

  return 0
}

# Detecta si la Nerd Font configurada en NERD_FONT_NAME/NERD_FONT_FULL_NAME
# está instalada vía cualquiera de los mecanismos estándar:
#   - fc-list (Linux/macOS con fontconfig)
#   - directorios estándar ($HOME/.local/share/fonts, $HOME/.fonts,
#     $HOME/Library/Fonts)
#   - system_profiler (macOS)
# Devuelve 0 si está instalada, 1 si no. Compartido por method_github_zip
# (utils.sh) y _nerd_fonts_present (04-localtools.sh) — ambos hacían
# detecciones casi idénticas con drift menor.
_nerd_font_installed() {
  local name="${NERD_FONT_NAME:-FiraCode}"
  local full="${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}"

  command_exists fc-list && fc-list 2>/dev/null | grep -q "$full" && return 0

  local d
  for d in "$HOME/.local/share/fonts" "$HOME/.fonts" "$HOME/Library/Fonts"; do
    [[ -d "$d" ]] && find "$d" -name "*${name}*" -type f 2>/dev/null | grep -q . && return 0
  done

  if [[ "$OSTYPE" == darwin* ]] || [[ "${OS_TYPE:-}" == "macos" ]]; then
    command_exists system_profiler && system_profiler SPFontsDataType 2>/dev/null | grep -q "$name" && return 0
  fi

  return 1
}

# --- Method: github-zip (download zip, extract to dest — used for Nerd Fonts) ---
method_github_zip() {
  local block="$1"
  local url version font_name dest

  url=$(_block_field "$block" .url)
  version=$(_block_field "$block" .version)
  font_name=$(_block_field "$block" .font_name)
  dest=$(_block_field "$block" .dest)

  # Expand variables
  font_name=$(expand_vars "$font_name")
  dest=$(expand_vars "$dest")

  # Expand url template variables
  local expanded_url
  expanded_url=$(echo "$url" | sed "s/\${version}/$version/g")
  expanded_url=$(echo "$expanded_url" | sed "s/\${font_name}/$font_name/g")

  if _nerd_font_installed; then
    dry_run_active && dry_note presente "${font_name} Nerd Font"
    return 0
  fi

  if dry_run_active; then
    dry_note descarga "${font_name} Nerd Font: $expanded_url  → $(_tilde "$dest") (+ fc-cache)"
    return 0
  fi

  local temp_dir="/tmp/nerd-fonts-${font_name}"
  mkdir -p "$dest"

  if ! ux_run_silent curl -fsSL -o "/tmp/${font_name}.zip" "$expanded_url"; then
    warning "${font_name}: descarga falló"
    return 1
  fi

  if ! ux_run_silent unzip -q "/tmp/${font_name}.zip" -d "$temp_dir"; then
    warning "${font_name}: extracción falló"
    rm -f "/tmp/${font_name}.zip"
    return 1
  fi

  cp -r "$temp_dir"/* "$dest/" >/dev/null 2>&1
  rm -rf "$temp_dir" "/tmp/${font_name}.zip"

  # Update font cache
  if command_exists fc-cache; then
    fc-cache -f -v >/dev/null 2>&1
  elif [[ "$OSTYPE" == "darwin"* ]] && command_exists atsutil; then
    atsutil server -shutdown >/dev/null 2>&1
    atsutil server -ping >/dev/null 2>&1
  fi

  log "$font_name Nerd Font instalada correctamente"
}

# Modo simulación de los hooks de repositorio: anota fuentes, clave y el gpg
# que instalarían. Args: $1 = nombre, $2 = fichero de fuentes, $3 = clave, $4 = URL
_dry_note_repo() {
  dry_note repo "$1: $2 + clave $3 ($4)"
  package_installed_apt gpg || dry_note apt "gpg (para importar la clave del repositorio $1)"
}

# --- Hook: setup Azlux repo for gping ---
setup_azlux_repo() {
  # Idempotent: skip if already configured
  if [[ -f /etc/apt/sources.list.d/azlux.list ]]; then
    dry_run_active && dry_note presente "repositorio azlux"
    return 0
  fi
  if dry_run_active; then
    _dry_note_repo azlux /etc/apt/sources.list.d/azlux.list /usr/share/keyrings/azlux.gpg https://packages.azlux.fr/debian/
    return 0
  fi
  echo 'deb [signed-by=/usr/share/keyrings/azlux.gpg] https://packages.azlux.fr/debian/ bookworm main' | sudo tee /etc/apt/sources.list.d/azlux.list >/dev/null
  sudo apt install -y -qq gpg >/dev/null 2>&1
  curl -s https://azlux.fr/repo.gpg.key | gpg --dearmor | sudo tee /usr/share/keyrings/azlux.gpg >/dev/null
  sudo apt update -y -qq >/dev/null 2>&1
}

# --- Hook: setup Gierens apt repo (eza) ---
# Repo oficial mantenido por Christopher Gierens (eza-community). Debian/Ubuntu
# nativo trae versión vieja de eza; este repo da la latest stable.
setup_gierens_repo() {
  if [[ -f /etc/apt/sources.list.d/gierens.list ]]; then
    dry_run_active && dry_note presente "repositorio gierens"
    return 0
  fi
  if dry_run_active; then
    _dry_note_repo gierens /etc/apt/sources.list.d/gierens.list /etc/apt/keyrings/gierens.gpg http://deb.gierens.de
    return 0
  fi
  sudo apt install -y -qq gpg >/dev/null 2>&1
  sudo install -d -m 0755 /etc/apt/keyrings
  # --batch --yes: sobrescribir sin preguntar si el keyring ya existe
  # (p.ej. quedó de una ejecución anterior interrumpida antes de crear el .list)
  curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
    | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/gierens.gpg
  sudo chmod 644 /etc/apt/keyrings/gierens.gpg
  echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
    | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
  sudo chmod 644 /etc/apt/sources.list.d/gierens.list
  sudo apt update -y -qq >/dev/null 2>&1
}

# --- Hook: setup Kubernetes apt repo (pkgs.k8s.io) ---
# La minor de k8s se pinea (el repo oficial obliga a ello desde 2023). Se puede
# sobrescribir con DEVCLI_K8S_MINOR=v1.31 al lanzar bootstrap.
setup_kubernetes_repo() {
  local k8s_minor="${DEVCLI_K8S_MINOR:-v1.32}"
  # Idempotent: skip if already configured
  if [[ -f /etc/apt/sources.list.d/kubernetes.list ]]; then
    dry_run_active && dry_note presente "repositorio kubernetes"
    return 0
  fi
  if dry_run_active; then
    _dry_note_repo kubernetes /etc/apt/sources.list.d/kubernetes.list /usr/share/keyrings/kubernetes-apt-keyring.gpg "https://pkgs.k8s.io/core:/stable:/${k8s_minor}/deb/"
    return 0
  fi
  sudo apt install -y -qq gpg >/dev/null 2>&1
  sudo install -d -m 0755 /etc/apt/keyrings
  curl -fsSL "https://pkgs.k8s.io/core:/stable:/${k8s_minor}/deb/Release.key" \
    | gpg --dearmor | sudo tee /usr/share/keyrings/kubernetes-apt-keyring.gpg >/dev/null
  sudo chmod 644 /usr/share/keyrings/kubernetes-apt-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${k8s_minor}/deb/ /" \
    | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
  sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list
  sudo apt update -y -qq >/dev/null 2>&1
}

# --- Hook executor ---
execute_hook() {
  local hook_json="$1"
  local json_file="${2:-}"
  local action
  action=$(echo "$hook_json" | jq -r '.action')

  case "$action" in
    symlink)
      local from_cmd to platforms_json
      from_cmd=$(echo "$hook_json" | jq -r '.from_cmd')
      to=$(echo "$hook_json" | jq -r '.to')
      to=$(expand_vars "$to")
      platforms_json=$(echo "$hook_json" | jq -r '.platforms[]? // empty')

      # Check platform filter
      if [[ -n "$platforms_json" ]]; then
        if ! echo "$platforms_json" | grep -q "^${OS_TYPE}$"; then
          return 0
        fi
      fi

      if dry_run_active; then
        # En simulación $from_cmd puede no existir aún (su paquete se
        # instalaría en esta misma ejecución): se anota igualmente.
        command_exists "$(basename "$to")" || dry_note home "$(_tilde "$to") → $from_cmd (enlace)"
        return 0
      fi

      if command_exists "$from_cmd" && ! command_exists "$(basename "$to")"; then
        ln -sf "$(command -v "$from_cmd")" "$to" >/dev/null 2>&1
        log "Symlink: $from_cmd → $(basename "$to")"
      fi
      ;;

    trigger)
      local tool
      tool=$(echo "$hook_json" | jq -r '.tool')
      if [[ -n "$json_file" ]]; then
        install_tool "$tool" "$json_file"
      fi
      ;;

    repo)
      local repo_type
      repo_type=$(echo "$hook_json" | jq -r '.type')
      case "$repo_type" in
        azlux) setup_azlux_repo ;;
        kubernetes) setup_kubernetes_repo ;;
        eza) setup_gierens_repo ;;
        *) warning "Tipo de repo desconocido: $repo_type" ;;
      esac
      ;;

    *)
      warning "Hook desconocido: $action"
      ;;
  esac
}

# --- Main dispatcher: install a tool from tools.json ---
install_tool() {
  local tool_name="$1"
  local json_file="$2"

  # Read the platform block for this tool
  local platform_block
  platform_block=$(jq -c --arg name "$tool_name" --arg os "$OS_TYPE" \
    '.tools[] | select(.name == $name) | .[$os] // empty' "$json_file" 2>/dev/null)

  if [[ -z "$platform_block" ]]; then
    return 0  # Tool not available on this platform
  fi

  local method
  method=$(echo "$platform_block" | jq -r '.method')

  # Perfil server: barrera independiente de lo que diga tools.json. Sólo apt
  # (repositorio oficial) y sin hooks: un pre_install podría añadir un
  # repositorio de terceros y un post_install descargar algo. Si alguien
  # etiqueta mal una herramienta, falla en vez de instalarla.
  if [[ "${DEVCLI_PROFILE:-}" == "server" ]]; then
    local hook_count
    hook_count=$(jq -r --arg name "$tool_name" --arg os "$OS_TYPE" \
      '[.tools[] | select(.name == $name) | ((.[$os].pre_install // []) + (.[$os].post_install // []) + (.post_install // []))[]] | length' \
      "$json_file" 2>/dev/null)
    if [[ "$method" != "apt" || "$hook_count" != "0" ]]; then
      warning "$tool_name: bloqueado en el perfil server (sólo apt del repositorio oficial, sin hooks)"
      return 1
    fi
  fi

  # Origen del paquete apt, para que la simulación distinga el repositorio
  # oficial de los de terceros que añade un pre_install.
  _DEVCLI_APT_ORIGIN=""
  if dry_run_active; then
    # El tipo "eza" es el repositorio de gierens (ver setup_gierens_repo).
    _DEVCLI_APT_ORIGIN=$(echo "$platform_block" | jq -r '[.pre_install[]? | select(.action == "repo") | .type | if . == "eza" then "gierens" else . end] | join(", ")' 2>/dev/null)
  fi

  # Execute pre_install hooks (platform-level)
  local pre_hooks
  pre_hooks=$(echo "$platform_block" | jq -c '.pre_install[]?' 2>/dev/null)
  if [[ -n "$pre_hooks" ]]; then
    while IFS= read -r hook; do
      [[ -n "$hook" ]] && execute_hook "$hook" "$json_file"
    done <<< "$pre_hooks"
  fi

  # Dispatch to method handler
  case "$method" in
    apt)            method_apt "$platform_block" ;;
    brew)           method_brew "$platform_block" ;;
    curl-sh)        method_curl_sh "$platform_block" ;;
    github-deb)     method_github_deb "$platform_block" ;;
    github-binary)  method_github_binary "$platform_block" ;;
    github-zip)     method_github_zip "$platform_block" ;;
    *)
      warning "Método desconocido: $method para $tool_name"
      return 1
      ;;
  esac

  local result=$?

  if [[ $result -eq 0 ]]; then
    # Execute platform-level post_install hooks
    local plat_post_hooks
    plat_post_hooks=$(echo "$platform_block" | jq -c '.post_install[]?' 2>/dev/null)
    if [[ -n "$plat_post_hooks" ]]; then
      while IFS= read -r hook; do
        [[ -n "$hook" ]] && execute_hook "$hook" "$json_file"
      done <<< "$plat_post_hooks"
    fi

    # Execute tool-level post_install hooks
    local tool_post_hooks
    tool_post_hooks=$(jq -c --arg name "$tool_name" \
      '.tools[] | select(.name == $name) | .post_install[]?' "$json_file" 2>/dev/null)
    if [[ -n "$tool_post_hooks" ]]; then
      while IFS= read -r hook; do
        [[ -n "$hook" ]] && execute_hook "$hook" "$json_file"
      done <<< "$tool_post_hooks"
    fi
  fi

  return $result
}

# Función para crear directorio si no existe
ensure_directory() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    if dry_run_active; then
      dry_note home "$(_tilde "$dir")/ (directorio nuevo)"
      return 0
    fi
    mkdir -p "$dir" >/dev/null 2>&1
  fi
}

# Función para verificar permisos sudo
check_sudo_access() {
  if ! sudo -n true 2>/dev/null; then
    if dry_run_active; then
      dry_note aviso "'$CURRENT_USER' no tiene sudo sin contraseña: la ejecución real se pararía"
      return 0
    fi
    error "El usuario '$CURRENT_USER' no tiene acceso a sudo sin contraseña. Aborta."
    exit 1
  fi
}

# Función para actualizar repositorios según OS (silenciosa)
update_package_manager() {
  case "${OS_TYPE:-}" in
    linux|wsl2)
      if dry_run_active; then
        dry_note apt "(antes de instalar) apt update: refresca los índices de los repositorios ya configurados"
        return 0
      fi
      if ! sudo apt update -y -qq >/dev/null 2>&1; then
        warning "No se pudo actualizar repositorios - continuando..."
        return 1
      fi
      ;;
    macos)
      # Homebrew se actualiza automáticamente
      ;;
    *)
      error "OS_TYPE no soportado para actualización: $OS_TYPE"
      return 1
      ;;
  esac
}

# ===================================================================
# UX layer — user-facing output for the install pipeline
# ===================================================================
#
# Activated by `ux_init` at bootstrap time. Once active, phase scripts
# call:
#
#   ux_phase_begin <num> <total> "<title>"
#   ux_progress    <c> <t> "<item>"        # in-place update on TTY
#   ux_phase_end   ok|warn|fail [details]
#
# Plus, anywhere:
#
#   ux_banner   "<os>" "<profile>"          # one-time, after ux_init
#   ux_warn     "<msg>" [log_range]         # yellow ⚠ sub-line
#   ux_error    "<msg>" [log_range]         # red ✖ sub-line
#   ux_run      -- <cmd...>                 # capture cmd output to log
#   ux_summary                              # final block (totals + log path)
#
# Honors:
#   $DEVCLI_VERBOSE=1   → no in-place updates, raw output to stderr
#   $NO_COLOR           → disables ANSI codes (also auto-off when not a TTY)

# --- Internal state (do not touch from outside the layer) ---

_DEVCLI_UX_ACTIVE=0
_DEVCLI_UX_TTY=0
_DEVCLI_UX_VERBOSE=0
_DEVCLI_UX_LOG_FILE=""
_DEVCLI_UX_RUN_START=0

_DEVCLI_UX_C_RESET=""
_DEVCLI_UX_C_GREEN=""
_DEVCLI_UX_C_YELLOW=""
_DEVCLI_UX_C_RED=""
_DEVCLI_UX_C_CYAN=""
_DEVCLI_UX_C_DIM=""
_DEVCLI_UX_C_BOLD=""

_DEVCLI_UX_PHASE_NUM=0
_DEVCLI_UX_PHASE_TOTAL=0
_DEVCLI_UX_PHASE_TITLE=""
_DEVCLI_UX_PHASE_START=0
_DEVCLI_UX_PHASE_LINE_OPEN=0

# Cola de warnings/errors emitidos durante la fase. Se descarga en
# ux_phase_end DESPUÉS del finalizer, evitando que los sub-warns trampleen
# la línea de progreso en TTY mode (stranded-line bug).
_DEVCLI_UX_PHASE_WARNINGS=()

_DEVCLI_UX_PHASES_OK=0
_DEVCLI_UX_PHASES_WARN=0
_DEVCLI_UX_PHASES_FAIL=0
_DEVCLI_UX_WARN_COUNT=0
_DEVCLI_UX_ERROR_COUNT=0

# Width of the left side of the phase line ("[n/m] title"). Tuned for 80-col.
_DEVCLI_UX_LEFT_WIDTH=44

# --- Public API ---

# Initialize the UX layer. Resolution order for the log file path:
#   $1 (explicit arg)  →  $DEVCLI_UX_LOG_FILE (env)  →  ~/.devcli/install.log
#
# Bootstrap calls this with an explicit path (and is the first to init, so it
# writes the session header). Phase scripts in subshells call this with no
# arg; they pick up $DEVCLI_UX_LOG_FILE from the environment and skip the
# header (already written).
ux_init() {
  local log_file="${1:-${DEVCLI_UX_LOG_FILE:-$HOME/.devcli/install.log}}"
  local is_first_init="0"
  [[ -z "${DEVCLI_UX_LOG_FILE:-}" ]] && is_first_init="1"

  _DEVCLI_UX_VERBOSE="${DEVCLI_VERBOSE:-0}"

  # TTY detection: only enable in-place updates when stdout is a real terminal,
  # NO_COLOR is unset, and we're not in verbose mode (verbose flushes raw output
  # which would trample any in-place magic).
  if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]] && [[ "$_DEVCLI_UX_VERBOSE" != "1" ]]; then
    _DEVCLI_UX_TTY=1
  fi

  # Colors: enabled whenever stdout is a TTY (verbose included) and NO_COLOR is unset.
  if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    _DEVCLI_UX_C_RESET=$'\033[0m'
    _DEVCLI_UX_C_GREEN=$'\033[32m'
    _DEVCLI_UX_C_YELLOW=$'\033[33m'
    _DEVCLI_UX_C_RED=$'\033[31m'
    _DEVCLI_UX_C_CYAN=$'\033[36m'
    _DEVCLI_UX_C_DIM=$'\033[2m'
    _DEVCLI_UX_C_BOLD=$'\033[1m'
  fi

  # Open log file (append mode). If we can't write to it, disable capture
  # (ux_run will fall back to direct execution).
  mkdir -p "$(dirname "$log_file")" 2>/dev/null || true
  if : >>"$log_file" 2>/dev/null; then
    _DEVCLI_UX_LOG_FILE="$log_file"
    if [[ "$is_first_init" == "1" ]]; then
      {
        echo
        echo "=== $(date '+%Y-%m-%d %H:%M:%S') · perfil=${DEVCLI_PROFILE:-?} · OS=${OS_TYPE:-?} · pid=$$ ==="
      } >>"$_DEVCLI_UX_LOG_FILE"
    fi
    # Export so subshells (phase scripts) inherit the same log file path.
    export DEVCLI_UX_LOG_FILE="$_DEVCLI_UX_LOG_FILE"
  fi

  _DEVCLI_UX_RUN_START=$(date +%s)
  _DEVCLI_UX_ACTIVE=1
}

# Top-of-run banner.
# Args: $1 = OS label (e.g. "macOS", "Ubuntu", "WSL2"), $2 = profile
ux_banner() {
  local os="$1" profile="$2"
  printf "\n%s%sdevcli%s · %s · perfil: %s\n" \
    "$_DEVCLI_UX_C_BOLD" "$_DEVCLI_UX_C_CYAN" "$_DEVCLI_UX_C_RESET" \
    "$os" "$profile"
  printf "%s─────────────────────────────────────────────%s\n\n" \
    "$_DEVCLI_UX_C_DIM" "$_DEVCLI_UX_C_RESET"
}

# Begin a phase. Records start time and prints the live header line.
# Args: $1 = phase number, $2 = total phases, $3 = title
ux_phase_begin() {
  _DEVCLI_UX_PHASE_NUM="$1"
  _DEVCLI_UX_PHASE_TOTAL="$2"
  _DEVCLI_UX_PHASE_TITLE="$3"
  _DEVCLI_UX_PHASE_START=$(date +%s)
  _DEVCLI_UX_PHASE_LINE_OPEN=1

  if [[ "$_DEVCLI_UX_TTY" == "1" ]]; then
    _ux_render_phase_line "..."
  else
    # Non-TTY / verbose: print a stable header line, no in-place updates later.
    printf "[%d/%d] %s\n" \
      "$_DEVCLI_UX_PHASE_NUM" "$_DEVCLI_UX_PHASE_TOTAL" "$_DEVCLI_UX_PHASE_TITLE"
  fi
}

# Update progress within a phase. No-op in non-TTY mode (the phase header is the
# only progress signal there) and in verbose mode (the raw command output is the
# progress).
# Args: $1 = current, $2 = total, $3 = item label
ux_progress() {
  [[ "$_DEVCLI_UX_TTY" == "1" ]] || return 0
  [[ "$_DEVCLI_UX_PHASE_LINE_OPEN" == "1" ]] || return 0
  local current="$1" total="$2" item="$3"
  _ux_render_phase_line "($(printf "%2d/%d" "$current" "$total")) ${item}"
}

# Finalize a phase line. Increments the global phase counters.
# Args: $1 = ok|warn|fail, $2 = optional details (e.g. "20 ok, 1 falló")
ux_phase_end() {
  local status="$1" details="${2:-}"
  local elapsed mark color
  elapsed=$(( $(date +%s) - _DEVCLI_UX_PHASE_START ))

  case "$status" in
    ok)
      mark="OK"; color="$_DEVCLI_UX_C_GREEN"
      _DEVCLI_UX_PHASES_OK=$((_DEVCLI_UX_PHASES_OK + 1))
      ;;
    warn)
      mark="WARN"; color="$_DEVCLI_UX_C_YELLOW"
      _DEVCLI_UX_PHASES_WARN=$((_DEVCLI_UX_PHASES_WARN + 1))
      ;;
    *)
      mark="FAIL"; color="$_DEVCLI_UX_C_RED"
      _DEVCLI_UX_PHASES_FAIL=$((_DEVCLI_UX_PHASES_FAIL + 1))
      ;;
  esac

  local final
  printf -v final "%s%-4s%s  %3ds" "$color" "$mark" "$_DEVCLI_UX_C_RESET" "$elapsed"
  if [[ -n "$details" ]]; then
    final="${final}   ${_DEVCLI_UX_C_DIM}${details}${_DEVCLI_UX_C_RESET}"
  fi

  if [[ "$_DEVCLI_UX_TTY" == "1" ]]; then
    _ux_render_phase_line "$final"
    printf "\n"
  else
    # Non-TTY: print result on its own indented line (header was already printed).
    printf "      %s\n" "$final"
  fi

  # Cerrar la fase ANTES de vaciar la cola: así, si algún `_ux_emit_subline`
  # se llama post-flush (poco probable), va por la rama immediate-print.
  _DEVCLI_UX_PHASE_LINE_OPEN=0

  # Vaciar la cola de warnings/errors emitidos durante la fase.
  if [[ ${#_DEVCLI_UX_PHASE_WARNINGS[@]} -gt 0 ]]; then
    local w
    for w in "${_DEVCLI_UX_PHASE_WARNINGS[@]}"; do
      printf "%s\n" "$w"
    done
    _DEVCLI_UX_PHASE_WARNINGS=()
  fi
}

# Internal: render the live phase line. TTY only (caller checks).
# Args: $1 = right-side content
_ux_render_phase_line() {
  local right="$1"
  local left
  left=$(printf "[%d/%d] %s" "$_DEVCLI_UX_PHASE_NUM" "$_DEVCLI_UX_PHASE_TOTAL" "$_DEVCLI_UX_PHASE_TITLE")
  printf "\r\033[K%-*s %s" "$_DEVCLI_UX_LEFT_WIDTH" "$left" "$right"
}

# Yellow ⚠ sub-line, optional log range.
# Args: $1 = message, $2 (optional) = log line range like "142-168"
ux_warn() {
  local msg="$1" log_range="${2:-}"
  _DEVCLI_UX_WARN_COUNT=$((_DEVCLI_UX_WARN_COUNT + 1))
  _ux_emit_subline "$_DEVCLI_UX_C_YELLOW" "⚠" "$msg" "$log_range"
}

# Red ✖ sub-line, optional log range.
ux_error() {
  local msg="$1" log_range="${2:-}"
  _DEVCLI_UX_ERROR_COUNT=$((_DEVCLI_UX_ERROR_COUNT + 1))
  _ux_emit_subline "$_DEVCLI_UX_C_RED" "✖" "$msg" "$log_range"
}

# Internal: format a sub-line para warning/error. Si hay una fase abierta, se
# encola para emitirla en ux_phase_end (después del finalizer). Si no, se
# imprime ya. Esto evita el "stranded line" en TTY mode (donde el progreso
# in-place se quedaba huérfano por encima del WARN finalizer).
_ux_emit_subline() {
  local color="$1" glyph="$2" msg="$3" log_range="$4"

  local block
  block=$(printf "      %s%s%s  %s" "$color" "$glyph" "$_DEVCLI_UX_C_RESET" "$msg")
  if [[ -n "$log_range" ]] && [[ -n "$_DEVCLI_UX_LOG_FILE" ]]; then
    block="${block}"$'\n'$(printf "         %sDetalles: %s:%s%s" \
      "$_DEVCLI_UX_C_DIM" "$_DEVCLI_UX_LOG_FILE" "$log_range" "$_DEVCLI_UX_C_RESET")
  fi

  if [[ "$_DEVCLI_UX_PHASE_LINE_OPEN" == "1" ]]; then
    # Cola: ux_phase_end la vacía después del finalizer.
    _DEVCLI_UX_PHASE_WARNINGS+=("$block")
  else
    # Sin fase activa, emitir ya.
    printf "%s\n" "$block"
  fi
}

# Run a command, capturing stdout+stderr to the log file. Returns the command's
# exit code. Echoes the captured log line range to stdout (so callers can capture
# it for ux_warn / ux_error).
#
# In verbose mode (or when no log file is open), runs directly with no capture.
#
# Usage:
#   if range=$(ux_run -- apt-get install -y -qq fzf); then
#     : # ok
#   else
#     ux_warn "fzf no se pudo instalar" "$range"
#   fi
# Like ux_run but without the line-range output (just exit code). Useful inside
# method handlers that don't need to surface the range to ux_warn/ux_error.
# Verbose mode passes through to stdout/stderr; otherwise captures to log file
# (or /dev/null if the log isn't available).
ux_run_silent() {
  if [[ "${1:-}" == "--" ]]; then shift; fi
  if [[ "${_DEVCLI_UX_VERBOSE:-0}" == "1" ]]; then
    "$@"
  elif [[ -n "${_DEVCLI_UX_LOG_FILE:-}" ]]; then
    echo "--- $(date '+%H:%M:%S') $* ---" >>"$_DEVCLI_UX_LOG_FILE"
    "$@" >>"$_DEVCLI_UX_LOG_FILE" 2>&1
  else
    "$@" >/dev/null 2>&1
  fi
}

ux_run() {
  if [[ "${1:-}" == "--" ]]; then shift; fi

  if [[ -z "$_DEVCLI_UX_LOG_FILE" ]] || [[ "$_DEVCLI_UX_VERBOSE" == "1" ]]; then
    "$@"
    return $?
  fi

  local before after rc
  before=$(wc -l <"$_DEVCLI_UX_LOG_FILE" 2>/dev/null || echo 0)
  echo "--- $(date '+%H:%M:%S') $* ---" >>"$_DEVCLI_UX_LOG_FILE"
  "$@" >>"$_DEVCLI_UX_LOG_FILE" 2>&1
  rc=$?
  after=$(wc -l <"$_DEVCLI_UX_LOG_FILE" 2>/dev/null || echo 0)

  if [[ $after -gt $before ]]; then
    printf "%d-%d" "$((before + 1))" "$after"
  fi
  return $rc
}

# Internal: pick singular/plural form based on count.
_ux_plural() {
  if [[ "$1" == "1" ]]; then printf "%s" "$2"; else printf "%s" "$3"; fi
}

# Internal: pick OK/WARN/FAIL status based on ok/fail counters, emit phase end,
# and return the phase exit code: 0=ok, 1=warn (some failed but some ok), 2=fail.
_ux_phase_finalize() {
  local ok="$1" fail="$2"
  if [[ $fail -eq 0 ]]; then
    ux_phase_end ok "${ok} ok"
    return 0
  elif [[ $ok -eq 0 ]]; then
    local fw; fw="$(_ux_plural "$fail" fallido fallidos)"
    ux_phase_end fail "${fail} ${fw}"
    return 2
  else
    local fw; fw="$(_ux_plural "$fail" fallido fallidos)"
    ux_phase_end warn "${ok} ok, ${fail} ${fw}"
    return 1
  fi
}

# ===================================================================
# Phase runners — drive a phase from a flat list of items + an install fn.
# ===================================================================
#
# Compatible con Bash 3.2 (macOS sin brew bash). Usa `eval` para copiar el
# array por nombre en lugar de `local -n` (que es Bash 4.3+).
#
# Usage:
#   MY_ITEMS=(); while IFS= read -r l; do MY_ITEMS+=("$l"); done < <(jq ...)
#   install_one() { install_tool "$1" "$TOOLS_JSON"; }
#   run_phase_items "$PHASE_NUM" "$PHASE_TOTAL" "Title" MY_ITEMS install_one

# Run a phase by iterating an array of items, calling an install function for
# each. The install function must return 0 on success, non-zero on failure.
# Failures are tallied; the runner does NOT call ux_warn (the install fn or
# the method handler does).
#
# Args:
#   $1 = phase number
#   $2 = phase total
#   $3 = phase title
#   $4 = name of an array variable holding items (passed by name, not value)
#   $5 = name of the install function (called with one arg per item)
run_phase_items() {
  local num="$1" total="$2" title="$3"
  local items_var="$4" install_fn="$5"

  ux_phase_begin "$num" "$total" "$title"

  # Bash 3.2 compat: copia los elementos del array nombrado vía eval.
  # `set -u` no se aplica aquí porque el caller debe inicializar el array
  # (todas nuestras phase scripts lo hacen, aunque sea a vacío).
  local _items_ref=()
  eval "_items_ref=( \"\${${items_var}[@]}\" )"

  local count=${#_items_ref[@]} idx=0 ok=0 fail=0
  if [[ $count -eq 0 ]]; then
    ux_phase_end ok "nada que instalar"
    return 0
  fi

  local item
  for item in "${_items_ref[@]}"; do
    idx=$((idx + 1))
    ux_progress "$idx" "$count" "$item"
    if "$install_fn" "$item"; then
      ok=$((ok + 1))
    else
      fail=$((fail + 1))
    fi
  done

  _ux_phase_finalize "$ok" "$fail"
}

# Final summary block. Call once at the very end.
#
# Counters can be passed explicitly (bootstrap does this to aggregate across
# subshell phases). With no args, falls back to internal per-process counters
# (useful for standalone phase runs).
#
# Usage (bootstrap, after collecting phase exit codes):
#   ux_summary "$ok_phases" "$warn_phases" "$fail_phases"
ux_summary() {
  local elapsed
  elapsed=$(( $(date +%s) - _DEVCLI_UX_RUN_START ))

  local phases_ok="${1:-$_DEVCLI_UX_PHASES_OK}"
  local phases_warn="${2:-$_DEVCLI_UX_PHASES_WARN}"
  local phases_fail="${3:-$_DEVCLI_UX_PHASES_FAIL}"
  local phases_total=$((phases_ok + phases_warn + phases_fail))

  printf "\n%s─────────────────────────────────────────────%s\n" \
    "$_DEVCLI_UX_C_DIM" "$_DEVCLI_UX_C_RESET"

  if dry_run_active; then
    _ux_dry_report
    _ux_server_shell_hint
    return 0
  fi

  if [[ $phases_fail -gt 0 ]]; then
    printf "%sInstalación con errores%s · %ds · %d/%d fases OK\n" \
      "$_DEVCLI_UX_C_RED" "$_DEVCLI_UX_C_RESET" \
      "$elapsed" "$phases_ok" "$phases_total"
  elif [[ $phases_warn -gt 0 ]]; then
    printf "%sInstalación completada con avisos%s · %ds · %d/%d fases con avisos\n" \
      "$_DEVCLI_UX_C_YELLOW" "$_DEVCLI_UX_C_RESET" \
      "$elapsed" "$phases_warn" "$phases_total"
  else
    printf "%sInstalación completada%s · %ds\n" \
      "$_DEVCLI_UX_C_GREEN" "$_DEVCLI_UX_C_RESET" "$elapsed"
  fi

  if [[ -n "$_DEVCLI_UX_LOG_FILE" ]] && [[ $((phases_warn + phases_fail)) -gt 0 ]]; then
    printf "%sLog: %s%s\n" "$_DEVCLI_UX_C_DIM" "$_DEVCLI_UX_LOG_FILE" "$_DEVCLI_UX_C_RESET"
  fi

  # Aviso de Personalización de WezTerm — sólo cuando WezTerm forma parte
  # del perfil instalado (dev/full), hay entorno de escritorio (en headless
  # y WSL2 no se instala) y no hubo errores duros. El usuario debe abrir el
  # dotfile y revisar la sección §0 para los knobs ajustables.
  local profile="${DEVCLI_PROFILE:-full}"
  if [[ $phases_fail -eq 0 ]] && [[ "$profile" == "dev" || "$profile" == "full" ]] \
    && [[ "${IS_DESKTOP:-true}" == "true" ]]; then
    printf "\n%sWezTerm:%s abre %s~/.config/wezterm/wezterm.lua%s y revisa\n" \
      "$_DEVCLI_UX_C_BOLD" "$_DEVCLI_UX_C_RESET" \
      "$_DEVCLI_UX_C_DIM" "$_DEVCLI_UX_C_RESET"
    printf "la sección %s§0 Personalización%s para los knobs de AI Mode\n" \
      "$_DEVCLI_UX_C_BOLD" "$_DEVCLI_UX_C_RESET"
    printf "(p.ej. %sCLAUDE_EXTRA_ARGS%s — viene con\n" \
      "$_DEVCLI_UX_C_DIM" "$_DEVCLI_UX_C_RESET"
    printf "%s--allow-dangerously-skip-permissions%s activado por defecto).\n" \
      "$_DEVCLI_UX_C_DIM" "$_DEVCLI_UX_C_RESET"
  fi

  _ux_server_shell_hint
}

# Perfil server: no se hace chsh (sería tocar /etc/passwd). Si la shell de
# inicio no es zsh, se dice cómo cambiarla a mano.
_ux_server_shell_hint() {
  [[ "${DEVCLI_PROFILE:-}" == "server" ]] || return 0
  local login_shell zsh_path
  login_shell="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7)"
  zsh_path="$(command -v zsh 2>/dev/null || echo /usr/bin/zsh)"
  [[ "$login_shell" == "$zsh_path" ]] && return 0
  printf "\n%sShell:%s el perfil server no cambia tu shell de inicio (%s).\n" \
    "$_DEVCLI_UX_C_BOLD" "$_DEVCLI_UX_C_RESET" "${login_shell:-?}"
  printf "Para usar la configuración de zsh: %schsh -s %s%s\n" \
    "$_DEVCLI_UX_C_DIM" "$zsh_path" "$_DEVCLI_UX_C_RESET"
}

# Informe del modo simulación: las notas de $DEVCLI_DRY_RUN_FILE agrupadas
# por categoría y sin duplicados. Las categorías que importan para auditar
# (repos, descargas, sistema) se muestran aunque estén vacías.
_ux_dry_report() {
  local f="${DEVCLI_DRY_RUN_FILE:-}"
  printf "%sSimulación%s: no se ha cambiado nada. Esto es lo que haría:\n" \
    "$_DEVCLI_UX_C_BOLD" "$_DEVCLI_UX_C_RESET"

  local cat title always lines dedup
  for cat in apt apt-terceros repo descarga brew sistema home aviso presente; do
    always=0
    case "$cat" in
      apt)          title="Paquetes del repositorio oficial de la distribución (apt)"; always=1 ;;
      apt-terceros) title="Paquetes de repositorios apt de terceros"; always=1 ;;
      repo)         title="Repositorios apt de terceros y claves de firma"; always=1 ;;
      descarga)     title="Instalaciones fuera del gestor de paquetes"; always=1 ;;
      brew)         title="Paquetes de Homebrew" ;;
      sistema)      title="Cambios fuera de \$HOME"; always=1 ;;
      home)         title="Ficheros y directorios en \$HOME"; always=1 ;;
      aviso)        title="Avisos" ;;
      presente)     title="Ya instalado (no haría nada)" ;;
    esac
    lines=""
    # Sin duplicados. En paquetes, por nombre: en simulación los
    # prerrequisitos no se instalan y la fase 01 los vuelve a anotar.
    case "$cat" in
      apt|apt-terceros|brew) dedup='!seen[$1]++' ;;
      *) dedup='!seen[$0]++' ;;
    esac
    [[ -n "$f" && -f "$f" ]] && lines=$(awk -F'\t' -v c="$cat" '$1 == c { print $2 }' "$f" | awk "$dedup")
    if [[ -z "$lines" ]]; then
      [[ $always -eq 1 ]] || continue
      printf "\n%s%s%s\n  (ninguno)\n" "$_DEVCLI_UX_C_BOLD" "$title" "$_DEVCLI_UX_C_RESET"
      continue
    fi
    printf "\n%s%s%s\n" "$_DEVCLI_UX_C_BOLD" "$title" "$_DEVCLI_UX_C_RESET"
    if [[ "$cat" == "presente" ]]; then
      printf "  %s\n" "$(printf '%s\n' "$lines" | paste -sd ' ' -)"
    else
      printf '%s\n' "$lines" | sed 's/^/  - /'
    fi
  done
}

