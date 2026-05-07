#Requires -Version 7.0
#
# Fase 04 — Binarios desde GitHub Releases (04-gitfiles.json) para Windows.
#
# Códigos de salida: 0=ok, 1=warn, 2=fail (config inválida).

[CmdletBinding()]
param()

# Modo estricto: caza typos en variables y accesos a propiedades nulas.
Set-StrictMode -Version Latest

. "$PSScriptRoot\env.ps1"
. "$PSScriptRoot\utils.ps1"

Initialize-Ux

if (-not (New-DirectoryIfNotExists $Global:BIN_DIR)) {
    Start-UxPhase -Num ([int]($env:PHASE_NUM ?? 4)) -Total ([int]($env:PHASE_TOTAL ?? 5)) -Title 'Repos externos (GitHub Releases)'
    Write-UxError -Message "no se pudo crear $($Global:BIN_DIR)"
    Complete-UxPhase -Status fail
    exit 2
}

$gitfilesConfig = Join-Path $PSScriptRoot '04-gitfiles.json'
if (-not (Test-Path $gitfilesConfig)) {
    Start-UxPhase -Num ([int]($env:PHASE_NUM ?? 4)) -Total ([int]($env:PHASE_TOTAL ?? 5)) -Title 'Repos externos (GitHub Releases)'
    Write-UxError -Message "configuración no encontrada: $gitfilesConfig"
    Complete-UxPhase -Status fail
    exit 2
}

try {
    $config = Get-Content $gitfilesConfig -Raw -Encoding UTF8 | ConvertFrom-Json
}
catch {
    Start-UxPhase -Num ([int]($env:PHASE_NUM ?? 4)) -Total ([int]($env:PHASE_TOTAL ?? 5)) -Title 'Repos externos (GitHub Releases)'
    Write-UxError -Message "config inválido: $($_.Exception.Message)"
    Complete-UxPhase -Status fail
    exit 2
}

# Detectar arquitectura: ARM64 si aplica, fallback amd64.
$arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLower()
$primaryKey = if ($arch -eq 'arm64') { 'win-arm64' } else { 'win-amd64' }
$fallbackKey = 'win-amd64'

# Resolver el asset para cada release según arquitectura. Items = nombres de
# binarios; mapas auxiliares conservan repo/asset por binario.
$repoFor   = @{}
$assetFor  = @{}
$releases  = @()
foreach ($r in $config.releases) {
    $assetName = $r.assets.$primaryKey
    if (-not $assetName -and $primaryKey -ne $fallbackKey) {
        $assetName = $r.assets.$fallbackKey
        if ($assetName) {
            Write-UxWarn -Message "$($r.repo): sin asset $primaryKey, usando $fallbackKey (correrá bajo emulación)"
        }
    }
    if (-not $assetName) {
        Write-UxWarn -Message "$($r.repo): sin asset para Windows, omitido"
        continue
    }
    $releases += $r.binary
    $repoFor[$r.binary]  = $r.repo
    $assetFor[$r.binary] = $assetName
}

function Get-LatestReleaseUrl {
    param([string]$Repo, [string]$AssetName)
    try {
        $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" `
            -Headers @{ Accept = 'application/vnd.github+json' }
        $asset = $rel.assets | Where-Object { $_.name -eq $AssetName }
        if ($asset) { return $asset.browser_download_url }
    }
    catch {}
    return $null
}

$installOne = {
    param($binary)
    $repo = $repoFor[$binary]
    $asset = $assetFor[$binary]
    $url = Get-LatestReleaseUrl -Repo $repo -AssetName $asset
    if (-not $url) {
        Write-UxWarn -Message "${binary}: asset '$asset' no encontrado en $repo"
        return $false
    }

    $tempDir = Join-Path $env:TEMP "gitfiles-$(Get-Date -Format 'yyyyMMddHHmmss')-$PID-$binary"
    $zipFile = Join-Path $tempDir $asset

    try {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        Invoke-WebRequest -Uri $url -OutFile $zipFile -UseBasicParsing
        Expand-Archive -Path $zipFile -DestinationPath $tempDir -Force

        $binaryFile = Get-ChildItem -Path $tempDir -Filter "$binary.exe" -Recurse -File | Select-Object -First 1
        if (-not $binaryFile) {
            $binaryFile = Get-ChildItem -Path $tempDir -Filter $binary -Recurse -File | Select-Object -First 1
        }
        if (-not $binaryFile) {
            Write-UxWarn -Message "${binary}: no encontrado dentro de $asset"
            return $false
        }

        Copy-Item $binaryFile.FullName (Join-Path $Global:BIN_DIR $binaryFile.Name) -Force
        return $true
    }
    catch {
        Write-UxWarn -Message "${binary}: error de instalación ($($_.Exception.Message))"
        return $false
    }
    finally {
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

$phaseRc = Invoke-PhaseItems `
    -Num   ([int]($env:PHASE_NUM ?? 4)) `
    -Total ([int]($env:PHASE_TOTAL ?? 5)) `
    -Title 'Repos externos (GitHub Releases)' `
    -Items $releases `
    -InstallScript $installOne

exit $phaseRc
