ScriptName TTT_ArousedNipsQuest extends Quest
{Hosts all state.}

TTT_ArousedNipsAlias Property TTT_ArousedNipsPlayerAlias Auto
TTT_ArousedNipsConfigMenu Property CONFIGMENU Auto

bool Property isNioOk = false Auto Hidden
bool Property isSLAroused28 = false Auto Hidden
bool Property isSLAroused29 = false Auto Hidden

bool Property DebugMode = false Auto Hidden
bool Property IgnoreMales = true Auto Hidden

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



Event OnInit()
	{First-time setup. Setting all defaults.}
	;Note: this initialization is performed only once.

	Debug.Notification("ArousedNips: first time initialization")
	Debug.Trace("TTT_ArousedNips: first time initialization")


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

	; DELIBERATELY do NOT call CONFIGMENU.ImportUserSettings() here.
	; This OnInit can fire during MCM registration (OnConfigRegister -> Quest.Start()),
	; and calling back into CONFIGMENU while SkyUI is still mid-registering creates a
	; cross-script lock contention that wedges the Papyrus VM hard enough to
	; freeze the game (reproduced after the 1.1.5 bump). The user can click
	; "Import Settings" from the MCM at any time to restore previously-exported
	; JSON config -- and the quest's MorphNames / MaxValue / DebugMode / IgnoreMales
	; properties persist in the cosave anyway, so on a normal upgrade nothing is lost.

	TTT_ArousedNipsPlayerAlias.OnPlayerLoadGame()

	Debug.Notification("ArousedNips: initialization complete")
	debug.Trace("TTT_ArousedNips: initialization complete")
EndEvent

Function ResetDefaults()
	{Keeps defaults up-to-date}
	
	MaxDefault = new float[128]
	MaxDefault[0] = DefaultSize
	MaxDefault[1] = DefaultLength
	MaxDefault[2] = DefaultCone
	MaxDefault[3] = DefaultArea
	
EndFunction
