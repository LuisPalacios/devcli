#Requires -Version 7.0
#
# Fase 01 — Paquetes base del sistema (jq, git, oh-my-posh) en Windows.
#
# Códigos de salida: 0=ok, 1=warn, 2=fail (scoop ausente).

[CmdletBinding()]
param()

# Modo estricto: caza typos en variables y accesos a propiedades nulas.
Set-StrictMode -Version Latest

. "$PSScriptRoot\env.ps1"
. "$PSScriptRoot\utils.ps1"

Initialize-Ux

# Crear ~/bin y añadirlo al PATH del usuario.
if (-not (New-DirectoryIfNotExists $Global:BIN_DIR)) {
    Start-UxPhase -Num ([int]($env:PHASE_NUM ?? 1)) -Total ([int]($env:PHASE_TOTAL ?? 5)) -Title 'Sistema base'
    Write-UxError -Message "no se pudo crear $($Global:BIN_DIR)"
    Complete-UxPhase -Status fail
    exit 2
}
Update-UserPath $Global:BIN_DIR

# Scoop es prerrequisito (lo instala bootstrap.ps1, pero verificamos).
if (-not (Test-Scoop)) {
    Start-UxPhase -Num ([int]($env:PHASE_NUM ?? 1)) -Total ([int]($env:PHASE_TOTAL ?? 5)) -Title 'Sistema base'
    Write-UxError -Message 'scoop no funciona — bootstrap deberá reintentarse'
    Complete-UxPhase -Status fail
    exit 2
}

# Filtrar herramientas con phase=system que tengan bloque "windows".
$toolsConfig = Join-Path $PSScriptRoot 'tools.json'
$allTools = Get-ConfigFromJson -JsonPath $toolsConfig -PropertyName 'tools'
$systemTools = @($allTools | Where-Object {
    ($_.ContainsKey('phase') -and $_.phase -eq 'system') -and ($_.ContainsKey('windows'))
})

$installOne = {
    param($tool)
    Install-Tool -ToolName $tool.name -ToolsRegistry $allTools
}

$phaseRc = Invoke-PhaseItems `
    -Num   ([int]($env:PHASE_NUM ?? 1)) `
    -Total ([int]($env:PHASE_TOTAL ?? 5)) `
    -Title 'Sistema base' `
    -Items $systemTools `
    -InstallScript $installOne

# Refrescar PATH y avisar si faltan herramientas críticas (no cambia el rc:
# la fase es OK si la instalación corrió, aunque PATH aún no esté refrescado).
Update-SessionPath
$missing = @()
foreach ($tool in @('jq', 'git', 'oh-my-posh')) {
    if (-not (Test-Command $tool)) { $missing += $tool }
}
if ($missing.Count -gt 0) {
    Write-UxWarn -Message "no detectadas en PATH (reinicia el terminal): $($missing -join ', ')"
    if ($phaseRc -eq 0) { $phaseRc = 1 }
}

exit $phaseRc
