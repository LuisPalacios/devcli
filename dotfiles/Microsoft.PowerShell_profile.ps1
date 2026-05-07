# =============================================================================
# Perfil personalizado de PowerShell 7 para Windows
# =============================================================================
# Ubicación final: ~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
# Propósito: Configurar PowerShell con aliases modernos, herramientas CLI
#            avanzadas, prompt personalizado y integración con Git
# Compatible con: PowerShell 7.0+ en Windows 10/11
# Dependencias: lsd, zoxide, btm, oh-my-posh, git, posh-git
# =============================================================================

#
# Fichero $PROFILE:
# C:\Users\<usuario>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
#

# Para poder detectar si estoy en un terminal normal
# ---------------------------------------------------------------
function Test-IsInteractiveTerminal {
    try {
        # ¿Host de consola real?
        if ($Host.Name -ne 'ConsoleHost') { return $false }

        # ¿No redirigido?
        if ([Console]::IsOutputRedirected -or [Console]::IsInputRedirected -or [Console]::IsErrorRedirected) {
            return $false
        }

        # ¿Soporte VT/ANSI? (PowerShell 7+ expone $PSStyle)
        # Si el rendering está forzado a PlainText, asumimos sin VT.
        if ($PSStyle -and $PSStyle.OutputRendering -eq 'PlainText') { return $false }

        return $true
    } catch { return $false }
}
$IsTTY = Test-IsInteractiveTerminal

# =============================================================================
# PERSONALIZACIÓN DEL COMANDO 'ping' PARA QUE SE PAREZCA AL DE LINUX
# =============================================================================

# Cambiar el alias interno de ping para que se comporte como el de Linux

function ping {
    # Verificar si el primer argumento es un parámetro (comienza con '-')
    # Si se proporciona un parámetro (por ejemplo, 'ping -n 5'), asumimos que el usuario no quiere -t y llama al ping original.
    if ($args[0] -notlike '-*') {
        # La parte 'ip' es el objetivo (x.x.x.x)
        $ip = $args[0]

        # Obtener todos los demás argumentos (por ejemplo, si se añadió '-n 5')
        $otrosArgumentos = $args | Select-Object -Skip 1

        # Ejecutar el comando original de Windows ping.exe con -t, la IP y cualquier otro argumento
        & ping.exe -t $ip $otrosArgumentos
    }
    else {
        # Si el primer argumento es un parámetro, o si no se proporcionan argumentos,
        # simplemente ejecutar el ping.exe original con todos los argumentos.
        & ping.exe $args
    }
}

# =============================================================================
# PERSONALIZACIÓN DEL COMANDO 'rm' CON SOPORTE PARA OPCIONES UNIX
# =============================================================================

# Cambiar el alias interno de rm para soportar opciones estilo Unix
# El rm nativo de PowerShell no soporta -fr (force recursive)
# Esta función añade compatibilidad con rm -fr para borrado recursivo

# Eliminar el alias nativo de PowerShell si existe
if (Get-Alias rm -ErrorAction SilentlyContinue) {
    Remove-Item Alias:rm -Force
}

# Función rm personalizada con soporte para -fr (force recursive)
function rm {
    param(
        [Parameter(Mandatory=$true, ValueFromRemainingArguments=$true)]
        [String[]] $Args
    )

    if ($Args -contains "-fr") {
        # Remover el parámetro -fr del arreglo de argumentos
        $targets = $Args | Where-Object { $_ -ne "-fr" }

        # Ejecutar borrado recursivo y forzado (equivalente a rm -rf en Unix)
        Remove-Item -LiteralPath $targets -Recurse -Force -ErrorAction SilentlyContinue
    }
    else {
        # Ejecutar borrado estándar (equivalente a rm en Unix)
        Remove-Item -LiteralPath $Args -ErrorAction SilentlyContinue
    }
}

# =============================================================================
# REEMPLAZO DE 'ls' CON LSD (LISTADO MODERNO CON ICONOS)
# =============================================================================

# Cambiar el alias interno de ls por eza (con fallback a lsd) para listados
# modernos con iconos, colores mejorados y --git en long views.
# eza:  https://github.com/eza-community/eza
# lsd:  https://github.com/lsd-rs/lsd  (fallback durante una temporada)

# Eliminar el alias nativo de PowerShell si existe
if (Get-Alias ls -ErrorAction SilentlyContinue) {
    Remove-Item Alias:ls -Force
}

# Función ls: prefiere eza, cae a lsd, último recurso Get-ChildItem.
# Sin --group-directories-first: sort alfabético interleaved (preferencia
# del usuario, idéntico a `lsd` directo con dir-grouping=none en config).
function ls {
    if (Get-Command eza -ErrorAction SilentlyContinue) {
        eza --icons=auto --color=auto --git @args
    } elseif (Get-Command lsd -ErrorAction SilentlyContinue) {
        lsd @args
    } else {
        Get-ChildItem @args
    }
}

# =============================================================================
# AÑADO 'gst' para hacer "git status"
# =============================================================================

# Eliminar el alias si existe
if (Get-Alias gst -ErrorAction SilentlyContinue) {
    Remove-Item Alias:gst -Force
}

# Función ls que usa lsd con directorios agrupados al principio
function gst {
    git status @args
}

# =============================================================================
# ELIMINACIÓN DE ALIASES CONFLICTIVOS
# =============================================================================

# Eliminar el alias 'where' para evitar conflictos con where.exe
# PowerShell tiene un alias 'where' que puede interferir con where.exe de Windows
# Esto asegura que where.exe funcione correctamente
if (Get-Alias where -ErrorAction SilentlyContinue) {
    Remove-Item Alias:where -Force
}

# =============================================================================
# FUNCIÓN NANO - EDITOR DE TEXTO EN CONSOLA
# =============================================================================

# Alias para nano, editor de texto en consola incluido con Git para Windows
# Busca automáticamente la instalación de Git y localiza nano.exe
# Proporciona editing de texto simple en consola estilo Unix
function nano {
    # Buscar la ruta de git.exe en el sistema
    $gitPath = & where.exe git.exe 2>$null | Select-Object -First 1

    if (-not $gitPath) {
        Write-Error "Git no está instalado o no está en el PATH."
        return
    }

    # Asumir que nano.exe está en usr\bin\ dentro de la raíz de Git
    $gitRoot = Split-Path -Parent $gitPath
    $nanoPath = Join-Path $gitRoot "..\usr\bin\nano.exe" | Resolve-Path -ErrorAction SilentlyContinue

    if (-not $nanoPath) {
        Write-Error "nano.exe no encontrado en la instalación de Git."
        return
    }

    # Ejecutar nano.exe con todos los argumentos proporcionados
    & $nanoPath @Args
}

# =============================================================================
# FUNCIÓN HTOP - MONITOR DE SISTEMA INTERACTIVO
# =============================================================================

# Alias para htop usando 'btm' (bottom) como alternativa en Windows
# htop es un monitor de procesos popular en Unix/Linux
# btm (bottom) es una alternativa moderna multiplataforma
# Instalación: scoop install bottom
function htop {
    $btm = Get-Command btm -ErrorAction SilentlyContinue

    if ($btm) {
        # Ejecutar bottom con todos los argumentos proporcionados
        & $btm @Args
    } else {
        Write-Warning "'btm' (bottom) no está instalado. Puedes instalarlo con 'scoop install bottom'"
    }
}

# =============================================================================
# INSTALACIÓN Y CONFIGURACIÓN DE POSH-GIT
# =============================================================================

# Instalación automática de posh-git para integración avanzada con Git
# posh-git proporciona: autocompletado de comandos Git, estado del repositorio,
# información de branches en el prompt, y shortcuts de comandos
if (-not (Get-Module -ListAvailable -Name posh-git)) {
    try {
        Write-Host "Instalando posh-git..." -ForegroundColor Yellow
        Install-Module posh-git -Scope CurrentUser -Force -AllowClobber
    }
    catch {
        Write-Warning "No se pudo instalar posh-git: $_"
    }
}

# Importar posh-git para habilitar integración con Git
# Proporciona autocompletado inteligente y información de estado en el prompt
try {
    Import-Module posh-git -ErrorAction Stop
}
catch {
    Write-Warning "No se pudo importar posh-git: $_"
}

# =============================================================================
# Kubernetes
# =============================================================================
$env:KUBECONFIG = Join-Path $HOME "kubeconfig"

# =============================================================================
# INICIALIZACIÓN DE ZOXIDE Y OH-MY-POSH (COMPATIBILIDAD TOTAL)
# =============================================================================
# Este bloque configura correctamente zoxide (navegación inteligente) junto
# a oh-my-posh (prompt personalizado), resolviendo conflictos comunes.
# Incluye:
#   - Inicialización del hook de zoxide usando `--hook prompt`
#   - Protección del hook frente a la sobrescritura del prompt por oh-my-posh
#   - Redefinición inteligente de `cd` que aprovecha zoxide si la ruta no existe
# Repositorio: https://github.com/ajeetdsouza/zoxide
# =============================================================================
#
# Comandos disponibles después de la inicialización:
# - z [directorio]  : salto rápido a directorio (ej: z doc, z pro)
# - cd [directorio] : navegación normal + aprendizaje automático
# - zi              : búsqueda interactiva de directorios
#
# - El flag '--hook prompt' configura zoxide para registrar los cambios
#   de directorio en cada render del prompt.
# - Requiere versión zoxide >= 0.9
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    if ($IsTTY) {
        Write-Host "Inicializando zoxide..." -ForegroundColor Green
        Invoke-Expression (& { (zoxide init powershell --hook prompt | Out-String) })
    }
}

# -----------------------------------------------------------------------------
# Inicializar Oh My Posh (si está disponible)
# -----------------------------------------------------------------------------
# - Personaliza el prompt con configuración avanzada desde ~/.oh-my-posh.json
# - Sobrescribe la función global `prompt`, lo cual rompe el hook de zoxide
#   si no se corrige a continuación
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    if ($IsTTY) {
    Write-Host "Inicializando oh-my-posh..." -ForegroundColor Cyan
    oh-my-posh init pwsh --config ~/.oh-my-posh.json | Invoke-Expression
    }
}

# -----------------------------------------------------------------------------
# Reparar hook de zoxide si fue sobrescrito por oh-my-posh
# -----------------------------------------------------------------------------
# - Compara el prompt actual con el original registrado por zoxide
# - Si es distinto, redefine `prompt` para llamar a ambos:
#   1. El prompt de oh-my-posh
#   2. El hook `__zoxide_hook` para registrar el directorio actual
if ($IsTTY -and $global:__zoxide_hooked -eq 1 -and $function:prompt -ne $global:__zoxide_prompt_old) {
    $ompPrompt = $function:prompt
    function global:prompt {
        & $ompPrompt
        $null = __zoxide_hook
    }
}

# -----------------------------------------------------------------------------
# Integración WezTerm — emisión de OSC-7 (CWD) en cada prompt
# -----------------------------------------------------------------------------
# - Envuelve el prompt actual (sea oh-my-posh, zoxide-repair o el por defecto).
# - Emite la secuencia OSC 7 con el CWD para que AI Mode y la barra de
#   pestañas de WezTerm conozcan el directorio activo.
# - Se activa solo dentro de WezTerm; WEZTERM_PANE lo define WezTerm
#   automáticamente para cada pane que lanza.
if ($env:WEZTERM_PANE) {
    $global:__wezterm_prev_prompt = $function:prompt
    function global:prompt {
        $output = & $global:__wezterm_prev_prompt
        $cwd = (Get-Location).ProviderPath -replace '\\','/'
        $esc = [char]27
        Write-Host -NoNewline "$esc]7;file://$env:COMPUTERNAME/$cwd$esc\"
        return $output
    }
}

# -----------------------------------------------------------------------------
# Redefinición inteligente de 'cd' para soporte integrado con zoxide
# -----------------------------------------------------------------------------
# - Elimina el alias predeterminado 'cd' (que apunta a Set-Location)
# - Redefine 'cd' como función que:
#     • Si no recibe parámetro: va al home
#     • Si la ruta existe: usa Set-Location
#     • Si no existe: intenta saltar usando zoxide (`__zoxide_z`)
# -----------------------------------------------------------------------------

# Eliminar alias nativo de PowerShell (evita que interfiera con la redefinición)
if (Get-Alias cd -ErrorAction SilentlyContinue) {
    Remove-Item Alias:cd -Force
}

# Redefinir 'cd' como función híbrida: navegación clásica + fuzzy matching
function cd {
    param([string]$Path)

    if (-not $Path) {
        # Sin argumentos: ir al directorio HOME
        Set-Location ~
    }
    elseif (Test-Path -LiteralPath $Path -PathType Container) {
        # Ruta válida: cambiar normalmente
        Set-Location -LiteralPath $Path
    }
    else {
        # Ruta no válida: intentar match parcial con zoxide
        __zoxide_z $Path
    }
}

# =============================================================================
# CONFIGURACIÓN AVANZADA DE PSREADLINE - PREDICCIÓN INTELIGENTE
# =============================================================================

# Configurar predicción inteligente PSReadLine (requiere PowerShell 7.2+)
# HistoryAndPlugin: usa historial local + plugins para sugerencias
# ListView: muestra sugerencias en lista desplegable
# Windows: modo de edición compatible con Windows (vs Emacs/Vi)

# Configurar las predictions solo si tengo consola VT-capable y no redirigida
# Habilitar predicción basada en historial y plugins
# Mostrar predicciones en vista de lista (más fácil de navegar)
# Usar modo de edición Windows (familiar para usuarios de Windows)
if ($IsTTY -and (Get-Module -ListAvailable -Name PSReadLine)) {
    try {
        # La mejor UX en un terminal adecuado
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin
        Set-PSReadLineOption -PredictionViewStyle ListView
        Set-PSReadLineOption -EditMode Windows
    } catch {
        # Fallback (raro): mantener la shell utilizable incluso si algo se escapa
        Set-PSReadLineOption -PredictionSource History
        Set-PSReadLineOption -PredictionViewStyle InlineView
    }
} else {
    # No-TTY / redirigido: evitar errores — configuraciones mínimas y seguras
    if (Get-Module -ListAvailable -Name PSReadLine) {
        Set-PSReadLineOption -PredictionSource History
        Set-PSReadLineOption -PredictionViewStyle InlineView
        Set-PSReadLineOption -EditMode Windows
    }
}

# =============================================================================
# VARIABLES DE ENTORNO PARA HERRAMIENTAS CLI (process-scope)
# =============================================================================
# Mismo patrón que bashrc/zshrc: se setean en cada arranque del perfil. NO
# usamos `setx` porque eza, oh-my-posh y demás corren como child processes
# de esta sesión y heredan el env desde aquí — no hace falta persistir en
# el registro del usuario, y así evitamos el footgun "necesita reboot".

# OMP_OS_ICON: icono del OS para oh-my-posh
$env:OMP_OS_ICON = "🪟"

# LS_COLORS: colores para listado de archivos. Usado por eza (extensiones)
# y herramientas GNU. fi=archivos, di=directorios, ln=enlaces, ex=ejecutables.
$lsColors  = "fi=00:mi=00:mh=00:ln=01;94:or=01;31:di=01;36:ow=04;01;34:st=34:tw=04;34"
$lsColors += ":pi=01;33:so=01;33:do=01;33:bd=01;33:cd=01;33:su=01;35:sg=01;35:ca=01;35:ex=01;32"
$lsColors += ":*.cmd=00;32:*.exe=01;32:*.com=01;32:*.bat=01;32:*.btm=01;32:*.dll=01;32"
$lsColors += ":*.tar=00;31:*.tbz=00;31:*.tgz=00;31:*.rpm=00;31:*.deb=00;31:*.arj=00;31"
$lsColors += ":*.taz=00;31:*.lzh=00;31:*.lzma=00;31:*.zip=00;31:*.zoo=00;31:*.z=00;31"
$lsColors += ":*.Z=00;31:*.gz=00;31:*.bz2=00;31:*.tb2=00;31:*.tz2=00;31:*.tbz2=00;31"
$lsColors += ":*.avi=01;35:*.bmp=01;35:*.fli=01;35:*.gif=01;35:*.jpg=01;35:*.jpeg=01;35"
$lsColors += ":*.mng=01;35:*.mov=01;35:*.mpg=01;35:*.pcx=01;35:*.pbm=01;35:*.pgm=01;35"
$lsColors += ":*.png=01;35:*.ppm=01;35:*.tga=01;35:*.tif=01;35:*.xbm=01;35:*.xpm=01;35"
$lsColors += ":*.dl=01;35:*.gl=01;35:*.wmv=01;35"
$env:LS_COLORS = $lsColors

# EZA_COLORS: replica los colores de ~/.config/lsd/colors.yaml para que la
# transición lsd → eza sea visualmente continua. Override de LS_COLORS
# donde aplica (eza usa LS_COLORS para extensiones, EZA_COLORS para UI:
# usuarios, grupos, perms, fechas, git, sizes). NO seteamos `di` — eza
# hereda de LS_COLORS (`di=01;36`, cyan bold), igual que en lsd.
$ezaColors  = "uu=38;5;230:gu=38;5;187"
$ezaColors += ":ur=32:uw=33:ux=31:ue=31:gr=32:gw=33:gx=31"
$ezaColors += ":tr=32:tw=33:tx=31:su=38;5;5:sf=38;5;5:xa=36:oc=38;5;6"
$ezaColors += ":sn=38;5;245:nb=38;5;229:nk=38;5;229:nm=38;5;216"
$ezaColors += ":ng=38;5;172:nt=38;5;172:ub=38;5;229:uk=38;5;229"
$ezaColors += ":um=38;5;216:ug=38;5;172:ut=38;5;172"
$ezaColors += ":da=38;5;36:in=38;5;13:lc=38;5;13:xx=38;5;245"
$ezaColors += ":ga=32:gm=33:gd=31:gv=32:gt=33:gi=38;5;245:gc=31"
$env:EZA_COLORS = $ezaColors


# =============================================================================
# CONFIGURACIÓN DE TECLAS Y COMPORTAMIENTO ESTILO UNIX
# =============================================================================

# Añadir Ctrl-D para emular el funcionamiento de Linux
# Permite salir de PowerShell usando Ctrl+D como en terminales Unix/Linux
# Esto mejora la experiencia para usuarios acostumbrados a sistemas Unix
Set-PSReadlineKeyHandler -Key ctrl+d -Function ViExit

# =============================================================================
# NOTAS IMPORTANTES PARA EL USUARIO:
# =============================================================================
# 1. Este perfil se ejecuta automáticamente al iniciar PowerShell
# 2. Requiere las siguientes herramientas instaladas via Scoop:
#    - lsd (listado moderno con iconos)
#    - zoxide (navegación inteligente de directorios)
#    - btm/bottom (monitor de sistema para htop)
#    - oh-my-posh (prompt personalizado)
# 3. Dependencias adicionales:
#    - Git for Windows (para nano y posh-git)
#    - Archivo ~/.oh-my-posh.json (tema de Oh My Posh)
#    - PowerShell 7.2+ (para predicción inteligente)
# 4. Si faltan herramientas, las funciones muestran mensajes informativos
# 5. Las variables de entorno se configuran una sola vez automáticamente
# 6. Para personalizar aliases, modifica las funciones en este archivo
# =============================================================================
