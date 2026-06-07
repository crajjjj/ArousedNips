ArousedNips 1.1.2
by TanookiTamaTachi

This is a small mod that applies BodyMorphs to characters' nipples, depending on their arousal.
The morphing is proportional to the arousal of the player or NPC in question, with no change at 0 and full effect at 100, with everything inbetween scaling linerarly.

- Inspired by some random post I saw like half a year ago -

Requirements:
SexLab Aroused (one of):
  - SexLab Aroused Redux SSE / SSELoose v28
  - SexLab Aroused eXtended (LE) v29
  - SexLab Aroused NG (recommended for SE/AE; tested against the build in
    C:\Playground\Skyrim\mods\SKSE\SexlabArousedNG)
RaceMenu / NiOverride (SKEE) 3.4.5 or later
BodySlide 2.8 or later (3BA/CBBE/UUNP morphs)
SkyUI if you want to use the MCM
BodySlide compatible Body and Armors
Please note: The effect will only be visible if you have properly generated the Morphs in BodySlide for your current nude body or armor!

The strength of the morphs can be adjusted individually in an MCM, at a step rate of 0.01, so you'll be able to make exactly the nips you want. I recommend using the Racemenu sliders for preview purposes.


This mod works purely event-based, and therfore shouldn't cause much script load.


Uninstallation:
Just remove the mod. NiOverride will automatically remove all the morphs.


yeh. That's all.

Changes
1.1.5
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