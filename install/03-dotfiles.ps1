#Requires -Version 7.0

# Script de instalación de dotfiles para Windows
# Lee configuración desde 03-dotfiles.json (filtrado por plataforma)

[CmdletBinding()]
param()

# Cargar variables y funciones comunes
. "$PSScriptRoot\env.ps1"
. "$PSScriptRoot\utils.ps1"

# Función para configurar Windows Terminal con cmd_aliases.cmd
function ConfigureWindowsTerminal {
    Write-Log "Configurando Windows Terminal para usar cmd_aliases.cmd..."

    try {
        # Rutas posibles del settings.json de Windows Terminal
        $possiblePaths = @(
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
        )

        $settingsPath = $null
        foreach ($path in $possiblePaths) {
            if (Test-Path $path) {
                $settingsPath = $path
                break
            }
        }

        if (-not $settingsPath) {
            Write-Log "No se encontró el archivo settings.json de Windows Terminal" "WARNING"
            Write-Log "⚠️  CONFIGURACIÓN MANUAL REQUERIDA:" "WARNING"
            Write-Log "   1. Abre Windows Terminal" "WARNING"
            Write-Log "   2. Ve a Configuración → Perfiles → CMD" "WARNING"
            Write-Log "   3. En 'Línea de comandos' cambia a:" "WARNING"
            Write-Log "      %SystemRoot%\System32\cmd.exe /k `"%USERPROFILE%\cmd_aliases.cmd`"" "WARNING"
            return $false
        }

        # Leer y parsear el JSON
        $settingsContent = Get-Content $settingsPath -Raw -Encoding UTF8
        $settings = ConvertFrom-Json $settingsContent

        if (-not $settings.profiles) {
            Write-Log "Estructura de settings.json no reconocida" "WARNING"
            return $false
        }

        # Buscar el perfil de CMD
        $cmdProfile = $null
        $cmdProfileIndex = -1

        # Buscar en profiles.list si existe, sino en profiles directamente
        $profilesList = if ($settings.profiles.list) { $settings.profiles.list } else { $settings.profiles }

        for ($i = 0; $i -lt $profilesList.Count; $i++) {
            $terminalProfile = $profilesList[$i]

            # Buscar perfil que use cmd.exe
            if ($terminalProfile.commandline -and $terminalProfile.commandline -match "cmd\.exe") {
                $cmdProfile = $terminalProfile
                $cmdProfileIndex = $i
                break
            }

            # Buscar por GUID estándar de CMD o por nombre
            if ($terminalProfile.guid -eq "{0caa0dad-35be-5f56-a8ff-afceeeaa6101}" -or
                $terminalProfile.name -match "(Command Prompt|CMD|cmd)") {
                $cmdProfile = $terminalProfile
                $cmdProfileIndex = $i
                break
            }
        }

        if (-not $cmdProfile) {
            Write-Log "No se encontró perfil de CMD en Windows Terminal" "WARNING"
            return $false
        }

        # Construir nueva línea de comandos
        $aliasesPath = Join-Path $env:USERPROFILE "cmd_aliases.cmd"
        $newCommandLine = "%SystemRoot%\System32\cmd.exe /k `"$aliasesPath`""

        # Verificar si ya está configurado
        if ($cmdProfile.commandline -and $cmdProfile.commandline -match "cmd_aliases\.cmd") {
            Write-Log "Windows Terminal ya está configurado para usar cmd_aliases.cmd"
            return $true
        }

        # Actualizar la línea de comandos
        $cmdProfile.commandline = $newCommandLine

        # Actualizar el perfil en la lista
        if ($settings.profiles.list) {
            $settings.profiles.list[$cmdProfileIndex] = $cmdProfile
        } else {
            $settings.profiles[$cmdProfileIndex] = $cmdProfile
        }

        # Guardar el archivo actualizado
        $updatedJson = ConvertTo-Json $settings -Depth 20 -Compress:$false
        Set-Content $settingsPath -Value $updatedJson -Encoding UTF8 -Force

        Write-Log "✅ Windows Terminal configurado para usar cmd_aliases.cmd" "SUCCESS"
        Write-Log "   Perfil CMD actualizado: $($cmdProfile.name)" "SUCCESS"
        Write-Log "   Nueva línea de comandos: $newCommandLine" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error configurando Windows Terminal: $($_.Exception.Message)" "WARNING"
        Write-Log "⚠️  CONFIGURACIÓN MANUAL REQUERIDA:" "WARNING"
        Write-Log "   1. Abre Windows Terminal → Configuración → Perfiles → CMD" "WARNING"
        Write-Log "   2. En 'Línea de comandos' cambia a:" "WARNING"
        Write-Log "      %SystemRoot%\System32\cmd.exe /k `"%USERPROFILE%\cmd_aliases.cmd`"" "WARNING"
        return $false
    }
}

Run-Phase {
    Write-Log "Iniciando instalación de dotfiles..."
    Write-Log "Usuario: $env:USERNAME | Idioma: $Global:LOCALE"
    Write-Log "Directorio original: $Global:OriginalDirectory"

    # Directorio de dotfiles
    $dotfilesDir = Join-Path $Global:SETUP_DIR "dotfiles"

    if (-not (Test-Path $dotfilesDir)) {
        Write-Log "Directorio de dotfiles no encontrado: $dotfilesDir" "ERROR"
        exit 1
    }

    # Archivo de configuración (compartido, con filtro por plataforma)
    $dotfilesConfig = Join-Path (Split-Path $PSScriptRoot -Parent) "install\03-dotfiles.json"

    # Leer dotfiles desde JSON usando función común
    $allDotfiles = Get-ConfigFromJson -JsonPath $dotfilesConfig -PropertyName "dotfiles"

    if (-not $allDotfiles -or $allDotfiles.Count -eq 0) {
        Write-Log "No hay dotfiles para instalar"
        return
    }

    # Filtrar por plataforma Windows
    $dotfiles = $allDotfiles | Where-Object {
        $_.platforms -contains "windows"
    }

    if ($dotfiles.Count -eq 0) {
        Write-Log "No hay dotfiles para Windows"
        return
    }

    $installedCount = 0
    $failedCount = 0

    Write-Log "Copiando dotfiles según configuración..."
    foreach ($dotfile in $dotfiles) {
        if (-not $dotfile.file) {
            Write-Log "Dotfile con configuración incompleta omitido" "WARNING"
            $failedCount++
            continue
        }

        $src = Join-Path $dotfilesDir $dotfile.file

        # Construir ruta de destino (dst es la ruta relativa a HOME incluyendo el nombre)
        if (-not $dotfile.dst) {
            Write-Log "Dotfile sin ruta destino especificada: $($dotfile.file)" "WARNING"
            $failedCount++
            continue
        }

        # Normalizar la ruta destino (forward slashes en JSON → separador nativo)
        $dstRelative = $dotfile.dst.Replace('/', [System.IO.Path]::DirectorySeparatorChar)

        # Construir ruta completa al archivo destino
        $dst = Join-Path $env:USERPROFILE $dstRelative

        # Extraer directorio padre para crear la estructura de directorios
        $dstDir = Split-Path $dst -Parent

        if (-not (Test-Path $src)) {
            Write-Log "Archivo fuente no encontrado: $src" "WARNING"
            $failedCount++
            continue
        }

        try {
            # Crear directorio de destino si no existe
            if (-not (Test-Path $dstDir)) {
                New-Item -Path $dstDir -ItemType Directory -Force | Out-Null
                Write-Log "Directorio creado: $dstDir"
            }

            # Copiar archivo
            Copy-Item $src $dst -Force
            Write-Log "✅ Copiado: $($dotfile.file) → $dstRelative" "SUCCESS"
            $installedCount++
        }
        catch {
            Write-Log "Error copiando $($dotfile.file): $($_.Exception.Message)" "WARNING"
            $failedCount++
        }
    }

    # Configurar variables de entorno específicas para Windows Terminal
    try {
        [Environment]::SetEnvironmentVariable("OMP_OS_ICON", "🪟", "User")
        Write-Log "Variable de entorno OMP_OS_ICON configurada"
    }
    catch {
        Write-Log "Error configurando variables de entorno: $($_.Exception.Message)" "WARNING"
    }

    # Configurar Windows Terminal para usar cmd_aliases.cmd
    $terminalConfigured = $false
    $aliasesFile = Join-Path $env:USERPROFILE "cmd_aliases.cmd"
    if (Test-Path $aliasesFile) {
        $terminalConfigured = ConfigureWindowsTerminal
    }
    else {
        Write-Log "cmd_aliases.cmd no encontrado, omitiendo configuración de Windows Terminal" "WARNING"
    }

    # Mostrar resumen final
    if ($installedCount -gt 0) {
        Write-Log "✅ Dotfiles instalados ($installedCount archivos)" "SUCCESS"
        if ($failedCount -gt 0) {
            Write-Log "$failedCount archivos fallaron en la copia" "WARNING"
        }
        if ($terminalConfigured) {
            Write-Log "✅ Windows Terminal configurado para usar cmd_aliases.cmd" "SUCCESS"
        }
    }
    else {
        Write-Log "No se instalaron dotfiles nuevos"
    }

    # Verificar archivos críticos instalados
    $criticalFiles = @(".oh-my-posh.json", "cmd_aliases.cmd")
    $missingFiles = @()

    foreach ($file in $criticalFiles) {
        $filePath = Join-Path $env:USERPROFILE $file
        if (-not (Test-Path $filePath)) {
            $missingFiles += $file
        }
    }

    if ($missingFiles.Count -gt 0) {
        Write-Log "❌ Archivos críticos no disponibles: $($missingFiles -join ', ')" "WARNING"
    }
}
