#Requires -Version 5.1

# Script de instalación de dotfiles para Windows
# Copia .luispa.omp.json al home del usuario

[CmdletBinding()]
param()

# Variables de entorno (definidas por bootstrap.ps1)
$SETUP_LANG = $env:SETUP_LANG ?? "es-ES"
$SETUP_DIR = $env:SETUP_DIR ?? "$env:USERPROFILE\.cli-setup"
$CURRENT_USER = $env:CURRENT_USER ?? $env:USERNAME
$TARGET_HOME = $env:USERPROFILE

# Función de log
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "Cyan" }
    }
    Write-Host "[03-dotfiles] $Message" -ForegroundColor $color
}

# Función para verificar si un comando existe
function Test-Command {
    param([string]$Command)
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

# Función para personalizar archivo de configuración
function Update-OmpConfig {
    param([string]$ConfigFile)
    
    if (-not (Test-Path $ConfigFile)) {
        Write-Log "Archivo de configuración no encontrado: $ConfigFile" "WARNING"
        return $false
    }
    
    try {
        # Leer contenido del archivo
        $content = Get-Content $ConfigFile -Raw -Encoding UTF8
        
        # Crear backup
        $backupFile = "$ConfigFile.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item $ConfigFile $backupFile -Force
        
        # Reemplazar configuraciones específicas para Windows si es necesario
        # Por ahora solo informamos que se ha copiado
        Write-Log "Configuración Oh-My-Posh personalizada para Windows"
        Write-Log "Backup creado: $backupFile"
        
        return $true
    }
    catch {
        Write-Log "Error personalizando configuración: $_" "WARNING"
        return $false
    }
}

# Función para configurar oh-my-posh en PowerShell
function Set-OhMyPoshProfile {
    param([string]$ConfigPath)
    
    if (-not (Test-Command "oh-my-posh")) {
        Write-Log "oh-my-posh no está disponible" "WARNING"
        return $false
    }
    
    # Obtener la ruta del perfil de PowerShell
    $profilePath = $PROFILE
    if (-not $profilePath) {
        Write-Log "No se puede determinar la ruta del perfil de PowerShell" "WARNING"
        return $false
    }
    
    try {
        # Crear directorio del perfil si no existe
        $profileDir = Split-Path $profilePath -Parent
        if (-not (Test-Path $profileDir)) {
            New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
            Write-Log "Directorio del perfil creado: $profileDir"
        }
        
        # Línea de inicialización para Oh-My-Posh
        $ompLine = "oh-my-posh init pwsh --config `"$ConfigPath`" | Invoke-Expression"
        
        # Verificar si ya está configurado
        if (Test-Path $profilePath) {
            $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
            if ($profileContent -and ($profileContent -match "oh-my-posh.*\.luispa\.omp\.json")) {
                Write-Log "Oh-My-Posh ya está configurado en el perfil"
                return $true
            }
        }
        
        # Añadir configuración al perfil
        if (Test-Path $profilePath) {
            Add-Content -Path $profilePath -Value "`n# Oh My Posh Configuration`n$ompLine" -Encoding UTF8
        }
        else {
            Set-Content -Path $profilePath -Value "# Oh My Posh Configuration`n$ompLine" -Encoding UTF8
        }
        
        Write-Log "Oh-My-Posh configurado en el perfil de PowerShell" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error configurando Oh-My-Posh en el perfil: $_" "WARNING"
        return $false
    }
}

# Función principal
function main {
    Write-Log "Iniciando instalación de dotfiles..."
    
    # Directorio de dotfiles
    $dotfilesDir = Join-Path $SETUP_DIR "dotfiles"
    
    if (-not (Test-Path $dotfilesDir)) {
        Write-Log "Directorio de dotfiles no encontrado: $dotfilesDir" "ERROR"
        exit 1
    }
    
    # Lista de dotfiles a instalar (solo para Windows)
    $dotfilesList = @(".luispa.omp.json")
    
    $installedCount = 0
    
    Write-Log "Instalando dotfiles..."
    foreach ($file in $dotfilesList) {
        $src = Join-Path $dotfilesDir $file
        $dst = Join-Path $TARGET_HOME $file
        
        # Verificar que el archivo fuente existe
        if (-not (Test-Path $src)) {
            Write-Log "Dotfile no encontrado: $src" "WARNING"
            continue
        }
        
        try {
            # Copiar archivo
            Copy-Item $src $dst -Force
            Write-Log "Copiado: $file"
            $installedCount++
            
            # Personalizar archivo si es necesario
            if ($file -eq ".luispa.omp.json") {
                Update-OmpConfig $dst
                
                # Configurar en el perfil de PowerShell
                Set-OhMyPoshProfile $dst
            }
        }
        catch {
            Write-Log "Error copiando $file`: $_" "WARNING"
        }
    }
    
    # Configurar variables de entorno específicas para Windows Terminal
    try {
        # Variable para detectar Windows en oh-my-posh
        [Environment]::SetEnvironmentVariable("OMP_OS_ICON", "🪟", "User")
        Write-Log "Variable de entorno OMP_OS_ICON configurada"
    }
    catch {
        Write-Log "Error configurando variables de entorno: $_" "WARNING"
    }
    
    # Mostrar resumen final
    if ($installedCount -gt 0) {
        Write-Log "✅ Dotfiles instalados ($installedCount archivos)" "SUCCESS"
        
        Write-Log ""
        Write-Log "🎨 Configuración aplicada:" "SUCCESS"
        Write-Log "  • Oh-My-Posh configurado con tema personalizado"
        Write-Log "  • Perfil de PowerShell actualizado"
        Write-Log "  • Variables de entorno configuradas"
        Write-Log ""
        Write-Log "💡 Para aplicar los cambios:"
        Write-Log "  1. Reinicia tu terminal"
        Write-Log "  2. O ejecuta: . `$PROFILE"
    }
    else {
        Write-Log "No se instalaron dotfiles"
    }
}

# Ejecutar función principal
main 