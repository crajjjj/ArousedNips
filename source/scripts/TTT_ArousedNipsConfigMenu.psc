ScriptName TTT_ArousedNipsConfigMenu extends SKI_ConfigBase
{the MCM, what else}

TTT_ArousedNipsQuest Property TTT_ArousedNipsMainQuest Auto
Spell Property TTT_ArousedNipsDebugSpell Auto

float property range = 3.0 AutoReadOnly hidden

int hasReqFlag
; Requirements-only variant of hasReqFlag: set when NiOverride / SLA are missing,
; but NOT when the mod is merely switched off. Used by the options that are
; diagnostics rather than tuning, so they keep working in the state they exist to
; report on.
int reqOnlyFlag

int oidModEnabled
int oidDebugMode
int oidIgnoreMales
int oidPollInterval
int oidScanCellRadius
int oidIgnoreDead
int oidIgnoreMaleBeast
int oidIgnoreFemaleBeast
int oidSuppressUnderArmor
int oidUnderArmorScale

; Combobox options for the intensity preset. Hardcoded in fixed order so the
; dropdown shows "Minimal" -> "Exaggerated" rather than alphabetical.
; Backed by JSON files at SKSE\Plugins\StorageUtilData\ArousedNips\
; IntensityPresets\<name>.json. Allocated lazily in GetIntensityPresetNames().
String[] _intensityPresetNames

int[] oidMaxValue

string version

bool toggleDebugSpell = false

String Property TTT_AN_Config_File = "ArousedNips/config.json" Auto hidden
String Property TTT_AN_Morph_file = "ArousedNips/morph.json" Auto hidden
int Property TTT_AN_Morphs = 4 Auto hidden

import JsonUtil
import MiscUtil


int function GetVersion()
	;format = (M)MmmPP
	;12345 => 1.23.45
	; 20102 = 2.01.02. The 2.01.00 baseline was chosen to skip ahead of the
	; Anon 2.0.4 fork (20004) so SkyUI's OnVersionUpdate gate
	; (CurrentVersion < GetVersion) fires when upgrading from a save that
	; previously had 2.0.4 installed -- clears the stale "2.0.4" MCM header
	; string and triggers the fork-to-1.1.5-based transition path.
	; 2.01.01 added the MCM Recovery > Reset button and the SLA framework
	; Quest.GetQuest fallback (handles ESPs where the sla_Framework Auto
	; property is unwired).
	; 2.01.02 adds the Intensity preset combobox (Minimal / Natural /
	; Noticeable / Exaggerated, backed by JSON files under
	; SKSE\Plugins\StorageUtilData\ArousedNips\IntensityPresets\).
	; 2.01.03 adds the under-armor suppression feature (Suppress morphs under
	; armor toggle + Nipple size under armor slider, -1..1; Advanced Nudity
	; Detection-aware top-nudity gating in the alias, vanilla cuirass/clothing
	; worn-keyword fallback without AND).
	; 2.01.04 reworks the MCM into two pages (General / Morphs -- the single
	; page ran past SkyUI's ~26-row column limit and clipped the last morph
	; sliders), adds the "Player arousal" check row, and rounds out
	; Import/Export (pollinterval + intensitypreset now round-trip, imported
	; morph tables get correct slider defaults without a reload, DebugMode
	; import syncs the debug spell). Install-default slider values rebased
	; from the Noticeable tier to the Natural tier (DefaultForMorph ==
	; Natural.json; fresh installs / Reset show preset "Natural").
	; 2.01.05 adds the "Mod enabled" master switch at the top of the General
	; page. Switching it off clears this mod's morphs from the player and
	; nearby NPCs and puts the alias fully dormant (no poll, no heartbeat /
	; StageStart / armor-change work); every other option greys out while off.
	return 20105
endFunction

Event OnVersionUpdate(Int ver)
	{Called by SKI_ConfigBase when the saved version is below GetVersion(). Update
	 the cached display string only.

	 We deliberately do NOT call anything cross-script here (no stop()/start(), no
	 RestartPolling on the alias). OnVersionUpdate fires DURING SkyUI's MCM
	 registration on first-install / first-load-after-bump, when the MCM script
	 lock is contended. Reaching across to the Quest / Alias from here was
	 reproduced freezing the game on the 1.1.4 -> 1.1.5 bump. The poll is
	 (re-)registered by Alias.OnPlayerLoadGame on every save load anyway, so no
	 force-restart is needed.}
	int Major = ver/10000
	int Minor = (ver%10000)/100
	int Patch = ver%100
	version = Major+"."+Minor+"."+Patch
	debug.Notification("ArousedNips: Updating to "+version)
	debug.Trace("TTT_ArousedNips: Updating to "+version)
EndEvent

Event OnConfigInit()
	debug.Notification("ArousedNips: Registering MCM. This could take a while.")
	debug.Trace("TTT_ArousedNips: Registering MCM. This could take a while.")
EndEvent

event OnConfigRegister()
	debug.Notification("ArousedNips: MCM registered!")
	debug.Trace("TTT_ArousedNips: MCM registered!")
	SetupPages()
	oidMaxValue = new int[128]
	TTT_ArousedNipsMainQuest.start()
endEvent


event OnConfigOpen()
	SetupPages()
	oidMaxValue = new int[128]
	; Upgrade heal: a save from before the full morph set shipped only the 4 nipple
	; morphs. Append the genital/labia sliders so they appear without a manual Reset.
	; EnsureFullMorphSet is non-destructive -- it preserves the existing 4 nipple
	; values (and their tuning). Self-terminating: after it runs MorphCount() is 23,
	; so this won't fire again.
	If TTT_ArousedNipsMainQuest.MorphCount() == 4
		TTT_ArousedNipsMainQuest.EnsureFullMorphSet()
	EndIf
	; Keep the MCM-side morph count in sync with whatever the table actually holds.
	TTT_AN_Morphs = TTT_ArousedNipsMainQuest.MorphCount()
endEvent

Function SetupPages()
	Pages = new string[2]
	Pages[0] = "General"
	Pages[1] = "Morphs"
EndFunction

Function RefreshReqFlag()
	{Recompute the disabled-flag applied to every tuning option: set when the mod is
	 switched off with the "Mod enabled" master toggle, or when its requirements
	 aren't met. Either way nothing the flagged options control has any effect, so
	 greying them out is honest rather than merely tidy.

	 Must run on EVERY page draw, not once per menu open: both the master toggle and
	 Recovery > Reset change this mid-menu and then redraw (Reset re-runs the
	 requirements check via ResetAllState -> Alias.OnPlayerLoadGame). A flag cached at
	 open time would leave the gated options greyed out against freshly-drawn "OK"
	 status rows until the MCM was closed and reopened -- failing exactly the recovery
	 path Reset exists for.

	 Deliberately NOT applied to "Mod enabled" itself, nor to Import / Export /
	 Reset: those have to stay usable to get back out of the disabled state. The
	 "Player arousal" check row and Debug mode take reqOnlyFlag instead -- they are
	 diagnostics, and a switched-off mod is a thing you may well want to diagnose.}
	reqOnlyFlag = 0
	If !(TTT_ArousedNipsMainQuest.isNioOk && (TTT_ArousedNipsMainQuest.isSLAroused28 || TTT_ArousedNipsMainQuest.isSLAroused29))
		reqOnlyFlag = OPTION_FLAG_DISABLED
	EndIf
	hasReqFlag = reqOnlyFlag
	If !TTT_ArousedNipsMainQuest.ModEnabled
		hasReqFlag = OPTION_FLAG_DISABLED
	EndIf
EndFunction

Event OnConfigClose()
	if toggleDebugSpell
		if TTT_ArousedNipsMainQuest.DebugMode
			Game.GetPlayer().addSpell(TTT_ArousedNipsDebugSpell)
		else
			Game.GetPlayer().removeSpell(TTT_ArousedNipsDebugSpell)
		endIf
		toggleDebugSpell = false
	endIf
EndEvent

event OnPageReset(string page)
	;;NOTE TO SELF;;;;;;;;;;;;
	;oid = AddSliderOption("desc",val,"{0}",flag)
	;oid = AddToggleOption("desc",val,flag)
	;oid = AddTextOption("desc","val",flag)
	;;;;;;;;;;;;;;;;;;;;;;;;;;
	RefreshReqFlag()
	ClearOptionIDs()
	If page == Pages[1]
		DrawMorphsPage()
	Else
		; "General", and the no-page-selected state ("") right after opening.
		DrawGeneralPage()
	EndIf
endEvent

Function ClearOptionIDs()
	{Option IDs are only valid for the page that drew them, and SkyUI ids are
	 buffer indices starting at 0 -- so a stale oid kept from the OTHER page can
	 numerically collide with a fresh oid on this one and misroute the handler
	 (e.g. a morph slider opening with the poll-interval dialog range). Wipe
	 everything to -1 before each page draw.}
	oidModEnabled         = -1
	oidDebugMode          = -1
	oidIgnoreMales        = -1
	oidPollInterval       = -1
	oidScanCellRadius     = -1
	oidIgnoreDead         = -1
	oidIgnoreMaleBeast    = -1
	oidIgnoreFemaleBeast  = -1
	oidSuppressUnderArmor = -1
	oidUnderArmorScale    = -1
	int i = 0
	while i < 128
		oidMaxValue[i] = -1
		i += 1
	endWhile
EndFunction

Function DrawGeneralPage()
	SetCursorFillMode(TOP_TO_BOTTOM)

	;Left side
	SetCursorPosition(0)
	AddHeaderOption("ArousedNips " + version)
	; Master switch. Never carries hasReqFlag -- it's the way back out of the
	; disabled state, so it has to stay clickable.
	oidModEnabled = AddToggleOption("Mod enabled", TTT_ArousedNipsMainQuest.ModEnabled)

	AddHeaderOption("Requirements")
	; Plain (disabled) status text, not clickable toggles -- these are read-only.
	String nioLabel = "MISSING"
	If TTT_ArousedNipsMainQuest.isNioOk
		nioLabel = "OK"
	EndIf
	AddTextOption("NiOverride / RaceMenu (SKEE)", nioLabel, OPTION_FLAG_DISABLED)
	String slaLabel = "MISSING - try loading a save"
	If TTT_ArousedNipsMainQuest.isSLAroused29
		slaLabel = "OK - NG / 3.x"
	ElseIf TTT_ArousedNipsMainQuest.isSLAroused28
		slaLabel = "OK - Legacy / OSL stub"
	EndIf
	AddTextOption("SexLab Aroused", slaLabel, OPTION_FLAG_DISABLED)
	; Live sanity check: click to read arousal fresh from SLA and re-apply morphs
	; (PokePlayerArousal on the alias).
	AddTextOptionST("State_CheckPlayer", "Player arousal", "Check now", reqOnlyFlag)

	AddHeaderOption("Intensity preset")
	; Display the last-selected preset name ("Natural" on fresh install / after
	; Reset, since the built-in defaults ARE the Natural tier; the "Choose..."
	; placeholder only shows on saves upgraded from pre-2.1.2 where the property
	; is still ""). Selecting one overwrites every MaxValue
	; slider with the preset's values for whichever morphs are currently
	; loaded -- sliders for morphs not in the preset (e.g. user-imported
	; morphs the bundled presets don't cover) keep their current values.
	String presetLabel = TTT_ArousedNipsMainQuest.IntensityPreset
	If presetLabel == ""
		presetLabel = "Choose..."
	EndIf
	AddMenuOptionST("State_IntensityPreset", "Preset", presetLabel, hasReqFlag)

	AddHeaderOption("Under armor")
	oidSuppressUnderArmor = AddToggleOption("Suppress morphs under armor", TTT_ArousedNipsMainQuest.SuppressUnderArmor, hasReqFlag)
	; Slider stays visible but disabled while suppression is off, so its role is clear.
	int uaFlag = hasReqFlag
	if !TTT_ArousedNipsMainQuest.SuppressUnderArmor
		uaFlag = OPTION_FLAG_DISABLED
	endif
	oidUnderArmorScale = AddSliderOption("Nipple size under armor", TTT_ArousedNipsMainQuest.UnderArmorScale, "{2}", uaFlag)

	AddHeaderOption("Performance")
	oidPollInterval   = AddSliderOption("Player poll interval (s)", TTT_ArousedNipsMainQuest.PollInterval, "{1}", hasReqFlag)
	oidScanCellRadius = AddSliderOption("NPC scan radius (units)",  TTT_ArousedNipsMainQuest.ScanCellRadius, "{0}", hasReqFlag)

	;Right side
	SetCursorPosition(1)
	AddHeaderOption("Actor filters")
	oidIgnoreMales       = AddToggleOption("Ignore males",         TTT_ArousedNipsMainQuest.IgnoreMales)
	oidIgnoreDead        = AddToggleOption("Ignore dead",          TTT_ArousedNipsMainQuest.IgnoreDead)
	oidIgnoreMaleBeast   = AddToggleOption("Ignore male beasts",   TTT_ArousedNipsMainQuest.IgnoreMaleBeast)
	oidIgnoreFemaleBeast = AddToggleOption("Ignore female beasts", TTT_ArousedNipsMainQuest.IgnoreFemaleBeast)

	AddHeaderOption("Debug")
	; Not gated: its traces and the debug spell are exactly what you want when the
	; requirements check is failing or the mod has been switched off.
	oidDebugMode = AddToggleOption("Debug mode", TTT_ArousedNipsMainQuest.DebugMode)

	AddHeaderOption("Import / Export")
	; Deliberately never disabled: they only move JSON <-> quest properties, and
	; staying usable when the requirements check fails is part of the recovery
	; story (same reasoning as the Reset button below).
	AddTextOptionST("State_Import", "Import settings", "Import", 0)
	AddTextOptionST("State_Export", "Export settings", "Export", 0)

	AddHeaderOption("Recovery")
	; Reset stays enabled even when NiOverride is missing -- the whole point
	; of this button is to recover from a state where things aren't right.
	AddTextOptionST("State_Reset", "Reset all state", "Reset", 0)
EndFunction

Function DrawMorphsPage()
	; Sync the render/handler count to the live morph table (handles the upgrade
	; heal, Import, and Reset all having changed it) before drawing sliders.
	TTT_AN_Morphs = TTT_ArousedNipsMainQuest.MorphCount()
	SetCursorFillMode(TOP_TO_BOTTOM)

	;Left side
	SetCursorPosition(0)
	AddHeaderOption("Morphs (" + TTT_AN_Morphs + ")")
	AddTextOption("Note: NippleSize is an inverted slider;", "", OPTION_FLAG_DISABLED)
	AddTextOption("smaller number means bigger result.", "", OPTION_FLAG_DISABLED)

	; Split the table across both columns. SkyUI renders ~26 rows per column with
	; no scrolling, so a single column clips past ~22 sliders (which is exactly
	; what the pre-2.1.4 one-page layout did to the 23-morph set).
	int split = (TTT_AN_Morphs + 1) / 2
	int i = 0
	while i < split
		oidMaxValue[i] = AddSliderOption(TTT_ArousedNipsMainQuest.MorphNames[i], TTT_ArousedNipsMainQuest.MaxValue[i], "{2}", hasReqFlag)
		i += 1
	endWhile

	;Right side -- pad with blanks so the slider rows line up with the left column.
	SetCursorPosition(1)
	AddHeaderOption("")
	AddEmptyOption()
	AddEmptyOption()
	while i < TTT_AN_Morphs
		oidMaxValue[i] = AddSliderOption(TTT_ArousedNipsMainQuest.MorphNames[i], TTT_ArousedNipsMainQuest.MaxValue[i], "{2}", hasReqFlag)
		i += 1
	endWhile
EndFunction

state State_CheckPlayer
	event OnHighlightST()
		SetInfoText("Click to read the player's arousal fresh from SexLab Aroused and re-apply the morphs immediately. Quick way to verify the mod is working without waiting for the poll or SLA's scan tick. Shows the arousal that was actually written; \"skipped by filters\" means an Actor filter excluded your character (e.g. a male player with 'Ignore males' on), so no morphs were applied.")
	endevent
	event OnSelectST()
		SetTextOptionValueST("...")
		int arousal = TTT_ArousedNipsMainQuest.TTT_ArousedNipsPlayerAlias.PokePlayerArousal()
		If arousal == -1
			SetTextOptionValueST("SLA unavailable")
		ElseIf arousal == -3
			; Master switch is off -- the mod writes nothing by design.
			SetTextOptionValueST("mod disabled")
		ElseIf arousal == -2
			; The actor filters (Ignore males / dead / beasts) excluded the player, so
			; UpdateActor wrote nothing -- reporting a number here would be a false pass.
			SetTextOptionValueST("skipped by filters")
		Else
			SetTextOptionValueST(arousal + " (applied)")
		EndIf
	endevent
endstate

state State_Import
	event OnHighlightST()
		SetInfoText("Load toggles, sliders and the morph table from SKSE\\Plugins\\StorageUtilData\\ArousedNips\\ (config.json + morph.json). Overwrites your current MCM values.")
	endevent
	event OnSelectST()
		ImportUserSettings()
		SetTextOptionValueST("Loading...")
		ForcePageReset()
	endevent
endstate

state State_Export
	event OnHighlightST()
		SetInfoText("Save the current toggles, sliders and morph table to SKSE\\Plugins\\StorageUtilData\\ArousedNips\\ (config.json + morph.json). Use it to back up tuning or copy it between saves.")
	endevent
	event OnSelectST()
		ExportUserSettings()
		SetTextOptionValueST("Loading...")
		ForcePageReset()
	endevent
endstate

state State_Reset
	event OnHighlightST()
		SetInfoText("Wipe everything back to install defaults: the full nipple + genital/labia morph set at the Natural preset values, all toggles to their on-install state, scan radius 1000, poll 5s. Re-runs the SLA / NiOverride requirements check. Use this to recover from broken save state (sliders all 0.00, SLA requirement stuck on \"MISSING\", upgrade from a different fork). Your tuning will be lost -- afterwards pick an Intensity preset or tune the sliders.")
	endevent
	event OnSelectST()
		TTT_ArousedNipsMainQuest.ResetAllState()
		; Sync the MCM-side morph count to the rebuilt table (persisted separately
		; from the quest's MorphNames array, which the quest reset doesn't see).
		TTT_AN_Morphs = TTT_ArousedNipsMainQuest.MorphCount()
		SetTextOptionValueST("Done")
		ForcePageReset()
	endevent
endstate

state State_IntensityPreset
	event OnMenuOpenST()
		String[] names = GetIntensityPresetNames()
		SetMenuDialogOptions(names)
		; Highlight the currently-selected preset in the dropdown (if any).
		int si = 0
		int i = 0
		String current = TTT_ArousedNipsMainQuest.IntensityPreset
		While i < names.Length
			If names[i] == current
				si = i
			EndIf
			i += 1
		EndWhile
		SetMenuDialogStartIndex(si)
	endevent
	event OnMenuAcceptST(int index)
		String[] names = GetIntensityPresetNames()
		If index < 0 || index >= names.Length
			return
		EndIf
		SetMenuOptionValueST("Loading...")
		String preset = names[index]
		ApplyIntensityPreset(preset)
		TTT_ArousedNipsMainQuest.IntensityPreset = preset
		SetMenuOptionValueST(preset)
		; Redraw so the Morphs page picks up the new MaxValue on its next draw.
		ForcePageReset()
	endevent
	event OnHighlightST()
		SetInfoText("Overwrites the per-morph MaxValue sliders with a named preset. Minimal = barely visible at peak arousal. Natural = realistic when fully aroused; the install default. Noticeable = clearly visible. Exaggerated = strongly emphasised. Your tuning will be replaced; the Reset all state button also returns the sliders to the Natural values.")
	endevent
endstate

event OnOptionSelect(int option)
	if option == oidModEnabled
		; SetModEnabled owns the whole transition (clear morphs / re-apply, stop or
		; re-arm the poll) and writes the property itself, so read it back rather
		; than assuming. ForcePageReset redraws so every other option greys out
		; (or comes back) to match.
		TTT_ArousedNipsMainQuest.TTT_ArousedNipsPlayerAlias.SetModEnabled(!TTT_ArousedNipsMainQuest.ModEnabled)
		SetToggleOptionValue(option, TTT_ArousedNipsMainQuest.ModEnabled)
		ForcePageReset()
		return
	elseif option == oidDebugMode
		TTT_ArousedNipsMainQuest.DebugMode = !TTT_ArousedNipsMainQuest.DebugMode
		SetToggleOptionValue(option,TTT_ArousedNipsMainQuest.DebugMode)
		toggleDebugSpell = true
		return
	elseif option == oidIgnoreMales
		TTT_ArousedNipsMainQuest.IgnoreMales = !TTT_ArousedNipsMainQuest.IgnoreMales
		SetToggleOptionValue(option,TTT_ArousedNipsMainQuest.IgnoreMales)
		return
	elseif option == oidIgnoreDead
		TTT_ArousedNipsMainQuest.IgnoreDead = !TTT_ArousedNipsMainQuest.IgnoreDead
		SetToggleOptionValue(option,TTT_ArousedNipsMainQuest.IgnoreDead)
		return
	elseif option == oidIgnoreMaleBeast
		TTT_ArousedNipsMainQuest.IgnoreMaleBeast = !TTT_ArousedNipsMainQuest.IgnoreMaleBeast
		SetToggleOptionValue(option,TTT_ArousedNipsMainQuest.IgnoreMaleBeast)
		return
	elseif option == oidIgnoreFemaleBeast
		TTT_ArousedNipsMainQuest.IgnoreFemaleBeast = !TTT_ArousedNipsMainQuest.IgnoreFemaleBeast
		SetToggleOptionValue(option,TTT_ArousedNipsMainQuest.IgnoreFemaleBeast)
		return
	elseif option == oidSuppressUnderArmor
		TTT_ArousedNipsMainQuest.SuppressUnderArmor = !TTT_ArousedNipsMainQuest.SuppressUnderArmor
		SetToggleOptionValue(option,TTT_ArousedNipsMainQuest.SuppressUnderArmor)
		; Redraw so the "Nipple size under armor" slider enables/disables to match.
		ForcePageReset()
		return
	endif
endEvent


event OnOptionDefault(int option)
	if option == oidModEnabled
		TTT_ArousedNipsMainQuest.TTT_ArousedNipsPlayerAlias.SetModEnabled(true)
		SetToggleOptionValue(option,true)
		ForcePageReset()
		return
	Elseif option == oidDebugMode
		TTT_ArousedNipsMainQuest.DebugMode = false
		SetToggleOptionValue(option,false)
		toggleDebugSpell = true
		return
	Elseif option == oidIgnoreMales
		TTT_ArousedNipsMainQuest.IgnoreMales = true
		SetToggleOptionValue(option,true)
		return
	Elseif option == oidIgnoreDead
		TTT_ArousedNipsMainQuest.IgnoreDead = true
		SetToggleOptionValue(option,true)
		return
	Elseif option == oidIgnoreMaleBeast
		TTT_ArousedNipsMainQuest.IgnoreMaleBeast = true
		SetToggleOptionValue(option,true)
		return
	Elseif option == oidIgnoreFemaleBeast
		TTT_ArousedNipsMainQuest.IgnoreFemaleBeast = true
		SetToggleOptionValue(option,true)
		return
	Elseif option == oidPollInterval
		TTT_ArousedNipsMainQuest.PollInterval = TTT_ArousedNipsMainQuest.DefaultPollInterval
		SetSliderOptionValue(option, TTT_ArousedNipsMainQuest.PollInterval, "{1}")
		TTT_ArousedNipsMainQuest.TTT_ArousedNipsPlayerAlias.RestartPolling()
		return
	Elseif option == oidScanCellRadius
		TTT_ArousedNipsMainQuest.ScanCellRadius = TTT_ArousedNipsMainQuest.DefaultScanCellRadius
		SetSliderOptionValue(option, TTT_ArousedNipsMainQuest.ScanCellRadius, "{0}")
		return
	Elseif option == oidSuppressUnderArmor
		TTT_ArousedNipsMainQuest.SuppressUnderArmor = true
		SetToggleOptionValue(option,true)
		ForcePageReset()
		return
	Elseif option == oidUnderArmorScale
		TTT_ArousedNipsMainQuest.UnderArmorScale = TTT_ArousedNipsMainQuest.DefaultUnderArmorScale
		SetSliderOptionValue(option, TTT_ArousedNipsMainQuest.UnderArmorScale, "{2}")
		return
	Else
		int i = 0
		while i < TTT_AN_Morphs
			If option == oidMaxValue[i]
				TTT_ArousedNipsMainQuest.MaxValue[i] = TTT_ArousedNipsMainQuest.MaxDefault[i]
				SetSliderOptionValue(option, TTT_ArousedNipsMainQuest.MaxValue[i], "{2}")
				return
			Endif
			i += 1
		endWhile
	endIf
endEvent

Event OnOptionSliderOpen(Int option)
	If option == oidPollInterval
		SetSliderDialogRange(0.0, 60.0)
		SetSliderDialogInterval(0.5)
		SetSliderDialogStartValue(TTT_ArousedNipsMainQuest.PollInterval)
		SetSliderDialogDefaultValue(TTT_ArousedNipsMainQuest.DefaultPollInterval)
		return
	ElseIf option == oidScanCellRadius
		SetSliderDialogRange(100.0, 10000.0)
		SetSliderDialogInterval(100.0)
		SetSliderDialogStartValue(TTT_ArousedNipsMainQuest.ScanCellRadius)
		SetSliderDialogDefaultValue(TTT_ArousedNipsMainQuest.DefaultScanCellRadius)
		return
	ElseIf option == oidUnderArmorScale
		; Allow negatives: NippleSize is an inverted morph, so a negative scale
		; pushes the nipples smaller than baseline (an active tuck under armor),
		; not just toward neutral.
		SetSliderDialogRange(-1.0, 1.0)
		SetSliderDialogInterval(0.05)
		SetSliderDialogStartValue(TTT_ArousedNipsMainQuest.UnderArmorScale)
		SetSliderDialogDefaultValue(TTT_ArousedNipsMainQuest.DefaultUnderArmorScale)
		return
	EndIf

	SetSliderDialogRange(-range, range)
	SetSliderDialogInterval(0.01)

	int i = 0
	while i < TTT_AN_Morphs
		If option == oidMaxValue[i]
			SetSliderDialogStartValue(TTT_ArousedNipsMainQuest.MaxValue[i])
			SetSliderDialogDefaultValue(TTT_ArousedNipsMainQuest.MaxDefault[i])
			return
		Endif
		i += 1
	endWhile


EndEvent

Event OnOptionSliderAccept(Int option, Float value)
	If option == oidPollInterval
		TTT_ArousedNipsMainQuest.PollInterval = value
		SetSliderOptionValue(option, TTT_ArousedNipsMainQuest.PollInterval, "{1}")
		TTT_ArousedNipsMainQuest.TTT_ArousedNipsPlayerAlias.RestartPolling()
		return
	ElseIf option == oidScanCellRadius
		TTT_ArousedNipsMainQuest.ScanCellRadius = value
		SetSliderOptionValue(option, TTT_ArousedNipsMainQuest.ScanCellRadius, "{0}")
		return
	ElseIf option == oidUnderArmorScale
		TTT_ArousedNipsMainQuest.UnderArmorScale = value
		SetSliderOptionValue(option, TTT_ArousedNipsMainQuest.UnderArmorScale, "{2}")
		return
	EndIf

	int i = 0
	while i < TTT_AN_Morphs
		If option == oidMaxValue[i]
			TTT_ArousedNipsMainQuest.MaxValue[i] = value
			SetSliderOptionValue(option, TTT_ArousedNipsMainQuest.MaxValue[i], "{2}")
			return
		Endif
		i += 1
	endWhile

EndEvent

Event OnOptionHighlight(Int option)
	If option == oidModEnabled
		SetInfoText("Master switch. Turn it off to stop the mod completely: the arousal morphs are cleared from you and from nearby NPCs (back to your BodySlide baseline), the player poll stops, and the SexLab / SexLab Aroused events are ignored -- no script work at all. Your slider tuning is kept, so turning it back on restores everything. NPCs further away than the scan radius keep their last morphs until they are near you again with the mod on.")
	ElseIf option == oidDebugMode
		SetInfoText("Will print debug info to screen and log.")
	ElseIf option == oidIgnoreMales
		SetInfoText("If on, male NPC actors are skipped entirely (no morph updates). On by default.")
	ElseIf option == oidIgnoreDead
		SetInfoText("If on, dead actors are skipped (no morphs applied to corpses). Filters at both the cell scan and the player poll. On by default.")
	ElseIf option == oidIgnoreMaleBeast
		SetInfoText("If on, male creature actors (animals/monsters, not the playable beast races) are skipped. On by default.")
	ElseIf option == oidIgnoreFemaleBeast
		SetInfoText("If on, female creature actors (animals/monsters, not the playable beast races) are skipped. On by default.")
	ElseIf option == oidPollInterval
		SetInfoText("Seconds between player-only arousal refreshes. SLA NG only broadcasts every 120s by default, so polling keeps morphs responsive mid-scene. Set to 0 to disable polling (NPC morphs still update on SLA's scan tick).")
	ElseIf option == oidScanCellRadius
		SetInfoText("Radius (game units) the SLA heartbeat scans for aroused NPCs. Default 1000 ~= one room. Larger values catch more actors but cost more per heartbeat tick.")
	ElseIf option == oidSuppressUnderArmor
		SetInfoText("If on, arousal morphs are scaled down while the chest is covered, so nipples don't clip through tops. If Advanced Nudity Detection is installed, its Topless/Nude state decides 'covered' (bikinis/skimpy tops handled correctly); otherwise any worn cuirass/body clothing counts. On by default.")
	ElseIf option == oidUnderArmorScale
		SetInfoText("How much of the arousal morph remains while the chest is covered. 0.00 = nipples flat under armor (no clipping); 1.00 = no reduction. Negative values invert the morph -- because NippleSize is inverted, a negative scale pushes the nipples smaller than baseline (an active tuck for tight tops). Only applies when 'Suppress morphs under armor' is on.")
	Else
		int i = 0
		while i < TTT_AN_Morphs
			If option == oidMaxValue[i]
				SetInfoText("Value of Morph " + TTT_ArousedNipsMainQuest.MorphNames[i] + " at arousal 100")
				return
			Endif
			i += 1
		endWhile

		;Default:
		SetInfoText("ArousedNips "+version+" by TTT.")
	EndIf
EndEvent

Bool Function ImportUserSettings()
	; General settings
	; data/SKSE/Plugins/StorageUtilData/ArousedNips/config.json
	bool oldDebugMode = TTT_ArousedNipsMainQuest.DebugMode
	bool oldModEnabled = TTT_ArousedNipsMainQuest.ModEnabled
	Load(TTT_AN_Config_file)
	; Master switch. Missing-default "1" so config.json files written before 2.1.5
	; import as enabled rather than silently switching the mod off.
	TTT_ArousedNipsMainQuest.ModEnabled        = (GetStringValue(TTT_AN_Config_file, "modenabled",        "1") as int) as bool
	TTT_ArousedNipsMainQuest.DebugMode         = (GetStringValue(TTT_AN_Config_file, "debugmode",         "0") as int) as bool
	TTT_ArousedNipsMainQuest.IgnoreMales       = (GetStringValue(TTT_AN_Config_file, "ignoremales",       "1") as int) as bool
	; 2.1.0 cherry-picked toggles & slider -- missing-defaults match the quest's
	; declared property defaults so older config.json files (pre-2.1.0) hydrate
	; cleanly into the new conservative defaults instead of zero/false.
	TTT_ArousedNipsMainQuest.IgnoreDead        = (GetStringValue(TTT_AN_Config_file, "ignoredead",        "1") as int) as bool
	TTT_ArousedNipsMainQuest.IgnoreMaleBeast   = (GetStringValue(TTT_AN_Config_file, "ignoremalebeast",   "1") as int) as bool
	TTT_ArousedNipsMainQuest.IgnoreFemaleBeast = (GetStringValue(TTT_AN_Config_file, "ignorefemalebeast", "1") as int) as bool
	TTT_ArousedNipsMainQuest.ScanCellRadius    = GetStringValue(TTT_AN_Config_file, "scancellradius", "1000") as float
	TTT_ArousedNipsMainQuest.PollInterval      = GetStringValue(TTT_AN_Config_file, "pollinterval",   "5")    as float
	; "Natural" (not "") as the missing-default: config.json files exported by
	; 2.1.2 / 2.1.3 never carried this key, and the built-in slider defaults those
	; versions shipped are the Natural tier -- so blanking the label to "Choose..."
	; on such an import would misreport a preset that IS effectively selected.
	TTT_ArousedNipsMainQuest.IntensityPreset   = GetStringValue(TTT_AN_Config_file, "intensitypreset", "Natural")
	; Under-armor suppression (added later) -- defaults match the quest's declared
	; property defaults so pre-existing config.json files hydrate cleanly.
	TTT_ArousedNipsMainQuest.SuppressUnderArmor = (GetStringValue(TTT_AN_Config_file, "suppressunderarmor", "1") as int) as bool
	TTT_ArousedNipsMainQuest.UnderArmorScale    = GetStringValue(TTT_AN_Config_file, "underarmorscale", "0") as float
	UnLoad(TTT_AN_Config_file, false, false)

	; An imported DebugMode change must grant/remove the debug spell on menu
	; close, same as toggling it by hand.
	If TTT_ArousedNipsMainQuest.DebugMode != oldDebugMode
		toggleDebugSpell = true
	EndIf
	; Sliders
	; data/SKSE/Plugins/StorageUtilData/ArousedNips/morph.json
	Load(TTT_AN_Morph_file)
	int it = StringListCount(TTT_AN_Morph_file, "morphs")
	if it > 0
		; Only overwrite the morph table if the file actually contains entries;
		; otherwise the defaults set by TTT_ArousedNipsQuest.OnInit() are preserved on first install.
		; Realloc BOTH arrays together so MaxValue can't retain stale entries past the new count.
		TTT_ArousedNipsMainQuest.MorphNames = new String[128]
		TTT_ArousedNipsMainQuest.MaxValue   = new Float[128]
		int i = 0
		int in = 0
		while i < it && i < 128
			string MorphName = StringListGet(TTT_AN_Morph_file, "morphs", i)
			if MorphName != ""
				TTT_ArousedNipsMainQuest.MorphNames[in] = MorphName
				TTT_ArousedNipsMainQuest.MaxValue[in] = GetStringValue(TTT_AN_Morph_file, MorphName, "0") as float
				in += 1
			endif
			i += 1
		EndWhile
		TTT_AN_Morphs = in
		; Rebuild MaxDefault against the imported names NOW, not on the next game
		; load -- otherwise the R-key slider default serves values from the old table.
		TTT_ArousedNipsMainQuest.ResetDefaults()
	endif
	UnLoad(TTT_AN_Morph_file, false, false)

	; Deliberately last, after the morph table above has landed: an imported flip of
	; the master switch has to run the full transition (clear morphs / re-apply +
	; poll), and re-applying before the sliders were read would paint the body with
	; the pre-import values -- and leave them there if the imported poll interval is
	; 0. SetModEnabled re-writes the property to the value it already holds, which is
	; harmless.
	If TTT_ArousedNipsMainQuest.ModEnabled != oldModEnabled
		TTT_ArousedNipsMainQuest.TTT_ArousedNipsPlayerAlias.SetModEnabled(TTT_ArousedNipsMainQuest.ModEnabled)
	Else
		; Re-arm the poll at the imported interval (also handles 0 <-> non-zero).
		TTT_ArousedNipsMainQuest.TTT_ArousedNipsPlayerAlias.RestartPolling()
	EndIf
	return TRUE
EndFunction

String[] Function GetIntensityPresetNames()
	{Lazy-allocate the hardcoded preset list. Order is intentional (subtle ->
	 strong) and matches the four JSON files shipped under SKSE\Plugins\
	 StorageUtilData\ArousedNips\IntensityPresets\. Power users can drop new
	 JSON files in that folder but won't see them in the combobox -- the list
	 is fixed.}
	If !_intensityPresetNames
		_intensityPresetNames = new String[4]
		_intensityPresetNames[0] = "Minimal"
		_intensityPresetNames[1] = "Natural"
		_intensityPresetNames[2] = "Noticeable"
		_intensityPresetNames[3] = "Exaggerated"
	EndIf
	Return _intensityPresetNames
EndFunction

String Function NormalizeMorphKey(String morphKey)
	{Normalize the 4 CapitalCase built-in morph names (NippleSize / NippleLength
	 / NipplePerkiness / AreolaSize -- set by Quest.OnInit / ResetAllState) to
	 their lowercase forms so the intensity preset JSONs can stay all-lowercase.
	 The 23-morph Anon 2.0.4 preset already uses lowercase, so its keys pass
	 through unchanged.}
	If morphKey == "NippleSize"
		Return "nipplesize"
	ElseIf morphKey == "NippleLength"
		Return "nipplelength"
	ElseIf morphKey == "NipplePerkiness"
		Return "nippleperkiness"
	ElseIf morphKey == "AreolaSize"
		Return "areolasize"
	EndIf
	Return morphKey
EndFunction

Function ApplyIntensityPreset(String presetName)
	{Load <presetName>.json from IntensityPresets/ and overwrite MaxValue[i] for
	 every morph in MorphNames[] that has a matching key in the preset. Morphs
	 absent from the preset keep their current MaxValue, so user-imported morphs
	 the preset doesn't cover aren't zeroed out.}
	String path = "ArousedNips/IntensityPresets/" + presetName
	Load(path)
	int i = 0
	String[] morphNames = TTT_ArousedNipsMainQuest.MorphNames
	while i < 128 && morphNames[i] != ""
		String morphKey = NormalizeMorphKey(morphNames[i])
		String value = GetStringValue(path, morphKey, "")
		If value != ""
			TTT_ArousedNipsMainQuest.MaxValue[i] = value as float
		EndIf
		i += 1
	EndWhile
	UnLoad(path, false, false)
EndFunction

Bool Function ExportUserSettings()
	Load(TTT_AN_Config_file)
	Load(TTT_AN_Morph_file)
	; General settings
	SetStringValue(TTT_AN_Config_file, "modenabled",        (TTT_ArousedNipsMainQuest.ModEnabled        as int) as string)
	SetStringValue(TTT_AN_Config_file, "debugmode",         (TTT_ArousedNipsMainQuest.DebugMode         as int) as string)
	SetStringValue(TTT_AN_Config_file, "ignoremales",       (TTT_ArousedNipsMainQuest.IgnoreMales       as int) as string)
	SetStringValue(TTT_AN_Config_file, "ignoredead",        (TTT_ArousedNipsMainQuest.IgnoreDead        as int) as string)
	SetStringValue(TTT_AN_Config_file, "ignoremalebeast",   (TTT_ArousedNipsMainQuest.IgnoreMaleBeast   as int) as string)
	SetStringValue(TTT_AN_Config_file, "ignorefemalebeast", (TTT_ArousedNipsMainQuest.IgnoreFemaleBeast as int) as string)
	SetStringValue(TTT_AN_Config_file, "scancellradius",     TTT_ArousedNipsMainQuest.ScanCellRadius              as string)
	SetStringValue(TTT_AN_Config_file, "pollinterval",       TTT_ArousedNipsMainQuest.PollInterval                as string)
	SetStringValue(TTT_AN_Config_file, "intensitypreset",    TTT_ArousedNipsMainQuest.IntensityPreset)
	SetStringValue(TTT_AN_Config_file, "suppressunderarmor", (TTT_ArousedNipsMainQuest.SuppressUnderArmor as int) as string)
	SetStringValue(TTT_AN_Config_file, "underarmorscale",     TTT_ArousedNipsMainQuest.UnderArmorScale            as string)
	; Clear any previously-exported list so we don't accumulate duplicates across exports.
	StringListClear(TTT_AN_Morph_file, "morphs")
	; Sliders
	int i = 0
	while i < TTT_AN_Morphs
		if TTT_ArousedNipsMainQuest.MorphNames[i] != ""
			StringListAdd(TTT_AN_Morph_file, "morphs", (TTT_ArousedNipsMainQuest.MorphNames[i]), false)
			SetStringValue(TTT_AN_Morph_file, TTT_ArousedNipsMainQuest.MorphNames[i], (TTT_ArousedNipsMainQuest.MaxValue[i] As string))
		endif
		i += 1
	EndWhile
	UnLoad(TTT_AN_Config_file, true, false)
	UnLoad(TTT_AN_Morph_file, true, false)
	return TRUE
EndFunction
