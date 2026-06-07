# TTT_ArousedNips (w/ Areola Fix + 3BA, 1.1.4 ESL AE)

Skyrim SE mod by TanookiTamaTachi. Drives BodyMorph sliders on nipples/areolas in proportion to an actor's SexLab Aroused arousal value (0 = no morph, 100 = full effect, linear in between). This folder is a Mod Organizer 2 mod directory — not a development repo with a `dist/` tree.

## Build

**Do NOT compile.** The user compiles Papyrus themselves. Edit `.psc` sources under `source\scripts\` and stop. Verify correctness by reading the code.

If the user asks how to build, they use `PapyrusCompiler.exe` with `skyrimse.ppj` (e.g. via Caprica / pyro / the Creation Kit). The PPJ writes `.pex` output to `scripts\` and produces a release zip under `Release\` when `Zip="true"`.

## Bumping the Version

Three places hold the version — keep in sync:

1. **`meta.ini`** — `version=1.1.4`. MO2 reads this; canonical user-facing version.
2. **`TTT_ArousedNipsConfigMenu.psc`** — `GetVersion()` returns an integer (see the function for the packing scheme). Recompile to `.pex` after editing.
3. **`ReadMe_TTT_ArousedNips.txt`** — top-of-file version line and changelog entry.

Original mod was 1.1.2 by TanookiTamaTachi; this folder's `1.1.4` reflects the bundled Areola Fix + 3BA patch.

## Project Layout

```
TTT_ArousedNips.esp              Plugin (ESL-flagged ESP for AE)
ReadMe_TTT_ArousedNips.txt       User-facing readme + changelog
meta.ini                         Mod Organizer 2 metadata
skyrimse.ppj                     Papyrus project (compile + zip config)
source/scripts/*.psc             Papyrus source (4 scripts)
scripts/*.pex                    Compiled bytecode
```

### Scripts

| Script | Role |
|--------|------|
| `TTT_ArousedNipsQuest` | Hosts mod state: morph names, max-value sliders, defaults, flags (`DebugMode`, `IgnoreMales`, `isNioOk`, `isSLAroused28/29`). `OnInit()` runs first-time setup. |
| `TTT_ArousedNipsAlias` | `ReferenceAlias` on the player. Detects NiOverride/SKEE version, identifies which SLA flavor is installed (Aroused Redux, AroustedSSELoose, Aroused NG), runs `UpdateActor()` to push BodyMorph values. NIO key is `"TTT_ArousedNips.esp"`. |
| `TTT_ArousedNipsConfigMenu` | SkyUI MCM. Exposes per-morph max-value sliders at 0.01 step, `IgnoreMales` toggle, `DebugMode` toggle (grants the debug spell), JSON import/export via `JsonUtil` (`ArousedNips/config.json`, `ArousedNips/morph.json`). 4 morphs by default. |
| `TTT_ArousedNipsDebugSpellEffectScript` | Lesser-power magic effect. Casts on crosshair target (or self), dumps actor base + current morph values to the Papyrus log, then forces an `UpdateActor()` and dumps again. |

### Hard Dependencies

| Dep | Provides | Min version | Reference path on this machine |
|-----|----------|-------------|---------------------------------|
| SexLab Aroused (one of: Redux SSELoose v28, eXtended LE v29, or NG) | `slaMainScr`, `slaFrameworkScr`, `slaConfigScr` | SSELoose 28 / LE 29 / NG (any) | `C:\Playground\Skyrim\mods\SKSE\SexlabArousedNG` (this is the canonical reference — its `dist\Core\Source\Scripts\slaconfigscr.psc` is what the PPJ imports) |
| SexLab Framework | `SexLabFramework` | any | `C:\Playground\Skyrim\mods\build\Sexlab\scripts\Source` |
| RaceMenu / NiOverride (SKEE) | BodyMorph API | SKEE 1, NiOverride script v6 | `C:\Playground\Skyrim\mods\build\racemenu\scripts\source` |
| PapyrusUtil | `JsonUtil`, `MiscUtil` | any | `C:\Playground\Skyrim\mods\build\PapyrusUtil\Source\Scripts` |
| SkyUI | `SKI_ConfigBase` (MCM) | optional but expected | `C:\Playground\Skyrim\mods\build\SkyUI_5.1_SDK\Scripts\Source` |

#### SLA flavor detection (multi-fork)

Follows the **"Supporting Both OSL Aroused and SLA NG"** pattern from `SexlabArousedNG/README.md`. `TTT_ArousedNipsAlias.OnPlayerLoadGame` calls `sla_Framework.GetVersion()` (portable across forks — both OSL's stub and real SLA NG implement it on `slaframeworkscr`) and branches on the date-stamped scheme:

| `GetVersion()` | Fork | Flag set | Read path |
|---|---|---|---|
| `>= 20200000` | SexLab Aroused NG / SLO Aroused NG (3.x, packs `MMmmppp`) | `isSLAroused29 = true` | `GetActorArousal` — full recalculation per call |
| `> 0` and `< 20200000` | OSL Aroused stub (`20140124`), SLAXSE2022 (`20190720`), eXtended LE, SSELoose | `isSLAroused28 = true` (relabel: "Legacy / OSL stub") | `GetActorArousal` works on the stub too |
| `0` | Nothing installed | both flags `false` | abort with notification |

Why `GetActorArousal` and not the `slaArousal` faction rank: the faction rank is a *cache* that SLA only refreshes on its scheduled scan tick (default 120s). `GetActorArousal` routes through `slaInternalModules.GetArousal(who)` which triggers a fresh recalculation on every call — required for the poll loop to be useful.

Historically the version branches were inverted (they set the flags to `false` on supported versions and aborted), which made the alias bail out on every real install. Fixed in 1.1.4 — see the readme changelog.

#### Player poll (mid-scene responsiveness)

`SLA NG` only broadcasts `sla_UpdateComplete` at the end of its periodic scan ([slamainscr.psc:819](../../SKSE/SexlabArousedNG/dist/Core/Source/Scripts/slamainscr.psc#L819)), default every 120s. Without a separate driver, mid-scene arousal changes from OSL/OStim, denial ramps, sleep decay etc. would not move the morphs until the next heartbeat.

The alias now runs its own player-only poll via `Event OnUpdate()`:

- Re-arms on each tick via `RegisterForSingleUpdate(PollInterval)` (the SLA pattern — gives an MCM-tunable cadence without the global cost of dropping SLA's scan interval).
- Reads `PollInterval` from `TTT_ArousedNipsQuest.PollInterval` (default 5.0s, MCM-configurable 0–60s; `0` disables polling and reverts to heartbeat-only behaviour).
- Calls `UpdateActor(Game.GetPlayer(), false)` — that's it. NPCs still only refresh on the heartbeat path (`OnArousalComputed`), to keep the per-tick cost trivial.
- `RestartPolling()` is called from the MCM after the slider is changed (cancels any pending tick, re-arms at the new interval, and restarts a `0 → non-zero` transition).

`SexLab StageStart` remains a separate path with its own immediate `+50` morph bump per stage — unaffected by the poll.

A BodySlide-compatible body/armor with morph data generated is required for the effect to be visible in-game (this is a user-side concern, not a code concern).

## Papyrus Project (skyrimse.ppj)

- `Output="scripts"` — `.pex` files land in the `scripts\` folder at mod root, matching MO2 layout.
- `Folders` points at `.\source\scripts` — flat layout, no nested `dist/` tree.
- `Imports` includes the local source first, then SLA NG, SexLab, SkyUI, PapyrusUtil, RaceMenu (the actual dependencies of these 4 scripts). The remaining imports are kept around to compile shared utility scripts that happen to be imported transitively — leave them unless you have a reason to prune.
- `ZipFiles` produces `Release\TTT_ArousedNips.zip` containing the ESP, readme, compiled scripts, and source.

## Papyrus Language Notes

### Control flow
- No `break` or `continue` — use flags or early `return` to exit loops.
- Only `if/elseif/else/endif` and `while/endwhile`. No for-loops, switch, or do-while.
- Logical `||` and `&&` short-circuit.

### Variables & types
- Five base types: `Bool`, `Int`, `Float`, `String`, plus object references and arrays.
- Value types copied on assignment; objects/arrays are by reference.
- **Locals are function-scoped, not block-scoped.** Declaring the same name in sibling `if` branches is a compile error — hoist the declaration above the branches.
- Variables inside `while` loops persist across iterations (NOT reset each iteration). Initialize explicitly.
- Script-level variables can only be initialized with literals; function-level can use expressions.

### Arrays
- Max 128 elements. Size must be an integer literal (`new float[4]`), not a variable.
- `array[i] += 5` does NOT compile — use `array[i] = array[i] + 5`.
- No arrays of arrays. Passed/assigned by reference.
- `Find()` / `RFind()` and SKSE string functions are case-insensitive; `==` string comparison is case-sensitive.

### States
- Script can be in only one state at a time. `GotoState("")` returns to empty state.
- State function signatures must exactly match the empty-state definition.
- State transitions fire `OnEndState()` → change → `OnBeginState()`.

### Threading
- Only one thread can run a script instance at a time. Any external call (including `Debug.Trace()`, property access on other objects) unlocks the script, allowing other threads in.
- After an external call returns, local assumptions about script state may be stale.

### Misc gotchas
- Compiler does not check all code paths for return values — missing returns cause undefined behavior.
- `parent.FunctionName()` calls one level up, not necessarily the base definition.
- Unary minus can misbehave without spaces: write `x = y - 1` not `x = y-1`.

## Code Conventions

- Papyrus source: `source\scripts\*.psc`. Compiled: `scripts\*.pex`. Both folders are flat — no subdirectories.
- Keep edits ASCII unless the file already contains non-ASCII.
- JSON config files (`ArousedNips/config.json`, `ArousedNips/morph.json`) live in `Data\SKSE\Plugins\StorageUtilData\` at runtime — not in this mod folder. Both files store all values as strings; readers cast to `int`/`float`, writers must do `(value as int) as string` / `(value as string)` explicitly.
- JsonUtil API quick-reference (callers must use the *real* function names):
  - `StringListClear(file, listKey)` — not `ClearList`
  - `StringListCount(file, listKey)` — count of entries
  - `StringListGet(file, listKey, index)` — read entry
  - `StringListAdd(file, listKey, value, allowDuplicate)` — append entry
  - `GetStringValue(file, key, missing)` — third arg is the default; pass positionally (do not use named-arg syntax)
  - `SetStringValue(file, key, value)` — value must be a string; cast bool/int/float explicitly
- Papyrus does not support named arguments in the stock CK compiler. Always use positional args.

## Commit Conventions

- **Never include a `Co-Authored-By: Claude ...` trailer** in commit messages. Commits should look authored solely by the human user.
- This folder is not a git repository; if commits are needed, the user runs `git init` first.
