#Requires -Version 7.0
#
# Fase 05 — Scripts auxiliares en ~/bin (05-localtools.json) en Windows.
#
# Códigos de salida: 0=ok, 1=warn, 2=fail.

[CmdletBinding()]
param()

# Modo estricto: caza typos en variables y accesos a propiedades nulas.
Set-StrictMode -Version Latest

. "$PSScriptRoot\env.ps1"
. "$PSScriptRoot\utils.ps1"

Initialize-Ux

if (-not (New-DirectoryIfNotExists $Global:BIN_DIR)) {
    Start-UxPhase -Num ([int]($env:PHASE_NUM ?? 5)) -Total ([int]($env:PHASE_TOTAL ?? 5)) -Title 'Herramientas locales'
    Write-UxError -Message "no se pudo crear $($Global:BIN_DIR)"
    Complete-UxPhase -Status fail
    exit 2
}

if (-not (Test-Path $Global:FILES_DIR)) {
    Start-UxPhase -Num ([int]($env:PHASE_NUM ?? 5)) -Total ([int]($env:PHASE_TOTAL ?? 5)) -Title 'Herramientas locales'
    Write-UxError -Message "directorio fuente no encontrado: $($Global:FILES_DIR)"
    Complete-UxPhase -Status fail
    exit 2
}

$localToolsConfig = Join-Path $PSScriptRoot '05-localtools.json'
$allTools = Get-ConfigFromJson -JsonPath $localToolsConfig -PropertyName 'tools'
$tools = @($allTools | Where-Object { $_.platforms -contains 'windows' })

# Patcher de variables Nerd Font en scripts copiados.
function Update-NerdFontVariables {
    param([string]$ScriptFile)
    if (-not (Test-Path $ScriptFile)) { return $false }
    try {
        $content = Get-Content $ScriptFile -Raw -Encoding UTF8
        $content = $content -replace '\$NERD_FONT_NAME = "[^"]*"',      "`$NERD_FONT_NAME = `"$Global:NERD_FONT_NAME`""
        $content = $content -replace '\$NERD_FONT_FULL_NAME = "[^"]*"', "`$NERD_FONT_FULL_NAME = `"$Global:NERD_FONT_FULL_NAME`""
        Set-Content -Path $ScriptFile -Value $content -Encoding UTF8
        return $true
    }
    catch { return $false }
}

$installOne = {
    param($t)
    $name = $t.name
    if (-not $name) { return $false }

    $src = Join-Path $Global:FILES_DIR $name
    $dst = Join-Path $Global:BIN_DIR $name

    if (-not (Test-Path $src)) {
        Write-UxWarn -Message "${name}: fuente no encontrada"
        return $false
    }
    try {
        Copy-Item $src $dst -Force
        if ($name -in @('nerd-setup.ps1', 'nerd-verify.ps1')) {
            Update-NerdFontVariables $dst | Out-Null
        }
        return $true
    }
    catch {
        Write-UxWarn -Message "${name}: error al copiar ($($_.Exception.Message))"
        return $false
    }
}

$phaseRc = Invoke-PhaseItems `
    -Num   ([int]($env:PHASE_NUM ?? 5)) `
    -Total ([int]($env:PHASE_TOTAL ?? 5)) `
    -Title 'Herramientas locales' `
    -Items $tools `
    -InstallScript $installOne

exit $phaseRc
