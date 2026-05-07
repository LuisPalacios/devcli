# ------------------------------------------------------------------
# utils.ps1 - Funciones utilitarias compartidas para scripts de instalación
# ------------------------------------------------------------------
#
# Error / control-flow contract (post-UX layer):
#
#   - Install-Method* (Scoop, Winget, ScoopBucket): devuelven $true en éxito,
#       $false en fallo de instalación. NUNCA llaman `throw` ni `exit`.
#       Usar Write-Log -Level WARNING para mensajes al usuario (se enruta a
#       Write-UxWarn cuando la capa UX está activa).
#
#   - Invoke-PhaseItems: devuelve int 0=ok, 1=warn, 2=fail. Los phase scripts
#       capturan ese valor y hacen `exit $rc` para que bootstrap tally.
#
#   - Phase scripts: NO llamar `exit` a media fase — dejar que
#       Invoke-PhaseItems cierre la fase y salir con su código al final.
#
#   - Prerrequisitos duros (scoop ausente, config inválida): emitir
#       `Start-UxPhase` + `Write-UxError` + `Complete-UxPhase fail` y
#       `exit 2` directamente.
#
# ------------------------------------------------------------------

# Bridge a la capa UX. Initialize-Ux se llama desde bootstrap.ps1 y desde
# cada phase script al arrancar — así que $script:UxActive siempre está set
# cuando se invoca esta función.
#   - ERROR    → Write-UxError (sub-línea roja bajo la fase actual)
#   - WARNING  → Write-UxWarn  (sub-línea amarilla)
#   - INFO/SUCCESS → log file (no pantalla — la maneja la fase)
function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [string]$Level = "INFO"
    )

    switch ($Level) {
        'ERROR'   { Write-UxError -Message $Message; return }
        'WARNING' { Write-UxWarn  -Message $Message; return }
        default {
            if ($script:UxLogFile) {
                Add-Content -Path $script:UxLogFile `
                    -Value ('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $Message) `
                    -ErrorAction SilentlyContinue
            }
        }
    }
}

# Función para verificar si un comando existe
function Test-Command {
    param(
        [Parameter(Mandatory)]
        [string]$Command
    )
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

# Función para crear directorio si no existe
function New-DirectoryIfNotExists {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        try {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
            Write-Log "Directorio creado: $Path"
            return $true
        }
        catch {
            Write-Log "Error creando directorio $Path`: $($_.Exception.Message)" "ERROR"
            return $false
        }
    }
    return $true
}

# Función para verificar si winget es realmente funcional.
# En Windows 11 ARM (o en imágenes recién provisionadas) a veces existe el
# reparse point de 0 bytes en %LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe
# pero el AppExecutionAlias no está registrado y cualquier invocación devuelve
# "Acceso denegado". Get-Command winget es insuficiente: hay que ejecutarlo.
function Test-WingetFunctional {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { return $false }
    try {
        $null = & winget --version 2>&1
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

# Función para verificar si un paquete winget está instalado
function Test-WingetPackage {
    param(
        [Parameter(Mandatory)]
        [string]$PackageId
    )

    if (-not (Test-WingetFunctional)) { return $false }

    try {
        $result = winget list --id $PackageId --exact 2>$null
        return $result -and ($result | Select-String $PackageId)
    }
    catch {
        return $false
    }
}

# Función para verificar si scoop está instalado
function Test-Scoop {
    # Solo verificar que el comando existe y el directorio de scoop existe
    $scoopCmd = Get-Command "scoop" -ErrorAction SilentlyContinue
    $scoopDir = Test-Path "$env:USERPROFILE\scoop"

    return $scoopCmd -and $scoopDir
}

# Función para verificar si un paquete scoop está instalado
function Test-ScoopPackage {
    param(
        [Parameter(Mandatory)]
        [string]$PackageName
    )

    try {
        # Solo verificar directorio - método 100% silencioso
        $scoopAppsDir = "$env:USERPROFILE\scoop\apps\$PackageName"
        return Test-Path $scoopAppsDir
    }
    catch {
        return $false
    }
}

# Función para instalar paquete con scoop
function Install-ScoopPackage {
    param(
        [Parameter(Mandatory)]
        [string]$PackageName
    )

    if (-not (Test-Scoop)) {
        Write-Log "Scoop no está disponible" "ERROR"
        return $false
    }

    if (Test-ScoopPackage $PackageName) {
        Write-Log "$PackageName ya instalado (scoop)" "INFO"
        return $true
    }

    try {
        $null = Invoke-UxCapture -ScriptBlock { scoop install $PackageName --no-update-scoop }
        if ($LASTEXITCODE -eq 0) {
            return $true
        }
        Write-Log "${PackageName}: scoop falló (código $LASTEXITCODE)" "WARNING"
        return $false
    }
    catch {
        Write-Log "${PackageName}: excepción de scoop ($($_.Exception.Message))" "WARNING"
        return $false
    }
}

# Función para instalar paquete con winget
function Install-WingetPackage {
    param(
        [Parameter(Mandatory)]
        [string]$PackageId,

        [string]$Name = $PackageId
    )

    if (-not (Test-WingetFunctional)) {
        Write-Log "winget no está operativo — omitiendo $Name. Ejecuta 'Reset' en Settings > Apps > App Installer o actualiza App Installer desde Microsoft Store." "WARNING"
        return $false
    }

    if (Test-WingetPackage $PackageId) {
        Write-Log "$Name ya instalado (winget)" "INFO"
        return $true
    }

    try {
        # Capturar stdout/stderr a temp files; luego append al log file para no
        # sobrescribir lo que ya hay (Start-Process -RedirectX no soporta append).
        $tmpOut = [System.IO.Path]::GetTempFileName()
        $tmpErr = [System.IO.Path]::GetTempFileName()
        $process = Start-Process -FilePath 'winget' `
            -ArgumentList @('install', $PackageId, '--silent', '--accept-package-agreements', '--accept-source-agreements') `
            -Wait -PassThru -NoNewWindow `
            -RedirectStandardOutput $tmpOut -RedirectStandardError $tmpErr

        if ($script:UxLogFile) {
            Add-Content -Path $script:UxLogFile -Value "--- $(Get-Date -Format 'HH:mm:ss') winget install $PackageId ---" -ErrorAction SilentlyContinue
            Get-Content $tmpOut, $tmpErr -ErrorAction SilentlyContinue | Add-Content -Path $script:UxLogFile -ErrorAction SilentlyContinue
        }
        Remove-Item $tmpOut, $tmpErr -Force -ErrorAction SilentlyContinue

        if ($process.ExitCode -eq 0) {
            return $true
        }
        else {
            Write-Log "${Name}: winget falló (código $($process.ExitCode))" "WARNING"
            return $false
        }
    }
    catch {
        Write-Log "Excepción instalando $Name`: $($_.Exception.Message)" "WARNING"
        return $false
    }
}

# Función para verificar si jq está disponible
function Test-Jq {
    if (-not (Test-Command "jq")) {
        Write-Log "jq no está disponible. Debe instalarse primero en 01-system.ps1" "ERROR"
        return $false
    }
    return $true
}

# Función para leer configuración desde JSON usando jq o PowerShell nativo
function Get-ConfigFromJson {
    param(
        [Parameter(Mandatory)]
        [ValidateScript({Test-Path $_})]
        [string]$JsonPath,

        [string]$PropertyName = $null
    )

    try {
        # PowerShell 7 maneja mejor la lectura directa de JSON
        $config = Get-Content $JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable

        if ($PropertyName) {
            if (-not $config.$PropertyName) {
                Write-Log "No se encontró sección '$PropertyName' en el JSON" "WARNING"
                return @()
            }
            return $config.$PropertyName
        }

        return $config
    }
    catch {
        Write-Log "Error leyendo configuración JSON: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

# ------------------------------------------------------------------
# Method Dispatchers — catalog-driven tool installation from tools.json
# ------------------------------------------------------------------
#
# Contrato unificado de idempotencia (follow-up #2):
#   - Install-MethodScoop / Install-MethodWinget / Install-MethodScoopBucket
#     delegan en Install-ScoopPackage / Install-WingetPackage, que ya tienen
#     idempotencia interna (Test-ScoopPackage / Test-WingetPackage). NO usan
#     check_cmd: el chequeo por package manager es más fiable que por nombre
#     de comando (el nombre del paquete y el del binario no siempre coinciden).
#   - El paralelo de check_cmd en Bash (curl-sh / github-deb / github-binary)
#     no aplica en PS porque no hay handlers Unix-style aquí. Si alguna vez
#     un tool concreto necesita un installer upstream (no scoop/winget), se
#     evaluará entonces ad-hoc.

# Extract a single field from a tools.json block hashtable, with default.
# Mirror del helper Bash `_block_field`. Acepta hashtable (cargado con
# ConvertFrom-Json -AsHashtable) y devuelve el default si la clave no existe
# o el valor es $null.
function Get-BlockField {
    param(
        [Parameter(Mandatory)][hashtable]$Block,
        [Parameter(Mandatory)][string]$Name,
        $Default = $null
    )
    if ($Block.ContainsKey($Name) -and $null -ne $Block[$Name]) {
        return $Block[$Name]
    }
    return $Default
}

# --- Method: scoop (wraps Install-ScoopPackage) ---
function Install-MethodScoop {
    param([Parameter(Mandatory)][hashtable]$Block)
    $package = Get-BlockField -Block $Block -Name 'package'
    return Install-ScoopPackage -PackageName $package
}

# --- Method: winget (wraps Install-WingetPackage) ---
function Install-MethodWinget {
    param([Parameter(Mandatory)][hashtable]$Block)
    $package = Get-BlockField -Block $Block -Name 'package'
    $name = Get-BlockField -Block $Block -Name 'name' -Default $package
    return Install-WingetPackage -PackageId $package -Name $name
}

# --- Method: scoop-bucket (add bucket + install) ---
function Install-MethodScoopBucket {
    param([Parameter(Mandatory)][hashtable]$Block)

    try {
        if (-not (Test-Scoop)) {
            Write-Log "Scoop no está disponible para instalar" "WARNING"
            return $true  # Non-critical
        }

        $bucketName = Get-BlockField -Block $Block -Name 'bucket_name'
        $bucketUrl  = Get-BlockField -Block $Block -Name 'bucket_url'
        $package    = Get-BlockField -Block $Block -Name 'package'

        # Check if already installed
        if (Test-ScoopPackage -PackageName $package) {
            Write-Log "$package ya está instalado"
            return $true
        }

        # Add bucket if needed
        $hasBucket = $false
        try {
            $buckets = & scoop bucket list 2>$null | Where-Object { $_ -match $bucketName }
            if ($buckets) { $hasBucket = $true }
        } catch { }

        if (-not $hasBucket) {
            Write-Log "Añadiendo bucket $bucketName..."
            try {
                & scoop bucket add $bucketName $bucketUrl 2>$null | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-Log "Error añadiendo bucket $bucketName (código: $LASTEXITCODE)" "WARNING"
                    return $true  # Non-critical
                }
            } catch {
                Write-Log "Excepción añadiendo bucket: $($_.Exception.Message)" "WARNING"
                return $true  # Non-critical
            }
        }

        # Install the package
        Write-Log "Instalando $package..."
        if (Install-ScoopPackage -PackageName $package) {
            Write-Log "$package instalado correctamente" "SUCCESS"
            Write-Log "IMPORTANTE: Reinicia tu terminal/editor para usar las nuevas fuentes" "WARNING"
            return $true
        } else {
            Write-Log "No se pudo instalar $package, pero continuando..." "WARNING"
            return $true  # Non-critical
        }
    } catch {
        Write-Log "Error en Install-MethodScoopBucket: $($_.Exception.Message)" "WARNING"
        return $true  # Non-critical
    }
}

# --- Hook: Configure CLINK for CMD autorun ---
function Configure-Clink {
    Write-Log "Configurando CLINK para CMD..."

    try {
        if (-not (Test-ScoopPackage -PackageName "clink")) {
            Write-Log "CLINK no está instalado, omitiendo configuración" "WARNING"
            return $false
        }

        $clinkPath = Get-Command "clink" -ErrorAction SilentlyContinue
        if (-not $clinkPath) {
            Write-Log "No se pudo encontrar el ejecutable de CLINK" "WARNING"
            return $false
        }

        $clinkDir = Split-Path $clinkPath.Source -Parent
        $clinkCmd = Join-Path $clinkDir "clink.cmd"

        if (-not (Test-Path $clinkCmd)) {
            $scoopClinkCmd = "$env:USERPROFILE\scoop\shims\clink.cmd"
            if (Test-Path $scoopClinkCmd) {
                $clinkCmd = $scoopClinkCmd
            } else {
                Write-Log "No se encontró clink.cmd" "WARNING"
                return $false
            }
        }

        $registryPath = "HKCU:\Software\Microsoft\Command Processor"
        $autoRunValue = "`"$clinkCmd`" inject --autorun"

        try {
            if (-not (Test-Path $registryPath)) {
                New-Item -Path $registryPath -Force | Out-Null
            }
            $currentAutoRun = Get-ItemProperty -Path $registryPath -Name "Autorun" -ErrorAction SilentlyContinue

            if ($currentAutoRun -and $currentAutoRun.Autorun -like "*clink*") {
                Write-Log "CLINK ya está configurado en Autorun del CMD"
            } else {
                Set-ItemProperty -Path $registryPath -Name "Autorun" -Value $autoRunValue -Force
                Write-Log "CLINK configurado para inyección automática en CMD" "SUCCESS"
            }
        } catch {
            Write-Log "Error configurando Autorun: $($_.Exception.Message)" "WARNING"
            return $false
        }

        return $true
    } catch {
        Write-Log "Error configurando CLINK: $($_.Exception.Message)" "WARNING"
        return $false
    }
}

# --- Hook executor ---
function Invoke-Hook {
    param(
        [Parameter(Mandatory)][hashtable]$Hook,
        [hashtable[]]$ToolsRegistry = @()
    )

    $action = $Hook["action"]

    # Skip hooks that declare platforms and don't include windows
    if ($Hook["platforms"] -and $Hook["platforms"] -notcontains "windows") {
        return
    }

    switch ($action) {
        "alias" {
            $cmdName = $Hook["cmd_name"]
            $target = $Hook["target"]

            if ((Test-Command $target) -and (-not (Test-Command $cmdName))) {
                try {
                    $aliasScript = "@echo off`r`n$target %*"
                    $aliasPath = Join-Path $Global:BIN_DIR "$cmdName.cmd"
                    Set-Content -Path $aliasPath -Value $aliasScript -Encoding ASCII
                    Write-Log "Alias $cmdName -> $target creado" "SUCCESS"
                } catch {
                    Write-Log "Error creando alias $cmdName`: $($_.Exception.Message)" "WARNING"
                }
            }
        }
        "trigger" {
            $toolName = $Hook["tool"]
            if ($ToolsRegistry.Count -gt 0) {
                Install-Tool -ToolName $toolName -ToolsRegistry $ToolsRegistry | Out-Null
            }
        }
        "registry" {
            $type = $Hook["type"]
            switch ($type) {
                "clink-autorun" { Configure-Clink | Out-Null }
                default { Write-Log "Tipo de registry desconocido: $type" "WARNING" }
            }
        }
        default {
            Write-Log "Hook desconocido: $action" "WARNING"
        }
    }
}

# --- Main dispatcher: install a tool from tools.json ---
function Install-Tool {
    param(
        [Parameter(Mandatory)][string]$ToolName,
        [Parameter(Mandatory)][hashtable[]]$ToolsRegistry
    )

    # Find the tool entry
    $tool = $null
    foreach ($t in $ToolsRegistry) {
        if ($t["name"] -eq $ToolName) {
            $tool = $t
            break
        }
    }
    if (-not $tool) {
        Write-Log "Herramienta no encontrada en registro: $ToolName" "WARNING"
        return $false
    }

    # Get the Windows platform block
    $platformBlock = $tool["windows"]
    if (-not $platformBlock) {
        return $true  # Tool not available on this platform, not an error
    }

    $method = $platformBlock["method"]

    # Execute pre_install hooks (platform-level)
    if ($platformBlock["pre_install"]) {
        foreach ($hook in $platformBlock["pre_install"]) {
            Invoke-Hook -Hook $hook -ToolsRegistry $ToolsRegistry
        }
    }

    # Dispatch to method handler
    $result = switch ($method) {
        "scoop"        { Install-MethodScoop -Block $platformBlock }
        "scoop-bucket" { Install-MethodScoopBucket -Block $platformBlock }
        "winget"       { Install-MethodWinget -Block $platformBlock }
        default {
            Write-Log "Método desconocido: $method para $ToolName" "WARNING"
            $false
        }
    }

    if ($result) {
        # Execute platform-level post_install hooks
        if ($platformBlock["post_install"]) {
            foreach ($hook in $platformBlock["post_install"]) {
                Invoke-Hook -Hook $hook -ToolsRegistry $ToolsRegistry
            }
        }

        # Execute tool-level post_install hooks
        if ($tool["post_install"]) {
            foreach ($hook in $tool["post_install"]) {
                Invoke-Hook -Hook $hook -ToolsRegistry $ToolsRegistry
            }
        }
    }

    return $result
}

# Función para refrescar PATH de la sesión actual
function Update-SessionPath {
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::Machine) + ";" + [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User)
}

# Función para actualizar PATH del usuario
function Update-UserPath {
    param(
        [Parameter(Mandatory)]
        [string]$NewPath
    )

    if (-not (Test-Path $NewPath)) {
        Write-Log "El directorio no existe: $NewPath" "WARNING"
        return
    }

    try {
        $currentUserPath = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User)

        if ($currentUserPath -notlike "*$NewPath*") {
            $newUserPath = if ($currentUserPath) { "$currentUserPath;$NewPath" } else { $NewPath }
            [System.Environment]::SetEnvironmentVariable("PATH", $newUserPath, [System.EnvironmentVariableTarget]::User)
            Write-Log "PATH de usuario actualizado: $NewPath" "SUCCESS"

            # También actualizar PATH de la sesión actual
            $env:PATH += ";$NewPath"
        }
        else {
            # Already in PATH, nothing to do
        }
    }
    catch {
        Write-Log "Error actualizando PATH: $($_.Exception.Message)" "ERROR"
    }
}

# ===================================================================
# UX layer — user-facing output for the install pipeline
# ===================================================================
#
# Activated by Initialize-Ux at bootstrap time. Once active, phase scripts
# call:
#
#   Start-UxPhase    -Num <n> -Total <t> -Title "<title>"
#   Write-UxProgress -Current <c> -Total <t> -Item "<item>"
#   Complete-UxPhase -Status ok|warn|fail [-Details "..."]
#
# Plus, anywhere:
#
#   Show-UxBanner       -OS "<os>" -Profile "<profile>"
#   Write-UxWarn        -Message "<msg>" [-LogRange "142-168"]
#   Write-UxError       -Message "<msg>" [-LogRange "142-168"]
#   Invoke-UxCapture    -ScriptBlock { scoop install fzf }   # captures to log
#   Show-UxSummary
#
# Honors:
#   $env:DEVCLI_VERBOSE = '1'  → no in-place updates, raw output through
#   $env:NO_COLOR              → disables ANSI codes (also auto-off when no TTY)

# --- Internal state (script-scoped, do not touch from outside the layer) ---

$script:UxActive   = $false
$script:UxTty      = $false
$script:UxVerbose  = $false
$script:UxLogFile  = $null
$script:UxRunStart = [datetime]::MinValue

$script:UxColors = @{ Reset = ''; Green = ''; Yellow = ''; Red = ''; Cyan = ''; Dim = ''; Bold = '' }

$script:UxPhaseNum    = 0
$script:UxPhaseTotal  = 0
$script:UxPhaseTitle  = ''
$script:UxPhaseStart  = [datetime]::MinValue
$script:UxPhaseOpen   = $false

# Cola de warnings/errors emitidos durante la fase. Complete-UxPhase la
# vacía DESPUÉS del finalizer, para que la línea de progreso in-place
# no quede huérfana sobre el WARN.
$script:UxPhaseWarnings = @()

$script:UxPhasesOk    = 0
$script:UxPhasesWarn  = 0
$script:UxPhasesFail  = 0
$script:UxWarnCount   = 0
$script:UxErrorCount  = 0

# Width of the left side of the phase line. Tuned for 80-col output.
$script:UxLeftWidth = 44

# --- Public API ---

# Initialize the UX layer. Resolution order for the log file path:
#   -LogFile arg  →  $env:DEVCLI_UX_LOG_FILE  →  ~/.devcli/install.log
#
# Bootstrap calls this with an explicit path (and is the first to init, so it
# writes the session header). Phase scripts call this with no arg; they pick
# up the env var and skip the header.
function Initialize-Ux {
    [CmdletBinding()]
    param(
        [string]$LogFile = ''
    )

    $isFirstInit = -not $env:DEVCLI_UX_LOG_FILE

    if (-not $LogFile) {
        $LogFile = if ($env:DEVCLI_UX_LOG_FILE) {
            $env:DEVCLI_UX_LOG_FILE
        } else {
            Join-Path $env:USERPROFILE '.devcli\install.log'
        }
    }

    $script:UxVerbose = ($env:DEVCLI_VERBOSE -eq '1')

    # TTY detection: in-place updates only when stdout is a terminal AND
    # NO_COLOR is unset AND we're not in verbose mode.
    $script:UxTty = (-not [Console]::IsOutputRedirected) `
                  -and (-not $env:NO_COLOR) `
                  -and (-not $script:UxVerbose)

    # Colors: enabled whenever stdout is a terminal and NO_COLOR is unset.
    if ((-not [Console]::IsOutputRedirected) -and (-not $env:NO_COLOR)) {
        $esc = [char]27
        $script:UxColors = @{
            Reset  = "$esc[0m"
            Green  = "$esc[32m"
            Yellow = "$esc[33m"
            Red    = "$esc[31m"
            Cyan   = "$esc[36m"
            Dim    = "$esc[2m"
            Bold   = "$esc[1m"
        }
    }

    # Silence Invoke-WebRequest's slow built-in progress bar everywhere.
    $global:ProgressPreference = 'SilentlyContinue'

    # Open log file (append mode). If we can't write to it, disable capture.
    $logDir = Split-Path $LogFile -Parent
    if ($logDir -and -not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force -ErrorAction SilentlyContinue | Out-Null
    }
    try {
        Add-Content -Path $LogFile -Value '' -ErrorAction Stop
        $script:UxLogFile = $LogFile
        if ($isFirstInit) {
            $header = "=== {0} · perfil={1} · OS=Windows · pid={2} ===" -f `
                (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),
                ($env:DEVCLI_PROFILE ?? '?'),
                $PID
            Add-Content -Path $LogFile -Value '' -ErrorAction SilentlyContinue
            Add-Content -Path $LogFile -Value $header -ErrorAction SilentlyContinue
        }
        # Export so child scopes (phase scripts) inherit the same path.
        $env:DEVCLI_UX_LOG_FILE = $LogFile
    }
    catch {
        $script:UxLogFile = $null
    }

    $script:UxRunStart = Get-Date
    $script:UxActive = $true
}

function Show-UxBanner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$OS,
        [Parameter(Mandatory)] [string]$Profile
    )
    $c = $script:UxColors
    Write-Host ''
    Write-Host ("{0}{1}devcli{2} · {3} · perfil: {4}" -f $c.Bold, $c.Cyan, $c.Reset, $OS, $Profile)
    Write-Host ("{0}─────────────────────────────────────────────{1}" -f $c.Dim, $c.Reset)
    Write-Host ''
}

function Start-UxPhase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [int]$Num,
        [Parameter(Mandatory)] [int]$Total,
        [Parameter(Mandatory)] [string]$Title
    )
    $script:UxPhaseNum   = $Num
    $script:UxPhaseTotal = $Total
    $script:UxPhaseTitle = $Title
    $script:UxPhaseStart = Get-Date
    $script:UxPhaseOpen  = $true

    if ($script:UxTty) {
        _Render-UxPhaseLine -Right '...'
    } else {
        Write-Host ("[{0}/{1}] {2}" -f $Num, $Total, $Title)
    }
}

function Write-UxProgress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [int]$Current,
        [Parameter(Mandatory)] [int]$Total,
        [Parameter(Mandatory)] [string]$Item
    )
    if (-not $script:UxTty -or -not $script:UxPhaseOpen) { return }
    $right = "({0,2}/{1}) {2}" -f $Current, $Total, $Item
    _Render-UxPhaseLine -Right $right
}

function Complete-UxPhase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('ok', 'warn', 'fail')]
        [string]$Status,

        [string]$Details = ''
    )
    $elapsed = [int]([datetime]::Now - $script:UxPhaseStart).TotalSeconds
    $c = $script:UxColors

    switch ($Status) {
        'ok'   { $mark = 'OK';   $color = $c.Green;  $script:UxPhasesOk++ }
        'warn' { $mark = 'WARN'; $color = $c.Yellow; $script:UxPhasesWarn++ }
        default { $mark = 'FAIL'; $color = $c.Red;   $script:UxPhasesFail++ }
    }

    $final = '{0}{1,-4}{2}  {3,3}s' -f $color, $mark, $c.Reset, $elapsed
    if ($Details) {
        $final = '{0}   {1}{2}{3}' -f $final, $c.Dim, $Details, $c.Reset
    }

    if ($script:UxTty) {
        _Render-UxPhaseLine -Right $final
        Write-Host ''
    } else {
        Write-Host ('      ' + $final)
    }

    # Cerrar la fase ANTES de vaciar la cola: si algún `_Emit-UxSubline`
    # se llama post-flush, va por la rama immediate-print.
    $script:UxPhaseOpen = $false

    # Vaciar la cola de warnings/errors emitidos durante la fase.
    if ($script:UxPhaseWarnings.Count -gt 0) {
        foreach ($w in $script:UxPhaseWarnings) {
            Write-Host $w
        }
        $script:UxPhaseWarnings = @()
    }
}

function _Render-UxPhaseLine {
    param([Parameter(Mandatory)] [string]$Right)
    $left = '[{0}/{1}] {2}' -f $script:UxPhaseNum, $script:UxPhaseTotal, $script:UxPhaseTitle
    $padded = $left.PadRight($script:UxLeftWidth)
    $esc = [char]27
    # \r + ESC[2K (erase entire line) so we don't leave stale chars from a longer
    # previous render.
    Write-Host ("`r$esc[2K{0} {1}" -f $padded, $Right) -NoNewline
}

function Write-UxWarn {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Message,
        [string]$LogRange = ''
    )
    $script:UxWarnCount++
    _Emit-UxSubline -Color $script:UxColors.Yellow -Glyph '⚠' -Message $Message -LogRange $LogRange
}

function Write-UxError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Message,
        [string]$LogRange = ''
    )
    $script:UxErrorCount++
    _Emit-UxSubline -Color $script:UxColors.Red -Glyph '✖' -Message $Message -LogRange $LogRange
}

function _Emit-UxSubline {
    param(
        [AllowEmptyString()] [string]$Color = '',
        [AllowEmptyString()] [string]$Glyph = '',
        [Parameter(Mandatory)] [string]$Message,
        [string]$LogRange = ''
    )
    $c = $script:UxColors

    # Construir el bloque (1-2 líneas) y, si hay fase abierta, encolarlo
    # para que Complete-UxPhase lo emita después del finalizer (evita el
    # stranded-line bug en TTY mode).
    $block = '      {0}{1}{2}  {3}' -f $Color, $Glyph, $c.Reset, $Message
    if ($LogRange -and $script:UxLogFile) {
        $block += "`n" + ('         {0}Detalles: {1}:{2}{3}' -f $c.Dim, $script:UxLogFile, $LogRange, $c.Reset)
    }

    if ($script:UxPhaseOpen) {
        $script:UxPhaseWarnings += $block
    } else {
        Write-Host $block
    }
}

# Run a script block, capturing stdout/stderr to the log file. Returns the
# captured log line range (e.g. "142-168") on stdout, or empty if no output.
# The wrapped command's exit code is preserved in $LASTEXITCODE.
#
# In verbose mode (or when no log file is open), runs the script block directly
# with no capture.
#
# Usage:
#   $range = Invoke-UxCapture -ScriptBlock { scoop install fzf }
#   if ($LASTEXITCODE -ne 0) { Write-UxWarn "fzf falló" -LogRange $range }
function Invoke-UxCapture {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [scriptblock]$ScriptBlock
    )

    if (-not $script:UxLogFile -or $script:UxVerbose) {
        & $ScriptBlock
        return ''
    }

    $before = (Get-Content -Path $script:UxLogFile -ErrorAction SilentlyContinue | Measure-Object -Line).Lines
    Add-Content -Path $script:UxLogFile -Value ("--- {0} {1} ---" -f (Get-Date -Format 'HH:mm:ss'), $ScriptBlock.ToString().Trim()) -ErrorAction SilentlyContinue

    # Capture both streams: 2>&1 merges stderr into success stream; *> redirects everything.
    & $ScriptBlock *>> $script:UxLogFile

    $after = (Get-Content -Path $script:UxLogFile -ErrorAction SilentlyContinue | Measure-Object -Line).Lines

    if ($after -gt $before) {
        return ('{0}-{1}' -f ($before + 1), $after)
    }
    return ''
}

# Internal: pick OK/WARN/FAIL status, finalize phase, and return the phase
# exit code: 0=ok, 1=warn (some failed but some ok), 2=fail.
function _Finalize-UxPhase {
    param([int]$Ok, [int]$Fail)
    if ($Fail -eq 0) {
        Complete-UxPhase -Status ok -Details "$Ok ok"
        return 0
    }
    elseif ($Ok -eq 0) {
        $w = if ($Fail -eq 1) { 'fallido' } else { 'fallidos' }
        Complete-UxPhase -Status fail -Details "$Fail $w"
        return 2
    }
    else {
        $w = if ($Fail -eq 1) { 'fallido' } else { 'fallidos' }
        Complete-UxPhase -Status warn -Details "$Ok ok, $Fail $w"
        return 1
    }
}

# ===================================================================
# Phase runner — drive a phase from a list of items + an install scriptblock.
# ===================================================================
#
# The install script block receives one item and must return $true (success)
# or $false (failure). Failures are tallied; the runner does NOT call
# Write-UxWarn (the install block or the method handler does, with the right
# log range).
#
# Usage:
#   $tools = $allTools | Where-Object { ... }
#   Invoke-PhaseItems -Num $PHASE_NUM -Total $PHASE_TOTAL `
#       -Title 'Herramientas de productividad' `
#       -Items $tools `
#       -InstallScript { param($t) Install-Tool -ToolName $t.name -ToolsRegistry $allTools }
# Internal: extract a friendly label from a JSON item. Tries .name (tools.json),
# .file (dotfiles), .binary (gitfiles); falls back to ToString().
function _Get-UxItemLabel {
    param($Item)
    if (-not $Item) { return '' }

    $candidates = @('name', 'file', 'binary', 'package')
    foreach ($prop in $candidates) {
        if ($Item -is [hashtable]) {
            if ($Item.ContainsKey($prop) -and $Item[$prop]) {
                return [string]$Item[$prop]
            }
        }
        elseif ($Item.PSObject -and $Item.PSObject.Properties.Match($prop).Count -gt 0) {
            $v = $Item.$prop
            if ($v) { return [string]$v }
        }
    }
    return [string]$Item
}

function Invoke-PhaseItems {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [int]$Num,
        [Parameter(Mandatory)] [int]$Total,
        [Parameter(Mandatory)] [string]$Title,
        [AllowEmptyCollection()] [object[]]$Items = @(),
        [Parameter(Mandatory)] [scriptblock]$InstallScript
    )

    Start-UxPhase -Num $Num -Total $Total -Title $Title

    $count = $Items.Count
    if ($count -eq 0) {
        Complete-UxPhase -Status ok -Details 'nada que instalar'
        return 0
    }

    $ok = 0; $fail = 0
    for ($i = 0; $i -lt $count; $i++) {
        $item = $Items[$i]
        $label = _Get-UxItemLabel $item
        Write-UxProgress -Current ($i + 1) -Total $count -Item $label

        if (& $InstallScript $item) { $ok++ } else { $fail++ }
    }

    _Finalize-UxPhase -Ok $ok -Fail $fail
}

# Final summary block. Counters can be passed explicitly (bootstrap does this
# to aggregate across child-scope phases). With no args, falls back to internal
# per-process counters.
function Show-UxSummary {
    [CmdletBinding()]
    param(
        [int]$PhasesOk   = -1,
        [int]$PhasesWarn = -1,
        [int]$PhasesFail = -1
    )

    if ($PhasesOk   -lt 0) { $PhasesOk   = $script:UxPhasesOk }
    if ($PhasesWarn -lt 0) { $PhasesWarn = $script:UxPhasesWarn }
    if ($PhasesFail -lt 0) { $PhasesFail = $script:UxPhasesFail }
    $phasesTotal = $PhasesOk + $PhasesWarn + $PhasesFail

    $elapsed = [int]([datetime]::Now - $script:UxRunStart).TotalSeconds
    $c = $script:UxColors

    Write-Host ''
    Write-Host ("{0}─────────────────────────────────────────────{1}" -f $c.Dim, $c.Reset)

    if ($PhasesFail -gt 0) {
        Write-Host ("{0}Instalación con errores{1} · {2}s · {3}/{4} fases OK" -f `
            $c.Red, $c.Reset, $elapsed, $PhasesOk, $phasesTotal)
    }
    elseif ($PhasesWarn -gt 0) {
        Write-Host ("{0}Instalación completada con avisos{1} · {2}s · {3}/{4} fases con avisos" -f `
            $c.Yellow, $c.Reset, $elapsed, $PhasesWarn, $phasesTotal)
    }
    else {
        Write-Host ("{0}Instalación completada{1} · {2}s" -f $c.Green, $c.Reset, $elapsed)
    }

    if ($script:UxLogFile -and ($PhasesWarn + $PhasesFail) -gt 0) {
        Write-Host ("{0}Log: {1}{2}" -f $c.Dim, $script:UxLogFile, $c.Reset)
    }

    # Aviso de Personalización de WezTerm — sólo cuando WezTerm forma parte
    # del perfil instalado (dev/full) y no hubo errores duros. El usuario debe
    # abrir el dotfile y revisar la sección §0 para los knobs ajustables.
    $profile = if ($env:DEVCLI_PROFILE) { $env:DEVCLI_PROFILE } else { 'full' }
    if (($PhasesFail -eq 0) -and ($profile -eq 'dev' -or $profile -eq 'full')) {
        Write-Host ''
        Write-Host ("{0}WezTerm:{1} abre {2}~/.config/wezterm/wezterm.lua{3} y revisa" -f `
            $c.Bold, $c.Reset, $c.Dim, $c.Reset)
        Write-Host ("la sección {0}§0 Personalización{1} para los knobs de AI Mode" -f `
            $c.Bold, $c.Reset)
        Write-Host ("(p.ej. {0}CLAUDE_EXTRA_ARGS{1} — viene con" -f $c.Dim, $c.Reset)
        Write-Host ("{0}--allow-dangerously-skip-permissions{1} activado por defecto)." -f `
            $c.Dim, $c.Reset)
    }
}