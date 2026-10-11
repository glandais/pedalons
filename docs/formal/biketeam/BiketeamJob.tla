---------------------------- MODULE BiketeamJob ----------------------------
(***************************************************************************)
(* One biketeam live-migration job (a reset job when Reset = TRUE) run by  *)
(* the worker of two backend instances (rolling deploy: both schedulers    *)
(* active), with recoverStuck and the retention purge on both.             *)
(*                                                                         *)
(* Code refs (backend/src/main/java/fr/pedalons/...):                      *)
(*  Claim      JobService.claimNext:285 + JobRepository.claim:497 (CAS)    *)
(*             JobService.loadContext:299 (ctx.attempt, ctx.targetTeamId)  *)
(*  Prepare    Worker.prepareTarget:297 + TargetResolver.evaluate          *)
(*  Ensure     MigrationService.ensureLiveTargetTeam:318 (one tx), with    *)
(*             Worker.setAside:367 (slug := <slug>-reset-<jobTsid>)        *)
(*  SetTarget  Worker:251 -> JobService.setTargetTeam:337 (own tx, owned())*)
(*  Item       MigrationService.migratePlaces:700 (find map, create, map   *)
(*             upsert in one tx; map PK (entity_type, biketeam_id))        *)
(*  Flush      JobProgressTracker.flush -> JobService.recordProgress:326   *)
(*  Succeed    JobService.succeed:341; Error -> retryOrFail:373            *)
(*  Recover    JobService.recoverStuck:430 (failStuck / requeueStuck)      *)
(*  Purge      RetentionScheduler + JobRepository.deleteEndedBefore:561    *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets, TLC

CONSTANTS Workers,        \* worker threads (one per instance)
          MaxAttempts,    \* pedalons.biketeam.max-attempts
          MaxCrashes,     \* bound on crashes / transient tx failures
          Reset,          \* the job's reset flag
          InitSlug,       \* slug of the migrated team: "S" (= targetSlug) or "L" (renamed)
          AllowStall,     \* can a live worker go silent > stuck-after ?
          FixSameTx       \* fixed variant: targetTeamId written in the team-creating tx

Teams == 1..3
NULL == 0
Aside(s) == IF s = "S" THEN "S-reset-J" ELSE "L-reset-J"   \* setAsideSlug(slug, jobTsid)

VARIABLES
  status,     \* QUEUED RUNNING SUCCEEDED FAILED GONE
  attempts, targetTeam, errCode, hbStale,
  team,       \* team[t] = [ex, slug, del]
  mapTeam,    \* TEAM mapping row -> team id (NULL = none)
  mapItem,    \* PLACE mapping row -> entity id (NULL = none)
  entities,   \* number of place entities created for the single biketeam place
  pc, ctx, plan, crashes, purgedActive

vars == <<status, attempts, targetTeam, errCode, hbStale, team, mapTeam, mapItem,
          entities, pc, ctx, plan, crashes, purgedActive>>

Init ==
  /\ status = "QUEUED" /\ attempts = 0 /\ targetTeam = NULL /\ errCode = "none"
  /\ hbStale = FALSE
  /\ team = [t \in Teams |-> IF t = 1 THEN [ex |-> TRUE, slug |-> InitSlug, del |-> FALSE]
                                      ELSE [ex |-> FALSE, slug |-> "", del |-> FALSE]]
  /\ mapTeam = 1
  /\ mapItem = NULL /\ entities = 0
  /\ pc = [w \in Workers |-> "idle"]
  /\ ctx = [w \in Workers |-> [att |-> 0, tgt |-> NULL]]
  /\ plan = [w \in Workers |-> [kind |-> "none", expected |-> NULL, aside |-> NULL, item |-> "none"]]
  /\ crashes = 0 /\ purgedActive = FALSE

Owned(w) == status = "RUNNING" /\ attempts = ctx[w].att      \* JobService.owned:408
SlugHolder(s) == {t \in Teams : team[t].ex /\ team[t].slug = s}
Live(t) == t # NULL /\ team[t].ex /\ ~team[t].del

\* ---- Claim: select ... for update skip locked + CAS QUEUED->RUNNING
Claim(w) ==
  /\ pc[w] = "idle" /\ status = "QUEUED"
  /\ status' = "RUNNING" /\ attempts' = attempts + 1 /\ hbStale' = FALSE
  /\ ctx' = [ctx EXCEPT ![w] = [att |-> attempts + 1, tgt |-> targetTeam]]
  /\ pc' = [pc EXCEPT ![w] = "prepare"]
  /\ UNCHANGED <<targetTeam, errCode, team, mapTeam, mapItem, entities, plan, crashes, purgedActive>>

\* ---- prepareTarget (read-only tx)
Prepare(w) ==
  /\ pc[w] = "prepare"
  /\ LET m == mapTeam
         p == IF Live(m) THEN
                 (IF Reset /\ m # ctx[w].tgt THEN
                     (IF SlugHolder("S") \ {m} # {} THEN [kind |-> "refuse", expected |-> NULL, aside |-> NULL, item |-> "none"]
                      ELSE [kind |-> "create", expected |-> NULL, aside |-> m, item |-> "none"])
                  ELSE [kind |-> "reuse", expected |-> m, aside |-> NULL, item |-> "none"])
              ELSE IF SlugHolder("S") # {} /\ (m = NULL \/ SlugHolder("S") # {m})
                   THEN [kind |-> "refuse", expected |-> NULL, aside |-> NULL, item |-> "none"]
              ELSE IF m # NULL /\ team[m].ex
                   THEN [kind |-> "create", expected |-> NULL, aside |-> m, item |-> "none"]
              ELSE [kind |-> "create", expected |-> NULL, aside |-> NULL, item |-> "none"]
     IN /\ plan' = [plan EXCEPT ![w] = p]
        /\ pc' = [pc EXCEPT ![w] = IF p.kind = "refuse" THEN "fail" ELSE "ensure"]
  /\ UNCHANGED <<status, attempts, targetTeam, errCode, hbStale, team, mapTeam, mapItem,
                 entities, ctx, crashes, purgedActive>>

\* ---- ensureLiveTargetTeam: one transaction (setAside + create, or reuse)
NewId == CHOOSE t \in Teams : ~team[t].ex
Ensure(w) ==
  /\ pc[w] = "ensure"
  /\ LET p == plan[w] IN
     IF p.kind = "reuse" THEN
        IF Live(p.expected) /\ mapTeam = p.expected
        THEN /\ pc' = [pc EXCEPT ![w] = "setTarget"]
             /\ ctx' = [ctx EXCEPT ![w].tgt = p.expected]
             /\ UNCHANGED <<team, mapTeam, mapItem, targetTeam, errCode>>
        ELSE /\ pc' = [pc EXCEPT ![w] = "fail"]
             /\ UNCHANGED <<team, mapTeam, mapItem, ctx, targetTeam, errCode>>
     ELSE
       LET a == p.aside
           newSlug == IF a = NULL THEN "" ELSE Aside(team[a].slug)
           \* setAside renames then flushes: uk_teams_domain_slug violation -> generic exception
           collide == a # NULL /\ SlugHolder(newSlug) \ {a} # {}
           team1 == IF a = NULL THEN team
                    ELSE [team EXCEPT ![a] = [ex |-> TRUE, slug |-> newSlug, del |-> TRUE]]
           map1 == IF a = NULL THEN mapTeam ELSE NULL   \* deleteByTeamOrKeys
           item1 == IF a = NULL THEN mapItem ELSE NULL
           holder == {t \in Teams : team1[t].ex /\ team1[t].slug = "S"}
       IN IF collide THEN
            \* tx rolled back; ConstraintViolationException -> catch(Exception) -> retryOrFail
            /\ pc' = [pc EXCEPT ![w] = "error"]
            /\ errCode' = "COLLISION"
            /\ UNCHANGED <<team, mapTeam, mapItem, ctx, targetTeam>>
          ELSE IF holder # {} THEN
            /\ pc' = [pc EXCEPT ![w] = "fail"]
            /\ UNCHANGED <<team, mapTeam, mapItem, ctx, targetTeam, errCode>>
          ELSE
            /\ team' = [team1 EXCEPT ![NewId] = [ex |-> TRUE, slug |-> "S", del |-> FALSE]]
            /\ mapTeam' = NewId
            /\ mapItem' = item1
            /\ ctx' = [ctx EXCEPT ![w].tgt = NewId]
            /\ IF FixSameTx /\ Owned(w) THEN targetTeam' = NewId ELSE targetTeam' = targetTeam
            /\ pc' = [pc EXCEPT ![w] = "setTarget"]
            /\ UNCHANGED errCode
  /\ UNCHANGED <<status, attempts, hbStale, entities, plan, crashes, purgedActive>>

\* ---- setTargetTeam: own tx, owned() check
SetTarget(w) ==
  /\ pc[w] = "setTarget"
  /\ IF Owned(w)
     THEN /\ targetTeam' = ctx[w].tgt /\ hbStale' = FALSE
          /\ pc' = [pc EXCEPT ![w] = "itemRead"]
     ELSE /\ pc' = [pc EXCEPT ![w] = "idle"] /\ UNCHANGED <<targetTeam, hbStale>>
  /\ UNCHANGED <<status, attempts, errCode, team, mapTeam, mapItem, entities, ctx, plan, crashes, purgedActive>>

\* ---- one place: beforeItem flush (owned), then find map ... create ... upsert, one tx
ItemRead(w) ==
  /\ pc[w] = "itemRead"
  /\ IF Owned(w)
     THEN /\ hbStale' = FALSE
          /\ plan' = [plan EXCEPT ![w].item = IF mapItem = NULL THEN "create" ELSE "update"]
          /\ pc' = [pc EXCEPT ![w] = "itemCommit"]
     ELSE /\ pc' = [pc EXCEPT ![w] = "idle"] /\ UNCHANGED <<hbStale, plan>>
  /\ UNCHANGED <<status, attempts, targetTeam, errCode, team, mapTeam, mapItem, entities, ctx, crashes, purgedActive>>

ItemCommit(w) ==
  /\ pc[w] = "itemCommit"
  /\ IF plan[w].item = "create"
     THEN IF mapItem = NULL
          THEN /\ entities' = entities + 1 /\ mapItem' = entities + 1
          ELSE UNCHANGED <<entities, mapItem>>   \* PK violation: whole item tx rolled back
     ELSE UNCHANGED <<entities, mapItem>>
  /\ pc' = [pc EXCEPT ![w] = "succeed"]
  /\ UNCHANGED <<status, attempts, targetTeam, errCode, hbStale, team, mapTeam, ctx, plan, crashes, purgedActive>>

Succeed(w) ==
  /\ pc[w] = "succeed"
  /\ IF Owned(w) THEN status' = "SUCCEEDED" /\ errCode' = "none"
                 ELSE UNCHANGED <<status, errCode>>
  /\ pc' = [pc EXCEPT ![w] = "idle"]
  /\ UNCHANGED <<attempts, targetTeam, hbStale, team, mapTeam, mapItem, entities, ctx, plan, crashes, purgedActive>>

Fail(w) ==   \* BiketeamJobFailure -> fail()
  /\ pc[w] = "fail"
  /\ IF Owned(w) THEN status' = "FAILED" /\ errCode' = IF errCode = "COLLISION" THEN "COLLISION" ELSE "BUSINESS"
                 ELSE UNCHANGED <<status, errCode>>
  /\ pc' = [pc EXCEPT ![w] = "idle"]
  /\ UNCHANGED <<attempts, targetTeam, hbStale, team, mapTeam, mapItem, entities, ctx, plan, crashes, purgedActive>>

Error(w) ==  \* generic exception -> retryOrFail()
  /\ pc[w] = "error"
  /\ IF Owned(w)
     THEN IF attempts >= MaxAttempts THEN status' = "FAILED" ELSE status' = "QUEUED"
     ELSE UNCHANGED status
  /\ pc' = [pc EXCEPT ![w] = "idle"]
  /\ UNCHANGED <<attempts, targetTeam, errCode, hbStale, team, mapTeam, mapItem, entities, ctx, plan, crashes, purgedActive>>

\* A crash (pod killed in a rolling deploy) or a transient exception between two of the
\* worker's short transactions.
Crash(w) ==
  /\ pc[w] \notin {"idle"} /\ crashes < MaxCrashes
  /\ crashes' = crashes + 1
  /\ \/ pc' = [pc EXCEPT ![w] = "idle"]     \* JVM gone: heartbeat stops
     \/ pc' = [pc EXCEPT ![w] = "error"]    \* exception -> retryOrFail
  /\ UNCHANGED <<status, attempts, targetTeam, errCode, hbStale, team, mapTeam, mapItem, entities, ctx, plan, purgedActive>>

OwnerAlive == \E w \in Workers : pc[w] # "idle" /\ Owned(w)
GoStale ==
  /\ status = "RUNNING" /\ ~hbStale
  /\ (~OwnerAlive \/ AllowStall)
  /\ hbStale' = TRUE
  /\ UNCHANGED <<status, attempts, targetTeam, errCode, team, mapTeam, mapItem, entities, pc, ctx, plan, crashes, purgedActive>>

Recover ==  \* failStuck / requeueStuck (bulk, condition re-read on the locked row)
  /\ status = "RUNNING" /\ hbStale
  /\ IF attempts >= MaxAttempts THEN status' = "FAILED" /\ errCode' = "WORKER_LOST"
                                ELSE status' = "QUEUED" /\ UNCHANGED errCode
  /\ UNCHANGED <<attempts, targetTeam, hbStale, team, mapTeam, mapItem, entities, pc, ctx, plan, crashes, purgedActive>>

Purge ==
  /\ status \in {"SUCCEEDED", "FAILED"}
  /\ purgedActive' = (status \in {"QUEUED", "RUNNING"})
  /\ status' = "GONE"
  /\ UNCHANGED <<attempts, targetTeam, errCode, hbStale, team, mapTeam, mapItem, entities, pc, ctx, plan, crashes>>

WStep(w) == Claim(w) \/ Prepare(w) \/ Ensure(w) \/ SetTarget(w) \/ ItemRead(w) \/ ItemCommit(w)
            \/ Succeed(w) \/ Fail(w) \/ Error(w)

Next == \/ \E w \in Workers : WStep(w) \/ Crash(w)
        \/ GoStale \/ Recover \/ Purge

Spec == Init /\ [][Next]_vars
        /\ \A w \in Workers : WF_vars(WStep(w))
        /\ WF_vars(GoStale) /\ WF_vars(Recover)

---------------------------------------------------------------------------
\* Safety
InContent(w) == pc[w] \in {"itemRead", "itemCommit"}
\* the team / content writes of a job are done by one worker at a time
SingleWriter == \A w1, w2 \in Workers : (w1 # w2) => ~(InContent(w1) /\ InContent(w2))
NoDuplicateEntity == entities <= 1
NoActivePurge == ~purgedActive
\* the reset must not trip over its own set-aside slug
NoSetAsideCollision == errCode # "COLLISION"
\* at most one live team carries the migrated content
OneLiveTeam == Cardinality({t \in Teams : Live(t)}) <= 1
\* the job never fails for an internal reason when nothing external refused it
NoSpuriousFailure == status = "FAILED" => errCode \in {"WORKER_LOST", "BUSINESS"}

\* a reset job is not FAILED by its own set-aside after a crash/transient error
NoCollisionFailure == ~(status = "FAILED" /\ errCode = "COLLISION")

\* Liveness: a job never stays RUNNING forever, and ends
EventuallyEnds == <>(status \in {"SUCCEEDED", "FAILED", "GONE"})
RunningLeaves == (status = "RUNNING") ~> (status # "RUNNING")
=============================================================================
