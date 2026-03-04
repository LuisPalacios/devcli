#Requires -Version 7.0

# Script de configuración base del sistema para Windows
# Instala herramientas esenciales: jq, git, oh-my-posh

[CmdletBinding()]
param()

# Cargar variables y funciones comunes
. "$PSScriptRoot\env.ps1"
. "$PSScriptRoot\utils.ps1"

Run-Phase {
    Write-Log "Instalando paquetes base del sistema..."

    # Crear directorio de binarios del usuario
    if (-not (New-DirectoryIfNotExists $Global:BIN_DIR)) {
        Write-Log "Error creando directorio de binarios" "ERROR"
        exit 1
    }

    # Actualizar PATH para incluir ~/bin
    Update-UserPath $Global:BIN_DIR

    # Verificar que scoop funciona
    if (-not (Test-Scoop)) {
        Write-Log "Scoop no está funcionando correctamente. Ejecutando diagnóstico..." "WARNING"
        Test-ScoopDiagnostic
        Write-Log "Abortando: Scoop es requerido" "ERROR"
        exit 1
    }

    # Instalar herramientas del sistema desde tools.json (tag: system)
    $toolsConfig = Join-Path $PSScriptRoot "tools.json"
    $allTools = Get-ConfigFromJson -JsonPath $toolsConfig -PropertyName "tools"
    $systemTools = $allTools | Where-Object { $_.tags -contains "system" -and $_.ContainsKey("windows") }

    $installedCount = 0
    $failedCount = 0

    foreach ($tool in $systemTools) {
        if (Install-Tool -ToolName $tool.name -ToolsRegistry $allTools) {
            $installedCount++
        } else {
            $failedCount++
        }
    }

    # Refrescar PATH
    Update-SessionPath

    # Verificar instalaciones críticas
    $criticalTools = @("jq", "git", "oh-my-posh")
    $missingCritical = @()
    foreach ($tool in $criticalTools) {
        if (-not (Test-Command $tool)) {
            $missingCritical += $tool
        }
    }

    if ($missingCritical.Count -gt 0) {
        Write-Log "Herramientas críticas no disponibles: $($missingCritical -join ', ')" "ERROR"
        Write-Log "Intenta ejecutar de nuevo después de reiniciar el terminal" "WARNING"
    }

    # Resumen
    Write-Log "Configuración base completada ($installedCount herramientas del sistema)" "SUCCESS"
    if ($failedCount -gt 0) {
        Write-Log "$failedCount paquetes fallaron en la instalación" "WARNING"
    }
}
