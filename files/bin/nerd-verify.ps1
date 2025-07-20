#Requires -Version 5.1
# Script completo de verificación de Nerd Fonts para Windows
# Uso: nerd-verify.ps1

[CmdletBinding()]
param()

# Configuración de Nerd Fonts
$NERD_FONT_NAME = "FiraCode"
$NERD_FONT_FULL_NAME = "FiraCode Nerd Font"

Write-Host "=== Verificación Completa de Nerd Fonts en Windows ===" -ForegroundColor Cyan
Write-Host ""

# Función para detectar sistema operativo
function Get-OSInfo {
    $version = [System.Environment]::OSVersion.Version
    $isWindows11 = $version.Build -ge 22000
    
    return @{
        OS = "Windows"
        Version = $version
        IsWindows11 = $isWindows11
        Build = $version.Build
    }
}

# Función para detectar terminal
function Get-Terminal {
    if ($env:WT_SESSION) {
        return "Windows Terminal"
    }
    elseif ($env:TERM_PROGRAM -eq "vscode") {
        return "Visual Studio Code"
    }
    elseif ($Host.Name -eq "ConsoleHost") {
        return "PowerShell Console"
    }
    elseif ($Host.Name -eq "PowerShell ISE Host") {
        return "PowerShell ISE"
    }
    else {
        return "Desconocido ($($Host.Name))"
    }
}

# Función para verificar fuentes instaladas
function Test-FontsInstallation {
    Write-Host "🔍 Verificando instalación de fuentes..." -ForegroundColor Yellow
    
    $fontsFound = @()
    $issues = @()
    
    # Directorios de fuentes
    $userFontsDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
    $systemFontsDir = "$env:WINDIR\Fonts"
    
    # Verificar fuentes de usuario
    if (Test-Path $userFontsDir) {
        $userFonts = Get-ChildItem -Path $userFontsDir -Filter "*FiraCode*" -ErrorAction SilentlyContinue
        if ($userFonts.Count -gt 0) {
            $fontsFound += "Usuario: $($userFonts.Count) archivos"
            foreach ($font in $userFonts) {
                Write-Host "  ✓ $($font.Name)" -ForegroundColor Green
            }
        }
    }
    
    # Verificar fuentes del sistema
    if (Test-Path $systemFontsDir) {
        $systemFonts = Get-ChildItem -Path $systemFontsDir -Filter "*FiraCode*" -ErrorAction SilentlyContinue
        if ($systemFonts.Count -gt 0) {
            $fontsFound += "Sistema: $($systemFonts.Count) archivos"
            foreach ($font in $systemFonts) {
                Write-Host "  ✓ $($font.Name)" -ForegroundColor Green
            }
        }
    }
    
    if ($fontsFound.Count -eq 0) {
        Write-Host "  ❌ No se encontraron fuentes FiraCode" -ForegroundColor Red
        $issues += "Fuentes no instaladas"
        return @{ Success = $false; Issues = $issues }
    }
    
    Write-Host "  ✓ Fuentes encontradas: $($fontsFound -join ', ')" -ForegroundColor Green
    return @{ Success = $true; Issues = @() }
}

# Función para verificar configuración de Windows Terminal
function Test-WindowsTerminalConfig {
    Write-Host "🔧 Verificando configuración de Windows Terminal..." -ForegroundColor Yellow
    
    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    
    if (-not (Test-Path $settingsPath)) {
        Write-Host "  ⚠️ Windows Terminal no encontrado o no configurado" -ForegroundColor Yellow
        return @{ Success = $false; Issues = @("Windows Terminal no configurado") }
    }
    
    try {
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
        
        $configured = $false
        $issues = @()
        
        # Verificar configuración en defaults
        if ($settings.profiles.defaults.font.face -eq $NERD_FONT_FULL_NAME) {
            Write-Host "  ✓ Fuente configurada en perfil por defecto" -ForegroundColor Green
            $configured = $true
        }
        
        # Verificar configuración en perfiles específicos
        if ($settings.profiles.list) {
            foreach ($profile in $settings.profiles.list) {
                if ($profile.font.face -eq $NERD_FONT_FULL_NAME) {
                    Write-Host "  ✓ Fuente configurada en perfil: $($profile.name)" -ForegroundColor Green
                    $configured = $true
                }
            }
        }
        
        if (-not $configured) {
            Write-Host "  ❌ Fuente no configurada en Windows Terminal" -ForegroundColor Red
            $issues += "Windows Terminal no configurado"
        }
        
        return @{ Success = $configured; Issues = $issues }
    }
    catch {
        Write-Host "  ❌ Error leyendo configuración: $_" -ForegroundColor Red
        return @{ Success = $false; Issues = @("Error leyendo configuración de Windows Terminal") }
    }
}

# Función para verificar configuración de Visual Studio Code
function Test-VSCodeConfig {
    Write-Host "🔧 Verificando configuración de Visual Studio Code..." -ForegroundColor Yellow
    
    $settingsPath = "$env:APPDATA\Code\User\settings.json"
    
    if (-not (Test-Path $settingsPath)) {
        Write-Host "  ⚠️ Visual Studio Code no encontrado o no configurado" -ForegroundColor Yellow
        return @{ Success = $false; Issues = @("VS Code no configurado") }
    }
    
    try {
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
        
        $fontFamily = $settings."terminal.integrated.fontFamily"
        
        if ($fontFamily -and ($fontFamily -like "*$NERD_FONT_FULL_NAME*")) {
            Write-Host "  ✓ Fuente configurada: $fontFamily" -ForegroundColor Green
            return @{ Success = $true; Issues = @() }
        }
        else {
            Write-Host "  ❌ Fuente no configurada en VS Code" -ForegroundColor Red
            return @{ Success = $false; Issues = @("VS Code no configurado") }
        }
    }
    catch {
        Write-Host "  ❌ Error leyendo configuración: $_" -ForegroundColor Red
        return @{ Success = $false; Issues = @("Error leyendo configuración de VS Code") }
    }
}

# Función para mostrar información del sistema
function Show-SystemInfo {
    $osInfo = Get-OSInfo
    $terminal = Get-Terminal
    
    Write-Host "📋 Información del Sistema:" -ForegroundColor Cyan
    Write-Host "  OS: $($osInfo.OS) $($osInfo.Version)" -ForegroundColor White
    Write-Host "  Build: $($osInfo.Build) $(if ($osInfo.IsWindows11) { '(Windows 11)' } else { '(Windows 10)' })" -ForegroundColor White
    Write-Host "  Terminal: $terminal" -ForegroundColor White
    Write-Host "  PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor White
    Write-Host ""
}

# Función para mostrar iconos de prueba
function Show-TestIcons {
    Write-Host "🎨 Prueba de Iconos:" -ForegroundColor Cyan
    
    $icons = @(
        @{ Name = "Carpeta"; Icon = "📁" },
        @{ Name = "Archivo"; Icon = "📄" },
        @{ Name = "Git"; Icon = "🔀" },
        @{ Name = "PowerShell"; Icon = "⚡" },
        @{ Name = "Windows"; Icon = "🪟" },
        @{ Name = "Nerd Font"; Icon = "" }
    )
    
    foreach ($icon in $icons) {
        Write-Host "  $($icon.Icon) $($icon.Name)" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "💡 Si ves cuadros o espacios en blanco, las fuentes no están funcionando correctamente" -ForegroundColor Yellow
    Write-Host ""
}

# Función para mostrar directorios de fuentes
function Show-FontDirectories {
    Write-Host "📂 Directorios de Fuentes:" -ForegroundColor Cyan
    
    $directories = @(
        @{ Name = "Usuario"; Path = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts" },
        @{ Name = "Sistema"; Path = "$env:WINDIR\Fonts" }
    )
    
    foreach ($dir in $directories) {
        if (Test-Path $dir.Path) {
            $fontCount = (Get-ChildItem -Path $dir.Path -Filter "*.ttf" -ErrorAction SilentlyContinue).Count
            Write-Host "  $($dir.Name): $($dir.Path) ($fontCount TTF)" -ForegroundColor White
        }
        else {
            Write-Host "  $($dir.Name): $($dir.Path) (No existe)" -ForegroundColor Red
        }
    }
    Write-Host ""
}

# Función para mostrar recomendaciones
function Show-Recommendations {
    param(
        [bool]$FontsInstalled,
        [array]$AllIssues
    )
    
    Write-Host "💡 Recomendaciones:" -ForegroundColor Cyan
    
    if (-not $FontsInstalled) {
        Write-Host "  🔧 Instalar fuentes:" -ForegroundColor Yellow
        Write-Host "    • Ejecuta: .\02-packages.ps1" -ForegroundColor White
        Write-Host "    • O instala manualmente desde: https://github.com/ryanoasis/nerd-fonts" -ForegroundColor White
    }
    
    if ($AllIssues -contains "Windows Terminal no configurado") {
        Write-Host "  🔧 Configurar Windows Terminal:" -ForegroundColor Yellow
        Write-Host "    • Ejecuta: .\nerd-setup.ps1 windows-terminal" -ForegroundColor White
    }
    
    if ($AllIssues -contains "VS Code no configurado") {
        Write-Host "  🔧 Configurar Visual Studio Code:" -ForegroundColor Yellow
        Write-Host "    • Ejecuta: .\nerd-setup.ps1 vscode" -ForegroundColor White
    }
    
    Write-Host "  🔧 Configuración automática:" -ForegroundColor Yellow
    Write-Host "    • Ejecuta: .\nerd-setup.ps1 auto" -ForegroundColor White
    
    Write-Host ""
}

# Función principal
function main {
    Show-SystemInfo
    
    # Verificar fuentes
    $fontsResult = Test-FontsInstallation
    $fontsStatus = $fontsResult.Success
    
    Write-Host ""
    
    # Verificar configuración de terminales
    $terminalResults = @()
    $terminalResults += Test-WindowsTerminalConfig
    $terminalResults += Test-VSCodeConfig
    
    Write-Host ""
    
    # Mostrar información adicional
    Show-FontDirectories
    Show-TestIcons
    
    # Recopilar todos los problemas
    $allIssues = @()
    $allIssues += $fontsResult.Issues
    foreach ($result in $terminalResults) {
        $allIssues += $result.Issues
    }
    
    # Mostrar recomendaciones
    Show-Recommendations -FontsInstalled $fontsStatus -AllIssues $allIssues
    
    # Resumen final
    Write-Host "=== Resumen Final ===" -ForegroundColor Cyan
    
    if ($fontsStatus) {
        Write-Host "✓ Fuentes instaladas" -ForegroundColor Green
    }
    else {
        Write-Host "✗ Fuentes NO instaladas" -ForegroundColor Red
    }
    
    $configuredTerminals = ($terminalResults | Where-Object { $_.Success }).Count
    $totalTerminals = $terminalResults.Count
    
    Write-Host "✓ Terminales configurados: $configuredTerminals/$totalTerminals" -ForegroundColor $(if ($configuredTerminals -gt 0) { "Green" } else { "Red" })
    
    if ($allIssues.Count -eq 0) {
        Write-Host ""
        Write-Host "🎉 ¡Todo está configurado correctamente!" -ForegroundColor Green
    }
    
    Write-Host ""
}

# Ejecutar función principal
main 