#Requires -Version 7.0
#
# Fase 03 — Copia los dotfiles definidos en 03-dotfiles.json a $HOME y
# configura Windows Terminal para usar cmd_aliases.cmd.
#
# Códigos de salida:
#   0  → todo OK
#   1  → algún archivo o config opcional falló (warning, no bloqueante)
#   2  → error de configuración (config no encontrada, dir fuente ausente)

[CmdletBinding()]
param()

# Modo estricto: caza typos en variables y accesos a propiedades nulas.
Set-StrictMode -Version Latest

. "$PSScriptRoot\env.ps1"
. "$PSScriptRoot\utils.ps1"

Initialize-Ux

$dotfilesDir = Join-Path $env:SETUP_DIR 'dotfiles'
$dotfilesConfig = Join-Path $PSScriptRoot '03-dotfiles.json'

# Validaciones de configuración
if (-not (Test-Path $dotfilesDir)) {
    Start-UxPhase -Num ([int]($env:PHASE_NUM ?? 3)) -Total ([int]($env:PHASE_TOTAL ?? 5)) -Title 'Dotfiles'
    Write-UxError -Message "directorio de dotfiles no encontrado: $dotfilesDir"
    Complete-UxPhase -Status fail
    exit 2
}
if (-not (Test-Path $dotfilesConfig)) {
    Start-UxPhase -Num ([int]($env:PHASE_NUM ?? 3)) -Total ([int]($env:PHASE_TOTAL ?? 5)) -Title 'Dotfiles'
    Write-UxError -Message "configuración no encontrada: $dotfilesConfig"
    Complete-UxPhase -Status fail
    exit 2
}

# Filtrar dotfiles aplicables a Windows
$allDotfiles = Get-ConfigFromJson -JsonPath $dotfilesConfig -PropertyName 'dotfiles'
$dotfiles = @($allDotfiles | Where-Object { $_.platforms -contains 'windows' })

# Configura Windows Terminal para que el perfil CMD use cmd_aliases.cmd.
# Devuelve $true si configurado, $false si requiere intervención manual.
function ConfigureWindowsTerminal {
    try {
        $possiblePaths = @(
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
        )

        $settingsPath = $null
        foreach ($p in $possiblePaths) {
            if (Test-Path $p) { $settingsPath = $p; break }
        }

        if (-not $settingsPath) {
            Write-UxWarn -Message 'Windows Terminal: settings.json no encontrado, configura manualmente CMD → cmd_aliases.cmd'
            return $false
        }

        $settings = ConvertFrom-Json (Get-Content $settingsPath -Raw -Encoding UTF8)
        # Helper para acceso seguro a propiedades en strict mode (PSCustomObject).
        $getProp = { param($obj, $name) if ($obj.PSObject.Properties[$name]) { $obj.$name } }

        if (-not (& $getProp $settings 'profiles')) {
            Write-UxWarn -Message 'Windows Terminal: settings.json con estructura inesperada'
            return $false
        }

        $profilesList = if (& $getProp $settings.profiles 'list') { $settings.profiles.list } else { $settings.profiles }
        $cmdProfileIndex = -1
        for ($i = 0; $i -lt $profilesList.Count; $i++) {
            $p = $profilesList[$i]
            $cmdLine = & $getProp $p 'commandline'
            $guid    = & $getProp $p 'guid'
            $name    = & $getProp $p 'name'
            if (($cmdLine -and $cmdLine -match 'cmd\.exe') -or
                ($guid -eq '{0caa0dad-35be-5f56-a8ff-afceeeaa6101}') -or
                ($name -match '(Command Prompt|CMD|cmd)')) {
                $cmdProfileIndex = $i
                break
            }
        }

        if ($cmdProfileIndex -lt 0) {
            Write-UxWarn -Message 'Windows Terminal: no se encontró perfil CMD'
            return $false
        }

        $aliasesPath = Join-Path $env:USERPROFILE 'cmd_aliases.cmd'
        $newCmd = "%SystemRoot%\System32\cmd.exe /k `"$aliasesPath`""

        $existingCmdLine = & $getProp $profilesList[$cmdProfileIndex] 'commandline'
        if ($existingCmdLine -and $existingCmdLine -match 'cmd_aliases\.cmd') {
            return $true  # ya estaba configurado
        }

        $profilesList[$cmdProfileIndex].commandline = $newCmd
        if (& $getProp $settings.profiles 'list') {
            $settings.profiles.list = $profilesList
        } else {
            $settings.profiles = $profilesList
        }
        Set-Content $settingsPath -Value (ConvertTo-Json $settings -Depth 20) -Encoding UTF8 -Force
        return $true
    }
    catch {
        Write-UxWarn -Message "Windows Terminal: error al configurar ($($_.Exception.Message))"
        return $false
    }
}

# Handler por archivo: copia src→dst. Devuelve $true / $false.
$installOne = {
    param($d)
    if (-not $d.file -or -not $d.dst) {
        Write-UxWarn -Message "$($d.file): configuración incompleta en JSON"
        return $false
    }

    $src = Join-Path $dotfilesDir $d.file
    $dstRelative = $d.dst.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    $dst = Join-Path $env:USERPROFILE $dstRelative
    $dstDir = Split-Path $dst -Parent

    if (-not (Test-Path $src)) {
        Write-UxWarn -Message "$($d.file): archivo fuente no encontrado"
        return $false
    }

    try {
        if (-not (Test-Path $dstDir)) {
            New-Item -Path $dstDir -ItemType Directory -Force | Out-Null
        }
        Copy-Item $src $dst -Force
        return $true
    }
    catch {
        Write-UxWarn -Message "$($d.file): error al copiar ($($_.Exception.Message))"
        return $false
    }
}

# Ejecutar la fase
$phaseRc = Invoke-PhaseItems `
    -Num   ([int]($env:PHASE_NUM ?? 3)) `
    -Total ([int]($env:PHASE_TOTAL ?? 5)) `
    -Title 'Dotfiles' `
    -Items $dotfiles `
    -InstallScript $installOne

# Post-fase: Windows Terminal config (no afecta al phase rc).
# OMP_OS_ICON / LS_COLORS / EZA_COLORS los setean los profiles de cada shell
# (bashrc, zshrc, PS7, PS5, cmd_aliases.cmd) en process-scope, sin User-scope.
$postWarn = $false

$aliasesFile = Join-Path $env:USERPROFILE 'cmd_aliases.cmd'
if (Test-Path $aliasesFile) {
    if (-not (ConfigureWindowsTerminal)) { $postWarn = $true }
}

# Si las copias fueron OK pero algún post-step avisó, devolver warn.
if ($postWarn -and $phaseRc -eq 0) { exit 1 }
exit $phaseRc
