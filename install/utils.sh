#!/usr/bin/env bash
# -------------------------------------------------------------------
# utils.sh - Utilidades compartidas para scripts de instalación
# -------------------------------------------------------------------

# Función de log con timestamp
log() {
  local script_name="${BASH_SOURCE[1]##*/}"
  script_name="${script_name%.sh}"
  echo "[$(date '+%H:%M:%S')] [$script_name] $*"
}

# Función de log simple (para compatibilidad)
log_simple() {
  local script_name="${BASH_SOURCE[1]##*/}"
  script_name="${script_name%.sh}"
  echo "[$script_name] $*"
}

# Función de log silencioso (solo errores y warnings)
log_quiet() {
  # Esta función no hace nada - para hacer scripts silenciosos
  :
}

# Función para mostrar errores importantes
error() {
  local script_name="${BASH_SOURCE[1]##*/}"
  script_name="${script_name%.sh}"
  echo "[$script_name] ❌ $*" >&2
}

# Función para mostrar warnings importantes
warning() {
  local script_name="${BASH_SOURCE[1]##*/}"
  script_name="${script_name%.sh}"
  echo "[$script_name] ⚠️ $*" >&2
}

# Función para mostrar éxito final
success() {
  local script_name="${BASH_SOURCE[1]##*/}"
  script_name="${script_name%.sh}"
  echo "[$script_name] ✅ $*"
}

# Función para verificar si un comando existe
command_exists() {
  command -v "$1" &>/dev/null
}

# Función para verificar si un paquete está instalado (Linux/WSL2)
package_installed_apt() {
  dpkg -s "$1" &>/dev/null
}

# Función para verificar si un paquete está instalado (macOS)
package_installed_brew() {
  brew list --formula "$1" &>/dev/null
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

# --- Method: apt ---
method_apt() {
  local pkg
  pkg=$(echo "$1" | jq -r '.package')

  if package_installed_apt "$pkg"; then
    return 0
  fi

  if ! sudo apt install -y -qq "$pkg" >/dev/null 2>&1; then
    warning "No se pudo instalar $pkg con apt"
    return 1
  fi
}

# --- Method: brew ---
method_brew() {
  local pkg
  pkg=$(echo "$1" | jq -r '.package')

  if package_installed_brew "$pkg"; then
    return 0
  fi

  if ! brew install "$pkg" >/dev/null 2>&1; then
    warning "No se pudo instalar $pkg con brew"
    return 1
  fi
}

# --- Method: curl-sh (curl URL | sh) ---
method_curl_sh() {
  local block="$1"
  local url args bin_path check_cmd

  url=$(echo "$block" | jq -r '.url')
  args=$(echo "$block" | jq -r '.args // ""')
  bin_path=$(echo "$block" | jq -r '.bin_path // ""')
  check_cmd=$(echo "$block" | jq -r '.check_cmd // ""')

  # Expand variables
  url=$(expand_vars "$url")
  args=$(expand_vars "$args")
  bin_path=$(expand_vars "$bin_path")

  # Check if already installed
  if [[ -n "$check_cmd" ]]; then
    # For oh-my-posh, also check BIN_DIR directly
    if command_exists "$check_cmd" || [[ -x "$BIN_DIR/$check_cmd" ]]; then
      return 0
    fi
  fi

  # Run the installer
  if [[ -n "$args" ]]; then
    curl -fsSL "$url" | bash -s -- $args >/dev/null 2>&1
  else
    curl -fsSL "$url" | sh - >/dev/null 2>&1
  fi

  # Add bin_path to PATH if specified
  if [[ -n "$bin_path" ]]; then
    export PATH="$bin_path:$PATH"
  fi

  # Verify installation
  if [[ -n "$check_cmd" ]]; then
    if ! command_exists "$check_cmd" && ! [[ -x "$BIN_DIR/$check_cmd" ]]; then
      warning "$check_cmd no se instaló correctamente"
      return 1
    fi
  fi

  return 0
}

# --- Method: github-deb (download .deb from GitHub releases) ---
method_github_deb() {
  local block="$1"
  local repo version deb_pattern check_cmd arch

  repo=$(echo "$block" | jq -r '.repo')
  version=$(echo "$block" | jq -r '.version')
  deb_pattern=$(echo "$block" | jq -r '.deb_pattern')
  check_cmd=$(echo "$block" | jq -r '.check_cmd // ""')

  # Check if already installed
  if [[ -n "$check_cmd" ]] && command_exists "$check_cmd"; then
    return 0
  fi

  arch=$(detect_arch) || return 1

  # Expand variables in the deb pattern
  local deb_file
  deb_file=$(echo "$deb_pattern" | sed "s/\${version}/$version/g; s/\${arch}/$arch/g")
  local download_url="https://github.com/${repo}/releases/download/v${version}/${deb_file}"
  local temp_file="/tmp/${deb_file}"

  log "Descargando ${repo} v${version} para ${arch}..."

  if ! curl -fsSL -o "$temp_file" "$download_url" >/dev/null 2>&1; then
    warning "No se pudo descargar desde $download_url"
    return 1
  fi

  if ! sudo dpkg -i "$temp_file" >/dev/null 2>&1; then
    warning "No se pudo instalar $deb_file"
    rm -f "$temp_file"
    return 1
  fi

  rm -f "$temp_file"

  if [[ -n "$check_cmd" ]] && ! command_exists "$check_cmd"; then
    warning "$check_cmd no se instaló correctamente"
    return 1
  fi

  return 0
}

# --- Method: github-binary (download pre-compiled binary) ---
method_github_binary() {
  local block="$1"
  local url bin_name check_cmd arch

  url=$(echo "$block" | jq -r '.url')
  bin_name=$(echo "$block" | jq -r '.bin_name')
  check_cmd=$(echo "$block" | jq -r '.check_cmd // ""')

  # Check if already installed
  if [[ -n "$check_cmd" ]] && command_exists "$check_cmd"; then
    return 0
  fi

  arch=$(detect_arch) || return 1

  # Expand variables in URL
  local expanded_url
  expanded_url=$(echo "$url" | sed "s/\${arch}/$arch/g")

  local temp_file="/tmp/${bin_name}-download"

  ensure_directory "$BIN_DIR"

  log "Descargando $bin_name..."

  if ! curl -JLo "$temp_file" "$expanded_url" >/dev/null 2>&1; then
    warning "No se pudo descargar $bin_name"
    return 1
  fi

  chmod +x "$temp_file" >/dev/null 2>&1
  mv "$temp_file" "$BIN_DIR/$bin_name" >/dev/null 2>&1

  export PATH="$BIN_DIR:$PATH"

  if [[ -n "$check_cmd" ]] && ! command_exists "$check_cmd"; then
    warning "$bin_name no se instaló correctamente"
    return 1
  fi

  return 0
}

# --- Method: github-zip (download zip, extract to dest — used for Nerd Fonts) ---
method_github_zip() {
  local block="$1"
  local url version font_name dest

  url=$(echo "$block" | jq -r '.url')
  version=$(echo "$block" | jq -r '.version')
  font_name=$(echo "$block" | jq -r '.font_name // ""')
  dest=$(echo "$block" | jq -r '.dest')

  # Expand variables
  font_name=$(expand_vars "$font_name")
  dest=$(expand_vars "$dest")

  # Expand url template variables
  local expanded_url
  expanded_url=$(echo "$url" | sed "s/\${version}/$version/g")
  expanded_url=$(echo "$expanded_url" | sed "s/\${font_name}/$font_name/g")

  # Check if fonts already installed (multi-method detection)
  local fonts_installed=false
  local font_full_name="${NERD_FONT_FULL_NAME:-FiraCode Nerd Font}"

  if command_exists fc-list; then
    if fc-list | grep -q "$font_full_name" 2>/dev/null; then
      fonts_installed=true
    fi
  fi

  if [[ "$fonts_installed" == "false" ]] && [[ -d "$dest" ]]; then
    if find "$dest" -name "*${font_name}*" -type f 2>/dev/null | grep -q "$font_name" 2>/dev/null; then
      fonts_installed=true
    fi
  fi

  if [[ "$fonts_installed" == "false" ]] && [[ -d "$HOME/.fonts" ]]; then
    if find "$HOME/.fonts" -name "*${font_name}*" -type f 2>/dev/null | grep -q "$font_name" 2>/dev/null; then
      fonts_installed=true
    fi
  fi

  if [[ "$fonts_installed" == "false" ]] && [[ "$OSTYPE" == "darwin"* ]]; then
    if command_exists system_profiler; then
      if system_profiler SPFontsDataType | grep -q "$font_name" 2>/dev/null; then
        fonts_installed=true
      fi
    fi
  fi

  if [[ "$fonts_installed" == "true" ]]; then
    log "'$font_full_name' ya está instalada, omitiendo"
    return 0
  fi

  # Install
  local temp_dir="/tmp/nerd-fonts-${font_name}"
  mkdir -p "$dest"

  log "Instalando $font_name Nerd Font..."

  if ! curl -fsSL -o "/tmp/${font_name}.zip" "$expanded_url" >/dev/null 2>&1; then
    warning "No se pudo descargar $font_name"
    return 1
  fi

  if ! unzip -q "/tmp/${font_name}.zip" -d "$temp_dir" >/dev/null 2>&1; then
    warning "No se pudo extraer $font_name"
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

# --- Hook: setup Azlux repo for gping ---
setup_azlux_repo() {
  # Idempotent: skip if already configured
  if [[ -f /etc/apt/sources.list.d/azlux.list ]]; then
    return 0
  fi
  echo 'deb [signed-by=/usr/share/keyrings/azlux.gpg] https://packages.azlux.fr/debian/ bookworm main' | sudo tee /etc/apt/sources.list.d/azlux.list >/dev/null
  sudo apt install -y -qq gpg >/dev/null 2>&1
  curl -s https://azlux.fr/repo.gpg.key | gpg --dearmor | sudo tee /usr/share/keyrings/azlux.gpg >/dev/null
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
    mkdir -p "$dir" >/dev/null 2>&1
  fi
}

# Función para verificar permisos sudo
check_sudo_access() {
  if ! sudo -n true 2>/dev/null; then
    error "El usuario '$CURRENT_USER' no tiene acceso a sudo sin contraseña. Aborta."
    exit 1
  fi
}

# Función para actualizar repositorios según OS (silenciosa)
update_package_manager() {
  case "${OS_TYPE:-}" in
    linux|wsl2)
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

# Función para contar paquetes instalados
count_installed_packages() {
  local count=0
  for pkg in "$@"; do
    case "${OS_TYPE:-}" in
      linux|wsl2)
        if package_installed_apt "$pkg"; then
          count=$((count + 1))
        fi
        ;;
      macos)
        if package_installed_brew "$pkg"; then
          count=$((count + 1))
        fi
        ;;
    esac
  done
  echo "$count"
}

