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

    $logPrefix = $Prefix ?? (Split-Path $MyInvocation.PSCommandPath -Leaf)
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
    $scoopCmd = Get-Command "scoop" -ErrorAction SilentlyContinue
    if ($scoopCmd) {
        # Verificar que scoop funciona ejecutando un comando simple
        try {
            $null = & scoop --version 2>$null
            return $LASTEXITCODE -eq 0
        }
        catch {
            return $false
        }
    }
    return $false
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
        $version = & scoop --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "✅ Versión de scoop: $version" "SUCCESS"
        }
        else {
            Write-Log "❌ Error obteniendo versión: $version" "ERROR"
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

    if (-not (Test-Scoop)) {
        return $false
    }

        try {
        # Ejecutar scoop list con modo silencioso
        $result = & scoop list $PackageName --quiet 2>$null

        # Verificar si el paquete aparece en la lista
        if ($LASTEXITCODE -eq 0 -and $result) {
            return $result -match $PackageName
        }

        return $false
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
        # Ejecutar scoop con opciones silenciosas
        $result = & scoop install $PackageName --quiet --no-update-scoop 2>&1

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

        # Instalar scoop
        Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

        # Refrescar PATH después de la instalación
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::Machine) + ";" + [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User)

        # Esperar un momento para que se complete la instalación
        Start-Sleep -Seconds 2

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
        return $false
    }

    try {
        $currentUserPath = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User)

        if ($currentUserPath -notlike "*$NewPath*") {
            $newUserPath = if ($currentUserPath) { "$currentUserPath;$NewPath" } else { $NewPath }
            [System.Environment]::SetEnvironmentVariable("PATH", $newUserPath, [System.EnvironmentVariableTarget]::User)
            Write-Log "PATH de usuario actualizado: $NewPath" "SUCCESS"

            # También actualizar PATH de la sesión actual
            $env:PATH += ";$NewPath"
            return $true
        }
        else {
            Write-Log "Directorio ya está en PATH: $NewPath"
            return $true
        }
    }
    catch {
        Write-Log "Error actualizando PATH: $($_.Exception.Message)" "ERROR"
        return $false
    }
}