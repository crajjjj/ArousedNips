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

Event OnInit()
	{Fires once when the alias is first filled. Warm the sla_Framework cache
	 eagerly so the manual OnPlayerLoadGame call from Quest.OnInit (and every
	 subsequent use) takes the fast path. Return value discarded -- side
	 effect (Auto property population) is what we want.}
	GetFramework()
EndEvent

slaFrameworkScr Function GetFramework()
	{Defensive accessor for the SLA framework script. Used in three modes:

	   (1) OnInit -- warm-cache the Auto property on first-fill.
	   (2) OnPlayerLoadGame -- double-check on every load (catches SLA reinstall
	       / formID rewire since the cosaved Auto value was last set).
	   (3) Call sites (OnArousalComputed scan, UpdateActor arousal read,
	       OnPlayerLoadGame version check) -- get the framework safely. Cheap
	       when sla_Framework is already populated (one bool check + return).

	 Falls back to Quest.GetQuest("sla_Framework") if the Auto property is None
	 -- both SLA NG / SLO Aroused NG and OSL Aroused's stub ship a quest with
	 that editor ID, per the SLA NG readme's portable detection pattern.

	 On successful fallback, populates the Auto property so subsequent calls
	 take the fast path and the resolved value persists in the cosave for the
	 next save load.

	 Why this exists: TTT_ArousedNips.esp shipped by some older forks has been
	 observed with the sla_Framework Auto property silently unwired -- callers
	 get None from the property even when SLA is loaded and the quest is alive
	 in memory. The dynamic lookup ignores the ESP wiring and goes straight to
	 the named quest.}
	If sla_Framework
		Return sla_Framework
	EndIf
	sla_Framework = Quest.GetQuest("sla_Framework") as slaFrameworkScr
	If sla_Framework
		debug.Trace("TTT_ArousedNips: populated sla_Framework Auto property via Quest.GetQuest fallback")
	EndIf
	Return sla_Framework
EndFunction

Event OnPlayerLoadGame()
	{Checking requirements every game load. Also re-runs GetFramework to
	 catch SLA reinstall / formID rewire since the cached Auto property was set.}
	; Double-check the framework property on every load. If the cosaved Auto
	; property is still valid (normal case) this is a no-op; if SLA was
	; reinstalled with different formIDs it'll re-populate via the fallback.
	GetFramework()

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
	; Defensive accessor -- GetFramework() at the top of OnPlayerLoadGame already
	; warmed/refreshed the cache, but going through the accessor here means a
	; mid-session re-entry (e.g. ResetAllState -> alias.OnPlayerLoadGame from the
	; MCM thread before OnInit's cache was committed) still resolves cleanly.
	slaFrameworkScr framework = GetFramework()
	if !framework
		; Both the Auto property AND the Quest.GetQuest fallback came back None.
		; Real-world this means SexLabAroused.esm isn't loaded at all. Without it
		; we cannot detect the fork or read arousal -- abort.
		TTT_ArousedNipsMainQuest.isSLAroused28 = false
		TTT_ArousedNipsMainQuest.isSLAroused29 = false
		debug.Notification("ArousedNips: SLA framework not found (Auto property unwired AND Quest.GetQuest fallback failed), aborting")
		debug.Trace("TTT_ArousedNips: SLA framework not found (Auto property unwired AND Quest.GetQuest fallback failed), aborting")
		return
	endif
	int slaVersion = framework.GetVersion()

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

	; Defensive accessor -- normally just returns the populated Auto property.
	; If something unusual happened (mid-session SLA reinstall, etc.) the
	; accessor re-resolves and re-populates so we don't silently skip ticks
	; on a cosmetic property glitch.
	slaFrameworkScr framework = GetFramework()
	If !framework
		return
	EndIf
	; slaArousal is itself an Auto property on slaframeworkscr -- if SLA's own
	; ESP is broken-wired the same way ours was, this comes back None and
	; MiscUtil.ScanCellNPCsByFaction(None, ...) is unspecified. Skip the tick
	; rather than poke PapyrusUtil with a null faction.
	If !framework.slaArousal
		If doDebug
			debug.Trace("TTT_ArousedNips: framework.slaArousal is None; skipping NPC scan this tick")
		EndIf
		return
	EndIf
	Actor[] theActors = MiscUtil.ScanCellNPCsByFaction(framework.slaArousal, Game.GetPlayer(), TTT_ArousedNipsMainQuest.ScanCellRadius, 0, 127, TTT_ArousedNipsMainQuest.IgnoreDead)
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
	If !who
		; Callers (OnArousalComputed, OnStageStart) guard their array entries,
		; but the debug spell's crosshair fallback and any third-party script
		; that ends up here can still pass None. Bail rather than null-deref.
		return
	EndIf
	ActorBase whoBase = who.GetLeveledActorBase()
	If !whoBase
		; LeveledActorBase can return None for actors in unusual states (e.g.
		; mid-spawn). No way to filter by sex / IsDead without it -- skip.
		return
	EndIf
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
	; Defensive accessor: GetFramework() normally just returns the cached
	; sla_Framework Auto property (warmed in OnInit / OnPlayerLoadGame), but
	; falls back to Quest.GetQuest if the property somehow became None at
	; runtime. Cheap when the cache is valid -- one bool check + return.
	slaFrameworkScr framework = GetFramework()
	If !framework
		If doDebug
			debug.Notification("ArousedNips: "+whoBase.GetName()+" -- SLA framework unavailable, skipping")
			debug.Trace("TTT_ArousedNips: "+whoBase.GetName()+" -- SLA framework unavailable, skipping")
		EndIf
		return
	EndIf
	int Arousal = framework.GetActorArousal(who) + modifier
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
	If !actorList
		return
	EndIf
	int len = actorList.length
	If len < 1
		return
	EndIf

	Utility.Wait(1)
	;giving Aroused time to do its thing.

	bool doDebug = TTT_ArousedNipsMainQuest.DebugMode
	int i = 0
	While i < len
		; HookActors can hand back arrays with null slots if SexLab's hook list
		; is mid-update; guard each entry rather than null-deref in UpdateActor.
		If actorList[i]
			UpdateActor(actorList[i], doDebug, 50)
		EndIf
		i += 1
	EndWhile
EndEvent