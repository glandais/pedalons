---------------------------- MODULE WeatherCells ----------------------------
(***************************************************************************)
(* Weather cache: WeatherPlanner / WeatherFetchWorker / WeatherHousekeeping *)
(* on two backend instances (rolling start-first deploy) sharing one        *)
(* PostgreSQL (READ COMMITTED, row locks held until commit).                *)
(*                                                                         *)
(* Code references (backend/src/main/java/fr/pedalons/...):                *)
(*  Planner  service/weather/WeatherPlanner.java:64-86 -- ONE @Transactional*)
(*           loop of upsertDemand over a HashMap (iteration order = hash    *)
(*           buckets, arbitrary w.r.t. any other txn's order).              *)
(*           repository/weather/WeatherCellRepository.java:45-83 INSERT ... *)
(*           ON CONFLICT DO UPDATE -> row lock (NO KEY UPDATE) until commit.*)
(*  Claim    WeatherFetchWorker.java:273-295 + Repo:97-130 -- own txn,      *)
(*           FOR UPDATE SKIP LOCKED + lease (claimed_until) then commit.    *)
(*  Fetch    WeatherFetchWorker.java:298-330 -- no txn, no lock.            *)
(*  Store    WeatherFetchWorker.java:332-341,359-392 -- ONE txn, per cell:  *)
(*           hourly upsert, daily upsert, markFetched (UPDATE -> row lock), *)
(*           cells in the order of `list("id in ?1")` (no ORDER BY).        *)
(*  Store KO WeatherFetchWorker.java:342-356 -> markFailed (multi-row UPDATE)*)
(*  Purge    WeatherHousekeeping.java:469-481, Repo:219-247: 3 statements in *)
(*           one txn; hourly/daily delete via subquery on statement snapshot,*)
(*           then DELETE cells (row lock + EvalPlanQual recheck).            *)
(***************************************************************************)
EXTENDS Naturals, Sequences, FiniteSets, TLC

CONSTANTS Cells,          \* 1..N
          Inst,           \* {1,2}
          SortedOrder,    \* TRUE = "fixed" variant: planner and store lock in the same order
          AllowSlowLease, \* TRUE = lease may expire while its holder still works (fetch > 5 min)
          CrashInst,      \* the instance that may be stopped (old release)
          Lite            \* TRUE = no housekeeping / day / ride changes (lock-order check only)

NONE == 0
LNONE == <<"none", 0>>
PT(i) == <<"P", i>>
WT(i) == <<"W", i>>
HT == <<"H", 0>>
Txns == {PT(i) : i \in Inst} \cup {WT(i) : i \in Inst} \cup {HT}

VARIABLES
  lock,          \* cell -> txn holding its row lock, or NONE
  exists, age,   \* row exists; days since last_demand_at (0..2), committed values
  needed,        \* cells an upcoming ride needs (environment)
  lease,         \* cell -> instance holding claimed_until, or NONE
  hasData,       \* forecast rows present
  ppc, pseq, pidx,
  wpc, wset, wseq, widx,
  hpc, hset, hseq, hidx, hdel,
  plannedToday, crashed,
  storeAborts, plannerAborts, badDelete, wipedLive

vars == <<lock, exists, age, needed, lease, hasData, ppc, pseq, pidx,
          wpc, wset, wseq, widx, hpc, hset, hseq, hidx, hdel,
          plannedToday, crashed, storeAborts, plannerAborts, badDelete, wipedLive>>

Perms(S) == {s \in [1..Cardinality(S) -> S] : \A a, b \in DOMAIN s : a # b => s[a] # s[b]}
Sorted(S) == CHOOSE s \in Perms(S) : \A a, b \in DOMAIN s : a < b => s[a] < s[b]
Orders(S) == IF SortedOrder THEN {Sorted(S)} ELSE Perms(S)
Range(s) == {s[k] : k \in DOMAIN s}

Init ==
  /\ lock = [c \in Cells |-> LNONE]
  /\ exists = [c \in Cells |-> FALSE]
  /\ age = [c \in Cells |-> 0]
  /\ needed = Cells
  /\ lease = [c \in Cells |-> NONE]
  /\ hasData = [c \in Cells |-> FALSE]
  /\ ppc = [i \in Inst |-> "idle"] /\ pseq = [i \in Inst |-> <<>>] /\ pidx = [i \in Inst |-> 1]
  /\ wpc = [i \in Inst |-> "idle"] /\ wset = [i \in Inst |-> {}]
  /\ wseq = [i \in Inst |-> <<>>] /\ widx = [i \in Inst |-> 1]
  /\ hpc = "idle" /\ hset = {} /\ hseq = <<>> /\ hidx = 1 /\ hdel = {}
  /\ plannedToday = FALSE /\ crashed = FALSE
  /\ storeAborts = 0 /\ plannerAborts = 0 /\ badDelete = FALSE /\ wipedLive = FALSE

ReleaseLocks(t) == [c \in Cells |-> IF lock[c] = t THEN LNONE ELSE lock[c]]

(* Cell a txn is about to lock, if any *)
NextCell(t) ==
  CASE t[1] = "P" -> IF ppc[t[2]] = "upsert" /\ pidx[t[2]] <= Len(pseq[t[2]])
                     THEN pseq[t[2]][pidx[t[2]]] ELSE NONE
    [] t[1] = "W" -> IF wpc[t[2]] \in {"store", "fail"} /\ widx[t[2]] <= Len(wseq[t[2]])
                     THEN wseq[t[2]][widx[t[2]]] ELSE NONE
    [] t[1] = "H" -> IF hpc = "delcells" /\ hidx <= Len(hseq) THEN hseq[hidx] ELSE NONE
WaitsFor(t) == LET c == NextCell(t) IN
               IF c # NONE /\ lock[c] # LNONE /\ lock[c] # t THEN {lock[c]} ELSE {}
RECURSIVE Reach(_, _)
Reach(S, n) == IF n = 0 THEN S ELSE Reach(S \cup UNION {WaitsFor(u) : u \in S}, n - 1)
InCycle(t) == t \in Reach(WaitsFor(t), Cardinality(Txns))
CanLock(t) == LET c == NextCell(t) IN c # NONE /\ lock[c] \in {LNONE, t}
Grab(t) == lock' = [lock EXCEPT ![NextCell(t)] = t]

(* ---------------- Planner (WeatherPlanner.plan) ---------------- *)
PStart(i) == /\ ppc[i] = "idle" /\ needed # {}
             /\ \E s \in Orders(needed) : pseq' = [pseq EXCEPT ![i] = s]
             /\ ppc' = [ppc EXCEPT ![i] = "upsert"] /\ pidx' = [pidx EXCEPT ![i] = 1]
             /\ UNCHANGED <<lock, exists, age, needed, lease, hasData, wpc, wset, wseq, widx,
                           hpc, hset, hseq, hidx, hdel, plannedToday, crashed,
                           storeAborts, plannerAborts, badDelete, wipedLive>>
PLock(i) == /\ CanLock(PT(i)) /\ Grab(PT(i))
            /\ pidx' = [pidx EXCEPT ![i] = @ + 1]
            /\ UNCHANGED <<exists, age, needed, lease, hasData, ppc, pseq, wpc, wset, wseq, widx,
                          hpc, hset, hseq, hidx, hdel, plannedToday, crashed,
                          storeAborts, plannerAborts, badDelete, wipedLive>>
PCommit(i) == /\ ppc[i] = "upsert" /\ pidx[i] > Len(pseq[i])
              /\ LET S == Range(pseq[i]) IN
                 /\ exists' = [c \in Cells |-> exists[c] \/ c \in S]
                 /\ age' = [c \in Cells |-> IF c \in S THEN 0 ELSE age[c]]
                 /\ hasData' = [c \in Cells |-> IF c \in S /\ ~exists[c] THEN FALSE ELSE hasData[c]]
              /\ lock' = ReleaseLocks(PT(i)) /\ ppc' = [ppc EXCEPT ![i] = "idle"]
              /\ plannedToday' = TRUE
              /\ UNCHANGED <<needed, lease, pseq, pidx, wpc, wset, wseq, widx,
                            hpc, hset, hseq, hidx, hdel, crashed,
                            storeAborts, plannerAborts, badDelete, wipedLive>>

(* ---------------- Worker (WeatherFetchWorker) ---------------- *)
Claimable == {c \in Cells : exists[c] /\ age[c] = 0 /\ lease[c] = NONE /\ lock[c] = LNONE}
WClaim(i) == /\ wpc[i] = "idle"
             /\ \E S \in SUBSET Claimable \ {{}} :
                  /\ lease' = [c \in Cells |-> IF c \in S THEN i ELSE lease[c]]
                  /\ wset' = [wset EXCEPT ![i] = S]
                  /\ \E s \in Orders(S) : wseq' = [wseq EXCEPT ![i] = s]
             /\ wpc' = [wpc EXCEPT ![i] = "fetch"]
             /\ UNCHANGED <<lock, exists, age, needed, hasData, ppc, pseq, pidx, widx,
                           hpc, hset, hseq, hidx, hdel, plannedToday, crashed,
                           storeAborts, plannerAborts, badDelete, wipedLive>>
WFetched(i, ok) == /\ wpc[i] = "fetch"
                   /\ wpc' = [wpc EXCEPT ![i] = IF ok THEN "store" ELSE "fail"]
                   /\ widx' = [widx EXCEPT ![i] = 1]
                   /\ UNCHANGED <<lock, exists, age, needed, lease, hasData, ppc, pseq, pidx,
                                 wset, wseq, hpc, hset, hseq, hidx, hdel, plannedToday, crashed,
                                 storeAborts, plannerAborts, badDelete, wipedLive>>
WLock(i) == /\ CanLock(WT(i)) /\ Grab(WT(i))
            /\ widx' = [widx EXCEPT ![i] = @ + 1]
            /\ UNCHANGED <<exists, age, needed, lease, hasData, ppc, pseq, pidx, wpc, wset, wseq,
                          hpc, hset, hseq, hidx, hdel, plannedToday, crashed,
                          storeAborts, plannerAborts, badDelete, wipedLive>>
WCommit(i) == /\ wpc[i] \in {"store", "fail"} /\ widx[i] > Len(wseq[i])
              /\ lease' = [c \in Cells |-> IF c \in wset[i] THEN NONE ELSE lease[c]]
              /\ hasData' = [c \in Cells |-> IF c \in wset[i] /\ wpc[i] = "store"
                                             THEN TRUE ELSE hasData[c]]
              /\ lock' = ReleaseLocks(WT(i))
              /\ wpc' = [wpc EXCEPT ![i] = "idle"] /\ wset' = [wset EXCEPT ![i] = {}]
              /\ UNCHANGED <<exists, age, needed, ppc, pseq, pidx, wseq, widx,
                            hpc, hset, hseq, hidx, hdel, plannedToday, crashed,
                            storeAborts, plannerAborts, badDelete, wipedLive>>
LeaseExpire(c) == /\ lease[c] # NONE
                  /\ \/ wpc[lease[c]] \in {"idle", "dead"}
                     \/ c \notin wset[lease[c]]
                     \/ AllowSlowLease
                  /\ lease' = [lease EXCEPT ![c] = NONE]
                  /\ UNCHANGED <<lock, exists, age, needed, hasData, ppc, pseq, pidx,
                                wpc, wset, wseq, widx, hpc, hset, hseq, hidx, hdel,
                                plannedToday, crashed, storeAborts, plannerAborts,
                                badDelete, wipedLive>>

(* ---------------- PostgreSQL deadlock detector ---------------- *)
(* A victim in a waits-for cycle gets "deadlock detected"; its txn rolls back. *)
Abort(t) == /\ InCycle(t)
            /\ lock' = ReleaseLocks(t)
            /\ CASE t[1] = "P" ->
                      /\ ppc' = [ppc EXCEPT ![t[2]] = "idle"]  \* tick() logs, next tick in 5 min
                      /\ plannerAborts' = plannerAborts + 1
                      /\ UNCHANGED <<wpc, widx, storeAborts, hpc, hdel>>
                 [] t[1] = "W" /\ wpc[t[2]] = "store" ->
                      \* WeatherFetchWorker.java:342-356: forecast dropped, markFailed for the batch
                      /\ wpc' = [wpc EXCEPT ![t[2]] = "fail"]
                      /\ widx' = [widx EXCEPT ![t[2]] = 1]
                      /\ storeAborts' = storeAborts + 1
                      /\ UNCHANGED <<ppc, plannerAborts, hpc, hdel>>
                 [] t[1] = "W" ->
                      \* markFailed itself aborted: exception escapes, lease left to expire
                      /\ wpc' = [wpc EXCEPT ![t[2]] = "idle"]
                      /\ UNCHANGED <<ppc, plannerAborts, widx, storeAborts, hpc, hdel>>
                 [] OTHER ->
                      /\ hpc' = "idle" /\ hdel' = {}
                      /\ UNCHANGED <<ppc, plannerAborts, wpc, widx, storeAborts>>
            /\ UNCHANGED <<exists, age, needed, lease, hasData, pseq, pidx, wset, wseq,
                          hset, hseq, hidx, plannedToday, crashed, badDelete, wipedLive>>

(* ---------------- Housekeeping (nightly purge) ---------------- *)
Purgeable(c) == exists[c] /\ age[c] >= 2 /\ lease[c] = NONE
HStart == /\ hpc = "idle"
          /\ hset' = {c \in Cells : Purgeable(c)}   \* subquery snapshot of the hourly/daily deletes
          /\ \E s \in Orders({c \in Cells : Purgeable(c)}) : hseq' = s
          /\ hidx' = 1 /\ hdel' = {} /\ hpc' = "delcells"
          /\ UNCHANGED <<lock, exists, age, needed, lease, hasData, ppc, pseq, pidx,
                        wpc, wset, wseq, widx, plannedToday, crashed,
                        storeAborts, plannerAborts, badDelete, wipedLive>>
HLock == /\ CanLock(HT) /\ Grab(HT)
         /\ LET c == hseq[hidx] IN   \* EvalPlanQual recheck on the latest committed row
              hdel' = IF Purgeable(c) THEN hdel \cup {c} ELSE hdel
         /\ hidx' = hidx + 1
         /\ UNCHANGED <<exists, age, needed, lease, hasData, ppc, pseq, pidx,
                       wpc, wset, wseq, widx, hpc, hset, hseq, plannedToday, crashed,
                       storeAborts, plannerAborts, badDelete, wipedLive>>
HCommit == /\ hpc = "delcells" /\ hidx > Len(hseq)
           /\ exists' = [c \in Cells |-> exists[c] /\ c \notin hdel]
           /\ hasData' = [c \in Cells |-> hasData[c] /\ c \notin hset]
           /\ badDelete' = (badDelete \/ \E c \in hdel : age[c] < 2)
           /\ wipedLive' = (wipedLive \/ \E c \in hset \ hdel : hasData[c] /\ exists[c])
           /\ lock' = ReleaseLocks(HT) /\ hpc' = "idle"
           /\ UNCHANGED <<age, needed, lease, ppc, pseq, pidx, wpc, wset, wseq, widx,
                         hset, hseq, hidx, hdel, plannedToday, crashed,
                         storeAborts, plannerAborts>>

(* ---------------- Environment ---------------- *)
(* A day passes; assumption: the planner committed at least once since the last one. *)
DayPasses == /\ plannedToday /\ \E c \in Cells : age[c] < 2
             /\ age' = [c \in Cells |-> IF age[c] < 2 THEN age[c] + 1 ELSE 2]
             /\ plannedToday' = FALSE
             /\ UNCHANGED <<lock, exists, needed, lease, hasData, ppc, pseq, pidx,
                           wpc, wset, wseq, widx, hpc, hset, hseq, hidx, hdel, crashed,
                           storeAborts, plannerAborts, badDelete, wipedLive>>
RidesChange == /\ \E n \in SUBSET Cells : needed' = n /\ n # needed
               /\ UNCHANGED <<lock, exists, age, lease, hasData, ppc, pseq, pidx,
                             wpc, wset, wseq, widx, hpc, hset, hseq, hidx, hdel,
                             plannedToday, crashed, storeAborts, plannerAborts,
                             badDelete, wipedLive>>
(* The old release is stopped: connection closed -> its txns roll back, leases stay. *)
Crash == /\ ~crashed /\ crashed' = TRUE
         /\ lock' = [c \in Cells |-> IF lock[c] \in {PT(CrashInst), WT(CrashInst)}
                                     THEN LNONE ELSE lock[c]]
         /\ wpc' = [wpc EXCEPT ![CrashInst] = "dead"]
         /\ ppc' = [ppc EXCEPT ![CrashInst] = "dead"]
         /\ UNCHANGED <<exists, age, needed, lease, hasData, pseq, pidx, wset, wseq, widx,
                       hpc, hset, hseq, hidx, hdel, plannedToday,
                       storeAborts, plannerAborts, badDelete, wipedLive>>

Next ==
  \/ \E i \in Inst : PStart(i) \/ PLock(i) \/ PCommit(i)
                     \/ WClaim(i) \/ WFetched(i, TRUE) \/ WFetched(i, FALSE)
                     \/ WLock(i) \/ WCommit(i)
  \/ \E c \in Cells : LeaseExpire(c)
  \/ \E t \in Txns : Abort(t)
  \/ (~Lite /\ HStart) \/ HLock \/ HCommit
  \/ (~Lite /\ (DayPasses \/ RidesChange)) \/ Crash

Spec == Init /\ [][Next]_vars

(* ---------------- Properties ---------------- *)
\* No cell is fetched by two workers at once (lease exclusivity).
NoConcurrentFetch == \A i, j \in Inst : i # j =>
   (({c \in wset[i] : wpc[i] \in {"fetch","store"}}) \cap ({c \in wset[j] : wpc[j] \in {"fetch","store"}})) = {}
\* A provider answer is never thrown away because of a DB lock conflict.
NoStoreDeadlock == storeAborts = 0
NoPlannerDeadlock == plannerAborts = 0
\* Housekeeping never deletes a cell demanded within the last two days.
NoBadDelete == ~badDelete
\* (informational) forecast rows of a cell kept alive are not wiped.
NoWipedLive == ~wipedLive
\* Abstract: the "lost update" check -- a committed markFetched never clears a lease
\* belonging to another live worker. (Only possible with AllowSlowLease.)
LeaseOwnedWhileWorking == \A i \in Inst : wpc[i] \in {"fetch","store"} =>
                             \A c \in wset[i] : lease[c] \in {i, NONE}

StateBound == storeAborts <= 2 /\ plannerAborts <= 2
=============================================================================
