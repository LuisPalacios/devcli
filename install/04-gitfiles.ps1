#Requires -Version 7.0

# Script de instalación de binarios desde GitHub Releases para Windows
# Lee configuración desde 04-gitfiles.json

[CmdletBinding()]
param()

# Cargar variables y funciones comunes
. "$PSScriptRoot\env.ps1"
. "$PSScriptRoot\utils.ps1"

# Obtener la URL de descarga del último release de un repositorio GitHub
function Get-LatestReleaseUrl {
    param(
        [Parameter(Mandatory)]
        [string]$Repo,

        [Parameter(Mandatory)]
        [string]$AssetName
    )

    $apiUrl = "https://api.github.com/repos/$Repo/releases/latest"

    try {
        $release = Invoke-RestMethod -Uri $apiUrl -Headers @{ Accept = "application/vnd.github+json" }
        $asset = $release.assets | Where-Object { $_.name -eq $AssetName }

        if (-not $asset) {
            Write-Log "No se encontró el asset '$AssetName' en $Repo/releases/latest" "ERROR"
            return $null
        }

        return $asset.browser_download_url
    }
    catch {
        Write-Log "Error consultando GitHub API para $Repo`: $_" "ERROR"
        return $null
    }
}

# Descargar, extraer e instalar un binario desde un ZIP de GitHub Releases
function Install-ReleaseBinary {
    param(
        [Parameter(Mandatory)]
        [string]$Repo,

        [Parameter(Mandatory)]
        [string]$BinaryName,

        [Parameter(Mandatory)]
        [string]$AssetName
    )

    # Obtener URL de descarga
    $downloadUrl = Get-LatestReleaseUrl -Repo $Repo -AssetName $AssetName
    if (-not $downloadUrl) {
        return $false
    }

    $tempDirName = "gitfiles-$(Get-Date -Format 'yyyyMMddHHmmss')-$PID"
    $tempDir = Join-Path $env:TEMP $tempDirName
    $zipFile = Join-Path $tempDir $AssetName

    try {
        # Crear directorio temporal
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

        # Descargar el ZIP
        Write-Log "Descargando $AssetName..."
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFile -UseBasicParsing

        # Extraer el ZIP
        Expand-Archive -Path $zipFile -DestinationPath $tempDir -Force

        # Buscar el binario (con extensión .exe en Windows)
        $binaryFile = Get-ChildItem -Path $tempDir -Filter "$BinaryName.exe" -Recurse -File | Select-Object -First 1

        if (-not $binaryFile) {
            # Intentar sin extensión .exe
            $binaryFile = Get-ChildItem -Path $tempDir -Filter $BinaryName -Recurse -File | Select-Object -First 1
        }

        if (-not $binaryFile) {
            Write-Log "Binario '$BinaryName' no encontrado en $AssetName" "ERROR"
            return $false
        }

        # Copiar al directorio de binarios
        $destPath = Join-Path $Global:BIN_DIR $binaryFile.Name
        Copy-Item $binaryFile.FullName $destPath -Force

        return $true
    }
    catch {
        Write-Log "Error instalando $BinaryName desde $Repo`: $($_.Exception.Message)" "ERROR"
        return $false
    }
    finally {
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Run-Phase {
    Write-Log "Instalando binarios desde GitHub Releases..."

    # Asegurar que existe el directorio de binarios
    if (-not (New-DirectoryIfNotExists $Global:BIN_DIR)) {
        Write-Log "Error creando directorio de binarios" "ERROR"
        exit 1
    }

    # Archivo de configuración
    $gitfilesConfig = Join-Path (Split-Path $PSScriptRoot -Parent) "install\04-gitfiles.json"

    if (-not (Test-Path $gitfilesConfig)) {
        Write-Log "Archivo de configuración no encontrado: $gitfilesConfig" "ERROR"
        exit 1
    }

    # Leer configuración
    try {
        $config = Get-Content $gitfilesConfig -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        Write-Log "Error leyendo configuración: $($_.Exception.Message)" "ERROR"
        exit 1
    }

    if (-not $config.releases -or $config.releases.Count -eq 0) {
        Write-Log "No hay releases configurados"
        return
    }

    # Detectar arquitectura: prioridad ARM64 si aplica, fallback a amd64
    $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLower()
    $primaryKey = switch ($arch) {
        'arm64' { 'win-arm64' }
        default { 'win-amd64' }
    }
    $fallbackKey = 'win-amd64'

    $binsInstalled = 0

    foreach ($release in $config.releases) {
        $repo = $release.repo
        $binaryName = $release.binary
        $assetName = $release.assets.$primaryKey
        $usingFallback = $false

        if (-not $assetName -and $primaryKey -ne $fallbackKey) {
            $assetName = $release.assets.$fallbackKey
            $usingFallback = $true
        }

        if (-not $assetName) {
            Write-Log "No hay asset para plataforma '$primaryKey' (ni fallback '$fallbackKey') en $repo - omitiendo" "WARNING"
            continue
        }

        if ($usingFallback) {
            Write-Log "$repo no publica asset para $primaryKey — usando $fallbackKey (correrá bajo emulación x64)" "WARNING"
        }

        if (Install-ReleaseBinary -Repo $repo -BinaryName $binaryName -AssetName $assetName) {
            $binsInstalled++
            Write-Log "✅ $binaryName instalado desde $repo" "SUCCESS"
        }
        else {
            Write-Log "Error instalando $binaryName desde $repo" "WARNING"
        }
    }

    # Resumen final
    if ($binsInstalled -gt 0) {
        Write-Log "✅ Binarios desde GitHub Releases instalados ($binsInstalled)" "SUCCESS"
    }
    else {
        Write-Log "No se instalaron binarios desde GitHub Releases"
    }
}
