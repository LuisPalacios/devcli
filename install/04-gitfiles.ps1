#Requires -Version 7.0

Write-Log "WiP gitfiles"
exit 0

# Script de instalación de archivos desde repositorios Git para Windows
# Lee configuración desde 04-gitfiles-win.json

[CmdletBinding()]
param()

# Variables de entorno (definidas por bootstrap.ps1)
$SETUP_LANG = $env:SETUP_LANG ?? "es-ES"
$SETUP_DIR = $env:SETUP_DIR ?? "$env:USERPROFILE\.devcli"
$CURRENT_USER = $env:CURRENT_USER ?? $env:USERNAME
$BIN_DIR = "$env:USERPROFILE\bin"

# Función de log
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "Cyan" }
    }
    Write-Host "[04-gitfiles] $Message" -ForegroundColor $color
}

# Función para verificar si un comando existe
function Test-Command {
    param([string]$Command)
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

# Función para verificar dependencias
function Test-Dependencies {
    $missing = @()

    if (-not (Test-Command "jq")) {
        $missing += "jq"
    }

    if (-not (Test-Command "git")) {
        $missing += "git"
    }

    if ($missing.Count -gt 0) {
        Write-Log "Dependencias faltantes: $($missing -join ', ')" "ERROR"
        return $false
    }

    return $true
}

# Función para validar archivo JSON
function Test-JsonFile {
    param([string]$JsonPath)

    if (-not (Test-Path $JsonPath)) {
        Write-Log "Archivo de configuración no encontrado: $JsonPath" "ERROR"
        return $false
    }

    try {
        $jsonContent = Get-Content $JsonPath -Raw -Encoding UTF8
        $config = $jsonContent | ConvertFrom-Json

        if (-not $config.repositories) {
            Write-Log "Estructura JSON inválida: falta 'repositories'" "ERROR"
            return $false
        }

        return $true
    }
    catch {
        Write-Log "Archivo JSON inválido: $_" "ERROR"
        return $false
    }
}

# Función para clonar repositorio temporalmente
function Get-TempRepository {
    param(
        [string]$RepoUrl,
        [string]$TempDir
    )

    try {
        # Clonar repositorio
        $result = git clone --depth 1 --quiet $RepoUrl $TempDir 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Log "Error clonando repositorio: $RepoUrl" "ERROR"
            return $false
        }

        if (-not (Test-Path $TempDir)) {
            Write-Log "Directorio clonado no encontrado: $TempDir" "ERROR"
            return $false
        }

        return $true
    }
    catch {
        Write-Log "Excepción clonando repositorio $RepoUrl`: $_" "ERROR"
        return $false
    }
}

# Función para copiar archivo con permisos apropiados
function Copy-FileWithPermissions {
    param(
        [string]$SourceFile,
        [string]$DestFile
    )

    if (-not (Test-Path $SourceFile)) {
        Write-Log "Archivo no encontrado: $SourceFile" "WARNING"
        return $false
    }

    try {
        # Copiar archivo
        Copy-Item $SourceFile $DestFile -Force

        $filename = Split-Path $SourceFile -Leaf

        # Para archivos .ps1, mantener permisos originales
        # Para otros archivos, no hay necesidad de chmod en Windows

        return $true
    }
    catch {
        Write-Log "Error copiando archivo $SourceFile -> $DestFile`: $_" "ERROR"
        return $false
    }
}

# Función para procesar un repositorio
function Invoke-ProcessRepository {
    param(
        [string]$RepoUrl,
        [array]$FilesList
    )

    Write-Log "Procesando repositorio: $RepoUrl"

    # Crear directorio temporal único
    $tempDirName = "gitfiles-$(Get-Date -Format 'yyyyMMddHHmmss')-$PID"
    $tempDir = Join-Path $env:TEMP $tempDirName

    try {
        # Clonar repositorio
        if (-not (Get-TempRepository -RepoUrl $RepoUrl -TempDir $tempDir)) {
            return 0
        }

        $filesCopied = 0

        # Procesar cada archivo
        foreach ($filePath in $FilesList) {
            # Limpiar path (remover ./ si existe)
            $cleanPath = $filePath -replace '^\./', ''
            $srcFile = Join-Path $tempDir $cleanPath
            $filename = Split-Path $cleanPath -Leaf
            $dstFile = Join-Path $BIN_DIR $filename

            if (Copy-FileWithPermissions -SourceFile $srcFile -DestFile $dstFile) {
                $filesCopied++
            }
        }

        Write-Log "Repositorio procesado: $filesCopied archivos copiados"
        return $filesCopied
    }
    finally {
        # Limpiar directorio temporal
        if (Test-Path $tempDir) {
            try {
                Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
            catch {
                Write-Log "Advertencia: no se pudo limpiar directorio temporal $tempDir" "WARNING"
            }
        }
    }
}

# Función para crear directorio si no existe
function New-DirectoryIfNotExists {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        try {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
            return $true
        }
        catch {
            Write-Log "Error creando directorio $Path`: $_" "ERROR"
            return $false
        }
    }
    return $true
}

# Función principal
function main {
    Write-Log "Iniciando instalación de archivos desde repositorios Git..."

    # Verificar dependencias
    if (-not (Test-Dependencies)) {
        Write-Log "Abortando: dependencias faltantes" "ERROR"
        exit 1
    }

    # Asegurar que existe el directorio de binarios
    if (-not (New-DirectoryIfNotExists $BIN_DIR)) {
        Write-Log "Error creando directorio de binarios" "ERROR"
        exit 1
    }

    # Archivo de configuración
    $gitfilesConfig = Join-Path (Split-Path $PSScriptRoot -Parent) "install\04-gitfiles-win.json"

    # Validar archivo de configuración
    if (-not (Test-JsonFile $gitfilesConfig)) {
        Write-Log "Configuración inválida - abortando" "ERROR"
        exit 1
    }

    # Leer configuración
    try {
        $jsonContent = Get-Content $gitfilesConfig -Raw -Encoding UTF8
        $config = $jsonContent | ConvertFrom-Json
        $repositories = $config.repositories
    }
    catch {
        Write-Log "Error leyendo configuración: $_" "ERROR"
        exit 1
    }

    if ($repositories.Count -eq 0) {
        Write-Log "No hay repositorios configurados"
        return
    }

    $totalFilesCopied = 0

    # Procesar cada repositorio
    foreach ($repo in $repositories) {
        if ($repo.url -and $repo.files) {
            $filesCopied = Invoke-ProcessRepository -RepoUrl $repo.url -FilesList $repo.files
            $totalFilesCopied += $filesCopied
        }
        else {
            Write-Log "Repositorio con configuración incompleta omitido" "WARNING"
        }
    }

    # Mostrar resumen final
    if ($totalFilesCopied -gt 0) {
        Write-Log "��� Archivos desde repositorios Git instalados ($totalFilesCopied archivos)" "SUCCESS"
    }
    else {
        Write-Log "No se copiaron archivos desde repositorios Git"
    }
}

# Ejecutar función principal
main