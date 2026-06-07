ScriptName TTT_ArousedNipsConfigMenu extends SKI_ConfigBase
{the MCM, what else}

TTT_ArousedNipsQuest Property TTT_ArousedNipsMainQuest Auto
Spell Property TTT_ArousedNipsDebugSpell Auto

float property range = 3.0 AutoReadOnly hidden

int hasReqFlag

int oidDebugMode
int oidIgnoreMales

int[] oidMaxValue

string version

bool toggleDebugSpell = false

int function GetVersion()
	;format = (M)MmmPP
	;12345 => 1.23.45
	return 10102
endFunction

Event OnVersionUpdate(Int ver)
	int Major = ver/10000
	int Minor = (ver%10000)/100
	int Patch = ver%100
	version = Major+"."+Minor+"."+Patch
	debug.Notification("ArousedNips: Updating to "+version)
	debug.Trace("TTT_ArousedNips: Updating to "+version)
	TTT_ArousedNipsMainQuest.stop()
	Utility.Wait(1)
	TTT_ArousedNipsMainQuest.start()
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
	
	oidMaxValue = new int[4]
	
	TTT_ArousedNipsMainQuest.start()
endEvent


event OnConfigOpen()
	Pages = new string[1]
	pages[0] = "General"
	
	oidMaxValue = new int[4]
	
	bool isOk = TTT_ArousedNipsMainQuest.isNioOk && TTT_ArousedNipsMainQuest.isSLArousedOk
	
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
	
	If page == pages[0]
		;Config
		SetCursorFillMode(TOP_TO_BOTTOM)
		
		;Left side
		SetCursorPosition(0)
		
		AddHeaderOption("ArousedNips "+version)
		AddEmptyOption()
		AddTextOption("Note: NippleSize is an inverted slider;","",hasReqFlag)
		AddTextOption("smaller number means bigger result.","",hasReqFlag)
		AddHeaderOption("Morphs at 100")
		
		int i = 0
		while i < 4
			oidMaxValue[i] = AddSliderOption(TTT_ArousedNipsMainQuest.MorphNames[i],TTT_ArousedNipsMainQuest.MaxValue[i],"{2}",hasReqFlag)
			i += 1
		EndWhile
		AddHeaderOption("")
		;TODO: Anything else?
		
		;Right side
		SetCursorPosition(1)
		AddHeaderOption("Version Checks")
		AddToggleOption("NiOverride (Required)", TTT_ArousedNipsMainQuest.isNiOok)
		AddToggleOption("SLAroused Redux (Required)", TTT_ArousedNipsMainQuest.isSLArousedok)
		AddEmptyOption()
		
		AddHeaderOption("")
		oidIgnoreMales = AddToggleOption("Ignore Males", TTT_ArousedNipsMainQuest.IgnoreMales)
		AddEmptyOption()
		oidDebugMode = AddToggleOption("Debug mode", TTT_ArousedNipsMainQuest.DebugMode)
	Endif
endEvent

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
	endIf
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
		
		
		;TODO: ElseIfs
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