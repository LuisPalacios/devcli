#Requires -Version 7.0

# Script de instalación de herramientas de productividad para Windows
# Lee configuración desde tools.json y usa el dispatcher de métodos

[CmdletBinding()]
param()

# Cargar variables y funciones comunes
. "$PSScriptRoot\env.ps1"
. "$PSScriptRoot\utils.ps1"

Run-Phase {
    Write-Log "Iniciando instalación de herramientas de productividad..."

    # Verificar que Scoop esté disponible
    if (-not (Test-Scoop)) {
        Write-Log "Scoop no está disponible. Ejecutando diagnóstico..." "WARNING"
        Test-ScoopDiagnostic
        Write-Log "Abortando: Scoop es requerido para instalar herramientas" "ERROR"
        exit 1
    }

    # Resolver perfil y tags permitidos
    $toolsConfig = Join-Path $PSScriptRoot "tools.json"
    $allConfig = Get-ConfigFromJson -JsonPath $toolsConfig
    $profileName = if ($env:DEVCLI_PROFILE) { $env:DEVCLI_PROFILE } else { "full" }
    $allowedTags = $allConfig.profiles[$profileName]
    if (-not $allowedTags) { $allowedTags = @("core", "dev", "k8s", "win") }
    Write-Log "Perfil: $profileName (tags: $($allowedTags -join ', '))" "INFO"

    # Filtrar herramientas por perfil
    $allTools = Get-ConfigFromJson -JsonPath $toolsConfig -PropertyName "tools"
    $packageTools = @($allTools | Where-Object {
        $_.ContainsKey("windows") -and
        ($_.auto_install -ne $false) -and
        ($_.tags | Where-Object { $allowedTags -contains $_ }).Count -gt 0
    })

    if ($packageTools.Count -eq 0) {
        Write-Log "No hay paquetes para instalar con perfil '$profileName'"
        return
    }

    $installedCount = 0
    $failedCount = 0

    Write-Log "Paquetes a instalar: $($packageTools.ForEach({ $_.name }) -join ', ')" "INFO"

    foreach ($tool in $packageTools) {
        if (Install-Tool -ToolName $tool.name -ToolsRegistry $allTools) {
            $installedCount++
        } else {
            $failedCount++
        }
    }

    # Refrescar PATH
    Update-SessionPath

    # Verificar herramientas críticas
    $criticalTools = @("lsd", "fzf", "fd", "ripgrep", "clink")
    $missingTools = @()
    foreach ($tool in $criticalTools) {
        if (-not (Test-ScoopPackage -PackageName $tool)) {
            $missingTools += $tool
        }
    }

    # Resumen
    if ($installedCount -gt 0) {
        Write-Log "Herramientas de productividad instaladas ($installedCount paquetes)" "SUCCESS"
        if ($failedCount -gt 0) {
            Write-Log "$failedCount paquetes fallaron en la instalación" "WARNING"
        }
    } else {
        Write-Log "No se instalaron nuevos paquetes"
    }

    if ($missingTools.Count -gt 0) {
        Write-Log "Herramientas no disponibles: $($missingTools -join ', ')" "WARNING"
    }
}
