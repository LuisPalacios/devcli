#Requires -Version 7.0

Write-Host "WiP packages"
exit 0

# Script de instalación de herramientas de productividad para Windows
# Lee configuración desde 02-packages-win.json

[CmdletBinding()]
param()

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
    Write-Host "[02-packages] $Message" -ForegroundColor $color
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
        [Console]::CancelKeyPress += {
            param($sender, $e)
            $e.Cancel = $true
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

# Función para verificar si jq está disponible
function Test-Jq {
    if (-not (Test-Command "jq")) {
        Write-Log "jq no está disponible. Debe instalarse primero en 01-system.ps1" "ERROR"
        return $false
    }
    return $true
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

# Función para leer paquetes desde JSON
function Get-PackagesFromJson {
    param(
        [Parameter(Mandatory)]
        [ValidateScript({Test-Path $_})]
        [string]$JsonPath
    )

    try {
        $config = Get-Content $JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable

        if (-not $config.packages) {
            Write-Log "No se encontró sección 'packages' en el JSON" "WARNING"
            return @()
        }

        return $config.packages
    }
    catch {
        Write-Log "Error leyendo configuración JSON: $($_.Exception.Message)" "ERROR"
        return @()
    }
}

# Función para instalar Nerd Fonts
function Install-NerdFonts {
    Write-Log "Instalando FiraCode Nerd Font..."

    try {
        $fontsDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
        if (-not (Test-Path $fontsDir)) {
            New-Item -Path $fontsDir -ItemType Directory -Force | Out-Null
        }

        $fontUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
        $tempZip = "$env:TEMP\FiraCode.zip"
        $tempDir = "$env:TEMP\FiraCode-NerdFont"

        Write-Log "Descargando FiraCode Nerd Font..."
        Invoke-WebRequest -Uri $fontUrl -OutFile $tempZip -UseBasicParsing

        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force
        }
        Expand-Archive -Path $tempZip -DestinationPath $tempDir -Force

        $fontFiles = Get-ChildItem "$tempDir\*.ttf" -ErrorAction SilentlyContinue
        $installedFonts = 0

        foreach ($fontFile in $fontFiles) {
            $destPath = Join-Path $fontsDir $fontFile.Name
            if (-not (Test-Path $destPath)) {
                Copy-Item $fontFile.FullName $destPath -Force
                $installedFonts++
            }
        }

        Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue

        if ($installedFonts -gt 0) {
            Write-Log "FiraCode Nerd Font instalada ($installedFonts archivos)" "SUCCESS"
            Write-Log "Reinicia tu terminal y configura la fuente 'FiraCode NF'" "SUCCESS"
        }
        else {
            Write-Log "FiraCode Nerd Font ya estaba instalada"
        }

        return $true
    }
    catch {
        Write-Log "Error instalando Nerd Fonts: $_" "WARNING"
        return $false
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
        Write-Log "Iniciando instalación de herramientas de productividad..."
        Write-Log "Directorio original: $script:OriginalDirectory"

        if (-not (Test-Jq)) {
            Write-Log "Abortando: jq es requerido para procesar la configuración" "ERROR"
            exit 1
        }

        $packagesConfig = Join-Path (Split-Path $PSScriptRoot -Parent) "install\02-packages-win.json"
        $packages = Get-PackagesFromJson $packagesConfig

        if ($packages.Count -eq 0) {
            Write-Log "No hay paquetes para instalar"
            return
        }

        $installedCount = 0
        $failedCount = 0

        Write-Log "Instalando herramientas de productividad..."
        foreach ($package in $packages) {
            if ($package.id -and $package.name) {
                if (Install-WingetPackage -PackageId $package.id -Name $package.name -Description $package.description) {
                    $installedCount++
                }
                else {
                    $failedCount++
                }
            }
            else {
                Write-Log "Paquete con configuración incompleta omitido" "WARNING"
                $failedCount++
            }
        }

        $hasLsd = $packages | Where-Object { $_.id -eq "lsd-rs.lsd" }
        if ($hasLsd) {
            Install-NerdFonts | Out-Null
        }

        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")

        $aliasesCreated = 0

        if ((Test-Command "btm") -and (-not (Test-Command "htop"))) {
            try {
                $aliasScript = @"
@echo off
btm %*
"@
                $htopPath = Join-Path $BIN_DIR "htop.cmd"
                Set-Content -Path $htopPath -Value $aliasScript -Encoding ASCII
                Write-Log "Alias htop -> btm creado"
                $aliasesCreated++
            }
            catch {
                Write-Log "Error creando alias htop: $_" "WARNING"
            }
        }

        if ($installedCount -gt 0) {
            Write-Log "✅ Herramientas de productividad instaladas ($installedCount paquetes)" "SUCCESS"
            if ($failedCount -gt 0) {
                Write-Log "$failedCount paquetes fallaron en la instalación" "WARNING"
            }
            if ($aliasesCreated -gt 0) {
                Write-Log "$aliasesCreated aliases creados"
            }
        }
        else {
            Write-Log "No se instalaron nuevos paquetes"
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
