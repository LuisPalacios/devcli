#Requires -Version 7.0
#
# Fase 02 — Herramientas de productividad (filtradas por perfil) en Windows.
#
# Códigos de salida: 0=ok, 1=warn (algún paquete falló), 2=fail (scoop ausente).

[CmdletBinding()]
param()

# Modo estricto: caza typos en variables y accesos a propiedades nulas.
Set-StrictMode -Version Latest

. "$PSScriptRoot\env.ps1"
. "$PSScriptRoot\utils.ps1"

Initialize-Ux

if (-not (Test-Scoop)) {
    Start-UxPhase -Num ([int]($env:PHASE_NUM ?? 2)) -Total ([int]($env:PHASE_TOTAL ?? 5)) -Title 'Herramientas de productividad'
    Write-UxError -Message 'scoop no funciona — abortando fase'
    Complete-UxPhase -Status fail
    exit 2
}

# Resolver perfil y tags permitidos.
$toolsConfig = Join-Path $PSScriptRoot 'tools.json'
$allConfig = Get-ConfigFromJson -JsonPath $toolsConfig
$profileName = if ($env:DEVCLI_PROFILE) { $env:DEVCLI_PROFILE } else { 'full' }
$allowedTags = $allConfig.profiles[$profileName]
if (-not $allowedTags) { $allowedTags = @('core', 'dev', 'k8s', 'win') }

# Filtrar herramientas: phase != "system" (esas van en phase 01), tener bloque
# "windows", auto_install != false, y al menos un tag dentro de los permitidos
# por el perfil.
$allTools = Get-ConfigFromJson -JsonPath $toolsConfig -PropertyName 'tools'
$packageTools = @($allTools | Where-Object {
    (-not ($_.ContainsKey('phase') -and $_.phase -eq 'system')) -and
    $_.ContainsKey('windows') -and
    (-not $_.ContainsKey('auto_install') -or $_.auto_install -ne $false) -and
    @($_.tags | Where-Object { $allowedTags -contains $_ }).Count -gt 0
})

$installOne = {
    param($tool)
    Install-Tool -ToolName $tool.name -ToolsRegistry $allTools
}

$phaseRc = Invoke-PhaseItems `
    -Num   ([int]($env:PHASE_NUM ?? 2)) `
    -Total ([int]($env:PHASE_TOTAL ?? 5)) `
    -Title 'Herramientas de productividad' `
    -Items $packageTools `
    -InstallScript $installOne

Update-SessionPath
exit $phaseRc
