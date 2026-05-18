#Requires -Version 7.0
#
# pathdoctor.ps1 — Inspector y editor del PATH de Windows (Sistema y Usuario).
#
# Uso:
#   pathdoctor                              Muestra ambos PATH en orden de búsqueda.
#   pathdoctor -Export <fichero>            Exporta el PATH actual (formato 'S|U <ruta>').
#   pathdoctor -Import <fichero>            Compara el fichero con el PATH actual (dry-run).
#   pathdoctor -Import <fichero> -Apply     Aplica los cambios (con backup automático).
#   pathdoctor -Help                        Muestra ayuda.
#
# También se aceptan los equivalentes POSIX: --export, --import, --apply, --no-color, --help.
#
# Códigos de salida: 0=ok, 1=warn (duplicados/inexistentes), 2=fail (admin/parse/registro).

# OJO: este script NO declara param() ni [CmdletBinding()] a propósito.
# Queremos parsear $args a mano para aceptar tanto el estilo PowerShell
# (-Export) como el estilo POSIX (--export). Con un param() declarado,
# PowerShell rechazaría '--export' antes de llegar aquí.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Parser de argumentos ------------------------------------------------- #

$Mode      = 'Show'
$ExportArg = $null
$ImportArg = $null
$Apply     = $false
$NoColor   = $false

function Show-Help {
    @'
pathdoctor — inspector y editor del PATH de Windows (Sistema y Usuario).

Uso:
  pathdoctor                                Muestra ambos PATH en orden de búsqueda.
  pathdoctor -Export <fichero>              Exporta el PATH actual.
  pathdoctor -Import <fichero>              Compara con el actual (dry-run).
  pathdoctor -Import <fichero> -Apply       Aplica los cambios (con backup).
  pathdoctor -Help                          Muestra esta ayuda.

Aliases POSIX: --export, --import, --apply, --no-color, --help también funcionan.

Códigos de salida: 0=ok, 1=warn (duplicados/inexistentes), 2=fail (admin/parse).
'@ | Write-Host
}

$i = 0
while ($i -lt $args.Count) {
    $a = [string]$args[$i]
    switch -regex ($a) {
        '^(?i)-{1,2}export$' {
            if ($i + 1 -ge $args.Count) {
                Write-Host "Falta valor tras '$a'." -ForegroundColor Red; exit 2
            }
            $i++; $ExportArg = [string]$args[$i]; $Mode = 'Export'
        }
        '^(?i)-{1,2}import$' {
            if ($i + 1 -ge $args.Count) {
                Write-Host "Falta valor tras '$a'." -ForegroundColor Red; exit 2
            }
            $i++; $ImportArg = [string]$args[$i]; $Mode = 'Import'
        }
        '^(?i)-{1,2}apply$'        { $Apply   = $true }
        '^(?i)-{1,2}no-?color$'    { $NoColor = $true }
        '^(?i)(-{1,2}help|-h|-\?|/\?)$' { Show-Help; exit 0 }
        default {
            Write-Host "Argumento no reconocido: '$a'. Ejecuta 'pathdoctor -Help' para ver opciones." -ForegroundColor Red
            exit 2
        }
    }
    $i++
}

if ($ExportArg -and $ImportArg) {
    Write-Host 'No se pueden combinar -Export e -Import en la misma invocación.' -ForegroundColor Red
    exit 2
}

# --- Salida coloreada ----------------------------------------------------- #

function Out-Line {
    param(
        [string]$Text = '',
        [System.ConsoleColor]$Color = [System.ConsoleColor]::Gray,
        [switch]$NoNewline
    )
    if ($NoColor) {
        if ($NoNewline) { [Console]::Write($Text) } else { [Console]::WriteLine($Text) }
    } else {
        Write-Host -Object $Text -ForegroundColor $Color -NoNewline:$NoNewline
    }
}

# --- Privilegios ---------------------------------------------------------- #

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]::new($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# --- Acceso al registro --------------------------------------------------- #
# Leemos con DoNotExpandEnvironmentNames para preservar literales como
# %SystemRoot% y conseguir round-trip exacto en export/import.

$RegSubKey = @{
    Machine = 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
    User    = 'Environment'
}

function Get-RawPathArray {
    param([ValidateSet('Machine','User')][string]$Scope)
    $hive = if ($Scope -eq 'Machine') { [Microsoft.Win32.Registry]::LocalMachine }
            else                       { [Microsoft.Win32.Registry]::CurrentUser }
    $key = $hive.OpenSubKey($RegSubKey[$Scope], $false)
    if (-not $key) { return ,@() }
    try {
        $raw = $key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        if (-not $raw) { return ,@() }
        return ,@($raw -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    } finally {
        $key.Close()
    }
}

function Set-RawPathString {
    param(
        [ValidateSet('Machine','User')][string]$Scope,
        [AllowEmptyString()][string]$Value
    )
    # SetEnvironmentVariable escribe REG_EXPAND_SZ porque el nombre 'Path'
    # está en la lista expandible del BCL, y emite WM_SETTINGCHANGE para que
    # los procesos nuevos hereden el cambio sin necesidad de logoff.
    $target = if ($Scope -eq 'Machine') { [EnvironmentVariableTarget]::Machine }
              else                      { [EnvironmentVariableTarget]::User }
    [Environment]::SetEnvironmentVariable('Path', $Value, $target)
}

# --- Normalización para detección de duplicados --------------------------- #

function Get-NormalKey {
    param([string]$Entry)
    return ([Environment]::ExpandEnvironmentVariables($Entry)).TrimEnd('\').ToLowerInvariant()
}

# --- Análisis compartido por SHOW y EXPORT -------------------------------- #
# Genera las anotaciones (DUP / MISSING) una sola vez para que ambos modos
# pinten exactamente lo mismo y que el fichero exportado sea autoexplicativo.

function Get-PathAnalysis {
    $sys  = Get-RawPathArray -Scope Machine
    $usr  = Get-RawPathArray -Scope User
    $seen = @{}
    $dup  = 0
    $miss = 0
    $entries = [System.Collections.Generic.List[pscustomobject]]::new()

    $blocks = @(
        @{ Scope = 'S'; List = $sys; Start = 1 },
        @{ Scope = 'U'; List = $usr; Start = $sys.Count + 1 }
    )

    foreach ($b in $blocks) {
        for ($i = 0; $i -lt $b.List.Count; $i++) {
            $idx  = $b.Start + $i
            $text = $b.List[$i]
            $key  = Get-NormalKey $text
            $exp  = [Environment]::ExpandEnvironmentVariables($text)
            $exists = Test-Path -LiteralPath $exp -ErrorAction SilentlyContinue
            $hasVar = $text -match '%[^%]+%'

            if ($seen.ContainsKey($key)) {
                $list = $seen[$key]
            } else {
                $list = [System.Collections.Generic.List[int]]::new()
                $seen[$key] = $list
            }
            $list.Add($idx)

            $color = [System.ConsoleColor]::Gray
            $tags  = [System.Collections.Generic.List[string]]::new()

            if ($list.Count -eq 2) {
                $color = [System.ConsoleColor]::Yellow
                $tags.Add("DUP #2 of #$($list[0])")
                $dup++
            } elseif ($list.Count -ge 3) {
                $color = [System.ConsoleColor]::Red
                $tags.Add("DUP #$($list.Count) of #$($list[0])")
                $dup++
            }
            if (-not $exists) {
                $miss++
                $tags.Add('MISSING')
                if ($list.Count -lt 2) { $color = [System.ConsoleColor]::DarkGray }
            }

            $entries.Add([pscustomobject]@{
                Idx      = $idx
                Scope    = $b.Scope
                Text     = $text
                Tags     = $tags.ToArray()
                Color    = $color
                Expanded = $exp
                HasVar   = $hasVar
            })
        }
    }

    return [pscustomobject]@{
        Entries      = $entries
        SystemCount  = $sys.Count
        UserCount    = $usr.Count
        DupCount     = $dup
        MissingCount = $miss
    }
}

# --- Modo SHOW ------------------------------------------------------------ #

function Show-PathReport {
    $a   = Get-PathAnalysis
    $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

    Out-Line "pathdoctor — $env:COMPUTERNAME — $now" Cyan
    Out-Line ('=' * 72) Cyan
    Out-Line ''

    $titles = @{ 'S' = 'SYSTEM'; 'U' = 'USER' }
    $counts = @{ 'S' = $a.SystemCount; 'U' = $a.UserCount }

    foreach ($scope in 'S','U') {
        Out-Line "[$($titles[$scope]) PATH] ($($counts[$scope]) entradas)" Cyan
        foreach ($e in $a.Entries) {
            if ($e.Scope -ne $scope) { continue }
            Out-Line ('  [{0,3}] {1} {2}' -f $e.Idx, $e.Scope, $e.Text) $e.Color -NoNewline
            if ($e.Tags.Length -gt 0) {
                Out-Line ('  [' + ($e.Tags -join '; ') + ']') DarkYellow -NoNewline
            }
            if ($e.HasVar) {
                Out-Line ('  → ' + $e.Expanded) DarkCyan -NoNewline
            }
            Out-Line ''
        }
        Out-Line ''
    }

    Out-Line ('-' * 72) Cyan
    Out-Line ("Total: {0} ({1} system, {2} user). Duplicados: {3}. Inexistentes: {4}." -f `
              ($a.SystemCount + $a.UserCount), $a.SystemCount, $a.UserCount, $a.DupCount, $a.MissingCount) Cyan

    if ($a.DupCount -gt 0 -or $a.MissingCount -gt 0) { return 1 } else { return 0 }
}

# --- Modo EXPORT ---------------------------------------------------------- #

function Export-PathToFile {
    param([string]$Path)
    $a   = Get-PathAnalysis
    $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("# pathdoctor export — $now — $env:COMPUTERNAME")
    $lines.Add("# Format: <S|U> <space> <entry as stored in the registry>")
    $lines.Add("# Inline annotations after '  # ' (e.g. [DUP #2 of #9; MISSING]) are stripped on import.")
    $lines.Add("# Lines starting with # and blank lines are ignored on import.")
    foreach ($e in $a.Entries) {
        $line = "$($e.Scope) $($e.Text)"
        if ($e.Tags.Length -gt 0) {
            $line += "  # [$($e.Tags -join '; ')]"
        }
        $lines.Add($line)
    }

    # Resolvemos contra $PWD.Path (no contra el CWD de .NET, que en PowerShell
    # se queda fijado al directorio inicial del proceso y no sigue a Set-Location).
    $resolved = [System.IO.Path]::GetFullPath($Path, $PWD.Path)
    Set-Content -LiteralPath $resolved -Value $lines -Encoding utf8NoBOM

    Out-Line "Exportado: $resolved" Green
    Out-Line ("Entradas: {0} system + {1} user = {2}. Duplicados: {3}. Inexistentes: {4}." -f `
              $a.SystemCount, $a.UserCount, ($a.SystemCount + $a.UserCount), $a.DupCount, $a.MissingCount) Gray
    return 0
}

# --- Modo IMPORT ---------------------------------------------------------- #

function Read-PathManifest {
    param([string]$Path)
    # Idéntico criterio que en Export: relativo al $PWD del usuario, no al
    # CWD inicial del proceso .NET.
    $resolved = [System.IO.Path]::GetFullPath($Path, $PWD.Path)
    if (-not (Test-Path -LiteralPath $resolved)) {
        throw "Fichero no encontrado: $resolved"
    }

    $sys = [System.Collections.Generic.List[string]]::new()
    $usr = [System.Collections.Generic.List[string]]::new()
    $lineNo = 0
    foreach ($raw in Get-Content -LiteralPath $resolved -Encoding utf8NoBOM) {
        $lineNo++
        $line = $raw.Trim()
        if (-not $line) { continue }
        if ($line.StartsWith('#')) { continue }
        # Quita la anotación inline (' # [...]') que -Export añade.
        $line = $line -replace '\s+#.*$', ''
        if ($line -match '^([SU])\s+(.+?)\s*$') {
            $scope = $matches[1]; $text = $matches[2]
            if ($scope -eq 'S') { $sys.Add($text) } else { $usr.Add($text) }
        } else {
            throw "Línea $lineNo inválida: '$raw' (esperado: 'S <ruta>' o 'U <ruta>')"
        }
    }

    return [pscustomobject]@{ System = $sys.ToArray(); User = $usr.ToArray() }
}

function Show-Diff {
    param(
        [string]$Title,
        [array]$Old,
        [array]$New,
        [string]$Scope
    )
    Out-Line "[$Title PATH] diff" Cyan

    $oldKeys = @{}
    foreach ($e in $Old) {
        $k = Get-NormalKey $e
        if (-not $oldKeys.ContainsKey($k)) { $oldKeys[$k] = $e }
    }
    $newKeys = @{}
    foreach ($e in $New) {
        $k = Get-NormalKey $e
        if (-not $newKeys.ContainsKey($k)) { $newKeys[$k] = $e }
    }

    $removed = @($oldKeys.Keys | Where-Object { -not $newKeys.ContainsKey($_) })
    $added   = @($newKeys.Keys | Where-Object { -not $oldKeys.ContainsKey($_) })

    foreach ($k in $removed) { Out-Line "  - $Scope $($oldKeys[$k])" Red }
    foreach ($k in $added)   { Out-Line "  + $Scope $($newKeys[$k])" Green }

    $commonOld = @($Old | Where-Object { $newKeys.ContainsKey((Get-NormalKey $_)) })
    $commonNew = @($New | Where-Object { $oldKeys.ContainsKey((Get-NormalKey $_)) })
    $sameOrder = $true
    if ($commonOld.Count -ne $commonNew.Count) {
        $sameOrder = $false
    } else {
        for ($i = 0; $i -lt $commonOld.Count; $i++) {
            if ((Get-NormalKey $commonOld[$i]) -ne (Get-NormalKey $commonNew[$i])) {
                $sameOrder = $false
                break
            }
        }
    }
    if (-not $sameOrder) { Out-Line '  ~ orden modificado' Cyan }

    if ($removed.Count -eq 0 -and $added.Count -eq 0 -and $sameOrder) {
        Out-Line '  (sin cambios)' DarkGray
    }

    Out-Line ''
    return [pscustomobject]@{ Added = $added.Count; Removed = $removed.Count; Reordered = (-not $sameOrder) }
}

function Import-PathFromFile {
    param([string]$Path, [bool]$DoApply)

    $manifest = Read-PathManifest -Path $Path
    $oldSys = Get-RawPathArray -Scope Machine
    $oldUsr = Get-RawPathArray -Scope User

    $sysDiff = Show-Diff -Title 'SYSTEM' -Old $oldSys -New $manifest.System -Scope 'S'
    $usrDiff = Show-Diff -Title 'USER'   -Old $oldUsr -New $manifest.User   -Scope 'U'

    $sysChanged = ($sysDiff.Added -gt 0 -or $sysDiff.Removed -gt 0 -or $sysDiff.Reordered)
    $usrChanged = ($usrDiff.Added -gt 0 -or $usrDiff.Removed -gt 0 -or $usrDiff.Reordered)

    if (-not $sysChanged -and -not $usrChanged) {
        Out-Line 'Sin cambios: el registro ya coincide con el manifiesto.' Green
        return 0
    }

    if (-not $DoApply) {
        Out-Line 'Dry-run: no se ha modificado el registro.' Yellow
        Out-Line 'Re-ejecuta con -Apply para escribir.' Yellow
        return 0
    }

    if ($sysChanged -and -not (Test-IsAdmin)) {
        Out-Line 'Los cambios afectan al PATH del sistema (HKLM).' Red
        Out-Line 'Lanza este script en una sesión PowerShell con privilegios de administrador.' Red
        return 2
    }

    $stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
    $bin    = Join-Path $env:USERPROFILE 'bin'
    if (-not (Test-Path -LiteralPath $bin)) {
        New-Item -ItemType Directory -Path $bin -Force | Out-Null
    }

    # Backup .reg NATIVO antes de cualquier escritura: si pathdoctor falla
    # o queda inservible, basta con `reg import <fichero>` desde cualquier
    # cmd/pwsh para volver al estado actual. Si el export falla, abortamos
    # ANTES de tocar el registro.
    $regSys = Join-Path $bin "pathdoctor-backup-$stamp-system.reg"
    $regUsr = Join-Path $bin "pathdoctor-backup-$stamp-user.reg"

    & reg.exe export 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' $regSys '/y' | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Out-Line "Aborto: reg export HKLM falló (exit $LASTEXITCODE). Registro NO modificado." Red
        return 2
    }
    & reg.exe export 'HKCU\Environment' $regUsr '/y' | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Out-Line "Aborto: reg export HKCU falló (exit $LASTEXITCODE). Registro NO modificado." Red
        Remove-Item -LiteralPath $regSys -Force -ErrorAction SilentlyContinue
        return 2
    }
    Out-Line "Backup .reg sistema: $regSys" Gray
    Out-Line "Backup .reg usuario: $regUsr" Gray

    # Backup textual adicional (re-importable con el propio pathdoctor).
    $backup = Join-Path $bin "pathdoctor-backup-$stamp.txt"
    $bk = [System.Collections.Generic.List[string]]::new()
    $bk.Add("# pathdoctor backup — $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') — $env:COMPUTERNAME")
    $bk.Add("# Re-importable con: pathdoctor -Import '$backup' -Apply")
    foreach ($e in $oldSys) { $bk.Add("S $e") }
    foreach ($e in $oldUsr) { $bk.Add("U $e") }
    Set-Content -LiteralPath $backup -Value $bk -Encoding utf8NoBOM
    Out-Line "Backup texto:        $backup" Gray

    if ($sysChanged) {
        $newSysVal = [string]::Join(';', $manifest.System)
        try {
            Set-RawPathString -Scope Machine -Value $newSysVal
        } catch {
            Out-Line "Error escribiendo HKLM: $($_.Exception.Message)" Red
            return 2
        }
        $verify = Get-RawPathArray -Scope Machine
        if (([string]::Join(';', $verify)) -ne $newSysVal) {
            Out-Line 'Verificación HKLM falló (el registro no coincide tras la escritura).' Red
            return 2
        }
        Out-Line 'HKLM Path actualizado.' Green
    }

    if ($usrChanged) {
        $newUsrVal = [string]::Join(';', $manifest.User)
        try {
            Set-RawPathString -Scope User -Value $newUsrVal
        } catch {
            Out-Line "Error escribiendo HKCU: $($_.Exception.Message)" Red
            return 2
        }
        $verify = Get-RawPathArray -Scope User
        if (([string]::Join(';', $verify)) -ne $newUsrVal) {
            Out-Line 'Verificación HKCU falló (el registro no coincide tras la escritura).' Red
            return 2
        }
        Out-Line 'HKCU Path actualizado.' Green
    }

    Out-Line ''
    Out-Line 'OK. Las shells abiertas mantienen $env:Path obsoleto; las nuevas heredan el cambio.' Green
    Out-Line ''
    Out-Line 'Rollback (sin pathdoctor):' Cyan
    Out-Line "  reg import `"$regSys`"   # HKLM, requiere admin" Gray
    Out-Line "  reg import `"$regUsr`"   # HKCU, sin admin" Gray
    Out-Line 'Rollback (con pathdoctor):' Cyan
    Out-Line "  pathdoctor -Import `"$backup`" -Apply" Gray
    return 0
}

# --- Dispatcher ----------------------------------------------------------- #

if (-not $IsWindows) {
    Out-Line 'pathdoctor sólo funciona en Windows.' Red
    exit 2
}

try {
    switch ($Mode) {
        'Export' { exit (Export-PathToFile -Path $ExportArg) }
        'Import' { exit (Import-PathFromFile -Path $ImportArg -DoApply:$Apply) }
        default  { exit (Show-PathReport) }
    }
} catch {
    Out-Line "ERROR: $($_.Exception.Message)" Red
    exit 2
}
