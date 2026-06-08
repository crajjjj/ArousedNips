ScriptName TTT_ArousedNipsAlias extends ReferenceAlias
{For event handling.}

TTT_ArousedNipsQuest Property TTT_ArousedNipsMainQuest Auto

; RaceMenu version used by transferNode code below
Int Property SKEE_VERSION = 1 AutoReadOnly
Int Property NIOVERRIDE_SCRIPT_VERSION = 6 AutoReadOnly

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
	
	; Multi-fork detection via slaframeworkscr.GetVersion() (portable -- both OSL
	; Aroused's stub framework and real SLA NG implement it). Date-stamped scheme:
	;   OSL Aroused stub      -> 20140124   (read-only API; GetActorArousal works,
	;                                        slaSet/ModArousalEffect ModEvents do not)
	;   SLAXSE2022            -> 20190720   (legacy)
	;   SexLab Aroused NG     -> >= 20200000 (NG-branded / SLO Aroused NG, packs
	;                                         MMmmppp e.g. 30100010 for 3.1.10)
	; The official "is this real NG?" gate per SLA NG's README is >= 20200000.
	; TTT_ArousedNips only consumes the read path (GetActorArousal) which is
	; portable across forks, so legacy / stub installs still work for morph display.
	if !sla_Framework
		; sla_Framework property unwired — SexLabAroused.esm master likely missing
		; or save data is corrupt. Without it we cannot detect the fork or read
		; arousal, so abort with a clear notification rather than null-crash on
		; the GetVersion() call below.
		TTT_ArousedNipsMainQuest.isSLAroused28 = false
		TTT_ArousedNipsMainQuest.isSLAroused29 = false
		debug.Notification("ArousedNips: sla_Framework property unwired, aborting")
		debug.Trace("TTT_ArousedNips: sla_Framework property unwired, aborting")
		return
	endif
	int slaVersion = sla_Framework.GetVersion()

	if slaVersion >= 20200000
		; Real SLA NG (or compatible >= NG-class fork).
		TTT_ArousedNipsMainQuest.isSLAroused28 = false
		TTT_ArousedNipsMainQuest.isSLAroused29 = true
	elseif slaVersion > 0
		; OSL Aroused stub, SLAXSE2022, eXtended LE, original SSELoose, or any
		; other pre-NG fork. Still routes through GetActorArousal so reads work.
		TTT_ArousedNipsMainQuest.isSLAroused28 = true
		TTT_ArousedNipsMainQuest.isSLAroused29 = false
	else
		TTT_ArousedNipsMainQuest.isSLAroused28 = false
		TTT_ArousedNipsMainQuest.isSLAroused29 = false
		debug.Notification("ArousedNips: SexLab Aroused framework not detected (GetVersion returned " + slaVersion + "), aborting")
		debug.Trace("TTT_ArousedNips: SexLab Aroused framework not detected (GetVersion returned " + slaVersion + "), aborting")
		return
	endif
	
	;success
	TTT_ArousedNipsMainQuest.ResetDefaults()

	RegisterForModevent("sla_UpdateComplete", "OnArousalComputed")

	RegisterForModEvent("StageStart", "OnStageStart")

	; Player-only polling refresh. SLA NG only fires sla_UpdateComplete on its
	; scheduled scan (default 120s); polling here keeps the player's morphs
	; responsive to mid-scene arousal changes (OSL/OStim, denial ramps, etc.)
	; without lowering SLA's global scan frequency.
	Float pollInterval = TTT_ArousedNipsMainQuest.PollInterval
	If pollInterval > 0.0
		RegisterForSingleUpdate(pollInterval)
	EndIf

	IF TTT_ArousedNipsMainQuest.DebugMode
		debug.Notification("ArousedNips: requirements check successful")
		debug.Trace("TTT_ArousedNips: requirements check successful")
	EndIf
EndEvent

Event OnUpdate()
	{Player-only refresh between SLA heartbeats.}
	If !(TTT_ArousedNipsMainQuest.isNioOk && (TTT_ArousedNipsMainQuest.isSLAroused28 || TTT_ArousedNipsMainQuest.isSLAroused29))
		; Requirements were lost (mod uninstalled / disabled mid-save) — stop polling.
		return
	EndIf

	UpdateActor(Game.GetPlayer(), false)

	Float pollInterval = TTT_ArousedNipsMainQuest.PollInterval
	If pollInterval > 0.0
		RegisterForSingleUpdate(pollInterval)
	EndIf
EndEvent

Function RestartPolling()
	{Called from MCM when the user changes PollInterval. Cancels any pending tick
	 and re-arms at the current interval so the change takes effect immediately
	 (and so dialing 0 -> non-zero can restart a stopped poll loop).}
	UnregisterForUpdate()
	Float pollInterval = TTT_ArousedNipsMainQuest.PollInterval
	If pollInterval > 0.0 && TTT_ArousedNipsMainQuest.isNioOk && (TTT_ArousedNipsMainQuest.isSLAroused28 || TTT_ArousedNipsMainQuest.isSLAroused29)
		RegisterForSingleUpdate(pollInterval)
	EndIf
EndFunction

Bool Function CheckNiOverride()
	Return SKSE.GetPluginVersion("skee") >= SKEE_VERSION && NiOverride.GetScriptVersion() >= NIOVERRIDE_SCRIPT_VERSION
EndFunction

Event OnArousalComputed(string eventName, string argString, float argNum, form sender)
	{SLA broadcast at the end of each scan tick. Refresh the player, then any nearby aroused NPCs.}
	bool doDebug = TTT_ArousedNipsMainQuest.DebugMode
	If doDebug
		debug.Notification("ArousedNips: Arousal event")
		debug.Trace("TTT_ArousedNips: Arousal event")
	EndIf

	UpdateActor(Game.GetPlayer(), doDebug)

	If argNum <= 0
		If doDebug
			debug.Notification("ArousedNips: No aroused NPCs nearby, updating player only")
			debug.Trace("TTT_ArousedNips: No aroused NPCs nearby, updating player only")
		EndIf
		return
	EndIf

	Actor[] theActors = MiscUtil.ScanCellNPCsByFaction(sla_Framework.slaArousal, Game.GetPlayer(), TTT_ArousedNipsMainQuest.ScanCellRadius, 0, 127, TTT_ArousedNipsMainQuest.IgnoreDead)
	; theActors can have null slots if SLA's faction faction-rank cache is mid-update.
	int i = 0
	int len = theActors.length
	While i < len
		If theActors[i]
			UpdateActor(theActors[i], doDebug)
		EndIf
		i += 1
	EndWhile

	If doDebug
		debug.Notification("ArousedNips: Arousal event end")
		debug.Trace("TTT_ArousedNips: Arousal event end")
	EndIf
endEvent

Function UpdateActor(Actor who, bool doDebug=false, int modifier=0)
	{Set morphs of "who" according to their arousal, offset by "modifier".}
	ActorBase whoBase = who.GetLeveledActorBase()
	; ActorBase.GetSex() encodes both gender and creature-ness:
	;   0 = male NPC, 1 = female NPC, 2 = male creature, 3 = female creature.
	; This lets us split the "Ignore Males" (humanoid) and "Ignore Beast"
	; (creature) filters without needing a keyword lookup.
	int sex = whoBase.GetSex()
	String skipReason = ""
	If TTT_ArousedNipsMainQuest.IgnoreMales && sex == 0
		skipReason = "is male"
	ElseIf TTT_ArousedNipsMainQuest.IgnoreMaleBeast && sex == 2
		skipReason = "is male beast"
	ElseIf TTT_ArousedNipsMainQuest.IgnoreFemaleBeast && sex == 3
		skipReason = "is female beast"
	ElseIf TTT_ArousedNipsMainQuest.IgnoreDead && who.IsDead()
		; Dead NPCs are already filtered out at the OnArousalComputed cell-scan
		; level (we pass IgnoreDead into ScanCellNPCsByFaction), but the player
		; poll and the debug spell can still hit this path with a corpse target,
		; so we re-check here.
		skipReason = "is dead"
	EndIf
	If skipReason != ""
		If doDebug
			debug.Notification("ArousedNips: "+whoBase.GetName()+" "+skipReason+", skipping")
			debug.Trace("TTT_ArousedNips: "+whoBase.GetName()+" "+skipReason+", skipping")
		EndIF
		return
	EndIf

	; Portable per-actor arousal read (works on SLA NG, SLO, OSL Aroused, eXtended).
	; GetActorArousal -> slaInternalModules.GetArousal(who), which triggers a fresh
	; recalculation rather than returning the cached faction-rank that SLA only
	; refreshes on its scan tick. Already clamped to [0,100] by GetActorArousal.
	int Arousal = sla_Framework.GetActorArousal(who) + modifier
	If Arousal > 100
		Arousal = 100
	ElseIf Arousal < 0
		Arousal = 0
	EndIf

	; Iterate the morph table until we hit the first empty slot. Honours imported
	; counts up to 128 (the array size set by OnInit / ImportUserSettings).
	; Papyrus && short-circuits, so MorphNames[j] is not read once j hits 128.
	String[] morphNames = TTT_ArousedNipsMainQuest.MorphNames
	Float[]  maxValues  = TTT_ArousedNipsMainQuest.MaxValue
	int j = 0
	while j < 128 && morphNames[j] != ""
		float Value = maxValues[j] * Arousal / 100
		NiOverride.SetBodyMorph(who, morphNames[j], NIO_KEY, Value)
		If doDebug
			debug.Notification("ArousedNips: setting "+morphNames[j]+" to "+Value)
			debug.Trace("TTT_ArousedNips: setting "+morphNames[j]+" to "+Value)
		EndIf
		j += 1
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