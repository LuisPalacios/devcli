#Requires -Version 7.0
#
# Fase 05 — Atajos de teclado personalizados (custom_keys), sólo Windows.
#
# Opt-in: bootstrap.ps1 -CustomKeys on|off|force. La elección se recuerda en
# ~/.config/devcli/state.json, así que los bootstraps siguientes la mantienen
# sin repetir el parámetro. Sin activarla, esta fase no toca nada.
#
# Con la capa activa:
#   1. PowerToys: lo instala si falta (winget, por usuario) y comprueba que
#      arranca con Windows y que Keyboard Manager está encendido.
#   2. Despliega la pareja de ficheros que forman el contrato:
#        dotfiles/custom_keys.lua             → ~/.config/wezterm/custom_keys.lua
#        dotfiles/custom_keys.powertoys.json  → Keyboard Manager\<perfil activo>.json
#      con política «seed»: escribe si el destino no existe, si sigue igual a
#      lo que devcli desplegó la última vez o si nunca lo desplegó devcli
#      (con copia de seguridad). Si el usuario lo cambió, avisa y no lo toca
#      (salvo -CustomKeys force).
#   3. Mueve el atajo del editor de Keyboard Manager a Win+Ctrl+Shift+Q: con
#      Win = Option, Win+Shift+Q se pulsa sin querer y el editor abierto
#      suspende todos los atajos.
#   4. Pide a PowerToys que recargue el mapa.
#
# Los símbolos de Option (| @ # ~ € [ ] { } \) sólo se incluyen con
# disposición de teclado española de España.
#
# Códigos de salida: 0=ok, 1=warn, 2=fail.

[CmdletBinding()]
param(
    # Rutas sobrescribibles para probar la fase sin tocar el sistema real.
    [string]$StateFile         = (Join-Path $env:USERPROFILE '.config\devcli\state.json'),
    [string]$BackupRoot        = (Join-Path $env:USERPROFILE '.config\devcli\backups'),
    [string]$WezTermDir        = (Join-Path $env:USERPROFILE '.config\wezterm'),
    [string]$PowerToysDataDir  = (Join-Path $env:LOCALAPPDATA 'Microsoft\PowerToys'),
    # Sólo despliega ficheros: ni instala, ni arranca, ni recarga PowerToys.
    [switch]$NoPowerToysProcess
)

# Modo estricto: caza typos en variables y accesos a propiedades nulas.
Set-StrictMode -Version Latest

. "$PSScriptRoot\env.ps1"
. "$PSScriptRoot\utils.ps1"

Initialize-Ux

$phaseNum   = [int]($env:PHASE_NUM ?? 5)
$phaseTotal = [int]($env:PHASE_TOTAL ?? 5)
$phaseTitle = 'Atajos de teclado'

$dotfilesDir = Join-Path $Global:SETUP_DIR 'dotfiles'
$srcLua      = Join-Path $dotfilesDir 'custom_keys.lua'
$srcMap      = Join-Path $dotfilesDir 'custom_keys.powertoys.json'
$kmDir       = Join-Path $PowerToysDataDir 'Keyboard Manager'
$utf8NoBom   = [Text.UTF8Encoding]::new($false)

# Atajo del editor que deja devcli: Win+Ctrl+Shift+Q (81 = Q).
$EDITOR_SHORTCUT = [ordered]@{ win = $true; ctrl = $true; alt = $false; shift = $true; code = 81; key = '' }
$EDITOR_PROCESSES = @('PowerToys.KeyboardManagerEditorUI', 'PowerToys.KeyboardManagerEditor')
$RELOAD_EVENT = 'PowerToys_KeyboardManager_Event_Settings'

# Notas para el resumen final del bootstrap (Show-UxSummary).
$script:Notes = [System.Collections.Generic.List[string]]::new()
$script:Warned = $false
function Add-Warn([string]$Message) { Write-UxWarn -Message $Message; $script:Warned = $true }

# ─── Estado persistente ────────────────────────────────────────────────────

function Read-State {
    if (Test-Path $StateFile) {
        try { return (Get-Content $StateFile -Raw | ConvertFrom-Json -AsHashtable) ?? @{} }
        catch { Add-Warn "estado ilegible ($StateFile), se rehace: $($_.Exception.Message)" }
    }
    return @{}
}

function Save-State([hashtable]$State) {
    $dir = Split-Path $StateFile -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    [IO.File]::WriteAllText($StateFile, ($State | ConvertTo-Json -Depth 10) + "`n", $utf8NoBom)
}

function Get-TextHash([string]$Text) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($utf8NoBom.GetBytes($Text)))
}

function Get-FileHashHex([string]$Path) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($Path)))
}

# ─── Copias de seguridad (una carpeta por ejecución, creada al primer uso) ─

$script:BackupDir = $null
function Backup-File([string]$Path, [string]$Name) {
    if (-not (Test-Path $Path)) { return }
    if (-not $script:BackupDir) {
        $script:BackupDir = Join-Path $BackupRoot ("custom-keys-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
        New-Item -ItemType Directory -Force $script:BackupDir | Out-Null
    }
    Copy-Item $Path (Join-Path $script:BackupDir $Name) -Force
}

# ─── Política seed ─────────────────────────────────────────────────────────
#
# Devuelve: created | unchanged | updated | replaced | kept | forced
#   kept = el usuario lo cambió desde el último despliegue; no se toca.
function Set-SeededFile {
    param(
        [Parameter(Mandatory)][hashtable]$Deployed,   # clave → hash de lo desplegado
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content,
        [string]$BackupName = (Split-Path $Path -Leaf),
        [switch]$Force
    )
    $newHash = Get-TextHash $Content
    $recorded = $Deployed[$Key]
    $status = 'created'

    if (Test-Path $Path) {
        $current = Get-FileHashHex $Path
        if ($current -eq $newHash) {
            $Deployed[$Key] = $newHash
            return 'unchanged'
        }
        if ($recorded -and $current -ne $recorded) {
            if (-not $Force) { return 'kept' }
            $status = 'forced'
        }
        elseif ($recorded) { $status = 'updated' }
        else { $status = 'replaced' }   # existía y devcli nunca lo desplegó
        Backup-File $Path $BackupName
    }
    else {
        $dir = Split-Path $Path -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    }

    [IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
    $Deployed[$Key] = $newHash
    return $status
}

function Test-Written([string]$Status) { $Status -in 'created', 'updated', 'replaced', 'forced' }

# ─── Disposición de teclado ────────────────────────────────────────────────

# $true si la disposición principal del usuario es la española de España.
# Preload\1 es el primer idioma; Substitutes dice qué teclado usa de verdad.
function Test-SpanishKeyboard {
    try {
        $preload = (Get-ItemProperty 'HKCU:\Keyboard Layout\Preload' -Name '1' -ErrorAction Stop).'1'
        $klid = $preload
        $subst = Get-ItemProperty 'HKCU:\Keyboard Layout\Substitutes' -Name $preload -ErrorAction SilentlyContinue
        if ($subst) { $klid = $subst.$preload }
        return $klid -in '0000040a', '00000c0a'
    }
    catch { return $false }
}

# Quita la capa de símbolos: entradas globales cuyo destino empieza por AltGr.
function Remove-SymbolLayer([string]$Json) {
    $map = $Json | ConvertFrom-Json -AsHashtable
    $map.remapShortcuts.global = @($map.remapShortcuts.global | Where-Object { -not $_.newRemapKeys.StartsWith('165;') })
    return ($map | ConvertTo-Json -Depth 10) + "`n"
}

# ─── PowerToys ─────────────────────────────────────────────────────────────

function Find-PowerToys {
    foreach ($p in @((Join-Path $env:LOCALAPPDATA 'PowerToys\PowerToys.exe'),
                     (Join-Path $env:ProgramFiles 'PowerToys\PowerToys.exe'))) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Test-PowerToysRunning { [bool](Get-Process PowerToys -ErrorAction SilentlyContinue) }

# Arranca PowerToys. Si existe su tarea de autoarranque, se usa: respeta la
# elevación que el usuario eligió («ejecutar como administrador») sin UAC.
function Start-PowerToys([string]$Exe) {
    $task = "\PowerToys\Autorun for $env:USERNAME"
    $null = & schtasks.exe /Query /TN $task 2>$null
    if ($LASTEXITCODE -eq 0) {
        $null = & schtasks.exe /Run /TN $task 2>$null
        if ($LASTEXITCODE -eq 0) { return }
    }
    Start-Process -FilePath $Exe | Out-Null
}

function Wait-Until([scriptblock]$Condition, [int]$Seconds = 20) {
    for ($i = 0; $i -lt $Seconds; $i++) {
        if (& $Condition) { return $true }
        Start-Sleep -Seconds 1
    }
    return [bool](& $Condition)
}

# Comprueba startup y Keyboard Manager en el settings.json general. Con
# PowerToys en marcha no se edita (lo reescribe él): sólo se avisa.
function Confirm-PowerToysSettings {
    $general = Join-Path $PowerToysDataDir 'settings.json'
    if (-not (Test-Path $general)) {
        Add-Warn 'PowerToys aún no ha creado su configuración: ábrelo una vez y repite el bootstrap'
        return
    }
    $s = Get-Content $general -Raw | ConvertFrom-Json -AsHashtable
    $startupOk = ($s.ContainsKey('startup') -and $s.startup)
    $kmOk = (-not $s.ContainsKey('enabled')) -or (-not $s.enabled.ContainsKey('Keyboard Manager')) -or $s.enabled['Keyboard Manager']
    if ($startupOk -and $kmOk) { return }

    if (Test-PowerToysRunning) {
        if (-not $startupOk) { Add-Warn 'PowerToys no arranca con Windows: actívalo en PowerToys → General' }
        if (-not $kmOk) { Add-Warn 'Keyboard Manager está apagado: actívalo en PowerToys → Keyboard Manager' }
        return
    }
    Backup-File $general 'powertoys-settings.json'
    $s.startup = $true
    if (-not $s.ContainsKey('enabled')) { $s.enabled = @{} }
    $s.enabled['Keyboard Manager'] = $true
    [IO.File]::WriteAllText($general, ($s | ConvertTo-Json -Depth 10 -Compress), $utf8NoBom)
    $script:Notes.Add('PowerToys: arranque con Windows y Keyboard Manager activados')
}

# Lee settings.json de Keyboard Manager (o lo crea mínimo).
function Read-KmSettings([string]$Path) {
    if (Test-Path $Path) { return Get-Content $Path -Raw | ConvertFrom-Json -AsHashtable }
    return @{
        properties = @{
            activeConfiguration    = @{ value = 'default' }
            keyboardConfigurations = @{ value = @('default') }
        }
        name    = 'Keyboard Manager'
        version = '1'
    }
}

# Pone EditorShortcut = Win+Ctrl+Shift+Q editando el JSON. $true si cambió.
function Set-EditorShortcut([string]$Path, [hashtable]$Settings) {
    $props = $Settings.properties
    $current = if ($props.ContainsKey('EditorShortcut')) { $props.EditorShortcut } else { $null }
    if ($current) {
        $same = $true
        foreach ($k in $EDITOR_SHORTCUT.Keys) {
            if (-not $current.ContainsKey($k) -or $current[$k] -ne $EDITOR_SHORTCUT[$k]) { $same = $false; break }
        }
        if ($same) { return $false }
    }
    Backup-File $Path 'keyboard-manager-settings.json'
    $props.EditorShortcut = $EDITOR_SHORTCUT
    [IO.File]::WriteAllText($Path, ($Settings | ConvertTo-Json -Depth 10 -Compress), $utf8NoBom)
    return $true
}

# Recarga: el evento si sólo cambió el mapa; reinicio si cambió el atajo del
# editor (sólo se lee al arrancar). Devuelve $true si PowerToys ya usa lo nuevo.
function Invoke-PowerToysReload([string]$Exe, [bool]$NeedRestart) {
    if (-not (Test-PowerToysRunning)) {
        Start-PowerToys $Exe
        return (Wait-Until { [bool](Get-Process PowerToys.KeyboardManagerEngine -ErrorAction SilentlyContinue) })
    }
    if (-not $NeedRestart) {
        try {
            $ev = [Threading.EventWaitHandle]::OpenExisting($RELOAD_EVENT)
            $null = $ev.Set()
            $ev.Dispose()
            return $true
        }
        catch {
            Write-Log "evento de recarga no disponible: $($_.Exception.Message)"
        }
    }
    # Reinicio. Si no hay permisos para pararlo, se devuelve $false y se avisa.
    try {
        Get-Process PowerToys -ErrorAction Stop | Stop-Process -Force -ErrorAction Stop
    }
    catch {
        return $false
    }
    $null = Wait-Until { -not (Test-PowerToysRunning) } 10
    Start-PowerToys $Exe
    return (Wait-Until { [bool](Get-Process PowerToys.KeyboardManagerEngine -ErrorAction SilentlyContinue) })
}

# ─── Fase ──────────────────────────────────────────────────────────────────

Start-UxPhase -Num $phaseNum -Total $phaseTotal -Title $phaseTitle

$state = Read-State
if (-not $state.ContainsKey('customKeys') -or $state.customKeys -isnot [hashtable]) { $state.customKeys = @{} }
$ck = $state.customKeys
if (-not $ck.ContainsKey('deployed') -or $ck.deployed -isnot [hashtable]) { $ck.deployed = @{} }

$mode = ($env:DEVCLI_CUSTOM_KEYS ?? '').ToLowerInvariant()
switch ($mode) {
    'on'    { $ck.enabled = $true }
    'force' { $ck.enabled = $true }
    'off'   { $ck.enabled = $false }
    ''      { }
    default {
        Write-UxError -Message "valor de -CustomKeys no válido: $mode (on | off | force)"
        Complete-UxPhase -Status fail
        exit 2
    }
}
$enabled = $ck.ContainsKey('enabled') -and $ck.enabled
$force = ($mode -eq 'force')

try { Save-State $state }
catch {
    Write-UxError -Message "no se pudo guardar $StateFile ($($_.Exception.Message))"
    Complete-UxPhase -Status fail
    exit 2
}

if (-not $enabled) {
    $env:DEVCLI_CUSTOMKEYS_STATUS = 'off'
    Complete-UxPhase -Status ok -Details 'desactivada (bootstrap -CustomKeys on)'
    exit 0
}

foreach ($src in $srcLua, $srcMap) {
    if (-not (Test-Path $src)) {
        Write-UxError -Message "fichero fuente no encontrado: $src"
        Complete-UxPhase -Status fail
        exit 2
    }
}

# 1. PowerToys instalado.
$ptExe = $null
if (-not $NoPowerToysProcess) {
    Write-UxProgress -Current 1 -Total 4 -Item 'PowerToys'
    $ptExe = Find-PowerToys
    if (-not $ptExe) {
        $null = Install-WingetPackage -PackageId 'Microsoft.PowerToys' -Name 'PowerToys' `
            -ExtraArgs @('--exact', '--source', 'winget', '--scope', 'user')
        $ptExe = Find-PowerToys
        if ($ptExe) {
            $script:Notes.Add('PowerToys instalado (por usuario)')
            # Primer arranque: crea su configuración.
            if (-not (Test-PowerToysRunning)) { Start-PowerToys $ptExe }
            $null = Wait-Until { Test-Path (Join-Path $PowerToysDataDir 'settings.json') } 30
        }
        else {
            Add-Warn 'PowerToys no está instalado: instálalo (winget install Microsoft.PowerToys --scope user) y repite el bootstrap'
        }
    }
    if ($ptExe) { Confirm-PowerToysSettings }
}

# 2a. Mitad WezTerm: custom_keys.lua.
Write-UxProgress -Current 2 -Total 4 -Item 'custom_keys.lua'
$luaDst = Join-Path $WezTermDir 'custom_keys.lua'
$luaStatus = Set-SeededFile -Deployed $ck.deployed -Key 'wezterm/custom_keys.lua' -Path $luaDst `
    -Content ([IO.File]::ReadAllText($srcLua)) -Force:$force
if ($luaStatus -eq 'kept') {
    Add-Warn "custom_keys.lua editado a mano: no se toca (bootstrap -CustomKeys force lo reescribe)"
}

# 2b. Mitad PowerToys: mapa de Keyboard Manager.
$mapStatus = 'skipped'
$shortcutChanged = $false
$symbols = Test-SpanishKeyboard
$editorOpen = @(Get-Process $EDITOR_PROCESSES -ErrorAction SilentlyContinue).Count -gt 0

if ($editorOpen) {
    Add-Warn 'el editor de Keyboard Manager está abierto (suspende los atajos y pisa los cambios al guardar): ciérralo y repite el bootstrap'
}
elseif ($NoPowerToysProcess -or $ptExe) {
    Write-UxProgress -Current 3 -Total 4 -Item 'Keyboard Manager'
    $kmSettingsPath = Join-Path $kmDir 'settings.json'
    $kmSettings = Read-KmSettings $kmSettingsPath
    $profileName = 'default'
    if ($kmSettings.properties.ContainsKey('activeConfiguration') -and $kmSettings.properties.activeConfiguration.value) {
        $profileName = [string]$kmSettings.properties.activeConfiguration.value
    }
    $mapJson = [IO.File]::ReadAllText($srcMap)
    if (-not $symbols) { $mapJson = Remove-SymbolLayer $mapJson }

    $mapDst = Join-Path $kmDir "$profileName.json"
    $mapStatus = Set-SeededFile -Deployed $ck.deployed -Key "powertoys/$profileName.json" -Path $mapDst `
        -Content $mapJson -BackupName "keyboard-manager-$profileName.json" -Force:$force
    if ($mapStatus -eq 'kept') {
        Add-Warn "mapa de Keyboard Manager ($profileName.json) editado a mano: no se toca (bootstrap -CustomKeys force lo reescribe)"
    }
    if (Test-Written $mapStatus) {
        # El editor guarda una copia privada del mapa y la reescribe al abrirse;
        # sin ella la reconstruye desde el mapa, y no resucitan reglas viejas.
        $editorCopy = Join-Path $kmDir 'editorSettings.json'
        if (Test-Path $editorCopy) {
            Backup-File $editorCopy 'keyboard-manager-editorSettings.json'
            Remove-Item $editorCopy -Force
        }
    }
    $shortcutChanged = Set-EditorShortcut $kmSettingsPath $kmSettings
}

# 3. Recarga.
$pendingRestart = $false
if ($ptExe -and -not $NoPowerToysProcess -and ((Test-Written $mapStatus) -or $shortcutChanged)) {
    Write-UxProgress -Current 4 -Total 4 -Item 'recarga'
    if (-not (Invoke-PowerToysReload $ptExe $shortcutChanged)) {
        $pendingRestart = $true
        Add-Warn 'reinicia PowerToys (icono de la bandeja → Salir, y ábrelo) para que lea el mapa y el atajo del editor'
    }
}

$ck.lastRun = (Get-Date).ToString('s')
try { Save-State $state } catch { Add-Warn "no se pudo guardar $StateFile ($($_.Exception.Message))" }

# Resumen para Show-UxSummary.
$env:DEVCLI_CUSTOMKEYS_STATUS  = 'on'
$env:DEVCLI_CUSTOMKEYS_LUA     = $luaStatus
$env:DEVCLI_CUSTOMKEYS_MAP     = $mapStatus
$env:DEVCLI_CUSTOMKEYS_SYMBOLS = if ($symbols) { 'es' } else { 'off' }
$env:DEVCLI_CUSTOMKEYS_BACKUP  = $script:BackupDir ?? ''
$env:DEVCLI_CUSTOMKEYS_RESTART = if ($pendingRestart) { '1' } else { '0' }
$env:DEVCLI_CUSTOMKEYS_NOTES   = $script:Notes -join '|'

$details = "custom_keys.lua: $luaStatus · mapa: $mapStatus"
if ($script:Warned) {
    Complete-UxPhase -Status warn -Details $details
    exit 1
}
Complete-UxPhase -Status ok -Details $details
exit 0
