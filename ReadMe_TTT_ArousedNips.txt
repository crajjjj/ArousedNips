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
1.1.4 (this build, w/ Areola Fix + 3BA bundle)
- Multi-fork compatibility per the SLA NG readme's "Supporting Both OSL Aroused
  and SLA NG" guidance:
    * Version detection now goes through slaframeworkscr.GetVersion() (portable
      across both forks) instead of the SLA-NG-only slaConfig path that was
      aborting on every real install.
    * Arousal reads now use slaframeworkscr.GetActorArousal() instead of the
      cached slaArousal faction rank. Three benefits: it works the same on OSL
      Aroused's stub, on legacy forks, and on SLA NG / SLO NG; it triggers a
      fresh recalculation rather than returning a stale cached value; and it's
      properly clamped 0-100.
    * Version gate: >= 20200000 -> SLA NG / SLO NG (full API); > 0 -> OSL stub
      / SLAXSE2022 / legacy SSELoose / eXtended LE (read-only path still works);
      0 -> not installed, abort. MCM rows updated to "NG / 3.x" vs
      "Legacy / OSL stub".
- Player-only poll: the alias now refreshes the player's morphs every
  PollInterval seconds (default 5s, MCM-configurable 0-60). SLA NG only
  broadcasts sla_UpdateComplete on its scheduled scan (default 120s), so
  without this poll mid-scene arousal changes from OSL/OStim or denial ramps
  wouldn't move the morphs until the next heartbeat. Setting the slider to 0
  disables the poll and reverts to heartbeat-only behaviour. NPCs continue to
  update on the SLA heartbeat path only.
- MCM: the "SLAroused 29+" requirements row now displays correctly (was hidden
  by a duplicate elseif condition).
- MCM Import Settings no longer corrupts the DebugMode / IgnoreMales option IDs;
  imported values are now applied to the quest properties instead of being
  written into the option-ID variables.
- MCM Export Settings: fixed an infinite loop that would hang the Papyrus VM
  whenever a morph slot was empty.
- MCM Import morph-list loop bound fixed (was effectively while-i<100 due to
  an || that should have been &&); morph table sizing aligned to 128 to match
  the quest's array allocation.
- First-time install no longer wipes the default morph table when no
  ArousedNips/morph.json exists yet.
- JsonUtil calls cleaned up: removed unsupported named-argument syntax,
  added proper bool->int->string casts on export, and the morph list is
  cleared before each export so repeated exports don't accumulate duplicates.

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