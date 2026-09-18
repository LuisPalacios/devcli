#Requires -Version 7.0
#
# devcli-ping.ps1 — ping con salida estilo iputils para Windows 11.
#
# Un único ping para Git Bash, PowerShell 7 y cmd: las tres shells definen
# `ping` como un envoltorio que sólo reenvía los argumentos a este guion.
# Mide desde el stack de red de Windows (clase .NET Ping + Stopwatch para
# tener precisión por debajo del milisegundo) y no arranca WSL.
#
# Sintaxis: subconjunto estricto de iputils. NO se traducen las banderas de
# Windows (-n, -t y -w significan otra cosa allí); para esa sintaxis sigue
# disponible `ping.exe` escrito con su extensión.
#
#   -c count     nº de paquetes (sin -c: continuo hasta Ctrl-C, con resumen)
#   -i interval  segundos entre paquetes, admite decimales (por defecto 1)
#   -s size      bytes de datos (por defecto 56; se muestran size + 8)
#   -W timeout   segundos de espera por respuesta (por defecto 1)
#   -w deadline  segundos totales antes de terminar
#   -t ttl       TTL / hop limit de salida
#   -q           silencioso: sólo cabecera y resumen
#   -n           numérico: no resolver el PTR de quien responde
#   -4 / -6      forzar IPv4 / IPv6
#
# Códigos de salida (iputils): 0 = alguna respuesta, 1 = ninguna, 2 = error.
#
# No lleva bloque param(): los parámetros de PowerShell no distinguen
# mayúsculas y no podrían separar -w de -W. Se recorre $args a mano.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$inv = [cultureinfo]::InvariantCulture

function Write-PingError {
    param([string]$Message)
    [Console]::Error.WriteLine($Message)
}

function Write-PingUsage {
    Write-PingError ''
    Write-PingError 'Usage'
    Write-PingError '  ping [-46nq] [-c count] [-i interval] [-s size] [-t ttl]'
    Write-PingError '       [-W timeout] [-w deadline] destination'
    Write-PingError ''
    Write-PingError 'Sintaxis de iputils. Para la de Windows usa ping.exe.'
}

# Convierte el valor de una bandera a número; sale con 2 si no es válido.
function ConvertTo-PingNumber {
    param([string]$Text, [double]$Min, [double]$Max, [switch]$Integer)
    $n = 0.0
    $ok = [double]::TryParse($Text, [Globalization.NumberStyles]::Float, $inv, [ref]$n)
    if ($ok -and $Integer -and ($n -ne [math]::Floor($n))) { $ok = $false }
    if (-not $ok) {
        Write-PingError "ping: invalid argument: '$Text'"
        exit 2
    }
    if ($n -lt $Min -or $n -gt $Max) {
        Write-PingError ("ping: invalid argument: '{0}': out of range: {1} <= value <= {2}" -f $Text, $Min.ToString($inv), $Max.ToString($inv))
        exit 2
    }
    return $n
}

# ---------------------------------------------------------------------------
# Argumentos. Llamado en proceso desde el perfil de PowerShell, `-4` llega
# como entero y `0.2` como double: se pasa todo a cadena con cultura
# invariante (en es-ES un double se convertiría en "0,2").
# ---------------------------------------------------------------------------
$argv = @(foreach ($a in $args) {
    if ($a -is [IFormattable]) { $a.ToString($null, $inv) } else { [string]$a }
})

$count = 0; $interval = 1.0; $size = 56; $timeout = 1.0; $deadline = 0.0; $ttl = 0
$quiet = $false; $numeric = $false; $family = $null
$destinations = [Collections.Generic.List[string]]::new()

$k = 0
while ($k -lt $argv.Count) {
    $a = $argv[$k]; $k++
    if ($a -ceq '--') {
        while ($k -lt $argv.Count) { $destinations.Add($argv[$k]); $k++ }
        break
    }
    if ($a.Length -lt 2 -or -not $a.StartsWith('-')) { $destinations.Add($a); continue }

    # Estilo getopt: banderas agrupables (-nq) y valor pegado (-c3) o suelto (-c 3).
    $j = 1
    while ($j -lt $a.Length) {
        $flag = [string]$a[$j]; $j++
        if ('cisWwt'.Contains($flag)) {
            if ($j -lt $a.Length) {
                $value = $a.Substring($j)
                # El tokenizador de PowerShell parte `-i0.2` en `-i0` y `.2`
                # (cmd y bash lo entregan entero), y en proceso el `.2` llega
                # como double, o sea "0.2": se vuelve a pegar la parte decimal.
                if ('iWw'.Contains($flag) -and $value -match '^\d+$' -and
                    $k -lt $argv.Count -and $argv[$k] -match '^0?(\.\d+)$') {
                    $value += $Matches[1]; $k++
                }
            }
            elseif ($k -lt $argv.Count) { $value = $argv[$k]; $k++ }
            else {
                Write-PingError "ping: option requires an argument -- '$flag'"
                Write-PingUsage
                exit 2
            }
            $j = $a.Length
            switch -CaseSensitive ($flag) {
                'c' { $count    = [int](ConvertTo-PingNumber $value 1 2147483647 -Integer) }
                'i' { $interval = ConvertTo-PingNumber $value 0 2147483 }
                's' { $size     = [int](ConvertTo-PingNumber $value 0 65500 -Integer) }
                'W' { $timeout  = ConvertTo-PingNumber $value 0 2147483 }
                'w' { $deadline = ConvertTo-PingNumber $value 0 2147483 }
                't' { $ttl      = [int](ConvertTo-PingNumber $value 1 255 -Integer) }
            }
            continue
        }
        switch -CaseSensitive ($flag) {
            'q' { $quiet = $true }
            'n' { $numeric = $true }
            '4' { $family = [Net.Sockets.AddressFamily]::InterNetwork }
            '6' { $family = [Net.Sockets.AddressFamily]::InterNetworkV6 }
            'h' { Write-PingUsage; exit 2 }
            default {
                Write-PingError "ping: invalid option -- '$flag'"
                Write-PingUsage
                exit 2
            }
        }
    }
}

if ($destinations.Count -eq 0) {
    Write-PingError 'ping: usage error: Destination address required'
    exit 2
}
if ($destinations.Count -gt 1) {
    Write-PingError 'ping: usage error: Only one destination address is allowed'
    exit 2
}
if ($interval -lt 0.002) {
    Write-PingError 'ping: cannot flood; minimal interval allowed for user is 2ms'
    exit 2
}
$destination = $destinations[0]

# ---------------------------------------------------------------------------
# Resolución directa, una sola vez. Después se hace ping a la IP: si Send()
# recibe un nombre, la consulta DNS entra en el tiempo medido.
# ---------------------------------------------------------------------------
$target = $null
$literal = $null
if ([ipaddress]::TryParse($destination, [ref]$literal)) {
    if ($null -eq $family -or $literal.AddressFamily -eq $family) { $target = $literal }
}
else {
    try {
        $found = [Net.Dns]::GetHostAddresses($destination)
    }
    catch {
        Write-PingError "ping: ${destination}: Name or service not known"
        exit 2
    }
    $target = $found | Where-Object { $null -eq $family -or $_.AddressFamily -eq $family } | Select-Object -First 1
}
if ($null -eq $target) {
    Write-PingError "ping: ${destination}: Address family for hostname not supported"
    exit 2
}
$isV6 = $target.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetworkV6

# ---------------------------------------------------------------------------
# PTR de quien responde, en caché por IP durante la ejecución (cubre también
# al router que contesta con TTL excedido). Resolve-DnsName -DnsOnly y no
# [Net.Dns]::GetHostEntry: con una IP sin PTR éste cae a LLMNR/NetBIOS y se
# queda colgado entre 4 y 9 segundos, sin cachear el fallo.
# ---------------------------------------------------------------------------
$ptrCache = @{}
function Get-PingPtrName {
    param([string]$Ip)
    if ($ptrCache.ContainsKey($Ip)) { return $ptrCache[$Ip] }
    $name = $null
    try {
        $rr = Resolve-DnsName -Name $Ip -Type PTR -DnsOnly -ErrorAction Stop |
            Where-Object { $_.Type -eq 'PTR' } | Select-Object -First 1
        if ($rr) { $name = $rr.NameHost }
    }
    catch { $name = $null }
    $ptrCache[$Ip] = $name
    return $name
}

# "nombre (ip)" o sólo "ip" si no hay PTR o se pidió -n.
function Format-PingSource {
    param([ipaddress]$Address)
    $ip = $Address.ToString()
    if ($numeric) { return $ip }
    $name = Get-PingPtrName $ip
    if ($name) { return "$name ($ip)" }
    return $ip
}

# Decimales como iputils: 0.346 / 9.41 / 23.4 / 123.
function Format-PingTime {
    param([double]$Ms)
    if ($Ms -ge 99.95) { return $Ms.ToString('F0', $inv) }
    if ($Ms -ge 9.995) { return $Ms.ToString('F1', $inv) }
    if ($Ms -ge 1)     { return $Ms.ToString('F2', $inv) }
    return $Ms.ToString('F3', $inv)
}

# ---------------------------------------------------------------------------
# Estadísticas y resumen
# ---------------------------------------------------------------------------
$sent = 0; $received = 0; $errors = 0
$rttMin = [double]::MaxValue; $rttMax = 0.0; $rttSum = 0.0; $rttSum2 = 0.0
$total = [Diagnostics.Stopwatch]::new()
# Lo que el resumen da como `time`: del primer envío a la última respuesta o
# timeout, sin contar lo que tarde el PTR en resolverse.
$spanMs = 0.0

function Get-PingSummary {
    $loss = if ($sent -gt 0) { ($sent - $received) * 100.0 / $sent } else { 0.0 }
    $line = "$sent packets transmitted, $received received"
    if ($errors -gt 0) { $line += ", +$errors errors" }
    $line += ', {0}% packet loss, time {1}ms' -f $loss.ToString('G6', $inv), [long]$spanMs
    ''
    "--- $destination ping statistics ---"
    $line
    if ($received -gt 0) {
        $avg = $rttSum / $received
        $mdev = [math]::Sqrt([math]::Max(0.0, $rttSum2 / $received - $avg * $avg))
        'rtt min/avg/max/mdev = {0}/{1}/{2}/{3} ms' -f $rttMin.ToString('F3', $inv), $avg.ToString('F3', $inv),
            $rttMax.ToString('F3', $inv), $mdev.ToString('F3', $inv)
    }
}

# ---------------------------------------------------------------------------
# Bucle principal
# ---------------------------------------------------------------------------
$pinger = [Net.NetworkInformation.Ping]::new()
$options = [Net.NetworkInformation.PingOptions]::new($(if ($ttl -gt 0) { $ttl } else { 128 }), $false)
$buffer = [byte[]]::new($size)
$timeoutMs = [int][math]::Max(1, [math]::Min(2147483, $timeout) * 1000)
$sw = [Diagnostics.Stopwatch]::new()
$completed = $false

# Un envío, cronometrado en $sw. Dos variantes:
#   - Síncrona: la más precisa, pero PowerShell no puede atender el Ctrl-C
#     hasta que Send() vuelve (como mucho, el timeout).
#   - Asíncrona con esperas de 100 ms: Wait() vuelve en cuanto llega la
#     respuesta y el Ctrl-C se atiende entre esperas; cuesta ~0,05-0,08 ms
#     más por el salto de hilo.
# El bucle usa la síncrona mientras el destino contesta y la asíncrona
# cuando calla, que es cuando la precisión da igual y el Ctrl-C importa.
function Send-PingProbe {
    param([ipaddress]$Address, [int]$WaitMs, [bool]$Async)
    if ($Async) {
        $sw.Restart()
        $task = $pinger.SendPingAsync($Address, $WaitMs, $buffer, $options)
        while (-not $task.Wait(100)) { }
        $sw.Stop()
        return $task.Result
    }
    $sw.Restart()
    $reply = $pinger.Send($Address, $WaitMs, $buffer, $options)
    $sw.Stop()
    return $reply
}

if ($isV6) { "PING $destination ($target) $size data bytes" }
else { "PING $destination ($target) $size($($size + 28)) bytes of data." }

try {
    # Calentamiento: el primer envío del proceso paga el JIT y el enlace
    # dinámico de PowerShell (4-8 ms) y el primero que no es loopback ~1 ms
    # más; sin esto icmp_seq=1 siempre miente. Se hace contra la IP propia
    # con la que se sale hacia el destino (un connect UDP la averigua sin
    # enviar nada): no pone ningún paquete en el cable ni llega al destino.
    # Tiene que pasar por Send-PingProbe: lo que se calienta es ese código.
    $warmAddress = if ($isV6) { [ipaddress]::IPv6Loopback } else { [ipaddress]::Loopback }
    try {
        $udp = [Net.Sockets.UdpClient]::new($target.AddressFamily)
        $udp.Connect($target, 9)
        $warmAddress = $udp.Client.LocalEndPoint.Address
        $udp.Dispose()
    }
    catch { $warmAddress = if ($isV6) { [ipaddress]::IPv6Loopback } else { [ipaddress]::Loopback } }
    foreach ($mode in $false, $true) {
        try { $null = Send-PingProbe $warmAddress 200 $mode } catch { $null = $_ }
    }

    $lastAnswered = $timeoutMs -le 1000
    $seq = 0
    $total.Start()
    while ($true) {
        if ($count -gt 0 -and $seq -ge $count) { break }
        if ($deadline -gt 0 -and $total.Elapsed.TotalSeconds -ge $deadline) { break }
        $seq++
        $cycleStart = $total.Elapsed.TotalMilliseconds

        $waitMs = $timeoutMs
        if ($deadline -gt 0) {
            $left = [int]($deadline * 1000 - $cycleStart)
            $waitMs = [math]::Max(1, [math]::Min($waitMs, $left))
        }

        $reply = $null
        $sent++
        try {
            $reply = Send-PingProbe $target $waitMs (-not $lastAnswered)
        }
        catch {
            $errors++
            if (-not $quiet) { "ping: sendmsg: $($_.Exception.GetBaseException().Message)" }
        }
        $spanMs = $total.Elapsed.TotalMilliseconds
        $lastAnswered = ($null -ne $reply) -and ($reply.Status.ToString() -eq 'Success')

        if ($null -ne $reply) {
            $status = $reply.Status.ToString()
            if ($status -eq 'Success') {
                $ms = $sw.Elapsed.TotalMilliseconds
                $received++
                $rttSum += $ms; $rttSum2 += $ms * $ms
                if ($ms -lt $rttMin) { $rttMin = $ms }
                if ($ms -gt $rttMax) { $rttMax = $ms }
                if (-not $quiet) {
                    # En IPv6 .NET no entrega el hop limit (Options es $null): sin ttl=.
                    $ttlText = if ($null -ne $reply.Options) { " ttl=$($reply.Options.Ttl)" } else { '' }
                    '{0} bytes from {1}: icmp_seq={2}{3} time={4} ms' -f ($reply.Buffer.Length + 8),
                        (Format-PingSource $reply.Address), $seq, $ttlText, (Format-PingTime $ms)
                }
            }
            elseif ($status -ne 'TimedOut') {
                # Un timeout no imprime nada (como iputils); el resto son errores ICMP.
                $errors++
                if (-not $quiet) {
                    $text = switch -Wildcard ($status) {
                        'TtlExpired'      { if ($isV6) { 'Time exceeded: Hop limit' } else { 'Time to live exceeded' }; break }
                        'TimeExceeded'    { if ($isV6) { 'Time exceeded: Hop limit' } else { 'Time to live exceeded' }; break }
                        'DestinationHost*'    { 'Destination Host Unreachable'; break }
                        'DestinationNetwork*' { 'Destination Net Unreachable'; break }
                        'DestinationPort*'    { 'Destination Port Unreachable'; break }
                        'DestinationProhibited' { 'Packet filtered'; break }
                        'PacketTooBig'    { 'Frag needed and DF set'; break }
                        default           { $status }
                    }
                    'From {0} icmp_seq={1} {2}' -f (Format-PingSource $reply.Address), $seq, $text
                }
            }
        }

        # Espera hasta completar el intervalo, salvo tras el último paquete.
        # Lo gastado en el PTR se descuenta aquí y no altera la cadencia.
        if ($count -gt 0 -and $seq -ge $count) { break }
        $sleepMs = $interval * 1000 - ($total.Elapsed.TotalMilliseconds - $cycleStart)
        if ($deadline -gt 0) { $sleepMs = [math]::Min($sleepMs, $deadline * 1000 - $total.Elapsed.TotalMilliseconds) }
        if ($sleepMs -ge 1) { Start-Sleep -Milliseconds ([int]$sleepMs) }
    }
    $total.Stop()
    Get-PingSummary
    $completed = $true
}
finally {
    # Ctrl-C: la pipeline ya se está deteniendo y Write-Output no llega a
    # ningún sitio; el resumen se escribe directamente en la consola.
    if (-not $completed) {
        $total.Stop()
        $spanMs = $total.Elapsed.TotalMilliseconds
        foreach ($line in Get-PingSummary) { [Console]::Out.WriteLine($line) }
    }
    $pinger.Dispose()
}

$rc = 0
if ($received -eq 0) { $rc = 1 }
elseif ($count -gt 0 -and $deadline -gt 0 -and $received -lt $count) { $rc = 1 }
exit $rc
