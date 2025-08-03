<#
.SYNOPSIS
    Software installer via winget with automatic elevation.
    Compatible with PowerShell 5.1 (default in Windows 10/11).
#>

# Check if running as administrator
function Is-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Auto-elevate using the script file itself
if (-not (Is-Administrator)) {
    Write-Host "Restarting PowerShell as administrator..." -ForegroundColor Yellow
    $myPath = $MyInvocation.MyCommand.Path
    Start-Process powershell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$myPath`""
    exit
}

# Handle Ctrl-C gracefully
$global:ShouldStop = $false
$null = Register-EngineEvent PowerShell.Exiting -Action {
    $global:ShouldStop = $true
}

# Verify winget is available
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Error "'winget' is not available. Install App Installer from Microsoft Store and try again."
    exit 2
}

# Check if app is already installed
function Is-AppInstalled {
    param ([string] $AppId)
    $output = winget list --id $AppId 2>$null
    return ($output -match $AppId)
}

# Install app if not present
function Install-App {
    param (
        [string] $AppId,
        [string] $AppName
    )

    if (Is-AppInstalled -AppId $AppId) {
        Write-Host "$AppName is already installed. Skipping." -ForegroundColor DarkGray
        return
    }

    Write-Host "`n--> Installing $AppName..." -ForegroundColor Cyan

    $installArgs = @(
        'install',
        '--id', $AppId,
        '--source', 'winget',
        '--accept-package-agreements',
        '--accept-source-agreements',
        '--silent',
        '--disable-interactivity'
    )

    try {
        $p = Start-Process -FilePath 'winget' -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
        if ($p.ExitCode -eq 0) {
            Write-Host "$AppName installed successfully." -ForegroundColor Green
        } else {
            Write-Warning "$AppName finished with exit code $($p.ExitCode)"
        }
    } catch {
        Write-Error "Error installing $AppName: $_"
    }
}

# List of apps to install
$apps = @(
    @{ id = 'Google.Chrome';              name = 'Google Chrome' },
    @{ id = '7zip.7zip';                  name = '7-Zip' },
    @{ id = 'Microsoft.VisualStudioCode'; name = 'Visual Studio Code' },
    @{ id = 'Microsoft.PowerShell';       name = 'PowerShell 7' },
    @{ id = 'Microsoft.PowerToys';        name = 'PowerToys' }
)

# Header
Write-Host "`n=========================================" -ForegroundColor Gray
Write-Host "  Automatic installer via winget          " -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Gray

# Main loop
foreach ($app in $apps) {
    if ($global:ShouldStop) {
        Write-Warning "`nScript interrupted by user. Exiting..."
        break
    }
    Install-App -AppId $app.id -AppName $app.name
}

Write-Host "`nAll programs have been processed." -ForegroundColor Green
