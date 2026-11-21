#Requires -Version 7.0
#
# Genera dotfiles/custom_keys.powertoys.json: el mapa de PowerToys Keyboard
# Manager de la capa «teclado de PC como un Mac» (opt-in con
# bootstrap.ps1 -CustomKeys on). La otra mitad del contrato, lo que WezTerm
# hace con F13–F24, está en dotfiles/custom_keys.lua.
#
# Uso:
#   pwsh -NoProfile -File install/build-custom-keys.ps1          regenera el JSON
#   pwsh -NoProfile -File install/build-custom-keys.ps1 -Check   falla si el JSON está desfasado o el mapa no es válido
#
# Para cambiar el mapa: edita las tablas de Get-GlobalRemaps / Get-TerminalRemaps,
# regenera y commitea el JSON. Lo que se despliega es el JSON, no este script.
#
# Disposición física (teclado PC español ISO, en el sitio de las teclas del Mac):
#   Alt izquierdo = Cmd · Win = Option · Ctrl = Control.
#   AltGr y Ctrl derecho NO se tocan (AltGr escribe los símbolos impresos).
#
# Códigos de salida: 0 = ok, 1 = JSON desfasado o mapa inválido.

[CmdletBinding()]
param(
    [switch]$Check,
    [string]$OutFile = (Join-Path $PSScriptRoot '..' 'dotfiles' 'custom_keys.powertoys.json')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─── Códigos de tecla virtual (VK) ─────────────────────────────────────────
$LWIN = 91; $LSHIFT = 160; $LCTRL = 162; $LALT = 164; $RALT = 165
$LEFT = 37; $UP = 38; $RIGHT = 39; $DOWN = 40
$HOME_ = 36; $END_ = 35; $BACKSPACE = 8; $PRINT_SCREEN = 44; $F4 = 115
# Teclas del teclado español ISO, por lo que llevan impreso.
$KEY_GRAVE = 186; $KEY_PLUS = 187; $KEY_COMMA = 188; $KEY_MINUS = 189; $KEY_CEDILLA = 191
$KEY_ORDINAL = 220; $KEY_ACUTE = 222; $KEY_ENYE = 192

$CMD = $LALT      # donde el Mac tiene Cmd
$OPTION = $LWIN   # donde el Mac tiene Option
$TERMINAL = 'wezterm-gui'
$LETTERS = [int][char]'A'..[int][char]'Z'
$DIGITS = [int][char]'0'..[int][char]'9'

function F([int]$n) { 111 + $n }          # F13 = 124 … F24 = 135
function K([string]$c) { [int][char]$c }  # letra o dígito → VK

# Un atajo: teclas de origen → teclas de destino.
function Map([int[]]$From, [int[]]$To) { [pscustomobject]@{ From = $From; To = $To } }

# ─── Capa global (todas las apps) ──────────────────────────────────────────
function Get-GlobalRemaps {
    $r = [System.Collections.Generic.List[object]]::new()
    foreach ($key in $LETTERS) {
        $c = [char]$key
        if ('HM'.Contains($c))   { $r.Add((Map ($CMD, $key) ($LWIN, $DOWN))) }   # ocultar / minimizar
        elseif ($c -eq 'Q')      { $r.Add((Map ($CMD, $key) ($LALT, $F4))) }     # salir
        else                     { $r.Add((Map ($CMD, $key) ($LCTRL, $key))) }
        if ($c -eq 'Z')          { $r.Add((Map ($CMD, $LSHIFT, $key) ($LCTRL, (K 'Y')))) }  # rehacer
        else                     { $r.Add((Map ($CMD, $LSHIFT, $key) ($LCTRL, $LSHIFT, $key))) }
    }
    foreach ($key in @($DIGITS) + @($KEY_PLUS, $KEY_MINUS, $KEY_COMMA)) {
        $r.Add((Map ($CMD, $key) ($LCTRL, $key)))
    }
    # Capturas de pantalla.
    $r.Add((Map ($CMD, $LSHIFT, (K '3')) ($LWIN, $PRINT_SCREEN)))
    $r.Add((Map ($CMD, $LSHIFT, (K '4')) ($LWIN, $LSHIFT, (K 'S'))))
    # Escritorios virtuales con una mano (º, a la izquierda del 1): el pulgar
    # izquierdo pulsa Alt, o Win+Alt a la vez, y el meñique la º.
    $r.Add((Map ($CMD, $KEY_ORDINAL)          ($LWIN, $LCTRL, $RIGHT)))   # escritorio siguiente
    $r.Add((Map ($CMD, $OPTION, $KEY_ORDINAL) ($LWIN, $LCTRL, $LEFT)))    # escritorio anterior
    # Cmd+flechas: bordes de línea y de documento; con Shift, seleccionan.
    $r.Add((Map ($CMD, $LEFT)  ($HOME_)))
    $r.Add((Map ($CMD, $RIGHT) ($END_)))
    $r.Add((Map ($CMD, $UP)    ($LCTRL, $HOME_)))
    $r.Add((Map ($CMD, $DOWN)  ($LCTRL, $END_)))
    $r.Add((Map ($CMD, $LSHIFT, $LEFT)  ($LSHIFT, $HOME_)))
    $r.Add((Map ($CMD, $LSHIFT, $RIGHT) ($LSHIFT, $END_)))
    $r.Add((Map ($CMD, $LSHIFT, $UP)    ($LCTRL, $LSHIFT, $HOME_)))
    $r.Add((Map ($CMD, $LSHIFT, $DOWN)  ($LCTRL, $LSHIFT, $END_)))
    # Option+flechas: palabra a palabra.
    $r.Add((Map ($OPTION, $LEFT)  ($LCTRL, $LEFT)))
    $r.Add((Map ($OPTION, $RIGHT) ($LCTRL, $RIGHT)))
    $r.Add((Map ($OPTION, $LSHIFT, $LEFT)  ($LCTRL, $LSHIFT, $LEFT)))
    $r.Add((Map ($OPTION, $LSHIFT, $RIGHT) ($LCTRL, $LSHIFT, $RIGHT)))
    $r.Add((Map ($OPTION, $BACKSPACE) ($LCTRL, $BACKSPACE)))
    # Símbolos del Mac español: Option+tecla = AltGr+tecla  ( | @ # ~ ¬ € [ ] { } \ ).
    # Sólo valen con disposición española: el instalador quita las entradas
    # cuyo destino empieza por AltGr (165) si la disposición es otra.
    foreach ($key in @((K '1'), (K '2'), (K '3'), (K '4'), (K '6'), (K 'E'), $KEY_GRAVE, $KEY_PLUS, $KEY_ACUTE, $KEY_CEDILLA, $KEY_ORDINAL)) {
        $r.Add((Map ($OPTION, $key) ($RALT, $key)))
    }
    $r.Add((Map ($OPTION, $KEY_ENYE) ($RALT, (K '4'))))   # ~ es Option+Ñ en el Mac
    return $r
}

# ─── Capa de WezTerm (sólo con wezterm-gui en primer plano) ────────────────
# Cmd nunca debe llegar a los programas como carácter de control: cada
# Cmd+tecla se convierte en F13–F24 / Shift+F13–F24, y custom_keys.lua les
# da la acción. El resto de Cmd+letra va a F24 (Nop).
function Get-TerminalRemaps {
    $noop = @(F 24)
    $actions = [ordered]@{}
    $add = { param([int[]]$from, [int[]]$to) $actions[($from -join ';')] = (Map $from $to) }
    & $add ($CMD, (K 'C')) (F 13)                   # copiar
    & $add ($CMD, (K 'V')) (F 14)                   # pegar
    & $add ($CMD, (K 'T')) (F 15)                   # pestaña nueva
    & $add ($CMD, (K 'W')) (F 16)                   # cerrar panel (e igualar)
    & $add ($CMD, (K 'N')) (F 17)                   # ventana nueva
    & $add ($CMD, (K 'D')) (F 18)                   # dividir a la derecha
    & $add ($CMD, $LSHIFT, (K 'D')) (F 19)          # dividir hacia abajo
    & $add ($CMD, (K 'F')) (F 20)                   # buscar
    & $add ($CMD, (K 'G')) (F 21)                   # siguiente coincidencia
    & $add ($CMD, $LSHIFT, (K 'G')) (F 22)          # coincidencia anterior
    & $add ($CMD, (K 'K')) (F 23)                   # limpiar pantalla e historial
    & $add ($CMD, (K 'A')) ($LSHIFT, (F 13))        # seleccionar todo
    & $add ($CMD, (K 'Q')) ($LSHIFT, (F 14))        # salir de WezTerm
    & $add ($CMD, $LEFT)  ($LSHIFT, (F 15))         # pestaña anterior
    & $add ($CMD, $RIGHT) ($LSHIFT, (F 16))         # pestaña siguiente
    & $add ($CMD, $UP)    ($LSHIFT, (F 17))         # subir una línea
    & $add ($CMD, $DOWN)  ($LSHIFT, (F 18))         # bajar una línea
    & $add ($CMD, $OPTION, $LEFT)  ($LSHIFT, (F 19))   # panel izquierdo
    & $add ($CMD, $OPTION, $RIGHT) ($LSHIFT, (F 20))   # panel derecho
    & $add ($CMD, $OPTION, $UP)    ($LSHIFT, (F 21))   # panel de arriba
    & $add ($CMD, $OPTION, $DOWN)  ($LSHIFT, (F 22))   # panel de abajo
    & $add ($CMD, $OPTION, $KEY_GRAVE) ($LSHIFT, (F 23))  # Cmd+[ panel anterior
    & $add ($CMD, $OPTION, $KEY_PLUS)  ($LSHIFT, (F 24))  # Cmd+] panel siguiente

    $r = [System.Collections.Generic.List[object]]::new()
    foreach ($v in $actions.Values) { $r.Add($v) }
    foreach ($key in $LETTERS) {
        # Cmd+H y Cmd+M siguen minimizando la ventana, como en el Mac.
        if (-not $actions.Contains("$CMD;$key") -and -not 'HM'.Contains([char]$key)) {
            $r.Add((Map ($CMD, $key) $noop))
        }
        if (-not $actions.Contains("$CMD;$LSHIFT;$key")) {
            $r.Add((Map ($CMD, $LSHIFT, $key) $noop))
        }
    }
    $r.Add((Map ($CMD, $KEY_COMMA) $noop))
    return $r
}

# ─── Validación ────────────────────────────────────────────────────────────
function Test-RemapList([string]$Name, [object[]]$Remaps) {
    $seen = @{}
    foreach ($m in $Remaps) {
        $set = ($m.From | Sort-Object) -join ';'
        if ($seen.ContainsKey($set)) { throw "atajo de origen duplicado en ${Name}: $($m.From -join ';')" }
        $seen[$set] = $true
        # 18 es «cualquier Alt», que también coincide con AltGr.
        if ($m.From -contains $RALT -or $m.From -contains 18) {
            throw "$Name reasigna AltGr, que debe quedar libre para los símbolos: $($m.From -join ';')"
        }
    }
}

# ─── Render (formato fijo: 2 espacios, LF, como lo escribe PowerToys) ──────
function Format-Entry([object]$m, [string]$App) {
    $lines = @(
        '    {'
        "      `"originalKeys`": `"$($m.From -join ';')`","
        '      "exactMatch": true,'
        '      "operationType": 0,'
        "      `"newRemapKeys`": `"$($m.To -join ';')`"$(if ($App) { ',' })"
    )
    if ($App) { $lines += "      `"targetApp`": `"$App`"" }
    $lines += '    }'
    ($lines | ForEach-Object { "  $_" }) -join "`n"
}

function Format-Config([object[]]$GlobalRemaps, [object[]]$TerminalRemaps) {
    $g = ($GlobalRemaps | ForEach-Object { Format-Entry $_ $null }) -join ",`n"
    $t = ($TerminalRemaps | ForEach-Object { Format-Entry $_ $TERMINAL }) -join ",`n"
    @(
        '{'
        '  "remapKeys": {'
        '    "inProcess": []'
        '  },'
        '  "remapKeysToText": {'
        '    "inProcess": []'
        '  },'
        '  "remapShortcuts": {'
        '    "global": ['
        $g
        '    ],'
        '    "appSpecific": ['
        $t
        '    ]'
        '  },'
        '  "remapShortcutsToText": {'
        '    "global": [],'
        '    "appSpecific": []'
        '  }'
        '}'
        ''
    ) -join "`n"
}

# ─── Main ──────────────────────────────────────────────────────────────────
$globalRemaps = @(Get-GlobalRemaps)
$terminalRemaps = @(Get-TerminalRemaps)
try {
    Test-RemapList 'global' $globalRemaps
    Test-RemapList 'appSpecific' $terminalRemaps
}
catch {
    Write-Error "mapa inválido: $($_.Exception.Message)" -ErrorAction Continue
    exit 1
}
$text = Format-Config $globalRemaps $terminalRemaps
$outName = Split-Path $OutFile -Leaf

if ($Check) {
    $current = if (Test-Path $OutFile) { [IO.File]::ReadAllText($OutFile) } else { $null }
    if ($current -ne $text) {
        Write-Error "$outName está desfasado: ejecuta install/build-custom-keys.ps1" -ErrorAction Continue
        exit 1
    }
}
else {
    [IO.File]::WriteAllText($OutFile, $text, [Text.UTF8Encoding]::new($false))
}
Write-Host "ok: $($globalRemaps.Count) globales, $($terminalRemaps.Count) para $TERMINAL"
exit 0
