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

; --- Top-nudity / armor-suppression state ---
; Resolved fresh on every load by ResolveNudityDetection(). IsTopCovered uses the
; vanilla ArmorCuirass / ClothingBody worn-keyword check as primary; when Advanced
; Nudity Detection ("Advanced Nudity Detection.esp") is present its Topless/Nude
; faction ranks (the same formIDs SLA NG resolves -- see slamainscr.psc) only
; OVERRIDE a covered result to bare, so skimpy / bikini tops are judged correctly
; without breaking on actors AND hasn't scanned. See IsActorNaked in slamainscr.psc.
Bool AND_Resolved = false
Faction AND_Nude
Faction AND_Topless
Keyword kwArmorCuirass
Keyword kwClothingBody

; Player-only reveal-tween state. PlayerArmorScale is the armor scale last applied
; to the player (the tween's start point); tweenGen is bumped by any direct player
; update (poll / heartbeat / a newer equip change) so an in-flight tween bails
; instead of fighting it.
Float PlayerArmorScale = 1.0
Int tweenGen = 0

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

	; Resolve AND factions + vanilla body keywords for the under-armor suppression.
	; Re-run every load so an AND install/uninstall since the last save is picked up.
	ResolveNudityDetection()

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

Function ResolveNudityDetection()
	{Resolve the Advanced Nudity Detection factions (top-nudity integration) and
	 the vanilla body keywords (no-AND fallback). Called from OnPlayerLoadGame on
	 every load so an AND install/uninstall since the last save is reflected.

	 The AND formIDs (0x831 Nude, 0x832 Topless) and ESP name match what SLA NG
	 itself resolves in slamainscr.psc -- AND owns these factions, not SLA, so we
	 can read them directly regardless of which SLA fork is installed.}
	AND_Resolved = false
	AND_Nude = None
	AND_Topless = None
	If Game.GetModByName("Advanced Nudity Detection.esp") != 255
		AND_Nude    = Game.GetFormFromFile(0x831, "Advanced Nudity Detection.esp") as Faction
		AND_Topless = Game.GetFormFromFile(0x832, "Advanced Nudity Detection.esp") as Faction
		AND_Resolved = (AND_Nude != None) || (AND_Topless != None)
		If TTT_ArousedNipsMainQuest.DebugMode
			debug.Trace("TTT_ArousedNips: Advanced Nudity Detection found, top-nudity gating enabled")
		EndIf
	EndIf
	kwArmorCuirass = Keyword.GetKeyword("ArmorCuirass")
	kwClothingBody = Keyword.GetKeyword("ClothingBody")
EndFunction

Bool Function IsTopCovered(Actor who)
	{True when the actor's chest is covered, so nipple/areola morphs should be
	 scaled down (prevents clipping through tops).

	 Mirrors SexLab Aroused's own naked test (slamainscr.IsActorNaked): the vanilla
	 ArmorCuirass / ClothingBody worn-keyword check is primary, and Advanced Nudity
	 Detection only OVERRIDES a "covered" result to bare. We deliberately do NOT make
	 AND the sole authority: AND's NPC factions are only populated by its periodic,
	 player-cast NPCScanSpell (MCM-gated via ScanNPC), so an unscanned / out-of-range
	 / just-stripped NPC has no Topless rank yet -- trusting AND alone would suppress
	 morphs on a genuinely naked NPC (e.g. mid-scene). The keyword check is per-actor
	 and immediate, so bare actors always show regardless of AND's scan coverage.

	 Reading the faction rank is cheap (a rank lookup); we never call SLA's expensive
	 IsActorNaked(). Naked-body armors / SOS carry neither keyword, so they read bare.}
	; No top worn at all -> bare chest. True for every actor with no dependency on
	; AND having scanned them.
	If !(who.WornHasKeyword(kwArmorCuirass) || who.WornHasKeyword(kwClothingBody))
		Return false
	EndIf
	; A top is worn. Let AND override to "bare" for skimpy / bikini / transparent
	; tops that still carry a cuirass keyword but expose the chest.
	If AND_Resolved
		If (AND_Nude && who.GetFactionRank(AND_Nude) == 1) || (AND_Topless && who.GetFactionRank(AND_Topless) == 1)
			Return false
		EndIf
	EndIf
	Return true
EndFunction

Event OnObjectEquipped(Form akBaseObject, ObjectReference akReference)
	{Player put something on -- suppress immediately (snap, no ease) so the chest
	 morphs collapse before anything can clip during a redress.}
	RefreshOnArmorChange(akBaseObject, false)
EndEvent

Event OnObjectUnequipped(Form akBaseObject, ObjectReference akReference)
	{Player took something off -- if that bares the chest, ease the morphs back in.}
	RefreshOnArmorChange(akBaseObject, true)
EndEvent

Function RefreshOnArmorChange(Form akBaseObject, Bool wasRemoved)
	{Player-only morph refresh when armor is equipped/unequipped. Gated on the same
	 requirements as the poll loop so we never poke NiOverride when the mod is
	 non-functional. With AND, a top change can come from many slots, so we react to
	 any worn armor (after a short settle so AND updates its factions first); without
	 AND only body-slot (32) armor can change the covered state.

	 Removing armor that leaves the chest bare eases the morphs in over ~1s
	 (TweenPlayerReveal); every other case snaps via UpdateActor -- notably equipping,
	 so nipples flatten instantly rather than poking through a redress.}
	If !TTT_ArousedNipsMainQuest.SuppressUnderArmor
		return
	EndIf
	If !(TTT_ArousedNipsMainQuest.isNioOk && (TTT_ArousedNipsMainQuest.isSLAroused28 || TTT_ArousedNipsMainQuest.isSLAroused29))
		return
	EndIf
	Armor armo = akBaseObject as Armor
	If !armo
		return
	EndIf
	If !AND_Resolved && !Math.LogicalAnd(armo.GetSlotMask(), 0x04)
		; Without AND, only body-slot (32) armor can change the covered state.
		return
	EndIf
	If AND_Resolved
		Utility.Wait(0.3)  ; let AND update its nudity factions first
	EndIf

	If wasRemoved && !IsTopCovered(Game.GetPlayer())
		TweenPlayerReveal()
	Else
		UpdateActor(Game.GetPlayer(), TTT_ArousedNipsMainQuest.DebugMode)
	EndIf
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

	; Under-armor suppression. When the chest is covered, scale every morph by
	; UnderArmorScale (0.0 = flat, no clip; 1.0 = full) so fitted nipples don't
	; poke through tops. IsTopCovered prefers Advanced Nudity Detection's
	; Topless/Nude state, falling back to the vanilla worn-keyword check.
	Float armorScale = 1.0
	If TTT_ArousedNipsMainQuest.SuppressUnderArmor && IsTopCovered(who)
		armorScale = TTT_ArousedNipsMainQuest.UnderArmorScale
		If doDebug
			debug.Notification("ArousedNips: "+whoBase.GetName()+" chest covered, scaling morphs x"+armorScale)
			debug.Trace("TTT_ArousedNips: "+whoBase.GetName()+" chest covered, scaling morphs x"+armorScale)
		EndIf
	EndIf

	SetActorMorphs(who, Arousal, armorScale, doDebug)

	; Track the player's last-applied scale (the reveal tween's start point) and
	; cancel any in-flight tween -- a direct update supersedes it.
	If who == Game.GetPlayer()
		PlayerArmorScale = armorScale
		tweenGen += 1
	EndIf
EndFunction

Function SetActorMorphs(Actor who, Int arousal, Float scale, Bool doDebug=false)
	{Write every morph = maxValue * arousal/100 * scale, then push the model update.
	 Shared by UpdateActor (a single snap) and TweenPlayerReveal (one step of the
	 reveal ease). Iterates the morph table until the first empty slot; honours
	 imported counts up to 128. Papyrus && short-circuits, so MorphNames[j] is not
	 read once j hits 128.}
	String[] morphNames = TTT_ArousedNipsMainQuest.MorphNames
	Float[]  maxValues  = TTT_ArousedNipsMainQuest.MaxValue
	int j = 0
	while j < 128 && morphNames[j] != ""
		float Value = maxValues[j] * arousal / 100 * scale
		NiOverride.SetBodyMorph(who, morphNames[j], NIO_KEY, Value)
		If doDebug
			debug.Notification("ArousedNips: setting "+morphNames[j]+" to "+Value)
			debug.Trace("TTT_ArousedNips: setting "+morphNames[j]+" to "+Value)
		EndIf
		j += 1
	EndWhile
	NiOverride.UpdateModelWeight(who)
EndFunction

Function TweenPlayerReveal()
	{Gradually grow the player's morphs from the currently-applied armor scale up to
	 the now-uncovered target over ~1s, for a smooth reveal when body armor is
	 removed. Player-only. Arousal is read once and held constant across the short
	 tween. Overlap-guarded: bumps tweenGen and bails if a newer update (another
	 equip change, the poll, or the heartbeat) supersedes it mid-ease.}
	Actor player = Game.GetPlayer()
	If !player
		return
	EndIf

	; Target scale after the armor change (1.0 = bare; still-covered -> no reveal).
	Float target = 1.0
	If TTT_ArousedNipsMainQuest.SuppressUnderArmor && IsTopCovered(player)
		target = TTT_ArousedNipsMainQuest.UnderArmorScale
	EndIf
	Float from = PlayerArmorScale
	If target == from
		; Already at the target (e.g. was never suppressed) -- nothing to animate.
		return
	EndIf

	slaFrameworkScr framework = GetFramework()
	If !framework
		return
	EndIf
	Int arousal = framework.GetActorArousal(player)
	If arousal > 100
		arousal = 100
	ElseIf arousal < 0
		arousal = 0
	EndIf

	; Claim this tween; a newer one (or any UpdateActor on the player) will bump
	; tweenGen and make the myGen check below fail, so this loop stops cleanly.
	tweenGen += 1
	Int myGen = tweenGen

	Int steps = 10
	Int s = 1
	While s <= steps && myGen == tweenGen
		Float f = from + (target - from) * s / steps
		SetActorMorphs(player, arousal, f)
		PlayerArmorScale = f
		Utility.Wait(0.1)
		s += 1
	EndWhile

	; Pin the exact target if we ran to completion (weren't superseded).
	If myGen == tweenGen
		SetActorMorphs(player, arousal, target)
		PlayerArmorScale = target
	EndIf
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