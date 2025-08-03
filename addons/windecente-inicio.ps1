<#
.SYNOPSIS
    Instala automáticamente software esencial en Windows 11 usando winget.
    Se relanza como administrador si no lo está. Solo instala lo que falte.
#>

# --- Re-elevación automática ---
if (-not ([Environment]::GetEnvironmentVariable("WINDECENTE_ELEVATED"))) {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrator')) {
        Write-Host "🔁 Reiniciando PowerShell como administrador..." -ForegroundColor Yellow
        $env:WINDECENTE_ELEVATED = "1"
        $scriptUrl = 'https://raw.githubusercontent.com/LuisPalacios/devcli/main/addons/windecente-inicio.ps1'
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoExit", "-Command `"`$env:WINDECENTE_ELEVATED='1'; iex (irm '$scriptUrl')`"" -Verb RunAs
        exit
    }
}

# --- Verificar winget disponible ---
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Error "❌ 'winget' no está disponible. Abre Microsoft Store, instala App Installer, y vuelve a intentarlo."
    exit 2
}

# --- Función para verificar si ya está instalado ---
function Is-AppInstalled {
    param ([string] $AppId)
    $result = winget list --id $AppId 2>$null
    return ($result -match $AppId)
}

# --- Función para instalar apps si faltan ---
function Install-App {
    param (
        [Parameter(Mandatory)][string] $AppId,
        [Parameter(Mandatory)][string] $AppName
    )
    if (Is-AppInstalled -AppId $AppId) {
        Write-Host "✔️  $AppName ya está instalado. Omitiendo." -ForegroundColor DarkGray
        return
    }

    Write-Host "`n--> Instalando $AppName..." -ForegroundColor Cyan
    $args = @(
        'install', '--id', $AppId,
        '--source', 'winget',
        '--accept-package-agreements', '--accept-source-agreements',
        '--silent', '--disable-interactivity'
    )
    try {
        $p = Start-Process -FilePath 'winget' -ArgumentList $args -Wait -PassThru -NoNewWindow
        if ($p.ExitCode -eq 0) {
            Write-Host "✅ $AppName instalado correctamente." -ForegroundColor Green
        } else {
            Write-Warning "⚠️  $AppName terminó con código $($p.ExitCode)"
        }
    } catch {
        Write-Error ("❌ Error al instalar {0}: {1}" -f $AppName, $_)
    }
}

# --- Lista de apps a instalar ---
$apps = @(
    @{ id = 'Google.Chrome';              name = 'Google Chrome' },
    @{ id = '7zip.7zip';                  name = '7-Zip' },
    @{ id = 'Microsoft.VisualStudioCode'; name = 'Visual Studio Code' },
    @{ id = 'Microsoft.PowerShell';       name = 'PowerShell 7' },
    @{ id = 'Microsoft.PowerToys';        name = 'PowerToys' }
)

# --- Título ---
Write-Host "`n=========================================" -ForegroundColor Gray
Write-Host "   Instalador automático via winget        " -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Gray

# --- Ejecutar instalaciones ---
foreach ($app in $apps) {
    Install-App -AppId $app.id -AppName $app.name
}

Write-Host "`n🎉 Todos los programas han sido procesados." -ForegroundColor Green

