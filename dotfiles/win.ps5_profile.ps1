# =============================================================================
# Perfil para Windows PowerShell 5.1 (legacy)
# =============================================================================
# Ubicación final: ~\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
# Propósito: paridad razonable con PS7 — env vars de color, funciones
#            ls/rm/cd y oh-my-posh. Quedan fuera (vs PS7): zoxide y el tuning
#            de PSReadLine 2.2+ (HistoryAndPlugin/ListView), que requieren
#            módulos modernos no garantizados en PS5.
# IMPORTANTE: este fichero está guardado en UTF-8 CON BOM. PS5 lee .ps1 con
#            la codepage del sistema cuando NO hay BOM, y eso mojibea el
#            emoji 🪟 que va en OMP_OS_ICON. NO QUITAR el BOM al editar.
# Para experiencia plena (zoxide, PSReadLine inteligente): usa PowerShell 7.
# =============================================================================

# -----------------------------------------------------------------------------
# Variables de entorno (process-scope, mismo patrón que bashrc/zshrc/PS7)
# -----------------------------------------------------------------------------
$env:OMP_OS_ICON = "🪟"

$lsColors  = "fi=00:mi=00:mh=00:ln=01;94:or=01;31:di=01;36:ow=04;01;34:st=34:tw=04;34"
$lsColors += ":pi=01;33:so=01;33:do=01;33:bd=01;33:cd=01;33:su=01;35:sg=01;35:ca=01;35:ex=01;32"
$lsColors += ":*.cmd=00;32:*.exe=01;32:*.com=01;32:*.bat=01;32:*.btm=01;32:*.dll=01;32"
$lsColors += ":*.tar=00;31:*.tbz=00;31:*.tgz=00;31:*.rpm=00;31:*.deb=00;31:*.arj=00;31"
$lsColors += ":*.taz=00;31:*.lzh=00;31:*.lzma=00;31:*.zip=00;31:*.zoo=00;31:*.z=00;31"
$lsColors += ":*.Z=00;31:*.gz=00;31:*.bz2=00;31:*.tb2=00;31:*.tz2=00;31:*.tbz2=00;31"
$lsColors += ":*.avi=01;35:*.bmp=01;35:*.fli=01;35:*.gif=01;35:*.jpg=01;35:*.jpeg=01;35"
$lsColors += ":*.mng=01;35:*.mov=01;35:*.mpg=01;35:*.pcx=01;35:*.pbm=01;35:*.pgm=01;35"
$lsColors += ":*.png=01;35:*.ppm=01;35:*.tga=01;35:*.tif=01;35:*.xbm=01;35:*.xpm=01;35"
$lsColors += ":*.dl=01;35:*.gl=01;35:*.wmv=01;35"
$env:LS_COLORS = $lsColors

$ezaColors  = "uu=38;5;230:gu=38;5;187"
$ezaColors += ":ur=32:uw=33:ux=31:ue=31:gr=32:gw=33:gx=31"
$ezaColors += ":tr=32:tw=33:tx=31:su=38;5;5:sf=38;5;5:xa=36:oc=38;5;6"
$ezaColors += ":sn=38;5;245:nb=38;5;229:nk=38;5;229:nm=38;5;216"
$ezaColors += ":ng=38;5;172:nt=38;5;172:ub=38;5;229:uk=38;5;229"
$ezaColors += ":um=38;5;216:ug=38;5;172:ut=38;5;172"
$ezaColors += ":da=38;5;36:in=38;5;13:lc=38;5;13:xx=38;5;245"
$ezaColors += ":ga=32:gm=33:gd=31:gv=32:gt=33:gi=38;5;245:gc=31"
$env:EZA_COLORS = $ezaColors

# -----------------------------------------------------------------------------
# ls: eza → lsd → Get-ChildItem (mismo orden que PS7 profile)
# -----------------------------------------------------------------------------
if (Get-Alias ls -ErrorAction SilentlyContinue) {
    Remove-Item Alias:ls -Force
}
function ls {
    if (Get-Command eza -ErrorAction SilentlyContinue) {
        eza --icons=auto --color=auto --git @args
    } elseif (Get-Command lsd -ErrorAction SilentlyContinue) {
        lsd @args
    } else {
        Get-ChildItem @args
    }
}

# -----------------------------------------------------------------------------
# rm con soporte -fr (estilo Unix)
# -----------------------------------------------------------------------------
if (Get-Alias rm -ErrorAction SilentlyContinue) {
    Remove-Item Alias:rm -Force
}
function rm {
    param(
        [Parameter(Mandatory=$true, ValueFromRemainingArguments=$true)]
        [String[]] $Args
    )
    if ($Args -contains "-fr") {
        $targets = $Args | Where-Object { $_ -ne "-fr" }
        Remove-Item -LiteralPath $targets -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Remove-Item -LiteralPath $Args -ErrorAction SilentlyContinue
    }
}

# -----------------------------------------------------------------------------
# cd: sin args → home, con args → Set-Location plain (sin zoxide en PS5)
# -----------------------------------------------------------------------------
if (Get-Alias cd -ErrorAction SilentlyContinue) {
    Remove-Item Alias:cd -Force
}
function cd {
    param([string]$Path)
    if (-not $Path) { Set-Location ~ }
    else { Set-Location -LiteralPath $Path }
}

# -----------------------------------------------------------------------------
# oh-my-posh (prompt) — solo en consola interactiva
# -----------------------------------------------------------------------------
# Skip si no hay consola, si está redirigido, o si oh-my-posh no está instalado.
# PS5 no tiene $PSStyle, así que el check de TTY es más simple que en PS7.
$IsInteractive = ($Host.Name -eq 'ConsoleHost') -and `
                 (-not [Console]::IsOutputRedirected) -and `
                 (-not [Console]::IsInputRedirected)

if ($IsInteractive -and (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
    oh-my-posh init pwsh --config ~/.oh-my-posh.json | Invoke-Expression
}
