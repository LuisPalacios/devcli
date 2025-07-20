#Requires -Version 7.0

# Script de configuración base del sistema para Windows
# Instala herramientas esenciales: jq, git, oh-my-posh

[CmdletBinding()]
param()

Write-Host "WiP system"
exit 0

# Variables de entorno (definidas por bootstrap.ps1)
$SETUP_LANG = $env:SETUP_LANG ?? "es-ES"
$SETUP_DIR = $env:SETUP_DIR ?? "$env:USERPROFILE\.devcli"
$CURRENT_USER = $env:CURRENT_USER ?? $env:USERNAME
$BIN_DIR = "$env:USERPROFILE\bin"

# Manejo de directorio original (heredado del bootstrap)
$script:OriginalDirectory = $env:ORIGINAL_DIRECTORY ?? $PWD.Path
$script:ShouldRestoreDirectory = $true

# Función de log
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "Cyan" }
    }
    Write-Host "[01-system] $Message" -ForegroundColor $color
}

# Funciones para manejo robusto de directorios
function Restore-OriginalDirectory {
    if ($script:ShouldRestoreDirectory -and $script:OriginalDirectory) {
        try {
            Set-Location $script:OriginalDirectory -ErrorAction SilentlyContinue
            Write-Log "Directorio restaurado: $script:OriginalDirectory"
        }
        catch {
            Write-Warning "No se pudo restaurar el directorio original: $script:OriginalDirectory"
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
    param([string]$Command)
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

# Función para verificar si un paquete winget está instalado
function Test-WingetPackage {
    param([string]$PackageId)
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

        [string]$Name = $PackageId
    )

    if (Test-WingetPackage $PackageId) {
        Write-Log "$Name ya está instalado, omitiendo instalación"
        return $true
    }

    Write-Log "Instalando $Name..."
    try {
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

# Función para crear directorio si no existe
function New-DirectoryIfNotExists {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        try {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
            Write-Log "Directorio creado: $Path"
        }
        catch {
            Write-Log "Error creando directorio $Path`: $_" "ERROR"
            return $false
        }
    }
    return $true
}

# Función para actualizar PATH del usuario
function Update-UserPath {
    param([string]$NewPath)

    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($currentPath -split ';' -notcontains $NewPath) {
        try {
            $newUserPath = "$currentPath;$NewPath"
            [Environment]::SetEnvironmentVariable("PATH", $newUserPath, "User")

            $env:PATH += ";$NewPath"

            Write-Log "PATH actualizado con: $NewPath" "SUCCESS"
        }
        catch {
            Write-Log "Error actualizando PATH: $_" "WARNING"
        }
    }
}

# Función principal
function main {
    trap {
        Write-Log "🛑 Excepción no manejada: $($_.Exception.Message)" "ERROR"
        Restore-OriginalDirectory
        exit 1
    }

    Setup-ScriptInterruptionHandler

    try {
        Write-Log "Iniciando configuración base del sistema..."
        Write-Log "Usuario: $CURRENT_USER | Idioma: $SETUP_LANG"
        Write-Log "Directorio original: $script:OriginalDirectory"

        if (-not (New-DirectoryIfNotExists $BIN_DIR)) {
            Write-Log "Error creando directorio de binarios" "ERROR"
            exit 1
        }

        Update-UserPath $BIN_DIR

        $essentialPackages = @(
            @{ Id = "jqlang.jq"; Name = "jq" },
            @{ Id = "Git.Git"; Name = "git" },
            @{ Id = "JanDeDobbeleer.OhMyPosh"; Name = "oh-my-posh" }
        )

        $installedCount = 0
        $failedCount = 0

        Write-Log "Instalando paquetes base..."
        foreach ($package in $essentialPackages) {
            if (Install-WingetPackage -PackageId $package.Id -Name $package.Name) {
                $installedCount++
            }
            else {
                $failedCount++
            }
        }

        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")

        $criticalTools = @("jq", "git", "oh-my-posh")
        $missingCritical = @()

        foreach ($tool in $criticalTools) {
            if (-not (Test-Command $tool)) {
                $missingCritical += $tool
            }
        }

        if ($missingCritical.Count -gt 0) {
            Write-Log "❌ Herramientas críticas no disponibles: $($missingCritical -join ', ')" "ERROR"
            Write-Log "Intenta ejecutar de nuevo después de reiniciar el terminal" "WARNING"
        }

        $profilePath = $PROFILE
        if ($profilePath -and (Test-Command oh-my-posh)) {
            try {
                $profileDir = Split-Path $profilePath -Parent
                if (-not (Test-Path $profileDir)) {
                    New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
                }

                $ompConfig = "$env:USERPROFILE\.luispa.omp.json"
                $ompLine = "oh-my-posh init pwsh --config `"$ompConfig`" | Invoke-Expression"

                if (Test-Path $profilePath) {
                    $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
                    if ($profileContent -notmatch "oh-my-posh.*\.luispa\.omp\.json") {
                        Add-Content -Path $profilePath -Value "`n# Oh My Posh`n$ompLine" -Encoding UTF8
                        Write-Log "Oh-My-Posh añadido al perfil de PowerShell" "SUCCESS"
                    }
                }
                else {
                    Set-Content -Path $profilePath -Value "# Oh My Posh`n$ompLine" -Encoding UTF8
                    Write-Log "Perfil de PowerShell creado con Oh-My-Posh" "SUCCESS"
                }
            }
            catch {
                Write-Log "Error configurando Oh-My-Posh en el perfil: $_" "WARNING"
            }
        }

        if ($installedCount -gt 0) {
            Write-Log "✅ Configuración base completada ($installedCount paquetes verificados)" "SUCCESS"
            if ($failedCount -gt 0) {
                Write-Log "$failedCount paquetes fallaron en la instalación" "WARNING"
            }
        }
        else {
            Write-Log "No se instalaron nuevos paquetes"
        }

        if ($missingCritical.Count -eq 0) {
            Write-Log "✅ Todas las herramientas críticas están disponibles" "SUCCESS"
        }

        $script:ShouldRestoreDirectory = $false
    }
    finally {
        if ($script:ShouldRestoreDirectory) {
            Restore-OriginalDirectory
        }
    }
}

try {
    main
}
catch {
    Write-Error "❌ Error crítico en script: $($_.Exception.Message)"
    Restore-OriginalDirectory
    exit 1
}
