ScriptName TTT_ArousedNipsAlias extends ReferenceAlias
{For event handling.}

TTT_ArousedNipsQuest Property TTT_ArousedNipsMainQuest Auto

Int Property NIO_VERSION = 6 AutoReadOnly hidden
Int Property NIO_SCRIPT_VERSION = 6 AutoReadOnly hidden

String Property NIO_KEY = "TTT_ArousedNips.esp" AutoReadOnly hidden

slaMainScr Property sla_Main Auto
slaFrameworkScr Property sla_Framework Auto
SexLabFramework Property SexLabQuestFramework Auto


Event OnPlayerLoadGame()
	{Checking requirements every game load.}
	if TTT_ArousedNipsMainQuest.DebugMode
		debug.Notification("ArousedNips: checking for requirements")
		debug.Trace("TTT_ArousedNips: checking for requirements")
	EndIf
	
	
	;Check Requirements
	if !CheckNiOverride()
		;NiO check fail
		TTT_ArousedNipsMainQuest.isNioOk = false
		debug.Notification("ArousedNips: NiOverride Version check failed, aborting.")
		debug.Trace("TTT_ArousedNips: NiOverride Version check failed, aborting.")
		return
	Else
		TTT_ArousedNipsMainQuest.isNioOk = true
	EndIf
	
	if (sla_Main.slaConfig.GetVersion() <26 || sla_Main.slaConfig.GetVersion() > 20110000)
		;Aroused version check fail
		TTT_ArousedNipsMainQuest.isSLArousedOk = false
		debug.Notification("ArousedNips: [Warning]: Unsupported Version of SLAroused Redux, aborting")
		debug.Trace("TTT_ArousedNips: [Warning]: Unsupported Version of SLAroused Redux, aborting")
		return
	Else
		TTT_ArousedNipsMainQuest.isSLArousedOk = true
	EndIf
	
	;success
	TTT_ArousedNipsMainQuest.ResetDefaults()
	
	RegisterForModevent("sla_UpdateComplete", "OnArousalComputed")
	
	RegisterForModEvent("StageStart", "OnStageStart")
	
	IF TTT_ArousedNipsMainQuest.DebugMode
		debug.Notification("ArousedNips: requirements check successful")
		debug.Trace("TTT_ArousedNips: requirements check successful")
	EndIf
EndEvent


Bool Function CheckNiOverride()
	Return SKSE.GetPluginVersion("NiOverride") >= NIO_VERSION && NiOverride.GetScriptVersion() >= NIO_SCRIPT_VERSION
EndFunction





Event OnArousalComputed(string eventName, string argString, float argNum, form sender)
	{Event thrown by Aroused}
	bool doDebug = TTT_ArousedNipsMainQuest.DebugMode
	If doDebug
		debug.Notification("ArousedNips: Arousal event")
		debug.Trace("TTT_ArousedNips: Arousal event")
	EndIf
	
	
	;player needs an extrawurst
	UpdateActor(Game.GetPlayer(), doDebug)
	
	if(argNum <= 0)
		If doDebug
			debug.Notification("ArousedNips: No aroused NPCs nearby, updating player only")
			debug.Trace("TTT_ArousedNips: No aroused NPCs nearby, updating player only")
		EndIf
		return
	endif
	
	;;modifying that nice Redux example code:
	
	int myLockNum = Utility.randomInt(10, 32000)
	Actor [] myActors = sla_Main.getLoadedActors(myLockNum) 
	;This could be null if called at the wrong time
	
	int t = 0
	while((!myActors) && t < 5)
		If doDebug
			debug.Notification("Warning: ArousedNips could not access Aroused's actor array. Retrying.")
		EndIf
		debug.Trace("Warning: TTT_ArousedNips could not access Aroused's actor array. Retrying. t = "+t)
		Utility.Wait(1)
		myActors = sla_Main.getLoadedActors(myLockNum)
		t += 1
	endWhile
	
	Actor [] theActors
	If(myActors)
		theActors = new Actor[20]
		int i = 0;
		;Copy the actors to a private array            
		while(i < 20)
			theActors[i] = myActors[i]
			i+= 1
		endwhile
		;It is imparative to call unlock
		sla_Main.UnlockScan(myLockNum)
		
		;Now do whatever I want with those actors  
	Else
		If doDebug
			debug.Notification("Warning: ArousedNips gave up accessing Aroused's actor array.")
		EndIf
		debug.Trace("Warning: TTT_ArousedNips gave up accessing Aroused's actor array.")
		
		return
	EndIf
	
	
	
	int i = 0;           
	while(i < 20)
		if(theActors[i]) ;make sure there is an actor
			UpdateActor(theActors[i], doDebug)
		EndIf
		i+= 1
	endwhile
	
	If doDebug
		debug.Notification("ArousedNips: Arousal event end")
		debug.Trace("TTT_ArousedNips: Arousal event end")
	EndIf
endEvent

Function UpdateActor(Actor who, bool doDebug=false, int modifier=0)
	{Set morphs of "who" according to their arousal, offset by "modifier".}
	
	If TTT_ArousedNipsMainQuest.IgnoreMales && (Who.GetLeveledActorBase().GetSex() == 0)
		If doDebug
			debug.Notification("ArousedNips: "+who.GetLeveledActorBase().GetName()+" is male, skipping")
			debug.Trace("TTT_ArousedNips: "+who.GetLeveledActorBase().GetName()+", is male, skipping")
		EndIF
		return
	EndIf
	
	int Arousal = who.GetFactionRank(sla_Framework.slaArousal)
	
	If doDebug
		debug.Notification("ArousedNips: "+who.GetLeveledActorBase().GetName()+" has Arousal "+Arousal+"(+" + modifier +")")
		debug.Trace("TTT_ArousedNips: "+who.GetLeveledActorBase().GetName()+" has Arousal "+Arousal+"(+" + modifier +")")
	EndIF
	
	If Arousal < 0
		return
	EndIf
	
	
	Arousal = Arousal + modifier
	
	If Arousal > 100
		Arousal = 100
	EndIf
	
	int j = 0
	while j<4
		float Value = TTT_ArousedNipsMainQuest.MaxValue[j]*Arousal/100
		NiOverride.SetBodyMorph(who, TTT_ArousedNipsMainQuest.MorphNames[j], NIO_KEY, Value)
		If doDebug
			debug.Notification("ArousedNips: setting "+TTT_ArousedNipsMainQuest.MorphNames[j]+" to "+Value)
			debug.Trace("TTT_ArousedNips: setting "+TTT_ArousedNipsMainQuest.MorphNames[j]+" to "+Value)
		EndIf
		j+=1
	EndWhile
	NiOverride.UpdateModelWeight(who)
	
EndFunction


Event OnStageStart(string eventName, string argString, float argNum, form sender)
	{Experimental.}
	
	Actor[] actorList = SexLabQuestFramework.HookActors(argString)
	
	If (actorList.length < 1)
		return
	EndIf
	
	Utility.Wait(1)
	;giving Aroused time to do its thing.
	
	int i = 0
	While i < actorList.length
		UpdateActor(actorList[i], TTT_ArousedNipsMainQuest.DebugMode, 50)
		i += 1
	EndWhile
	
EndEvent

