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

# =============================================================================
# CONFIGURACIÓN DE TECLAS Y COMPORTAMIENTO ESTILO UNIX
# =============================================================================

# Añadir Ctrl-D para emular el funcionamiento de Linux
# Permite salir de PowerShell usando Ctrl+D como en terminales Unix/Linux
# Esto mejora la experiencia para usuarios acostumbrados a sistemas Unix
Set-PSReadlineKeyHandler -Key ctrl+d -Function ViExit

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

# Cambiar el alias interno de ls por lsd para listados modernos
# lsd proporciona: iconos, colores mejorados, agrupación de directorios
# Repositorio: https://github.com/lsd-rs/lsd

# Eliminar el alias nativo de PowerShell si existe
if (Get-Alias ls -ErrorAction SilentlyContinue) {
    Remove-Item Alias:ls -Force
}

# Función ls que usa lsd con directorios agrupados al principio
function ls {
    lsd --group-directories-first @args
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
# INICIALIZACIÓN DE ZOXIDE (NAVEGACIÓN INTELIGENTE)
# =============================================================================

# Inicializar zoxide para navegación inteligente de directorios
# zoxide recuerda directorios visitados y permite saltos rápidos
# Comandos disponibles después de la inicialización:
# - z [directorio]  : salto rápido a directorio (ej: z doc, z pro)
# - cd [directorio] : navegación normal + aprendizaje automático
# - zi              : búsqueda interactiva de directorios
# Repositorio: https://github.com/ajeetdsouza/zoxide

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Write-Host "Inicializando zoxide..." -ForegroundColor Green

    # Inicializar zoxide con hook en prompt
    Invoke-Expression (& { (zoxide init powershell | Out-String) })

    # Si oh-my-posh sobreescribió el prompt, reinyectar el hook de zoxide
    if ($global:__zoxide_hooked -eq 1 -and $function:prompt -ne $global:__zoxide_prompt_old) {
        $ompPrompt = $function:prompt
        function global:prompt {
            & $ompPrompt
            $null = __zoxide_hook
        }
    }
}

# =============================================================================
# INICIALIZACIÓN DE OH MY POSH - PROMPT PERSONALIZADO
# =============================================================================

# Ejecutar oh-my-posh para personalizar el prompt de PowerShell
# Usa el archivo de configuración personalizado ~/.oh-my-posh.yaml
# Oh My Posh proporciona un prompt rico con información de Git, directorio,
# tiempo de ejecución, estado del sistema, etc.
oh-my-posh init pwsh --config ~/.oh-my-posh.yaml | Invoke-Expression

# =============================================================================
# CONFIGURACIÓN AVANZADA DE PSREADLINE - PREDICCIÓN INTELIGENTE
# =============================================================================

# Configurar predicción inteligente PSReadLine (requiere PowerShell 7.2+)
# HistoryAndPlugin: usa historial local + plugins para sugerencias
# ListView: muestra sugerencias en lista desplegable
# Windows: modo de edición compatible con Windows (vs Emacs/Vi)

# Habilitar predicción basada en historial y plugins
Set-PSReadLineOption -PredictionSource HistoryAndPlugin

# Mostrar predicciones en vista de lista (más fácil de navegar)
Set-PSReadLineOption -PredictionViewStyle ListView

# Usar modo de edición Windows (familiar para usuarios de Windows)
Set-PSReadLineOption -EditMode Windows

# =============================================================================
# CONFIGURACIÓN AUTOMÁTICA DE VARIABLES DE ENTORNO CRÍTICAS
# =============================================================================

# Acumulador donde se guardan las variables de entorno críticas para el
# funcionamiento óptimo de:
# - lsd: colores y iconos en listados
# - oh-my-posh: iconos del sistema operativo
# - Herramientas CLI modernas: esquemas de color consistentes

$envVarsToSet = @()

# =============================================================================
# CONFIGURACIÓN DE OMP_OS_ICON - ICONO DEL SISTEMA OPERATIVO
# =============================================================================

# Establecer OMP_OS_ICON (icono del OS para oh-my-posh)
# Este icono aparece en el prompt para identificar el sistema operativo
# Se configura permanentemente con setx para persistir entre sesiones
if (-not [Environment]::GetEnvironmentVariable("OMP_OS_ICON", "User")) {
    try {
        setx OMP_OS_ICON "🪟" >$null 2>&1
        $envVarsToSet += "OMP_OS_ICON"
        Write-Host "✅ Variable OMP_OS_ICON configurada" -ForegroundColor Green
    }
    catch {
        Write-Warning "No se pudo configurar OMP_OS_ICON: $_"
    }
}

# =============================================================================
# CONFIGURACIÓN DE LS_COLORS - ESQUEMA DE COLORES PARA ARCHIVOS
# =============================================================================

# Verificar y configurar LS_COLORS (colores para lsd y listado de directorios)
# Define colores específicos para diferentes tipos de archivos y directorios
# Mejora la legibilidad y navegación visual en el terminal
if (-not [Environment]::GetEnvironmentVariable("LS_COLORS", "User")) {
    try {
        # Configuración completa de colores para diferentes tipos de archivos:
        # fi=archivos regulares, di=directorios, ln=enlaces, ex=ejecutables
        # Extensiones específicas: .exe, .cmd, .tar, .zip, .jpg, etc.
        $lsColors = "fi=00:mi=00:mh=00:ln=01;94:or=01;31:di=01;36:ow=04;01;34:st=34:tw=04;34:pi=01;33:so=01;33:do=01;33:bd=01;33:cd=01;33:su=01;35:sg=01;35:ca=01;35:ex=01;32:*.cmd=00;32:*.exe=01;32:*.com=01;32:*.bat=01;32:*.btm=01;32:*.dll=01;32:*.tar=00;31:*.tbz=00;31:*.tgz=00;31:*.rpm=00;31:*.deb=00;31:*.arj=00;31:*.taz=00;31:*.lzh=00;31:*.lzma=00;31:*.zip=00;31:*.zoo=00;31:*.z=00;31:*.Z=00;31:*.gz=00;31:*.bz2=00;31:*.tb2=00;31:*.tz2=00;31:*.tbz2=00;31:*.avi=01;35:*.bmp=01;35:*.fli=01;35:*.gif=01;35:*.jpg=01;35:*.jpeg=01;35:*.mng=01;35:*.mov=01;35:*.mpg=01;35:*.pcx=01;35:*.pbm=01;35:*.pgm=01;35:*.png=01;35:*.ppm=01;35:*.tga=01;35:*.tif=01;35:*.xbm=01;35:*.xpm=01;35:*.dl=01;35:*.gl=01;35:*.wmv=01;35"

        setx LS_COLORS $lsColors >$null 2>&1
        $envVarsToSet += "LS_COLORS"
        Write-Host "✅ Variable LS_COLORS configurada" -ForegroundColor Green
    }
    catch {
        Write-Warning "No se pudo configurar LS_COLORS: $_"
    }
}

# =============================================================================
# NOTIFICACIÓN IMPORTANTE SOBRE REINICIO REQUERIDO
# =============================================================================

# Mostrar mensaje importante si se configuraron nuevas variables de entorno
# Las variables configuradas con setx requieren reinicio para tomar efecto
if ($envVarsToSet.Count -gt 0) {
    Write-Host ""
    Write-Host "🔄 " -NoNewline -ForegroundColor Yellow
    Write-Host "IMPORTANTE: " -NoNewline -ForegroundColor Red -BackgroundColor Yellow
    Write-Host "Variables de entorno configuradas: " -NoNewline -ForegroundColor Yellow
    Write-Host ($envVarsToSet -join ", ") -ForegroundColor Cyan
    Write-Host ""
    Write-Host "⚠️  Para que los cambios surtan efecto, necesitas " -NoNewline -ForegroundColor Yellow
    Write-Host "REINICIAR WINDOWS" -ForegroundColor Red -BackgroundColor Black
    Write-Host "   y abrir una nueva sesión de PowerShell después del reinicio." -ForegroundColor Yellow
    Write-Host ""
}

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
#    - Archivo ~/.oh-my-posh.yaml (tema de Oh My Posh)
#    - PowerShell 7.2+ (para predicción inteligente)
# 4. Si faltan herramientas, las funciones muestran mensajes informativos
# 5. Las variables de entorno se configuran una sola vez automáticamente
# 6. Para personalizar aliases, modifica las funciones en este archivo
# =============================================================================

