ArousedNips 1.1.2
by TanookiTamaTachi

This is a small mod that applies BodyMorphs to characters' nipples, depending on their arousal.
The morphing is proportional to the arousal of the player or NPC in question, with no change at 0 and full effect at 100, with everything inbetween scaling linerarly.

- Inspired by some random post I saw like half a year ago -

Requirements:

Required:
- SKSE (matching your Skyrim version: SKSE64 for SE, SKSE for AE/VR).
- PapyrusUtil SE -- the MCM Import/Export and the bundled morph preset
  use JsonUtil from this.
- RaceMenu / NiOverride (SKEE). NiOverride script version 6 or later (the
  alias verifies this at every game load and aborts if absent).
- SexLab Aroused -- any one of the supported forks. Detected automatically
  via slaframeworkscr.GetVersion(); the MCM Requirements row tells you
  which path was taken. In order of recommendation:
    * SexLab Aroused NG / SLO Aroused NG (best multi-mod compatibility,
      modern API, full read+write arousal support)
    * SexLab Aroused Redux SSE / SSELoose v28 (legacy SE)
    * SexLab Aroused eXtended (LE) v29 (legacy LE)
    * OSL Aroused stub (read-only; mod displays current arousal but can't
      affect ramps. Same alias path as the legacy forks.)
- BodySlide 2.8 or later, with morphs generated for your current body
  and armours. WITHOUT this the morph values are written into NiOverride
  but produce no visible change in-game.
- A BodySlide-compatible body. 3BA / CBBE 3BA recommended (ships the
  4 default nipple morphs: NippleSize, NippleLength, NipplePerkiness,
  AreolaSize). UUNP also works for the 4 nipple defaults.

Strongly recommended:
- SkyUI 5.1 or later -- the mod runs without it but you can't configure
  anything (slider tuning, preset import, requirements check display,
  recovery reset all require the MCM).

Optional -- only if importing the bundled 23-morph preset (Recovery >
Import Settings in MCM):
- A body / morph pack that defines the labia / vagina / clit slider names
  referenced by the preset (innieoutie, labianeat_v2, labiatightup,
  labiapuffyness, labiamorepuffyness_v2, labiaprotrude / 2 / back,
  labiaspread, labiacrumpled_v2, labiabulgogi_v2, vaginasize, vaginahole,
  clit, clitswell_v2, cutepuffyness, cbpc, nippleperkmanga, nippletube_v2).
  3BA Genital Morphs (or an equivalent labia/vagina morph add-on) covers
  these. The preset will Import cleanly even without these morph names
  defined on the body -- the extra sliders just become silent no-ops
  in-game.

Please note: The effect will only be visible if you have properly generated
the Morphs in BodySlide for your current nude body or armour!

The strength of the morphs can be adjusted individually in an MCM, at a step rate of 0.01, so you'll be able to make exactly the nips you want. I recommend using the Racemenu sliders for preview purposes.


This mod works purely event-based, and therfore shouldn't cause much script load.


Uninstallation:
Just remove the mod. NiOverride will automatically remove all the morphs.


yeh. That's all.

Changes
2.1.1 (by crajjjj)
- New MCM "Recovery > Reset all state" button. Wipes the persisted morph
  table back to 4 nipple defaults, resets every toggle / slider to its on-
  install value, and re-runs the requirements check against the live SLA
  framework. Use this if upgrading from a different fork (Anon 2.0.4 etc)
  leaves you with mismatched arrays -- symptoms include all MCM sliders
  stuck at 0.00, "SLAroused (Required): Try Load Save" with SLA actually
  installed, or persistent "Cannot access an element of a None array"
  errors in Papyrus.0.log from OnPageReset. After clicking Reset, click
  Import Settings to re-apply the bundled 23-morph preset (or any config
  you previously exported).
- SLA framework resolution now falls back to Quest.GetQuest("sla_Framework")
  if the ESP-wired sla_Framework Auto property is None. Older forks of
  TTT_ArousedNips.esp have been observed shipping with the property silently
  unwired -- callers got None from the property even when SLA was loaded and
  the quest was alive in memory. This was the actual root cause of "SLAroused
  (Required): Try Load Save" persisting across save+reload on otherwise-
  healthy SLA NG installs. The fallback follows the SLA NG readme's official
  multi-fork detection pattern (both SLA NG / SLO and OSL Aroused's stub
  ship a quest with editor ID "sla_Framework"). A diagnostic trace
  ("sla_Framework Auto property is None; resolved via Quest.GetQuest
  fallback") fires on every game load when the fallback kicks in.

2.1.0 (by crajjjj)
- Bundled 23-morph labia/vagina preset cherry-picked from the community Anon 2.0.4
  fork. Ships as Data\SKSE\Plugins\StorageUtilData\ArousedNips\morphs.json --
  click "Import Settings" in the MCM once after install to activate it. Default
  on-load behaviour is unchanged (4 nipple morphs); the preset is purely
  opt-in.
- New MCM "Performance" slider: NPC scan radius (100-10000 units, default 1000).
  Replaces the previously-hardcoded 1000 in the SLA-heartbeat NPC cell scan.
- New MCM "Debug" toggles, all default on:
    * Ignore Dead -- skips corpses (filters at both the cell scan and
      UpdateActor for the player poll / debug spell paths). NOTE: the Anon
      2.0.4 fork shipped this toggle but never wired it into UpdateActor;
      ours actually works.
    * Ignore Male Beasts -- skips creature actors with GetSex() == 2 (wolves,
      bears, etc; NOT the playable beast races Khajiit/Argonian which are
      GetSex() 0/1 and remain covered by Ignore Males).
    * Ignore Female Beasts -- as above for GetSex() == 3.
- Version int bumped from 10105 to 20100 specifically so upgrades from saves
  with the Anon 2.0.4 fork (which persisted SKI CurrentVersion=20004) fire
  OnVersionUpdate and clear the stale "2.0.4" MCM header string. Going from
  1.1.5's 10105 to a 1.x.y would have looked like a downgrade to SKI and left
  the header unrefreshed.
- All 1.1.5 fixes carry forward: portable slaframeworkscr.GetVersion() multi-
  fork SLA detection (NG / SLO / OSL stub / SSELoose / eXtended), portable
  GetActorArousal() reads (fresh recalc, no faction-rank caching), player-only
  poll for mid-scene responsiveness, MCM Import not clobbering option IDs,
  Export not infinite-looping on empty morph slots, no Quest.OnInit -> MCM
  re-entrance freeze, etc. See the 1.1.5 entry below for the full list.

1.1.5 (by crajjjj)
- FREEZE FIX: removed the Quest.OnInit -> CONFIGMENU.ImportUserSettings()
  callback and the OnVersionUpdate -> RestartPolling() cross-script call.
  Both could fire while SkyUI was mid-registering the MCM, and the resulting
  cross-script lock contention wedged the Papyrus VM hard enough to freeze
  the game on first install / first load after the version bump. Auto-import
  on first install is intentionally gone -- cosave persistence already covers
  upgrades; users who want to restore an exported JSON config can click
  "Import Settings" from the MCM at any time.
- Multi-fork compatibility per the SLA NG readme's "Supporting Both OSL Aroused
  and SLA NG" guidance:
    * Version detection now goes through slaframeworkscr.GetVersion() (portable
      across both forks) instead of the SLA-NG-only slaConfig path that was
      aborting on every real install -- both fork-detection if-branches were
      previously inverted so the alias bailed out on every supported version.
    * Arousal reads now use slaframeworkscr.GetActorArousal() instead of the
      cached slaArousal faction rank. Works the same on OSL Aroused's stub,
      legacy forks, and SLA NG / SLO NG; triggers a fresh recalculation rather
      than returning a stale cached value; properly clamped 0-100.
    * Version gate: >= 20200000 -> SLA NG / SLO NG (full API); > 0 -> OSL stub
      / SLAXSE2022 / legacy SSELoose / eXtended LE (read-only path still works);
      0 -> not installed, abort. MCM rows relabeled "NG / 3.x" and
      "Legacy / OSL stub".
    * Null-check on sla_Framework so an unwired property aborts cleanly with
      a notification instead of null-crashing the alias.
- Player-only poll: the alias now refreshes the player's morphs every
  PollInterval seconds (default 5s, MCM-configurable 0-60). SLA NG only
  broadcasts sla_UpdateComplete on its scheduled scan (default 120s), so
  without this poll mid-scene arousal changes from OSL/OStim or denial ramps
  wouldn't move the morphs until the next heartbeat. Setting the slider to 0
  disables the poll and reverts to heartbeat-only behaviour. NPCs continue to
  update on the SLA heartbeat path only.
- MCM:
    * The "SLAroused 29+" requirements row now displays correctly (was hidden
      by a duplicate elseif condition).
    * Import Settings no longer corrupts the DebugMode / IgnoreMales option
      IDs; imported values are applied to the quest properties instead.
    * Export Settings: fixed an infinite loop that would hang the Papyrus VM
      whenever a morph slot was empty.
    * Import morph-list loop bound fixed (was effectively while-i<100 due to
      an || that should have been &&); morph table sizing aligned to 128 to
      match the quest's array allocation.
    * First-time install no longer wipes the default morph table when no
      ArousedNips/morph.json exists yet.
    * OnPageReset no longer renders a bogus blank slider row after the first
      empty morph name.
    * Performance page added with the player poll slider.
    * Info text for the Ignore Males toggle no longer falls through to the
      generic "by TTT" tagline.
- Save handling: OnVersionUpdate no longer Stop()s + Start()s the main quest
  on version bumps -- that was wiping MorphNames / MaxValue / PollInterval
  and tearing down the polling registration. New poll properties are added
  Auto Hidden with sensible defaults so older saves load cleanly.
- UpdateActor honours imported morph counts up to 128 (was hard-coded to 4,
  silently dropping any morph past index 3 even though the MCM rendered them);
  GetActorArousal result clamped [0, 100] symmetrically so future negative
  modifiers can't flip the morph direction; GetLeveledActorBase() cached so
  the debug branch isn't calling it three times.
- NPC scan no longer arbitrarily capped at the first 20 actors -- now scans
  up to whatever ScanCellNPCsByFaction returns (max 127); duplicated
  debug/non-debug branches of OnArousalComputed collapsed into one.
- JsonUtil calls cleaned up: removed unsupported named-argument syntax,
  added proper bool->int->string casts on export, ImportUserSettings
  reallocates MaxValue together with MorphNames so re-imports with fewer
  morphs can't leave stale tail values, and the morph list is cleared before
  each export so repeated exports don't accumulate duplicates.

1.1.4
- Bundled re-pack with Areola Fix patch and 3BA body morphs.
- ESP flagged ESL for AE load-order safety.

1.1.2
- Fixed the MCM toggle "Ignore Males" not actually doing anything. Oops.

1.1.1
- Changed the way updates during sex work. Should be a more noticeable effect now.

1.1.0
- Added an experimental feature to update actors currently having sex at the beginning of every animation stage. SLAR has a feature that should increase Arousal during sex, but I'm not quite sure if it'll be a noticeable effect.

1.0.3
- Fixed a bug where the player's nipples wouldn't be updated when there were no NPCs nearby.
- Due to popular request, added a toggle to ignore male actors. I doubt it'll change much, but hey, options!

1.0.2
- Added Debug Spell to hopefully facilitate helping people for whom it doesn't seem to work. To access it, simply tick "Debug mode" in the MCM. A lesser power "ArousedNips Debug Spell" will be added. Cast it on an actor (or no one to target yourself) to print their info to your papyrus log.

1.0.1
- fixed issue where MCM sliders would not initialize properly.

1.0.0
- initial release