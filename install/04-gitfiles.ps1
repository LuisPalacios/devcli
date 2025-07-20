#Requires -Version 7.0

# Script de instalaci?n de archivos desde repositorios Git para Windows
# Lee configuraci?n desde 04-gitfiles-win.json

[CmdletBinding()]
param()

Write-Host "WiP gitfiles"
exit 0

$SETUP_LANG = $env:SETUP_LANG ?? "es-ES"
$SETUP_DIR = $env:SETUP_DIR ?? "$env:USERPROFILE\.devcli"
$CURRENT_USER = $env:CURRENT_USER ?? $env:USERNAME
$BIN_DIR = "$env:USERPROFILE\bin"

$script:OriginalDirectory = $env:ORIGINAL_DIRECTORY ?? $PWD.Path
$script:ShouldRestoreDirectory = $true

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

function Restore-OriginalDirectory {
    if ($script:ShouldRestoreDirectory -and $script:OriginalDirectory) {
        try {
            Set-Location $script:OriginalDirectory -ErrorAction SilentlyContinue
            Write-Log "Directorio restaurado: $script:OriginalDirectory"
        }
        catch {
            Write-Warning "No se pudo restaurar el directorio original: $script:OriginalDirectory"
        }
    }
}

function Handle-ScriptInterruption {
    Write-Host "`n? Script interrumpido por el usuario" -ForegroundColor Red
    Restore-OriginalDirectory
    exit 130
}

function Setup-ScriptInterruptionHandler {
    try {
        # Solo CancelKeyPress - suficiente para scripts hijos
        $null = Register-ObjectEvent -InputObject ([Console]) -EventName CancelKeyPress -Action {
            $Event.Args[1].Cancel = $true
            Handle-ScriptInterruption
        }
    }
    catch {
        Write-Warning "No se pudo configurar el manejador de interrupciones: $_"
    }
}

function Test-Command {
    param([string]$Command)
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Test-Dependencies {
    $missing = @()
    if (-not (Test-Command "jq")) { $missing += "jq" }
    if (-not (Test-Command "git")) { $missing += "git" }

    if ($missing.Count -gt 0) {
        Write-Log "Dependencias faltantes: $($missing -join ', ')" "ERROR"
        return $false
    }

    return $true
}

function Test-JsonFile {
    param([string]$JsonPath)

    if (-not (Test-Path $JsonPath)) {
        Write-Log "Archivo de configuraci?n no encontrado: $JsonPath" "ERROR"
        return $false
    }

    try {
        $jsonContent = Get-Content $JsonPath -Raw -Encoding UTF8
        $config = $jsonContent | ConvertFrom-Json

        if (-not $config.repositories) {
            Write-Log "Estructura JSON inv?lida: falta 'repositories'" "ERROR"
            return $false
        }

        return $true
    }
    catch {
        Write-Log "Archivo JSON inv?lido: $_" "ERROR"
        return $false
    }
}

function Get-TempRepository {
    param(
        [string]$RepoUrl,
        [string]$TempDir
    )

    try {
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
        Write-Log "Excepci?n clonando repositorio $RepoUrl`: $_" "ERROR"
        return $false
    }
}

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
        Copy-Item $SourceFile $DestFile -Force
        return $true
    }
    catch {
        Write-Log "Error copiando archivo $SourceFile -> $DestFile`: $_" "ERROR"
        return $false
    }
}

function Invoke-ProcessRepository {
    param(
        [string]$RepoUrl,
        [array]$FilesList
    )

    Write-Log "Procesando repositorio: $RepoUrl"
    $tempDirName = "gitfiles-$(Get-Date -Format 'yyyyMMddHHmmss')-$PID"
    $tempDir = Join-Path $env:TEMP $tempDirName

    try {
        if (-not (Get-TempRepository -RepoUrl $RepoUrl -TempDir $tempDir)) {
            return 0
        }

        $filesCopied = 0

        foreach ($filePath in $FilesList) {
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

function main {
    trap {
        Write-Log "?? Excepci?n no manejada: $($_.Exception.Message)" "ERROR"
        Restore-OriginalDirectory
        exit 1
    }

    Setup-ScriptInterruptionHandler

    try {
        Write-Log "Iniciando instalaci?n de archivos desde repositorios Git..."

        if (-not (Test-Dependencies)) {
            Write-Log "Abortando: dependencias faltantes" "ERROR"
            exit 1
        }

        if (-not (New-DirectoryIfNotExists $BIN_DIR)) {
            Write-Log "Error creando directorio de binarios" "ERROR"
            exit 1
        }

        $gitfilesConfig = Join-Path (Split-Path $PSScriptRoot -Parent) "install\04-gitfiles-win.json"

        if (-not (Test-JsonFile $gitfilesConfig)) {
            Write-Log "Configuraci?n inv?lida - abortando" "ERROR"
            exit 1
        }

        try {
            $jsonContent = Get-Content $gitfilesConfig -Raw -Encoding UTF8
            $config = $jsonContent | ConvertFrom-Json
            $repositories = $config.repositories
        }
        catch {
            Write-Log "Error leyendo configuraci?n: $_" "ERROR"
            exit 1
        }

        if ($repositories.Count -eq 0) {
            Write-Log "No hay repositorios configurados"
            return
        }

        $totalFilesCopied = 0

        foreach ($repo in $repositories) {
            if ($repo.url -and $repo.files) {
                $filesCopied = Invoke-ProcessRepository -RepoUrl $repo.url -FilesList $repo.files
                $totalFilesCopied += $filesCopied
            }
            else {
                Write-Log "Repositorio con configuraci?n incompleta omitido" "WARNING"
            }
        }

        if ($totalFilesCopied -gt 0) {
            Write-Log "? Archivos desde repositorios Git instalados ($totalFilesCopied archivos)" "SUCCESS"
        }
        else {
            Write-Log "No se copiaron archivos desde repositorios Git"
        }

        $script:ShouldRestoreDirectory = $false
    }
    finally {
        if ($script:ShouldRestoreDirectory) {
            Restore-OriginalDirectory
        }
    }
}

try {
    main
}
catch {
    Write-Error "? Error cr?tico en script: $($_.Exception.Message)"
    Restore-OriginalDirectory
    exit 1
}
