ScriptName TTT_ArousedNipsQuest extends Quest
{Hosts all state.}

TTT_ArousedNipsAlias Property TTT_ArousedNipsPlayerAlias Auto
TTT_ArousedNipsConfigMenu Property CONFIGMENU Auto

bool Property isNioOk = false Auto Hidden
bool Property isSLAroused28 = false Auto Hidden
bool Property isSLAroused29 = false Auto Hidden

bool Property DebugMode = false Auto Hidden
bool Property IgnoreMales = true Auto Hidden

; NPC filter toggles added in 2.1.0 (cherry-picked from the Anon 2.0.4 fork).
; All three default to TRUE -- skipping dead actors and creatures is the
; conservative default that matches typical user expectation (morph effect
; on living humanoid NPCs only). Tunable in MCM.
; Note: "Beast" here means engine-level creature actors (Skyrim's GetSex()
; returns 2 for male creatures and 3 for female creatures), NOT the playable
; beast races (Khajiit / Argonian / orc), which are GetSex() 0/1 and stay
; covered by IgnoreMales.
bool Property IgnoreDead         = true Auto Hidden
bool Property IgnoreMaleBeast    = true Auto Hidden
bool Property IgnoreFemaleBeast  = true Auto Hidden

; When true, arousal morphs are scaled down (by UnderArmorScale) on any actor
; whose chest is covered, so fitted nipples don't clip through the top. "Covered"
; = wearing a cuirass / body-clothing (vanilla keyword check), unless Advanced
; Nudity Detection is installed and flags the actor Topless/Nude (override for
; skimpy / bikini tops). See IsTopCovered in TTT_ArousedNipsAlias.
; The player alias refreshes instantly on equip/unequip via OnObjectEquipped /
; OnObjectUnequipped; NPCs collapse on the next heartbeat/poll. Default ON.
bool Property SuppressUnderArmor = true Auto Hidden

; Multiplier (0.0 .. 1.0) applied to every arousal morph while the chest is
; covered (and SuppressUnderArmor is on). 0.0 = nipples fully flat under armor
; (no clipping); 1.0 = no reduction. MCM-tunable. Default 0.0.
float Property UnderArmorScale = 0.0 Auto Hidden
float Property DefaultUnderArmorScale = 0.0 AutoReadOnly Hidden

string[] Property MorphNames Auto Hidden
float[] Property MaxValue Auto Hidden
float[] Property MaxDefault Auto Hidden

float Property DefaultSize = -0.75 AutoReadOnly Hidden
float Property DefaultLength = 1.0 AutoReadOnly Hidden
float Property DefaultCone = 1.5 AutoReadOnly Hidden
float Property DefaultArea = 0.0 AutoReadOnly Hidden

; Player-only morph poll interval (seconds). SLA NG only broadcasts
; sla_UpdateComplete on its scheduled scan (default 120s); polling the player
; in between keeps morphs responsive to mid-scene arousal changes from
; OSL/OStim, denial ramps, etc. Set to 0 in MCM to disable polling and
; fall back to the heartbeat-only behaviour.
float Property PollInterval = 5.0 Auto Hidden
float Property DefaultPollInterval = 5.0 AutoReadOnly Hidden

; NPC cell-scan radius (units) used by OnArousalComputed's
; MiscUtil.ScanCellNPCsByFaction call. Replaces the previously-hardcoded
; 1000 from 1.1.5 and earlier. Default 1000 preserves prior behaviour.
; Range in MCM: 100 (very tight) to 10000 (full exterior cell).
float Property ScanCellRadius = 1000.0 Auto Hidden
float Property DefaultScanCellRadius = 1000.0 AutoReadOnly Hidden

; Last-selected intensity preset (Minimal / Natural / Noticeable / Exaggerated)
; from the MCM combobox. Display-only -- the actual values are loaded from
; SKSE\Plugins\StorageUtilData\ArousedNips\IntensityPresets\<name>.json into
; MaxValue[] at selection time. Empty string means the user hasn't picked one
; yet (or did a Reset, which clears this back to ""), and the combobox shows
; "Choose...".
String Property IntensityPreset = "" Auto Hidden



Event OnInit()
	{First-time setup. Setting all defaults.}
	;Note: this initialization is performed only once.

	Debug.Notification("ArousedNips: first time initialization")
	Debug.Trace("TTT_ArousedNips: first time initialization")

	; OnInit and the MCM "Reset all state" button share the same reset path.
	; DELIBERATELY do NOT call CONFIGMENU.ImportUserSettings() from this chain.
	; OnInit can fire during MCM registration (OnConfigRegister -> Quest.Start()),
	; and calling back into CONFIGMENU while SkyUI is still mid-registering creates
	; cross-script lock contention that wedges the Papyrus VM hard enough to
	; freeze the game (reproduced after the 1.1.5 bump). The user can click
	; "Import Settings" from the MCM at any time afterwards to load a saved
	; preset (e.g. the bundled 23-morph labia/vagina one).
	ResetAllState()

	Debug.Notification("ArousedNips: initialization complete")
	debug.Trace("TTT_ArousedNips: initialization complete")
EndEvent

Function ResetAllState()
	{Wipe persisted state back to install defaults. Called from OnInit on first install
	 AND from the MCM "Reset all state" button to recover from corrupt / upgrade-stale state
	 (None arrays, mismatched morph counts, flags stuck false, etc).

	 This explicitly overwrites toggles to their declared defaults too, since those
	 persist in the cosave and a fresh-install user can have arbitrary saved values
	 from a previous fork. Re-runs the alias requirements check at the end so the
	 SLA flags refresh against the live SLA framework.}
	MaxValue = new float[128]
	MaxValue[0] = DefaultSize
	MaxValue[1] = DefaultLength
	MaxValue[2] = DefaultCone
	MaxValue[3] = DefaultArea

	ResetDefaults()

	MorphNames = new String[128]
	MorphNames[0] = "NippleSize"
	MorphNames[1] = "NippleLength"
	MorphNames[2] = "NipplePerkiness"
	MorphNames[3] = "AreolaSize"

	; Toggles + sliders back to their declared defaults.
	DebugMode         = false
	IgnoreMales       = true
	IgnoreDead        = true
	IgnoreMaleBeast   = true
	IgnoreFemaleBeast = true
	PollInterval      = DefaultPollInterval
	ScanCellRadius    = DefaultScanCellRadius
	IntensityPreset   = ""
	SuppressUnderArmor = true
	UnderArmorScale   = DefaultUnderArmorScale

	; Re-run requirements check so isNioOk / isSLAroused28 / isSLAroused29 reflect
	; the live framework state (and on first install, register the mod events + poll).
	TTT_ArousedNipsPlayerAlias.OnPlayerLoadGame()
EndFunction

Function ResetDefaults()
	{Keeps the MaxDefault array up-to-date. Called from OnPlayerLoadGame on every load
	 and from ResetAllState.}

	MaxDefault = new float[128]
	MaxDefault[0] = DefaultSize
	MaxDefault[1] = DefaultLength
	MaxDefault[2] = DefaultCone
	MaxDefault[3] = DefaultArea

EndFunction
