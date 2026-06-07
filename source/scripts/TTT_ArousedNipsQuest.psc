ScriptName TTT_ArousedNipsQuest extends Quest
{Hosts all state.}

TTT_ArousedNipsAlias Property TTT_ArousedNipsPlayerAlias Auto


bool Property isNioOk = false Auto Hidden
bool Property isSLArousedOk = false Auto Hidden

bool Property DebugMode = false Auto Hidden
bool Property IgnoreMales = true Auto Hidden

string[] Property MorphNames Auto Hidden
float[] Property MaxValue Auto Hidden
float[] Property MaxDefault Auto Hidden

float Property DefaultSize = -0.75 AutoReadOnly Hidden
float Property DefaultLength = 1.0 AutoReadOnly Hidden
float Property DefaultCone = 1.5 AutoReadOnly Hidden
float Property DefaultArea = 0.0 AutoReadOnly Hidden



Event OnInit()
	{First-time setup. Setting all defaults.}
	;Note: this initialization is performed only once.
	
	Debug.Notification("ArousedNips: first time initialization")
	Debug.Trace("TTT_ArousedNips: first time initialization")
	
	
	MaxValue = new float[4]
	MaxValue[0] = DefaultSize
	MaxValue[1] = DefaultLength
	MaxValue[2] = DefaultCone
	MaxValue[3] = DefaultArea
	
	ResetDefaults()
	
	MorphNames = new String[4]
	MorphNames[0] = "NippleSize"
	MorphNames[1] = "NippleLength"
	MorphNames[2] = "NipplePerkiness"
	MorphNames[3] = "NippleAreola" 
	
	
	
	TTT_ArousedNipsPlayerAlias.OnPlayerLoadGame()
	
	
	Debug.Notification("ArousedNips: initialization complete")
	debug.Trace("TTT_ArousedNips: initialization complete")
EndEvent

Function ResetDefaults()
	{Keeps defaults up-to-date}
	
	MaxDefault = new float[4]
	MaxDefault[0] = DefaultSize
	MaxDefault[1] = DefaultLength
	MaxDefault[2] = DefaultCone
	MaxDefault[3] = DefaultArea
	
EndFunction
