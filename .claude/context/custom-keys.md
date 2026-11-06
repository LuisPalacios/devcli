# custom_keys — Mac-style keyboard layer for Windows (context)

**Audience**: future sessions touching the `custom_keys` feature. Read BEFORE changing any file in the map below. User-facing doc: `docs/teclado-mac.md` (Spanish, has the full key map, limitations, real-keyboard test checklist and the D1–D8 rationale).

**Privacy rule (public repo)**: no person names, machine names or personal data in any versioned file or commit about this feature. No author credit (user decision).

## File map

| Path | What it is |
| --- | --- |
| `dotfiles/wezterm.lua` §9 | Generic, cross-platform hook. If `<config_dir>/custom_keys.lua` exists: `loadfile` + `pcall(chunk)` + check it returns a table with `apply`, then `pcall(mod.apply, config)`. Any failure → `wezterm.log_error`, config stays alive. Runs last (after §7/§8) so it can extend `config.keys`. |
| `dotfiles/custom_keys.lua` | Default module (Windows-only behaviour): F13–F24 / Shift+F13–F24 action table, keys that arrive unchanged (Alt+Enter, Ctrl+Alt+arrows, Alt+Home/End/PgUp/PgDn, Ctrl+1–9, Ctrl++/−/0), pane equalizer (`M.split`, `M.close`), `search_mode` F21/F22. `apply` is a no-op outside Windows. |
| `dotfiles/custom_keys.powertoys.json` | GENERATED Keyboard Manager map (153 shortcuts: 92 global, 61 `targetApp: wezterm-gui`). Never hand-edit; regenerate. |
| `install/build-custom-keys.ps1` | Generator (PS7). Tables `Get-GlobalRemaps` / `Get-TerminalRemaps`, `Test-RemapList` (no duplicate key sets; VK 165 AltGr and VK 18 any-Alt forbidden as source), fixed renderer (2-space, LF, no BOM). `-Check` exits 1 if the JSON is stale or the map invalid. |
| `install/05-customkeys.ps1` | Windows-only phase (no `.sh` twin; `bootstrap.sh` globs `[0-9][0-9]-*.sh`). Params let you point it at scratch dirs: `-StateFile -BackupRoot -WezTermDir -PowerToysDataDir -NoPowerToysProcess`. |
| `bootstrap.ps1` | `-CustomKeys on|off|force` → `$env:DEVCLI_CUSTOM_KEYS`; forwarded on the 5.1 → pwsh relaunch. |
| `install/utils.ps1` | `Install-WingetPackage -ExtraArgs` (used for `--scope user`); `Show-UxSummary` block reading `$env:DEVCLI_CUSTOMKEYS_*`. |
| `~/.config/devcli/state.json` | Per-machine state: `customKeys.enabled`, `customKeys.deployed` (logical key → SHA-256 of what devcli wrote), `lastRun`. |
| `~/.config/devcli/backups/custom-keys-<ts>/` | Backups, one dir per run, created lazily. |

## The contract (why the two halves ship together)

Inside `wezterm-gui`, PowerToys maps Cmd (LAlt) shortcuts to F13–F24 / Shift+F13–F24; `custom_keys.lua` gives each an action. Unused Cmd+letter → F24 (Nop) so no control char reaches the program (Cmd+C never SIGINTs). PowerToys without the `.lua` → Cmd+C does nothing in WezTerm; `.lua` without PowerToys → no F13–F24 ever arrives. F-keys instead of Ctrl+Shift because `wezterm.lua` already owns CTRL+SHIFT+A/E/T. If you add an F-key in one file, add it in the other.

WezTerm on Windows (20240203) only decodes F13–F20 as `Physical(Fn)`; F21–F24 arrive as `RawCode(132–135)` (phys_code None), so `key='F21'` never matches. `with_raw_twins()` in `custom_keys.lua` duplicates every F21–F24 binding (main table and `search_mode`) as `raw:<VK>`. Verified with `debug_key_events` + `show-keys` (2026-11-06). Deliberate deviation from the source material (which has the same bug).

VK codes: LWin 91, LShift 160, LCtrl 162, LAlt 164, RAlt/AltGr 165, F13–F24 = 124–135. Spanish ISO symbol keys: 186 ` 187 + 188 , 189 - 191 ç 192 ñ 220 º 222 ´.

## Phase 05 behaviour (settled decisions)

- **D1 opt-in, persistent**: `on`/`force` set `enabled=true`, `off` sets false, absent keeps the stored value (default off). Off → phase prints `desactivada (bootstrap -CustomKeys on)` and touches nothing.
- **D2 seed policy** (`Set-SeededFile`): missing → write · same hash as new → nothing · recorded and current == recorded → update · recorded and current ≠ recorded → `kept` + warning (unless `force`) · no record (devcli never deployed it) → backup + replace. Statuses: `created|unchanged|updated|replaced|kept|forced`.
- **D4 PowerToys**: detect `%LOCALAPPDATA%\PowerToys\PowerToys.exe` or `%ProgramFiles%\PowerToys\PowerToys.exe`; else `winget install Microsoft.PowerToys --exact --source winget --scope user` (user installer exists) and start it once so it creates its settings. `startup` / `enabled."Keyboard Manager"` are fixed only when PowerToys is NOT running (it rewrites its general `settings.json` while running); otherwise just warn. `run_elevated` is never written (needs admin + UAC), but if it is false/missing `Confirm-PowerToysSettings` warns on EVERY run asking the user to enable PowerToys → General → «Ejecutar siempre como administrador» (decision 2026-11-06: elevation is recommended; without it the layer is dead in elevated windows due to UIPI).
- **Map target** = `Keyboard Manager\<properties.activeConfiguration.value>.json` (don't assume `default`). Writing it also deletes `editorSettings.json` (the new editor's private copy; if stale it resurrects old rules when the editor opens).
- **Editor shortcut**: `properties.EditorShortcut = {win,ctrl,alt:false,shift,code:81,key:""}` edited as JSON (the key may not exist on a stock install). Only read at PowerToys start → needs a restart.
- **Editor open** (`PowerToys.KeyboardManagerEditorUI` WinUI3 or classic `PowerToys.KeyboardManagerEditor`) → warn, skip map + shortcut (the `.lua` is still deployed).
- **Reload**: map only → `EventWaitHandle.OpenExisting('PowerToys_KeyboardManager_Event_Settings').Set()` (verified: openable from a non-elevated process even when PowerToys runs elevated). Shortcut changed → stop + start via the `\PowerToys\Autorun for <user>` task (keeps elevation without UAC) or the exe. Verified on PowerToys 0.102 running elevated: a non-elevated bootstrap COULD stop it, and the autorun task brought it back elevated. If stopping ever fails → `DEVCLI_CUSTOMKEYS_RESTART=1` and the summary asks the user to restart it.
- **D8 symbols**: included only if `HKCU:\Keyboard Layout\Preload\1` (resolved through `Substitutes`) is `0000040a`/`00000c0a`; otherwise global entries whose target starts with `165;` are dropped (92 → 80) and the JSON is re-rendered with `ConvertTo-Json` (hash is of what was written, so still idempotent).
- **D6**: `custom_keys.lua` deploys only on Windows (phase 05), not via `03-dotfiles.json`.

## Testing

- Generator: `pwsh -NoProfile -File install/build-custom-keys.ps1 -Check`.
- Hook: `wezterm --config-file <dir>/wezterm.lua show-keys --lua` with no / broken / non-table / throwing / valid `custom_keys.lua` next to it. (Note: with `--config-file`, `package.path` still points to `~/.config/wezterm`, which is why the hook uses `loadfile`, not `require`.)
- Phase dry run: call `install/05-customkeys.ps1` with all path params pointing at a scratch dir plus `-NoPowerToysProcess`, `$env:SETUP_DIR` = clone, `$env:DEVCLI_CUSTOM_KEYS` = mode.
- Pane equalizer: an external Lua harness (not in the repo) that loads `dotfiles/custom_keys.lua`, splits in many layouts and logs pane sizes. Known pre-existing limits: some 5-column and mixed 6-column orders end uneven (one mixed order leaves a 0-width pane on a 241-col window).
- Keys only count as tested when pressed on a real keyboard (checklist in `docs/teclado-mac.md`).

## Known pitfalls

- The editor open suspends every remap and overwrites files on save.
- `wezterm.gui` is nil when the config is evaluated without GUI (`wezterm cli`, mux server): the module then skips `key_tables`.
- If `wezterm.lua` ever defines `config.key_tables`, the module extends `search_mode` instead of replacing the tables.
- PowerToys events only exist in the desktop session; over SSH nothing reloads (and winget/AppX aliases fail).
