# =============================================================================
# Archivo de configuración de Bash para Git Bash en Windows
# =============================================================================
# Ubicación final: ~/.bashrc
# Propósito: Personaliza el entorno de Git Bash con herramientas modernas,
#            prompt personalizado con Oh My Posh, y aliases útiles
# Compatible con: Git Bash en Windows 10/11
# Dependencias: lsd, zoxide, fzf, oh-my-posh, git
# =============================================================================

# =============================================================================
# CONFIGURACIÓN BÁSICA DE SHELL INTERACTIVO
# =============================================================================

# Si no se ejecuta de forma interactiva, no hacer nada
case $- in
    *i*) ;;
      *) return;;
esac

# =============================================================================
# PATH ADICIONAL (solo afecta a Git Bash, no al PATH de Windows)
# =============================================================================

# Scoop ya añade ~/scoop/shims al PATH del usuario; las apps se invocan por
# nombre (eza, btm, oh-my-posh, zoxide, fzf) sin resolución manual.
export PATH="$HOME/bin:$HOME/Nextcloud/priv/bin:/c/Windows/System32/OpenSSH:$PATH"

# -----------------------------------------------------------------------------
# SSH + RedirectionGuard de Windows OpenSSH
# -----------------------------------------------------------------------------
# Windows OpenSSH spawnea `sshd.exe` con la mitigación RedirectionGuard
# activa, que bloquea a los procesos hijos para que NO atraviesen reparse
# points (junctions ni symlinks) en el perfil del usuario. Eso rompe los
# shims de Scoop, que cablean `~/scoop/apps/<app>/current/<bin>.exe`.
#
# Dos rutas para arreglarlo, controladas por `DEVCLI_SSH_REGISTRY_FIX`:
#
#   - Default (variable unset o `true`): asumimos la ruta sistémica —
#     desactivar RedirectionGuard sólo para `sshd.exe` vía Registro
#     (HKLM\...\Image File Execution Options\sshd.exe\MitigationOptions
#     con byte 10 != 0x00). Verificamos en cada sesión SSH; si el fix
#     no está aplicado, imprimimos las instrucciones. Si está aplicado
#     no hacemos nada (junctions funcionan nativamente).
#
#   - `DEVCLI_SSH_REGISTRY_FIX=false`: opt-out del registro. Bajo SSH
#     prependemos al PATH el dir versionado real de oh-my-posh, zoxide,
#     fzf, eza y bottom para bypassear la junction `current`. Más lento
#     que el fix del registro pero no requiere admin ni cambios de Win.
#
#DEVCLI_SSH_REGISTRY_FIX=false
#
# En ambos casos el coste local es 0 ms (la rama no se ejecuta).
if [ -n "${SSH_CONNECTION:-}" ] && [ -d "$HOME/scoop/apps" ]; then
    case "${DEVCLI_SSH_REGISTRY_FIX:-true}" in
        false|FALSE|0|no|NO)
            # Modo bypass en bashrc — opt-out del registro
            for _app in oh-my-posh zoxide fzf eza bottom; do
                _d="$HOME/scoop/apps/$_app"
                [ -d "$_d" ] || continue
                _ver=$(\ls -1 "$_d" 2>/dev/null | grep -v '^current$' | sort -V | tail -n1)
                [ -n "$_ver" ] && [ -d "$_d/$_ver" ] && PATH="$_d/$_ver:$PATH"
            done
            unset _app _d _ver
            ;;
        *)
            # Modo registro (default): verificar que RedirectionGuard
            # esté desactivado para sshd.exe. Si no, instruir al usuario.
            _devcli_rg_disabled() {
                local out hex byte10
                out=$(MSYS_NO_PATHCONV=1 reg.exe query \
                    "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\sshd.exe" \
                    /v MitigationOptions 2>/dev/null) || return 1
                hex=$(printf '%s\n' "$out" | grep -i 'REG_BINARY' \
                    | sed 's/.*REG_BINARY[[:space:]]*//' | tr -d '[:space:]')
                [ -z "$hex" ] && return 1
                byte10=${hex:18:2}
                [ -n "$byte10" ] && [ "$byte10" != "00" ]
            }
            if ! _devcli_rg_disabled; then
                cat >&2 <<'EOF'
⚠ Si ves este mensaje seguramente verás errores del tipo:
  
   "Shim: Could not create process" en oh-my-posh/zoxide/fzf/eza/btm

  Ejecuta lo siguiente en PowerShell admin:

    $k='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\sshd.exe'
    New-Item $k -Force | Out-Null
    New-ItemProperty $k -Name MitigationOptions -Type Binary `
      -Value ([byte[]](0,0,0,0,0,0,0,0,0,0x10,0,0,0,0,0,0,0,0,0x10)) -Force
    Restart-Service sshd

  Nota: Bajo tu responsabilidad — desactivará una mitigación de seguridad
  sólo para sshd.exe. Tras reiniciar sshd e intentar conectar de nuevo 
  los shims funcionan
  
  Si prefieres no hacerlo, pon "DEVCLI_SSH_REGISTRY_FIX=false" arriba.
  
EOF
            fi
            unset -f _devcli_rg_disabled
            ;;
    esac
fi

# =============================================================================
# CONFIGURACIÓN DEL HISTORIAL DE COMANDOS
# =============================================================================

# No duplicar líneas o líneas que empiecen con espacio en el historial
# ignoreboth = ignoredups + ignorespace
HISTCONTROL=ignoreboth

# Añadir al archivo de historial, no sobrescribirlo
shopt -s histappend

# Historial amplio para uso como terminal principal
HISTSIZE=10000
HISTFILESIZE=20000

# =============================================================================
# CONFIGURACIÓN DE VENTANA Y TERMINAL
# =============================================================================

# Desactivar el parpadeo de pantalla (visible bell) en autocompletado
# Sin esto, Git Bash muestra un flash blanco cuando TAB no encuentra coincidencia única
bind 'set bell-style none'

# Verificar el tamaño de la ventana después de cada comando
shopt -s checkwinsize

# Habilitar ** para búsqueda recursiva de archivos (ej: ls **/*.ts)
shopt -s globstar

# Escribir nombre de directorio para hacer cd automáticamente (sin escribir 'cd')
shopt -s autocd

# Autocorregir errores tipográficos menores en cd y autocompletado
shopt -s cdspell
shopt -s dirspell

# =============================================================================
# CONFIGURACIÓN AVANZADA DE READLINE (AUTOCOMPLETADO)
# =============================================================================

# Autocompletado sin distinguir mayúsculas/minúsculas
bind 'set completion-ignore-case on'

# Mostrar todas las opciones en el primer TAB (sin necesitar dos pulsaciones)
bind 'set show-all-if-ambiguous on'

# Tratar guiones y guiones bajos como equivalentes en autocompletado
bind 'set completion-map-case on'

# Mostrar colores en las sugerencias de autocompletado
bind 'set colored-stats on'
bind 'set colored-completion-prefix on'

# =============================================================================
# CONFIGURACIÓN DE COLORES PARA COMANDOS
# =============================================================================

# Aliases para grep con colores (resaltado de coincidencias)
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# =============================================================================
# CONFIGURACIÓN DE EZA (CON FALLBACK A LSD POR SI ACASO)
# =============================================================================

# eza es el sucesor moderno de lsd; añade --git a long views.
# Mientras eza está siendo probado, mantenemos lsd como fallback.
# Sin --group-directories-first: sort alfabético interleaved
# (preferencia del usuario, idéntico a `lsd` directo).
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons=auto --color=auto --git'
    alias ll='eza -lh --icons=auto --color=auto --git'
    alias la='eza -a --icons=auto --color=auto --git'
    alias lla='eza -la --icons=auto --color=auto --git'
elif command -v lsd >/dev/null 2>&1; then
    alias ls='lsd'
    alias ll='lsd -l'
    alias la='lsd -a'
    alias lla='lsd -la'
fi

# =============================================================================
# CONFIGURACIÓN DETALLADA DE COLORES LS_COLORS
# =============================================================================

# Colores para diferentes tipos de archivos (usado por lsd y autocompletado)
export LS_COLORS='fi=00:mi=00:mh=00:ln=01;94:or=01;31:di=01;36:ow=04;01;34:st=34:tw=04;34:'
LS_COLORS+='pi=01;33:so=01;33:do=01;33:bd=01;33:cd=01;33:su=01;35:sg=01;35:ca=01;35:ex=01;32'
LS_COLORS+=':*.cmd=00;32:*.exe=01;32:*.com=01;32:*.bat=01;32:*.btm=01;32:*.dll=01;32'
LS_COLORS+=':*.tar=00;31:*.tbz=00;31:*.tgz=00;31:*.rpm=00;31:*.deb=00;31:*.arj=00;31'
LS_COLORS+=':*.taz=00;31:*.lzh=00;31:*.lzma=00;31:*.zip=00;31:*.zoo=00;31:*.z=00;31'
LS_COLORS+=':*.Z=00;31:*.gz=00;31:*.bz2=00;31:*.tb2=00;31:*.tz2=00;31:*.tbz2=00;31'
LS_COLORS+=':*.avi=01;35:*.bmp=01;35:*.fli=01;35:*.gif=01;35:*.jpg=01;35:*.jpeg=01;35'
LS_COLORS+=':*.mng=01;35:*.mov=01;35:*.mpg=01;35:*.pcx=01;35:*.pbm=01;35:*.pgm=01;35'
LS_COLORS+=':*.png=01;35:*.ppm=01;35:*.tga=01;35:*.tif=01;35:*.xbm=01;35:*.xpm=01;35'
LS_COLORS+=':*.dl=01;35:*.gl=01;35:*.wmv=01;35'

# EZA_COLORS: replica los colores de ~/.config/lsd/colors.yaml para que
# la transición lsd → eza sea visualmente continua. Override de LS_COLORS
# donde aplica (eza usa LS_COLORS para extensiones, EZA_COLORS para UI).
# Nota: NO seteamos `di` aquí — eza hereda de LS_COLORS (`di=01;36`,
# cyan bold), que es lo que el usuario tenía en lsd visualmente.
export EZA_COLORS='uu=38;5;230:gu=38;5;187'                     # user/group
EZA_COLORS+=':ur=32:uw=33:ux=31:ue=31:gr=32:gw=33:gx=31'        # perms (user+group)
EZA_COLORS+=':tr=32:tw=33:tx=31:su=38;5;5:sf=38;5;5:xa=36:oc=38;5;6'  # other perms+attrs
EZA_COLORS+=':sn=38;5;245:nb=38;5;229:nk=38;5;229:nm=38;5;216'  # size numbers
EZA_COLORS+=':ng=38;5;172:nt=38;5;172:ub=38;5;229:uk=38;5;229'  # size units
EZA_COLORS+=':um=38;5;216:ug=38;5;172:ut=38;5;172'              # size units (cont)
EZA_COLORS+=':da=38;5;36:in=38;5;13:lc=38;5;13:xx=38;5;245'     # date/inode/links/punct
EZA_COLORS+=':ga=32:gm=33:gd=31:gv=32:gt=33:gi=38;5;245:gc=31'  # git status

# =============================================================================
# ALIASES Y FUNCIONES PERSONALIZADAS
# =============================================================================

# Abrir Visual Studio Code rápidamente
alias e='code $*'

# Git status (consistente con zsh y PowerShell)
alias gst='git status'

# Monitor de sistema (btm/bottom como alternativa a htop)
command -v btm >/dev/null 2>&1 && alias htop='btm'

# Llevo años usando more... me sale solo
alias more='less'

# Claude Code permitir no necesitar confirmaciones de permisos
alias claude='claude --allow-dangerously-skip-permissions'

# =============================================================================
# PING ESTILO LINUX (DELEGADO A WSL2)
# =============================================================================
#
# El ping.exe de Windows usa su propia sintaxis (-n, -w, -l) y NO se puede
# sustituir por PATH: Windows compone el PATH del proceso como Máquina +
# Usuario, y C:\Windows\system32 vive en el de máquina, así que nada puesto
# en ~/bin puede taparlo. La única vía limpia es una función de shell.
#
# Delegamos en el ping real de iputils dentro de WSL2: -c, -i, -D, -s, -w,
# -q, -f y el resumen con "rtt min/avg/max/mdev". Es idéntico al de Linux
# porque es el de Linux. El código de salida se propaga tal cual (0 = ok,
# 1 = sin respuesta, 2 = error de resolución).
#
# Ajustes (exportar en ~/.bashrc.local, que se carga al final del fichero):
#   DEVCLI_PING_WSL=0              desactiva la delegación y usa ping.exe
#   DEVCLI_PING_WSL_DISTRO=nombre  fuerza una distro (vacío = la por defecto)
#
# Limitaciones conocidas:
#   - El origen es la interfaz NAT de WSL2, no el stack de red de Windows:
#     no atraviesa adaptadores exclusivos del host (p.ej. una VPN levantada
#     en Windows). Para esos casos, `ping.exe` sigue disponible sin alias.
#   - `-i` por debajo de 0.2s requiere root dentro de la distro.
#   - Sólo aplica a Git Bash; en PowerShell sigue vigente su propia función.
ping() {
    if [ "${DEVCLI_PING_WSL:-1}" = "1" ] && command -v wsl.exe >/dev/null 2>&1; then
        if [ -n "${DEVCLI_PING_WSL_DISTRO:-}" ]; then
            wsl.exe -d "${DEVCLI_PING_WSL_DISTRO}" -e ping "$@"
        else
            wsl.exe -e ping "$@"
        fi
    else
        ping.exe "$@"
    fi
}

# =============================================================================
# INCLUSIÓN DE ALIASES EXTERNOS
# =============================================================================

# Aliases personalizados adicionales en ~/.bash_aliases
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# =============================================================================
# AUTOCOMPLETADO PROGRAMABLE
# =============================================================================

if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# =============================================================================
# PRIVACIDAD Y TELEMETRÍA
# =============================================================================

# Deshabilitar telemetría de herramientas de desarrollo
export DOTNET_CLI_TELEMETRY_OPTOUT=1

# Servidor X para aplicaciones gráficas (ej: X410, VcXsrv)
export DISPLAY=localhost:0.0

# =============================================================================
# CONFIGURACIÓN DE OH MY POSH PARA GIT BASH (WINDOWS)
# =============================================================================

# Icono del sistema operativo para Oh My Posh
export OMP_OS_ICON="⚡"

if command -v oh-my-posh >/dev/null 2>&1; then
    eval "$(oh-my-posh --init --shell bash --config ~/.oh-my-posh.json)"
fi

# =============================================================================
# CONFIGURACIÓN PARA KUBERNETES
# =============================================================================

export KUBECONFIG="${HOME}/kubeconfig"

# =============================================================================
# CONFIGURACIÓN DE ZOXIDE (NAVEGACIÓN INTELIGENTE DE DIRECTORIOS)
# =============================================================================

# Reemplaza 'cd' con zoxide para saltar a directorios frecuentes.
# Uso: cd nombre_directorio (salta al directorio más frecuente que coincida)
#       cdi                 (selector interactivo con fzf)
#
# Nota de rendimiento: el hook por defecto (`zoxide init bash`, sin más) es
# `--hook pwd`, que añade un chequeo en cada prompt — y en Git Bash llama a
# `cygpath` por dentro, costando ~30 ms ocultos. Usamos `--hook none` y
# movemos el `zoxide add` al wrapper de `cd`, que es la única ruta por la
# que cambia $PWD (incluido `autocd`, que pasa por la función `cd`).
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash --cmd cd --hook none)"
    __devcli_zoxide_cd() {
        builtin cd -- "$@" || return
        # No dejar que un fallo de "zoxide add" (mero housekeeping en segundo
        # plano) contamine el exit status visible de "cd" en el prompt.
        command zoxide add -- "$(__zoxide_pwd)" >/dev/null 2>&1
        return 0
    }
    __zoxide_cd() {
        __devcli_zoxide_cd "$@"
    }
fi

# =============================================================================
# CONFIGURACIÓN DE FZF (BÚSQUEDA DIFUSA)
# =============================================================================

# Ctrl+R: búsqueda en historial, Ctrl+T: búsqueda de archivos, Alt+C: cd a directorio
command -v fzf >/dev/null 2>&1 && eval "$(fzf --bash 2>/dev/null)"

# Integración WezTerm — emite OSC 7 (CWD) y OSC 133 (prompt semántico)
# para que AI Mode y la barra de pestañas conozcan el directorio activo.
# Se activa solo dentro de WezTerm (WEZTERM_PANE lo define WezTerm).
#
# Nota de rendimiento: wezterm.sh registra hooks `precmd` que corren en
# cada Enter. Sin ajustes son ~125 ms por prompt en Windows (5 spawns
# externos: id+hostname+base64×3 para user_vars, más wezterm.exe para
# OSC 7). Aplicamos dos optimizaciones que no afectan AI Mode:
#
#   1. WEZTERM_SHELL_SKIP_USER_VARS=1: salta __wezterm_user_vars_precmd
#      (OSC 1337 SetUserVar). Esos vars sólo se usan para que WezTerm
#      muestre user/host en tab title, irrelevante para AI Mode.
#   2. Override de __wezterm_osc7 con printf inline (mismo OSC 7) para
#      evitar el spawn de `wezterm set-working-directory` por prompt.
if [[ -n "$WEZTERM_PANE" ]] && [[ -f "$HOME/.config/wezterm/wezterm.sh" ]]; then
    export WEZTERM_SHELL_SKIP_USER_VARS=1
    source "$HOME/.config/wezterm/wezterm.sh"
    __wezterm_osc7() {
        printf '\033]7;file://%s%s\033\\' "${HOSTNAME}" "${PWD}"
    }

    # No arrastrar la "❌" de Oh My Posh tras pulsar Enter en línea vacía.
    # _omp_hook (el PROMPT_COMMAND de Oh My Posh) lee $? tal cual lo deja
    # bash al redibujar el prompt. Si el comando anterior falló y el
    # usuario sólo pulsa Enter sin escribir nada, bash no ejecuta nada
    # nuevo y $? sigue siendo el del comando fallido — la cruz roja queda
    # "pegada" aunque no haya habido un fallo nuevo.
    #
    # wezterm.sh ya instala bash-preexec (necesario para OSC 133); usamos
    # sus hooks preexec/precmd para distinguir "se ejecutó un comando
    # real" de "sólo se pulsó Enter", y así resetear a 0 el exit code que
    # _omp_hook capturará cuando no hubo comando.
    __devcli_omp_cmd_ran=0
    __devcli_omp_preexec() { __devcli_omp_cmd_ran=1; }
    __devcli_omp_precmd() {
        [[ "$__devcli_omp_cmd_ran" == "1" ]] || __bp_last_ret_value=0
        __devcli_omp_cmd_ran=0
    }
    preexec_functions+=(__devcli_omp_preexec)
    precmd_functions+=(__devcli_omp_precmd)
fi

# =============================================================================
# NOTAS IMPORTANTES PARA EL USUARIO:
# =============================================================================
# 1. Este archivo se copia automáticamente a ~/.bashrc durante la instalación
# 2. Requiere tener instalados: lsd, zoxide, fzf, oh-my-posh
# 3. El archivo ~/.oh-my-posh.json debe existir para el prompt personalizado
# 4. Si Oh My Posh no está instalado, el prompt usará el formato estándar
# 5. Autocompletado: TAB muestra opciones, sin distinguir mayúsculas/minúsculas
# 6. Navegación: autocd (escribir directorio = cd), cdspell (autocorrección)
# 7. Búsqueda: Ctrl+R (historial), Ctrl+T (archivos), Alt+C (directorios)
# =============================================================================

# =============================================================================
# Override local (no versionado): permite extender PATH, definir alias o
# funciones específicas de esta máquina sin tocar este archivo. Se ejecuta
# al final, así que tiene prioridad sobre todo lo anterior.
# Crea ~/.bashrc.local manualmente si lo necesitas; no existe por defecto.
# =============================================================================
[ -f ~/.bashrc.local ] && source ~/.bashrc.local
