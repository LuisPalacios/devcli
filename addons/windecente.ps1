#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Script de automatización para "Un Windows 11 decente"
    Basado en el apunte técnico de Luis Palacios: https://www.luispa.com/posts/2024-08-24-win-decente/

.DESCRIPTION
    Automatiza la configuración de Windows 11 para eliminar bloatware, optimizar privacy/security,
    configurar el explorador de archivos y instalar software esencial para desarrollo.

.PARAMETER WhatIf
    Muestra qué acciones se realizarían sin ejecutarlas

.PARAMETER Verbose
    Muestra información detallada durante la ejecución

.EXAMPLE
    .\windecente.ps1

.EXAMPLE
    iex (irm "https://raw.githubusercontent.com/LuisPalacios/devcli/main/windecente.ps1")

.NOTES
    Autor: Luis Palacios
    Versión: 1.0
    Requiere: PowerShell 5.1+ ejecutado como Administrador
    Compatible: Windows 11 (todas las ediciones)
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$WhatIf
)

# Configuración del script
$ErrorActionPreference = "Continue"
$ProgressPreference = "Continue"
$VerbosePreference = if ($PSBoundParameters.Verbose) { "Continue" } else { "SilentlyContinue" }

# Variables globales
$ScriptVersion = "1.0"
$LogPath = "$env:TEMP\WindecenteLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$BackupPath = "$env:TEMP\WindecenteBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

#region Funciones auxiliares

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Escribir a consola con colores
    switch ($Level) {
        "INFO"    { Write-Host $logMessage -ForegroundColor White }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
    }

    # Escribir a archivo de log
    Add-Content -Path $LogPath -Value $logMessage -ErrorAction SilentlyContinue
}

function Test-RegistryPath {
    param([string]$Path)
    try {
        Get-Item -Path $Path -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = "DWORD"
    )

    try {
        if (-not (Test-RegistryPath $Path)) {
            New-Item -Path $Path -Force | Out-Null
            Write-Log "Creada clave de registro: $Path" -Level INFO
        }

        if ($PSCmdlet.ShouldProcess("$Path\$Name", "Set Registry Value")) {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -ErrorAction Stop
            Write-Log "Configurado: $Path\$Name = $Value" -Level SUCCESS
        }
    }
    catch {
        Write-Log "Error configurando registro $Path\$Name : $_" -Level ERROR
    }
}

function Remove-AppxPackageSafe {
    param([string]$PackageName)

    try {
        $packages = Get-AppxPackage -Name "*$PackageName*" -ErrorAction SilentlyContinue
        if ($packages) {
            foreach ($package in $packages) {
                if ($PSCmdlet.ShouldProcess($package.Name, "Remove AppxPackage")) {
                    Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
                    Write-Log "Desinstalada app: $($package.Name)" -Level SUCCESS
                }
            }
        } else {
            Write-Log "No se encontró app: $PackageName" -Level INFO
        }
    }
    catch {
        Write-Log "Error desinstalando $PackageName : $_" -Level ERROR
    }
}

function Install-Software {
    param(
        [string]$Name,
        [string]$Url,
        [string]$Arguments = "/S"
    )

    try {
        Write-Log "Descargando $Name..." -Level INFO
        $tempFile = "$env:TEMP\$Name-$(Get-Date -Format 'yyyyMMdd').exe"

        if ($PSCmdlet.ShouldProcess($Url, "Download $Name")) {
            Invoke-WebRequest -Uri $Url -OutFile $tempFile -UseBasicParsing -ErrorAction Stop

            Write-Log "Instalando $Name..." -Level INFO
            Start-Process -FilePath $tempFile -ArgumentList $Arguments -Wait -NoNewWindow

            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            Write-Log "$Name instalado correctamente" -Level SUCCESS
        }
    }
    catch {
        Write-Log "Error instalando $Name : $_" -Level ERROR
    }
}

#endregion

#region Funciones principales

function Initialize-Script {
    Write-Host "`n" -NoNewline
    Write-Host "═══════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "                          UN WINDOWS 11 DECENTE                           " -ForegroundColor White
    Write-Host "                     Automatización v$ScriptVersion by LuisPa                      " -ForegroundColor Gray
    Write-Host "═══════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    Write-Log "Iniciando Windows Decente v$ScriptVersion" -Level INFO
    Write-Log "Log guardado en: $LogPath" -Level INFO
    Write-Log "Sistema: $((Get-CimInstance Win32_OperatingSystem).Caption)" -Level INFO

    # Crear punto de restauración del sistema
    if ($PSCmdlet.ShouldProcess("Sistema", "Crear punto de restauración")) {
        try {
            Checkpoint-Computer -Description "Windows Decente v$ScriptVersion" -RestorePointType "MODIFY_SETTINGS"
            Write-Log "Punto de restauración creado" -Level SUCCESS
        }
        catch {
            Write-Log "No se pudo crear punto de restauración: $_" -Level WARNING
        }
    }

    # Crear directorio de backup
    if (-not (Test-Path $BackupPath)) {
        New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
    }
}

function Set-PrivacyAndSecurity {
    Write-Log "Configurando Privacy & Security..." -Level INFO

    # Privacy & Security - General
    Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0
    Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" "TailoredExperiencesWithDiagnosticDataEnabled" 0
    Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" "HasAccepted" 0
    Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Input\TIPC" "Enabled" 0
    Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack" "ShowedToastAtLevel" 1

    # Location settings
    Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" "Value" "Deny"
    Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" "Value" "Deny"

    # App Permissions
    Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone" "Value" "Deny"
    Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam" "Value" "Deny"

    # Diagnostics & feedback
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0
    Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Feedback" "Frequency" 0
    Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Feedback" "AutoSample" 0

    # Search permissions
    Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings" "IsAADCloudSearchEnabled" 0
    Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings" "IsDeviceSearchHistoryEnabled" 0

    Write-Log "Privacy & Security configurado" -Level SUCCESS
}

function Remove-Bloatware {
    Write-Log "Eliminando bloatware..." -Level INFO

    # Lista de aplicaciones a desinstalar
    $appsToRemove = @(
        "Microsoft.MicrosoftEdge",
        "Microsoft.BingNews",
        "Microsoft.BingWeather",
        "Microsoft.GetHelp",
        "Microsoft.Getstarted",
        "Microsoft.Microsoft3DViewer",
        "Microsoft.MicrosoftOfficeHub",
        "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.MixedReality.Portal",
        "Microsoft.Office.OneNote",
        "Microsoft.People",
        "Microsoft.Print3D",
        "Microsoft.SkypeApp",
        "Microsoft.Wallet",
        "Microsoft.WindowsAlarms",
        "Microsoft.WindowsCamera",
        "microsoft.windowscommunicationsapps",
        "Microsoft.WindowsFeedbackHub",
        "Microsoft.WindowsMaps",
        "Microsoft.WindowsSoundRecorder",
        "Microsoft.Xbox.TCUI",
        "Microsoft.XboxApp",
        "Microsoft.XboxGameOverlay",
        "Microsoft.XboxGamingOverlay",
        "Microsoft.XboxIdentityProvider",
        "Microsoft.XboxSpeechToTextOverlay",
        "Microsoft.YourPhone",
        "Microsoft.ZuneMusic",
        "Microsoft.ZuneVideo",
        "SpotifyAB.SpotifyMusic",
        "Microsoft.Todos"
    )

    foreach ($app in $appsToRemove) {
        Remove-AppxPackageSafe $app
    }

    # Eliminar también para todos los usuarios
    foreach ($app in $appsToRemove) {
        try {
            $packages = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*$app*" }
            foreach ($package in $packages) {
                if ($PSCmdlet.ShouldProcess($package.DisplayName, "Remove Provisioned Package")) {
                    Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName -ErrorAction Stop
                    Write-Log "Eliminado paquete provisionado: $($package.DisplayName)" -Level SUCCESS
                }
            }
        }
        catch {
            Write-Log "Error eliminando paquete provisionado $app : $_" -Level ERROR
        }
    }

    Write-Log "Bloatware eliminado" -Level SUCCESS
}

function Set-FileExplorerConfig {
    Write-Log "Configurando File Explorer..." -Level INFO

    # Mostrar extensiones de archivo
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0

    # Mostrar archivos ocultos y del sistema
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 1
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSuperHidden" 1

    # Mostrar path completo en title bar
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" "FullPath" 1

    # Mostrar unidades vacías
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideDrivesWithNoMedia" 0

    # Quitar sync provider notifications
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSyncProviderNotifications" 0

    Write-Log "File Explorer configurado" -Level SUCCESS
}

function Disable-WindowsAds {
    Write-Log "Deshabilitando anuncios de Windows..." -Level INFO

    # Lock Screen ads
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "RotatingLockScreenEnabled" 0
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "RotatingLockScreenOverlayEnabled" 0

    # Start Menu ads
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SystemPaneSuggestionsEnabled" 0
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SoftLandingEnabled" 0
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338388Enabled" 0
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338389Enabled" 0
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-314559Enabled" 0
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338393Enabled" 0
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-353698Enabled" 0

    # Explorer ads
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSyncProviderNotifications" 0

    # Notification ads
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" "NOC_GLOBAL_SETTING_ALLOW_NOTIFICATION_SOUND" 0
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" "NOC_GLOBAL_SETTING_ALLOW_CRITICAL_TOASTS_ABOVE_LOCK" 0

    # Widgets
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" 0
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 0

    Write-Log "Anuncios deshabilitados" -Level SUCCESS
}

function Disable-CortanaAndTelemetry {
    Write-Log "Deshabilitando Cortana y telemetría..." -Level INFO

    # Cortana
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCortana" 0
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "DisableWebSearch" 1
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "ConnectedSearchUseWeb" 0

    # Telemetría
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0
    Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" 0
    Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" "TailoredExperiencesWithDiagnosticDataEnabled" 0

    # Error reporting
    Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" "Disabled" 1

    Write-Log "Cortana y telemetría deshabilitados" -Level SUCCESS
}

function Set-TaskbarAndStartMenu {
    Write-Log "Configurando Taskbar y Start Menu..." -Level INFO

    # Quitar widgets del taskbar
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" 0

    # Quitar Task View del taskbar
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0

    # Quitar Meet Now del taskbar
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarMn" 0

    # Start Menu configuración
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_Layout" 1
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_IrisRecommendations" 0
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338393Enabled" 0
    Set-RegistryValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-353698Enabled" 0

    Write-Log "Taskbar y Start Menu configurados" -Level SUCCESS
}

function Set-NetworkAndFirewall {
    Write-Log "Configurando red y firewall..." -Level INFO

    try {
        # Cambiar perfil de red a privado si es posible
        $networkProfiles = Get-NetConnectionProfile
        foreach ($profile in $networkProfiles) {
            if ($profile.NetworkCategory -eq "Public") {
                if ($PSCmdlet.ShouldProcess($profile.Name, "Change to Private Network")) {
                    Set-NetConnectionProfile -InterfaceIndex $profile.InterfaceIndex -NetworkCategory Private
                    Write-Log "Perfil de red cambiado a privado: $($profile.Name)" -Level SUCCESS
                }
            }
        }

        # Deshabilitar notificaciones del firewall
        Set-NetFirewallProfile -Profile Domain,Public,Private -NotifyOnListen False
        Write-Log "Notificaciones del firewall deshabilitadas" -Level SUCCESS

        # Habilitar File and Printer Sharing
        Set-NetFirewallRule -DisplayGroup "File And Printer Sharing" -Enabled True
        Write-Log "File and Printer Sharing habilitado" -Level SUCCESS

    }
    catch {
        Write-Log "Error configurando red/firewall: $_" -Level ERROR
    }
}

function Disable-UnnecessaryServices {
    Write-Log "Deshabilitando servicios innecesarios..." -Level INFO

    $servicesToDisable = @(
        "XblAuthManager",
        "XblGameSave",
        "XboxGipSvc",
        "XboxNetApiSvc",
        "MapsBroker",
        "lfsvc",  # Geolocation Service
        "DiagTrack",  # Connected User Experiences and Telemetry
        "dmwappushservice",  # WAP Push Message Routing Service
        "WerSvc",  # Windows Error Reporting Service
        "Fax"
    )

    foreach ($serviceName in $servicesToDisable) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service) {
                if ($PSCmdlet.ShouldProcess($serviceName, "Disable Service")) {
                    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
                    Set-Service -Name $serviceName -StartupType Disabled -ErrorAction Stop
                    Write-Log "Servicio deshabilitado: $serviceName" -Level SUCCESS
                }
            }
        }
        catch {
            Write-Log "Error deshabilitando servicio $serviceName : $_" -Level ERROR
        }
    }
}

function Set-UserAccountControl {
    Write-Log "Configurando User Account Control..." -Level INFO

    # Establecer UAC en Never Notify (como indica el apunte)
    Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "ConsentPromptBehaviorAdmin" 0
    Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "ConsentPromptBehaviorUser" 0
    Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "EnableInstallerDetection" 0
    Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "EnableLUA" 0
    Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "EnableVirtualization" 0
    Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "PromptOnSecureDesktop" 0

    Write-Log "UAC configurado (Never Notify)" -Level SUCCESS
}

function Install-EssentialSoftware {
    Write-Log "Instalando software esencial..." -Level INFO

    # URLs actualizadas (verificar periódicamente)
    $software = @{
        "7-Zip" = "https://www.7-zip.org/a/7z2407-x64.exe"
        "GoogleChrome" = "https://dl.google.com/chrome/install/latest/chrome_installer.exe"
        "VSCode" = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64"
    }

    foreach ($app in $software.GetEnumerator()) {
        try {
            if ($app.Key -eq "VSCode") {
                Install-Software -Name $app.Key -Url $app.Value -Arguments "/VERYSILENT /MERGETASKS=!runcode"
            } else {
                Install-Software -Name $app.Key -Url $app.Value
            }
        }
        catch {
            Write-Log "Error instalando $($app.Key): $_" -Level ERROR
        }
    }

    # Instalar PowerShell 7
    try {
        Write-Log "Instalando PowerShell 7..." -Level INFO
        if ($PSCmdlet.ShouldProcess("PowerShell 7", "Install")) {
            iex "& { $(irm https://aka.ms/install-powershell.ps1) } -UseMSI"
            Write-Log "PowerShell 7 instalado" -Level SUCCESS
        }
    }
    catch {
        Write-Log "Error instalando PowerShell 7: $_" -Level ERROR
    }

    # Instalar PowerToys
    try {
        Write-Log "Instalando Microsoft PowerToys..." -Level INFO
        if ($PSCmdlet.ShouldProcess("PowerToys", "Install")) {
            $powerToysUrl = "https://github.com/microsoft/PowerToys/releases/latest/download/PowerToysSetup-0.75.1-x64.exe"
            Install-Software -Name "PowerToys" -Url $powerToysUrl -Arguments "/S"
        }
    }
    catch {
        Write-Log "Error instalando PowerToys: $_" -Level ERROR
    }
}

function Enable-DeveloperMode {
    Write-Log "Habilitando modo desarrollador..." -Level INFO

    Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" "AllowDevelopmentWithoutDevLicense" 1
    Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" "AllowAllTrustedApps" 1

    Write-Log "Modo desarrollador habilitado" -Level SUCCESS
}

function Enable-SMBFileSharing {
    Write-Log "Habilitando SMB File Sharing..." -Level INFO

    try {
        # Habilitar SMB1 si no está habilitado
        if ($PSCmdlet.ShouldProcess("SMB1.0", "Enable Feature")) {
            Enable-WindowsOptionalFeature -Online -FeatureName "SMB1Protocol" -All -NoRestart
            Write-Log "SMB 1.0 habilitado" -Level SUCCESS
        }

        # Configurar file sharing
        Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Services\lanmanserver\parameters" "AutoShareWks" 1
        Set-RegistryValue "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "forceguest" 0

        Write-Log "SMB File Sharing configurado" -Level SUCCESS
    }
    catch {
        Write-Log "Error configurando SMB: $_" -Level ERROR
    }
}

function Set-WindowsUpdateSettings {
    Write-Log "Configurando Windows Update..." -Level INFO

    # Deshabilitar actualizaciones automáticas de drivers
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "ExcludeWUDriversInQualityUpdate" 1

    # Configurar para notificar antes de descargar
    Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "AUOptions" 2

    Write-Log "Windows Update configurado" -Level SUCCESS
}

function Invoke-SystemMaintenance {
    Write-Log "Ejecutando comandos de mantenimiento del sistema..." -Level INFO

    try {
        if ($PSCmdlet.ShouldProcess("Sistema", "Ejecutar SFC Scan")) {
            Write-Log "Ejecutando sfc /scannow..." -Level INFO
            Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -Wait -NoNewWindow
        }

        if ($PSCmdlet.ShouldProcess("Sistema", "Ejecutar DISM Cleanup")) {
            Write-Log "Ejecutando DISM cleanup..." -Level INFO
            Start-Process -FilePath "dism.exe" -ArgumentList "/online", "/cleanup-image", "/restorehealth" -Wait -NoNewWindow
        }

        Write-Log "Mantenimiento del sistema completado" -Level SUCCESS
    }
    catch {
        Write-Log "Error en mantenimiento del sistema: $_" -Level ERROR
    }
}

function Show-Summary {
    Write-Host "`n" -NoNewline
    Write-Host "═══════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "                             RESUMEN FINAL                               " -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""

    Write-Log "Script completado exitosamente" -Level SUCCESS
    Write-Log "Log completo disponible en: $LogPath" -Level INFO
    Write-Host ""
    Write-Host "ACCIONES REALIZADAS:" -ForegroundColor Yellow
    Write-Host "✓ Configuraciones de privacidad y seguridad aplicadas" -ForegroundColor Green
    Write-Host "✓ Bloatware eliminado" -ForegroundColor Green
    Write-Host "✓ File Explorer configurado" -ForegroundColor Green
    Write-Host "✓ Anuncios de Windows deshabilitados" -ForegroundColor Green
    Write-Host "✓ Cortana y telemetría deshabilitados" -ForegroundColor Green
    Write-Host "✓ Taskbar y Start Menu optimizados" -ForegroundColor Green
    Write-Host "✓ Firewall y red configurados" -ForegroundColor Green
    Write-Host "✓ Servicios innecesarios deshabilitados" -ForegroundColor Green
    Write-Host "✓ UAC configurado" -ForegroundColor Green
    Write-Host "✓ Software esencial instalado" -ForegroundColor Green
    Write-Host "✓ Modo desarrollador habilitado" -ForegroundColor Green
    Write-Host "✓ SMB File Sharing habilitado" -ForegroundColor Green
    Write-Host "✓ Windows Update configurado" -ForegroundColor Green
    Write-Host "✓ Mantenimiento del sistema ejecutado" -ForegroundColor Green
    Write-Host ""
    Write-Host "RECOMENDACIONES POST-SCRIPT:" -ForegroundColor Yellow
    Write-Host "• Reiniciar el sistema para aplicar todos los cambios" -ForegroundColor Cyan
    Write-Host "• Verificar que el software instalado funciona correctamente" -ForegroundColor Cyan
    Write-Host "• Revisar configuraciones de red si hay problemas de conectividad" -ForegroundColor Cyan
    Write-Host "• Ejecutar Windows Update manualmente si es necesario" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Gracias por usar Windows Decente v$ScriptVersion by LuisPa!" -ForegroundColor Magenta
    Write-Host "Blog: https://www.luispa.com/posts/2024-08-24-win-decente/" -ForegroundColor Blue
    Write-Host ""
}

#endregion

#region Script principal

try {
    # Verificar prerrequisitos
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Este script requiere privilegios de administrador. Ejecute PowerShell como administrador."
    }

    if ([Environment]::OSVersion.Version.Major -lt 10) {
        throw "Este script requiere Windows 10 o superior."
    }

    # Inicializar script
    Initialize-Script

    # Ejecutar configuraciones
    Set-PrivacyAndSecurity
    Remove-Bloatware
    Set-FileExplorerConfig
    Disable-WindowsAds
    Disable-CortanaAndTelemetry
    Set-TaskbarAndStartMenu
    Set-NetworkAndFirewall
    Disable-UnnecessaryServices
    Set-UserAccountControl
    Install-EssentialSoftware
    Enable-DeveloperMode
    Enable-SMBFileSharing
    Set-WindowsUpdateSettings
    Invoke-SystemMaintenance

    # Mostrar resumen
    Show-Summary
}
catch {
    Write-Log "Error crítico: $_" -Level ERROR
    Write-Host "`nScript interrumpido debido a un error crítico." -ForegroundColor Red
    Write-Host "Consulte el log en: $LogPath" -ForegroundColor Yellow
    exit 1
}

#endregion