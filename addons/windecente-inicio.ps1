#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Instala automáticamente software esencial en Windows 11 usando winget.

.DESCRIPTION
    Este script instala de forma automatizada una serie de programas útiles
    para entornos de desarrollo y productividad: Google Chrome, 7-Zip, Visual Studio Code,
    PowerShell 7 y PowerToys.

.NOTES
    - Requiere ejecución como Administrador.
    - Utiliza winget, que debe estar preinstalado en Windows 11.
    - Compatible con PowerShell 5.1 y superior.

.EXAMPLE
    iex (irm "https://raw.githubusercontent.com/LuisPalacios/devcli/main/addons/windecente-inicio.ps1")

.AUTHOR
    Luis Palacios
#>

# ============================
# Función: Verifica permisos de admin (opcional si se usa #Requires)
# ============================
function Assert-IsAdministrator {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrator')
    if (-not $isAdmin) {
        Write-Error "❌ Este script debe ejecutarse como administrador. Salida..."
        exit 1
    }
}

# ============================
# Función: Verifica que winget esté disponible
# ============================
function Assert-WingetAvailable {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Error "❌ 'winget' no está disponible. Actualiza 'App Installer' desde Microsoft Store y vuelve a intentarlo."
        exit 2
    }
}

# ============================
# Función: Instala aplicación vía winget
# ============================
function Install-App {
    param (
        [Parameter(Mandatory)]
        [string] $AppId,

        [Parameter(Mandatory)]
        [string] $AppName
    )

    Write-Host "`n🚀 Instalando $AppName..." -ForegroundColor Cyan

    $arguments = @(
        'install'
        '--id', $AppId
        '--source', 'winget'
        '--accept-package-agreements'
        '--accept-source-agreements'
        '--silent'
        '--disable-interactivity'
    )

    try {
        $process = Start-Process -FilePath 'winget' -ArgumentList $arguments -Wait -PassThru -NoNewWindow
        if ($process.ExitCode -eq 0) {
            Write-Host "✅ $AppName instalado correctamente." -ForegroundColor Green
        } else {
            Write-Warning "⚠️ Instalación de $AppName finalizó con código de salida $($process.ExitCode)."
        }
    } catch {
        Write-Error ("❌ Error al instalar {0}: {1}" -f $AppName, $_)
    }
}

# ============================
# Inicio del script
# ============================

Write-Host "=========================================" -ForegroundColor Gray
Write-Host "   Script de instalación automática" -ForegroundColor Yellow
Write-Host "   PowerShell 5.1 + winget + Admin" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Gray

Assert-IsAdministrator
Assert-WingetAvailable

$apps = @(
    @{ id = 'Google.Chrome';              name = 'Google Chrome' },
    @{ id = '7zip.7zip';                  name = '7-Zip' },
    @{ id = 'Microsoft.VisualStudioCode'; name = 'Visual Studio Code' },
    @{ id = 'Microsoft.PowerShell';       name = 'PowerShell 7' },
    @{ id = 'Microsoft.PowerToys';        name = 'PowerToys' }
)

foreach ($app in $apps) {
    Install-App -AppId $app.id -AppName $app.name
}

Write-Host "`n🎉 Todos los programas han sido procesados." -ForegroundColor Green
