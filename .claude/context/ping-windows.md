# Windows `ping` with iputils output — Claude context

**Audience**: future Claude sessions touching `files/bin/devcli-ping.ps1` or the `ping` wrappers in `dotfiles/win.gitbash.bashrc`, `dotfiles/Microsoft.PowerShell_profile.ps1` and `dotfiles/cmd_aliases.cmd`. Read this BEFORE making changes — it records what exists, why, and the numbers behind each choice. The decisions are Luis's; don't relitigate them without checking with him first.

**Status (2026-09-18)**: implemented and verified on Windows 11 / PowerShell 7.6 in the three shells.

This repo is public: keep private hostnames and LAN addresses out of code, comments, docs and commit messages. Use `gateway`, `1.1.1.1`, `example.org` in examples.

## What it is

One `ping`, same behaviour in Git Bash, PowerShell 7 and cmd, printing iputils lines, measured from the Windows network stack (it sees a host-only adapter such as a VPN), without starting WSL:

```text
PING example.org (93.184.215.14) 56(84) bytes of data.
64 bytes from host.example.org (93.184.215.14): icmp_seq=1 ttl=56 time=9.41 ms

--- example.org ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 9.412/9.412/9.412/0.000 ms
```

It replaced the delegation to `wsl.exe -e ping` (commit `c42e236`), which cold-started the WSL2 VM (8 s, plus a Hyper-V vSwitch re-attach each time), measured through the WSL NAT instead of the host stack, and left each shell with a different `ping`. `.wslconfig` was never part of this — WSL is needed for other things.

## File map

| Piece | Role |
| --- | --- |
| `files/bin/devcli-ping.ps1` | The whole ping. Deployed to `~/bin` by phase 05 (`install/05-localtools.json`, `windows`) |
| `dotfiles/win.gitbash.bashrc` | `ping()` → `pwsh.exe -NoProfile -File ~/bin/devcli-ping.ps1 "$@"` (~0.25 s pwsh start-up). If `pwsh.exe` or the script is missing: one-line warning on stderr, then `ping.exe "$@"` |
| `dotfiles/Microsoft.PowerShell_profile.ps1` | `function ping` → `& ~/bin/devcli-ping.ps1 @args`, in-process (no start-up cost). Same missing-script fallback |
| `dotfiles/cmd_aliases.cmd` | `doskey ping=pwsh -NoProfile -File "%USERPROFILE%\bin\devcli-ping.ps1" $*`. Doskey macros only exist at an interactive prompt; `.bat` files keep seeing `ping.exe` |
| `dotfiles/win.ps5_profile.ps1` | No `ping`. Left alone on purpose |

Why wrappers and not a PATH shim: Windows builds PATH as Machine + User and `C:\Windows\system32` is in the Machine half, so nothing in `~/bin` can shadow `ping.exe`.

Why `devcli-ping.ps1` and not `ping.ps1`: `~/bin` is on the user PATH and PowerShell resolves `.ps1` files on PATH by bare name. `ping.exe` would win today only because Machine precedes User; any PATH reordering would flip `ping` silently, and `Get-Command ping -All` / tab completion would be ambiguous.

There is **no escape variable**. `ping.exe` typed with its extension bypasses the bash function, the PowerShell function and the doskey macro alike, so it is the escape hatch in all three shells. An environment variable would exist in bash only and bring back per-shell behaviour.

## Decisions (Luis, 2026-09-18)

| Topic | Decision |
| --- | --- |
| Engine | `[System.Net.NetworkInformation.Ping]` + `Stopwatch`. `Test-Connection` is a thin wrapper over it with integer-ms latency (`time=0 ms` on a LAN), `-Delay` in whole seconds and no deadline |
| No `-c` | Continuous until Ctrl-C, then the iputils summary. Same in all three shells |
| Flags | Strict Unix subset with iputils semantics: `-c -i -s -W -w -t -q -n -4 -6`. Unknown flag → usage on stderr, exit 2. **No translation of Windows flags** — `-n`, `-t`, `-w` mean different things on each side |
| PTR | Resolved the first time each replying address appears, cached per IP for the run (covers a router answering with TTL exceeded). `-n` disables it. Unlike iputils, a literal-IP destination is reverse-resolved too |
| Exit codes | iputils: 0 = at least one reply, 1 = none (or fewer than `-c` when `-w` is also given), 2 = error |
| Default `-W` | 1 s. The loop is sequential (send, wait, sleep the rest of the interval), so 1 s keeps the iputils 1 s cadence against a silent host. An RTT above 1 s counts as loss unless `-W` is raised |
| Timeouts | Each one prints `Request timeout for icmp_seq N`, like macOS. The only deliberate departure from iputils output, together with reverse-resolving literal IPs |
| WSL | No delegation left |

## How the script works

- **No `param()` block.** PowerShell parameters are case-insensitive and could not tell `-w` from `-W`. `$args` is walked by hand, getopt-style: bundled flags (`-nq`), attached or detached values (`-c3`, `-c 3`), options after the destination, `--`.
- **Everything is stringified with `InvariantCulture` first.** Called in-process, PowerShell hands over `0.2` as a double, and on an `es-ES` machine that would become `0,2`. All number formatting uses `InvariantCulture` for the same reason.
- **`-i0.2` from a PowerShell caller** arrives as `-i0` + `.2` (tokenizer quirk; in-process the second half is the double `0.2`). For `-i`, `-W` and `-w` the script glues the decimal part back. cmd and bash deliver it intact.
- **Forward resolution once**, with `[Net.Dns]::GetHostAddresses` (23 ms; a dotted name that does not exist fails in 23 ms, a single-label one takes ~1.3 s through LLMNR, as with `ping.exe`). Then the IP is pinged: `Send()` with a hostname would put the DNS lookup inside the measured time.
- **PTR with `Resolve-DnsName -Type PTR -DnsOnly`**, never `[Net.Dns]::GetHostEntry`. Measured with addresses that have no PTR: `GetHostEntry` stalls 9.5 s (private address) or 4.5 s (public one) falling back to LLMNR/NetBIOS, and does not cache the failure; it even took 4.5 s for an address that does have a PTR. `Resolve-DnsName` costs ~300 ms on its first call (≈185 ms is the `DnsClient` module import) and 1–2 ms afterwards, hit or miss. The lookup runs outside the stopwatch and is deducted from the interval sleep, so the first reply line shows ~300 ms late and the cadence is unaffected — except that with `-i` below ~0.3 s the second packet leaves late. Launched in-process from a session that already loaded the module, that cost disappears.
- **Warm-up before `icmp_seq=1`.** The first send of a process costs 4–8 ms (JIT plus PowerShell's dynamic call-site binding) and the first non-loopback send ~1 ms more; unwarmed, the first line always lies. The script pings its **own source address** towards the target (found with a UDP `Connect`, which sends nothing): that absorbs both costs, puts no packet on the wire and never reaches the target. Loopback alone leaves the ~1 ms residue. The warm-up must go through `Send-PingProbe`, in both modes — what gets warmed is that exact code path.
- **Sync while it answers, async when it is silent.** `Send()` is the most precise call but PowerShell cannot service Ctrl-C until it returns. `SendPingAsync` + `Wait(100)` lets Ctrl-C through within 100 ms but adds 0.05–0.08 ms (thread hop; medians 0.474 vs 0.550 ms on a LAN). So a probe is synchronous when the previous one got a reply, asynchronous otherwise — when nobody answers precision is moot and Ctrl-C latency is what matters. The first probe is async if `-W` is above 1 s.
- **Output format.** `time=` decimals follow iputils (`0.346`, `9.41`, `23.4`, `123`). Size printed is payload + 8. A timeout prints `Request timeout for icmp_seq N` (the macOS/BSD wording; Luis's call — iputils stays silent unless `-O`, and a dead destination should be visible at once). It counts as loss, not as an ICMP error, and `-q` hides it. ICMP errors print `From <name (ip)> icmp_seq=N <text>` and add `+N errors` to the summary. IPv6: `.NET` gives no hop limit (`Reply.Options` is `$null`), so `ttl=` is omitted; header is `PING host (addr) 56 data bytes`. The summary's `time` spans first send to last reply/timeout, excluding PTR latency.
- **Ctrl-C summary.** Normal lines go through the pipeline (`ping … | sls ttl` works in PowerShell). On Ctrl-C the pipeline is already stopping and `Write-Output` goes nowhere, so the `finally` block writes the summary with `[Console]::Out.WriteLine`. Do not register a scriptblock on `[Console]::CancelKeyPress` — it runs on a thread with no runspace and crashes pwsh.
- **Exit code.** The script ends with `exit N`. `pwsh -File` propagates it; invoked in-process with `&`, `exit` only ends the script and sets `$LASTEXITCODE` — the session survives. After a Ctrl-C the exit code is not iputils' 0/1: Git Bash reports 130 (128 + SIGINT), PowerShell 7 and cmd report 0. Forcing an `exit` from the `finally` block was left out on purpose — it cannot be tested without a keyboard and the in-process case runs inside the user's interactive session.
- **Windows ICMP timeouts are coarse below 1 s**: `-W 0.5` was seen firing at ~220 ms; 1 s and above are honoured to the millisecond. The interval sleep keeps the cadence either way.
- **`Time to live exceeded` depends on the path**: a router that stays silent at that hop (or rate-limits ICMP) shows up as a plain timeout. `-t 1` towards any off-link address always gets an answer from the local gateway.
- Line endings: `.ps1`/`.cmd` CRLF, bashrc LF (`.gitattributes` enforces it).

## Deploying a working copy

The phase scripts read from `$env:SETUP_DIR` (default `~/.devcli`, a clone of the published repo). To deploy uncommitted or unpushed changes:

```powershell
$env:SETUP_DIR = '<path to the working copy>'
pwsh -NoProfile -File "$env:SETUP_DIR\install\03-dotfiles.ps1"
pwsh -NoProfile -File "$env:SETUP_DIR\install\05-localtools.ps1"
```

## How to verify

No test suite here; verify by running, in a **new** shell of each kind, and paste real output.

1. In each of Git Bash, PowerShell 7, cmd: `ping -c 3 <gateway>` (sub-ms times, name resolved, exit 0), `ping -c 2 -n 1.1.1.1` (numeric), `ping -c 1 -W 1 <dead LAN ip>` (`Request timeout for icmp_seq 1`, exit 1), `ping nope.invalid` (exit 2), `ping -c 1 -t 1 1.1.1.1` (`From <gateway> … Time to live exceeded`, exit 1), `ping -c 2 -i 0.2 -s 1400 <gateway>` (`1408 bytes`), `ping -c 1 ::1` (no `ttl=`), `ping -c2 -i0.2 -nq 1.1.1.1` (attached values, bundled flags).
2. From an agent session the doskey macro cannot be exercised (`cmd /c` is not interactive): run its expansion and check the definition with `doskey /macros`.
3. The Ctrl-C summary needs a real keyboard: `ping 1.1.1.1`, a few replies, Ctrl-C → summary and prompt back at once; `ping 192.0.2.1` (never answers) → Ctrl-C cuts just as fast, summary with 100% loss. Luis verified the first on 2026-09-18 in Git Bash, PowerShell 7 and cmd (cmd does not ask to terminate a batch job). What an agent can do is stop the pipeline, which is what the host does on Ctrl-C: run the script through `[powershell]::Create().AddScript(…).BeginInvoke()`, call `.Stop()` after a couple of seconds, and the summary must appear on the console.
4. WSL stays down: with the VM stopped (`wsl --shutdown` — ask Luis first), run `ping -c 1 <gateway>` from Git Bash; `wsl --list --running` must list nothing and this query must show no new event:

```powershell
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-Hyper-V-VmSwitch'; Id=9} -MaxEvents 3
```
