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