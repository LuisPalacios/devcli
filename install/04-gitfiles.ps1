#Requires -Version 7.0

# Script de instalación de archivos desde repositorios Git para Windows
# Lee configuración desde 04-gitfiles-win.json

[CmdletBinding()]
param()

# Cargar variables y funciones comunes
. "$PSScriptRoot\env.ps1"
. "$PSScriptRoot\utils.ps1"

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
        [Parameter(Mandatory)]
        [string]$RepoUrl,

        [Parameter(Mandatory)]
        [string]$TempDir
    )

    try {
        $result = git clone --depth 1 --quiet $RepoUrl $TempDir 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Log "Repositorio clonado: $RepoUrl"
            return $true
        }
        else {
            Write-Log "Error clonando repositorio $RepoUrl`: $result" "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Excepción clonando repositorio $RepoUrl`: $_" "ERROR"
        return $false
    }
}

# Función para copiar archivo con permisos apropiados
function Copy-FileWithPermissions {
    param(
        [Parameter(Mandatory)]
        [string]$SourceFile,

        [Parameter(Mandatory)]
        [string]$DestFile
    )

    try {
        Copy-Item $SourceFile $DestFile -Force
        return $true
    }
    catch {
        Write-Log "Error copiando archivo: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Función para procesar un repositorio
function Invoke-ProcessRepository {
    param(
        [Parameter(Mandatory)]
        [string]$RepoUrl,

        [Parameter(Mandatory)]
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
            $fileName = Split-Path $cleanPath -Leaf
            $destFile = Join-Path $Global:BIN_DIR $fileName

            if (Test-Path $srcFile) {
                if (Copy-FileWithPermissions -SourceFile $srcFile -DestFile $destFile) {
                    Write-Log "Copiado: $fileName"
                    $filesCopied++
                }
            }
            else {
                Write-Log "Archivo no encontrado en repositorio: $cleanPath" "WARNING"
            }
        }

        return $filesCopied
    }
    finally {
        if (Test-Path $tempDir) {
            try {
                Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
            catch {
                Write-Log "Advertencia: No se pudo limpiar directorio temporal: $tempDir" "WARNING"
            }
        }
    }
}

# Función principal
function main {
    trap {
        Write-Log "🛑 Excepción no manejada: $($_.Exception.Message)" "ERROR"
        Restore-OriginalDirectory
        exit 1
    }

    Setup-ScriptInterruptionHandler

    try {
        Write-Log "Iniciando instalación de archivos desde repositorios Git..."

        # Verificar dependencias
        if (-not (Test-Dependencies @("jq", "git"))) {
            Write-Log "Abortando: dependencias faltantes" "ERROR"
            exit 1
        }

        # Asegurar que existe el directorio de binarios
        if (-not (New-DirectoryIfNotExists $Global:BIN_DIR)) {
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

        # Leer configuración usando función común
        try {
            $config = Get-ConfigFromJson -JsonPath $gitfilesConfig
            $repositories = $config.repositories
        }
        catch {
            Write-Log "Error leyendo configuración: $($_.Exception.Message)" "ERROR"
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
            Write-Log "✅ Archivos desde repositorios Git instalados ($totalFilesCopied archivos)" "SUCCESS"
        }
        else {
            Write-Log "No se copiaron archivos desde repositorios Git"
        }

        $Global:ShouldRestoreDirectory = $false
    }
    finally {
        if ($Global:ShouldRestoreDirectory) {
            Restore-OriginalDirectory
        }
    }
}

# Ejecutar función principal con manejo robusto
try {
    main
}
catch {
    Write-Error "❌ Error crítico en script: $($_.Exception.Message)"
    Restore-OriginalDirectory
    exit 1
}
