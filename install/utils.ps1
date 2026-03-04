# ------------------------------------------------------------------
# utils.ps1 - Funciones utilitarias compartidas para scripts de instalación PowerShell
# ------------------------------------------------------------------

# Función de log común
function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [string]$Level = "INFO",

        [string]$Prefix = $null
    )

    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "Cyan" }
    }

    # Detectar nombre del script de manera más robusta
    if ($Prefix) {
        $logPrefix = $Prefix
    } else {
        # Intentar obtener el nombre desde el call stack
        $callStack = Get-PSCallStack
        $scriptPath = $null
        
        # Buscar el primer archivo .ps1 en el call stack que no sea utils.ps1
        foreach ($frame in $callStack) {
            if ($frame.ScriptName -and $frame.ScriptName -like "*.ps1" -and $frame.ScriptName -notlike "*utils.ps1") {
                $scriptPath = $frame.ScriptName
                break
            }
        }
        
        if ($scriptPath) {
            $scriptName = Split-Path $scriptPath -Leaf
            $logPrefix = $scriptName -replace '\.ps1$', ''
        } else {
            $logPrefix = "unknown"
        }
    }

    Write-Host "[$logPrefix] $Message" -ForegroundColor $color
}

# Funciones para manejo robusto de directorios
function Restore-OriginalDirectory {
    if ($Global:ShouldRestoreDirectory -and $Global:OriginalDirectory) {
        try {
            Set-Location $Global:OriginalDirectory -ErrorAction SilentlyContinue
            Write-Log "Directorio restaurado: $Global:OriginalDirectory"
        }
        catch {
            Write-Warning "No se pudo restaurar el directorio original: $Global:OriginalDirectory"
        }
    }
}

function Handle-ScriptInterruption {
    Write-Host "`n❌ Script interrumpido por el usuario" -ForegroundColor Red
    Restore-OriginalDirectory
    exit 130
}

function Setup-ScriptInterruptionHandler {
    try {
        # Solo CancelKeyPress - suficiente para scripts hijos
        $null = Register-ObjectEvent -InputObject ([Console]) -EventName CancelKeyPress -Action {
            $Event.Args[1].Cancel = $true
            Handle-ScriptInterruption
        }
    }
    catch {
        Write-Warning "No se pudo configurar el manejador de interrupciones: $_"
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

# Función para verificar si un paquete winget está instalado
function Test-WingetPackage {
    param(
        [Parameter(Mandatory)]
        [string]$PackageId
    )

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

# Función de diagnóstico para scoop
function Test-ScoopDiagnostic {
    Write-Log "=== Diagnóstico de Scoop ===" "INFO"

    # Verificar comando scoop
    $scoopCmd = Get-Command "scoop" -ErrorAction SilentlyContinue
    if ($scoopCmd) {
        Write-Log "✅ Comando scoop encontrado en: $($scoopCmd.Source)" "SUCCESS"
    }
    else {
        Write-Log "❌ Comando scoop no encontrado" "ERROR"
        return
    }

    # Verificar versión
    try {
        $version = & scoop --version *>$null 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "✅ Scoop funciona correctamente" "SUCCESS"
        }
        else {
            Write-Log "❌ Error ejecutando scoop --version" "ERROR"
        }
    }
    catch {
        Write-Log "❌ Excepción obteniendo versión: $($_.Exception.Message)" "ERROR"
    }

    # Verificar directorio de scoop
    $scoopDir = "$env:USERPROFILE\scoop"
    if (Test-Path $scoopDir) {
        Write-Log "✅ Directorio scoop encontrado: $scoopDir" "SUCCESS"
    }
    else {
        Write-Log "❌ Directorio scoop no encontrado: $scoopDir" "ERROR"
    }
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
        [string]$PackageName,

        [string]$Description = ""
    )

    if (-not (Test-Scoop)) {
        Write-Log "Scoop no está disponible" "ERROR"
        return $false
    }

    if (Test-ScoopPackage $PackageName) {
        Write-Log "$PackageName ya está instalado (scoop)"
        return $true
    }

    $displayName = $Description ? "$PackageName ($Description)" : $PackageName
    Write-Log "Instalando $displayName con scoop..."

            try {
        # Ejecutar scoop silenciosamente (sin opciones que no existen)
        $result = & scoop install $PackageName --no-update-scoop *>$null 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Log "$PackageName instalado correctamente con scoop" "SUCCESS"
            return $true
        }
        else {
            Write-Log "Error instalando $PackageName con scoop (código: $LASTEXITCODE)" "WARNING"
            Write-Log "Salida: $result" "WARNING"
            return $false
        }
    }
    catch {
        Write-Log "Excepción instalando $PackageName con scoop: $($_.Exception.Message)" "WARNING"
        return $false
    }
}

# Función para instalar scoop
function Install-Scoop {
    if (Test-Scoop) {
        Write-Log "Scoop ya está instalado"
        return $true
    }

    Write-Log "Instalando Scoop..."

    try {
        # Configurar política de ejecución si es necesario
        $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
        if ($currentPolicy -eq "Restricted") {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Write-Log "Política de ejecución actualizada a RemoteSigned para el usuario actual"
        }

                        # Instalar scoop silenciosamente
        $installScript = Invoke-RestMethod -Uri https://get.scoop.sh
        $null = Invoke-Expression $installScript *>$null 2>$null

        # Refrescar PATH después de la instalación
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::Machine) + ";" + [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User)

        # Esperar un momento para que se complete la instalación
        Start-Sleep -Seconds 3

        # Verificar instalación
        if (Test-Scoop) {
            Write-Log "✅ Scoop instalado correctamente" "SUCCESS"
            return $true
        }
        else {
            Write-Log "Error: Scoop no se instaló correctamente" "ERROR"
            Write-Log "Intenta reiniciar PowerShell y ejecutar de nuevo" "WARNING"
            return $false
        }
    }
    catch {
        Write-Log "Error instalando Scoop: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Función para instalar paquete con winget
function Install-WingetPackage {
    param(
        [Parameter(Mandatory)]
        [string]$PackageId,

        [string]$Name = $PackageId,

        [string]$Description = ""
    )

    if (Test-WingetPackage $PackageId) {
        Write-Log "$Name ya está instalado, omitiendo instalación"
        return $true
    }

    $displayName = $Description ? "$Name ($Description)" : $Name
    Write-Log "Instalando $displayName..."

    try {
        # Usar Start-Process para mejor control en PowerShell 7
        $process = Start-Process -FilePath "winget" -ArgumentList @("install", $PackageId, "--silent", "--accept-package-agreements", "--accept-source-agreements") -Wait -PassThru -NoNewWindow

        if ($process.ExitCode -eq 0) {
            Write-Log "$Name instalado correctamente" "SUCCESS"
            return $true
        }
        else {
            Write-Log "Error instalando $Name (código: $($process.ExitCode))" "WARNING"
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

# Scaffold para ejecutar fases con manejo robusto de errores e interrupciones.
# Elimina el boilerplate main/trap/try/finally/catch repetido en cada script de fase.
function Run-Phase {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Logic
    )

    function _phase_main {
        trap {
            Write-Log "🛑 Excepción no manejada: $($_.Exception.Message)" "ERROR"
            Restore-OriginalDirectory
            exit 1
        }

        Setup-ScriptInterruptionHandler

        try {
            & $Logic
            $Global:ShouldRestoreDirectory = $false
        }
        finally {
            if ($Global:ShouldRestoreDirectory) {
                Restore-OriginalDirectory
            }
        }
    }

    try {
        _phase_main
    }
    catch {
        Write-Error "❌ Error crítico en script: $($_.Exception.Message)"
        Restore-OriginalDirectory
        exit 1
    }
}

# ------------------------------------------------------------------
# Method Dispatchers — catalog-driven tool installation from tools.json
# ------------------------------------------------------------------

# --- Method: scoop (wraps Install-ScoopPackage) ---
function Install-MethodScoop {
    param([Parameter(Mandatory)][hashtable]$Block)
    $package = $Block["package"]
    return Install-ScoopPackage -PackageName $package
}

# --- Method: scoop-bucket (add bucket + install) ---
function Install-MethodScoopBucket {
    param([Parameter(Mandatory)][hashtable]$Block)

    try {
        if (-not (Test-Scoop)) {
            Write-Log "Scoop no está disponible para instalar" "WARNING"
            return $true  # Non-critical
        }

        $bucketName = $Block["bucket_name"]
        $bucketUrl = $Block["bucket_url"]
        $package = $Block["package"]

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

# Función para verificar dependencias comunes
function Test-Dependencies {
    param(
        [string[]]$RequiredCommands = @("jq", "git")
    )

    $missing = @()
    foreach ($cmd in $RequiredCommands) {
        if (-not (Test-Command $cmd)) {
            $missing += $cmd
        }
    }

    if ($missing.Count -gt 0) {
        Write-Log "Dependencias faltantes: $($missing -join ', ')" "ERROR"
        return $false
    }

    return $true
}

# Función para refrescar PATH de la sesión actual
function Update-SessionPath {
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::Machine) + ";" + [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User)
    Write-Log "PATH de sesión actualizado"
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
            Write-Log "Directorio ya está en PATH: $NewPath"
        }
    }
    catch {
        Write-Log "Error actualizando PATH: $($_.Exception.Message)" "ERROR"
    }
}