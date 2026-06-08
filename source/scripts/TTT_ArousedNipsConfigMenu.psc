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
	; 20101 = 2.01.01. The 2.01.00 baseline was chosen to skip ahead of the
	; Anon 2.0.4 fork (20004) so SkyUI's OnVersionUpdate gate
	; (CurrentVersion < GetVersion) fires when upgrading from a save that
	; previously had 2.0.4 installed -- clears the stale "2.0.4" MCM header
	; string and triggers the fork-to-1.1.5-based transition path.
	; 2.01.01 adds the MCM Recovery > Reset button and the SLA framework
	; Quest.GetQuest fallback (handles ESPs where the sla_Framework Auto
	; property is unwired).
	return 20101
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