ScriptName TTT_ArousedNipsConfigMenu extends SKI_ConfigBase
{the MCM, what else}

TTT_ArousedNipsQuest Property TTT_ArousedNipsMainQuest Auto
Spell Property TTT_ArousedNipsDebugSpell Auto

float property range = 3.0 AutoReadOnly hidden

int hasReqFlag

int oidDebugMode
int oidIgnoreMales
int oidImportS
int oidExportS
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
	return 20103
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
	Pages = new string[1]
	pages[0] = "General"
	oidMaxValue = new int[128]
	TTT_ArousedNipsMainQuest.start()
endEvent


event OnConfigOpen()
	Pages = new string[1]
	pages[0] = "General"
	oidMaxValue = new int[128]
	bool isOk = TTT_ArousedNipsMainQuest.isNioOk && TTT_ArousedNipsMainQuest.isSLAroused28 || TTT_ArousedNipsMainQuest.isNioOk && TTT_ArousedNipsMainQuest.isSLAroused29
	hasReqFlag = OPTION_FLAG_DISABLED * (!isOk) as int
endEvent

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
	If page == pages[0] || pages[0] == ""
		;Config
		SetCursorFillMode(TOP_TO_BOTTOM)
		
		;Left side
		SetCursorPosition(0)
		
		AddHeaderOption("ArousedNips "+ version)
		AddEmptyOption()
		AddTextOption("Note: NippleSize is an inverted slider;","",hasReqFlag)
		AddTextOption("smaller number means bigger result.","",hasReqFlag)
		AddHeaderOption("Morphs " + TTT_AN_Morphs)
		
		int i = 0
		while i < TTT_AN_Morphs
			if TTT_ArousedNipsMainQuest.MorphNames[i] == ""
				; Stop on first empty slot so we don't render a bogus blank row.
				; Setting i past the loop bound is the Papyrus idiom (no `break`).
				i = TTT_AN_Morphs
			else
				oidMaxValue[i] = AddSliderOption(TTT_ArousedNipsMainQuest.MorphNames[i], TTT_ArousedNipsMainQuest.MaxValue[i], "{2}", hasReqFlag)
				i += 1
			endif
		EndWhile
		AddHeaderOption("")
		;TODO: Anything else?
		
		;Right side
		SetCursorPosition(1)
		AddHeaderOption("Requirements Checks")
		AddToggleOption("NiOverride (Required)", TTT_ArousedNipsMainQuest.isNiOok)
		if TTT_ArousedNipsMainQuest.isSLAroused29
			AddToggleOption("SLAroused (Required) NG / 3.x", TTT_ArousedNipsMainQuest.isSLAroused29)
		elseif TTT_ArousedNipsMainQuest.isSLAroused28
			AddToggleOption("SLAroused (Required) Legacy / OSL stub", TTT_ArousedNipsMainQuest.isSLAroused28)
		else
			AddTextOption("SLAroused (Required)","Try Load Save",OPTION_FLAG_DISABLED)
		endif
		

		int a_flags = 1
		if TTT_ArousedNipsMainQuest.isNiOok
			a_flags = 0
		endif
		
		AddHeaderOption("Performance")
		oidPollInterval    = AddSliderOption("Player poll interval (s)", TTT_ArousedNipsMainQuest.PollInterval, "{1}", hasReqFlag)
		oidScanCellRadius  = AddSliderOption("NPC scan radius (units)",  TTT_ArousedNipsMainQuest.ScanCellRadius, "{0}", hasReqFlag)

		AddHeaderOption("Intensity preset")
		; Display the last-selected preset name, or a placeholder if none selected
		; yet (fresh install, post-Reset). Selecting one overwrites every MaxValue
		; slider with the preset's values for whichever morphs are currently
		; loaded -- sliders for morphs not in the preset (e.g. user-imported
		; morphs the bundled presets don't cover) keep their current values.
		String presetLabel = TTT_ArousedNipsMainQuest.IntensityPreset
		If presetLabel == ""
			presetLabel = "Choose..."
		EndIf
		AddMenuOptionST("State_IntensityPreset", "Preset", presetLabel, hasReqFlag)

		AddHeaderOption("Under armor")
		oidSuppressUnderArmor = AddToggleOption("Suppress morphs under armor", TTT_ArousedNipsMainQuest.SuppressUnderArmor)
		; Slider stays visible but disabled while suppression is off, so its role is clear.
		int uaFlag = hasReqFlag
		if !TTT_ArousedNipsMainQuest.SuppressUnderArmor
			uaFlag = OPTION_FLAG_DISABLED
		endif
		oidUnderArmorScale   = AddSliderOption("Nipple size under armor", TTT_ArousedNipsMainQuest.UnderArmorScale, "{2}", uaFlag)

		AddHeaderOption("Debug")
		oidIgnoreMales       = AddToggleOption("Ignore Males",          TTT_ArousedNipsMainQuest.IgnoreMales)
		oidIgnoreDead        = AddToggleOption("Ignore Dead",           TTT_ArousedNipsMainQuest.IgnoreDead)
		oidIgnoreMaleBeast   = AddToggleOption("Ignore Male Beasts",    TTT_ArousedNipsMainQuest.IgnoreMaleBeast)
		oidIgnoreFemaleBeast = AddToggleOption("Ignore Female Beasts",  TTT_ArousedNipsMainQuest.IgnoreFemaleBeast)
		oidDebugMode         = AddToggleOption("Debug mode",            TTT_ArousedNipsMainQuest.DebugMode)
		AddHeaderOption("IMPORT - EXPORT")
		AddTextOptionST("State_Page_01","Import Settings","Import", a_flags)
		AddTextOptionST("State_Page_02","Export Settings","Export", a_flags)

		AddHeaderOption("Recovery")
		; Reset stays enabled even when NiOverride is missing -- the whole point
		; of this button is to recover from a state where things aren't right.
		AddTextOptionST("State_Reset","Reset all state","Reset", 0)
	Endif
endEvent

state State_Page_01
	event OnHighlightST()
		SetInfoText("Import Settings")
	endevent
	event OnSelectST()
		ImportUserSettings()
		SetTextOptionValueST("Loading...")
		ForcePageReset()
	endevent
endstate

state State_Page_02
	event OnHighlightST()
		SetInfoText("Export Settings")
	endevent
	event OnSelectST()
		ExportUserSettings()
		SetTextOptionValueST("Loading...")
		ForcePageReset()
	endevent
endstate

state State_Reset
	event OnHighlightST()
		SetInfoText("Wipe everything back to install defaults: 4 nipple morphs, all toggles to their on-install state, scan radius 1000, poll 5s. Re-runs the SLA / NiOverride requirements check. Use this to recover from broken save state (sliders all 0.00, SLA requirement stuck on \"Try Load Save\", upgrade from a different fork). Your tuning will be lost -- after reset you can click Import Settings to re-load the bundled preset or a previously-exported config.")
	endevent
	event OnSelectST()
		; Reset the MCM-side morph count too -- it's persisted separately from the
		; quest's MorphNames array and the quest reset doesn't see it.
		TTT_AN_Morphs = 4
		TTT_ArousedNipsMainQuest.ResetAllState()
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
		; Redraw so the morph sliders pick up their new MaxValue.
		ForcePageReset()
	endevent
	event OnHighlightST()
		SetInfoText("Overwrites the per-morph MaxValue sliders with a named preset. Minimal = barely visible at peak arousal. Natural = realistic when fully aroused. Noticeable = current install defaults; clearly visible. Exaggerated = strongly emphasised. Your tuning will be replaced; the Reset all state button clears it back to Noticeable-equivalent built-in defaults.")
	endevent
endstate

event OnOptionSelect(int option)
	if option == oidDebugMode
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
	if option == oidDebugMode
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
		while i < 4
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
	while i < 4
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
	while i < 4
		If option == oidMaxValue[i]
			TTT_ArousedNipsMainQuest.MaxValue[i] = value
			SetSliderOptionValue(option, TTT_ArousedNipsMainQuest.MaxValue[i], "{2}")
			return
		Endif
		i += 1
	endWhile

EndEvent

Event OnOptionHighlight(Int option)
	If option == oidDebugMode
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
		while i < 4
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
	; About page
	; data/SKSE/Plugins/StorageUtilData/ArousedNips/config.json
	Load(TTT_AN_Config_file)
	TTT_ArousedNipsMainQuest.DebugMode         = (GetStringValue(TTT_AN_Config_file, "debugmode",         "0") as int) as bool
	TTT_ArousedNipsMainQuest.IgnoreMales       = (GetStringValue(TTT_AN_Config_file, "ignoremales",       "1") as int) as bool
	; 2.1.0 cherry-picked toggles & slider -- missing-defaults match the quest's
	; declared property defaults so older config.json files (pre-2.1.0) hydrate
	; cleanly into the new conservative defaults instead of zero/false.
	TTT_ArousedNipsMainQuest.IgnoreDead        = (GetStringValue(TTT_AN_Config_file, "ignoredead",        "1") as int) as bool
	TTT_ArousedNipsMainQuest.IgnoreMaleBeast   = (GetStringValue(TTT_AN_Config_file, "ignoremalebeast",   "1") as int) as bool
	TTT_ArousedNipsMainQuest.IgnoreFemaleBeast = (GetStringValue(TTT_AN_Config_file, "ignorefemalebeast", "1") as int) as bool
	TTT_ArousedNipsMainQuest.ScanCellRadius    = GetStringValue(TTT_AN_Config_file, "scancellradius", "1000") as float
	; Under-armor suppression (added later) -- defaults match the quest's declared
	; property defaults so pre-existing config.json files hydrate cleanly.
	TTT_ArousedNipsMainQuest.SuppressUnderArmor = (GetStringValue(TTT_AN_Config_file, "suppressunderarmor", "1") as int) as bool
	TTT_ArousedNipsMainQuest.UnderArmorScale    = GetStringValue(TTT_AN_Config_file, "underarmorscale", "0") as float
	UnLoad(TTT_AN_Config_file, false, false)

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
	endif
	UnLoad(TTT_AN_Morph_file, false, false)
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
	; About page
	SetStringValue(TTT_AN_Config_file, "debugmode",         (TTT_ArousedNipsMainQuest.DebugMode         as int) as string)
	SetStringValue(TTT_AN_Config_file, "ignoremales",       (TTT_ArousedNipsMainQuest.IgnoreMales       as int) as string)
	SetStringValue(TTT_AN_Config_file, "ignoredead",        (TTT_ArousedNipsMainQuest.IgnoreDead        as int) as string)
	SetStringValue(TTT_AN_Config_file, "ignoremalebeast",   (TTT_ArousedNipsMainQuest.IgnoreMaleBeast   as int) as string)
	SetStringValue(TTT_AN_Config_file, "ignorefemalebeast", (TTT_ArousedNipsMainQuest.IgnoreFemaleBeast as int) as string)
	SetStringValue(TTT_AN_Config_file, "scancellradius",     TTT_ArousedNipsMainQuest.ScanCellRadius              as string)
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