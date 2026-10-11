---------------------------- MODULE RideJoin ----------------------------
(***************************************************************************)
(* RideService.joinGroup / leaveGroup / updateRide(group removal) under   *)
(* PostgreSQL READ COMMITTED, as the code actually runs:                   *)
(*  joinGroup  RideService.java:493-524                                    *)
(*    "chkReg"  findByUserAndRide          (RideService.java:502-507)      *)
(*    "chkCap"  group.hasCapacity()        (RideService.java:514, RideGroup *)
(*              .java:133 -> participations.size(), a separate SELECT)     *)
(*    "insert"  persist + flush at commit  (RideService.java:519)          *)
(*              unique(ride_group_id,user_id) V2__initial_schema.sql:210   *)
(*              FK ride_group_id -> ride_groups V2:579                      *)
(*    "commit"                                                              *)
(*  No lock: participations is mappedBy, so Hibernate 7 excludes it from   *)
(*  optimistic locking (CollectionBinder.bindOptimisticLock: !isMappedBy)  *)
(*  -> RideGroup.@Version is NOT bumped by a join.                          *)
(*  removeGroup = updateRide dropping a group (RideService.java:386-416):  *)
(*    snapshot participations, delete them + the group (orphanRemoval),    *)
(*    commit; FK makes a concurrently inserted row abort one side.         *)
(* FIXED=TRUE: join takes SELECT .. FOR UPDATE on the ride row first.      *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS Users, Groups, Cap, NJoin, FIXED

Procs == 1..NJoin
Org   == 0            \* organiser removing a group

VARIABLES
  committed,   \* set of <<g,u>> rows visible to everybody
  groups,      \* groups still existing (committed)
  pc, req,     \* per join process
  pend,        \* uncommitted row of each join process (or <<>>)
  lockHolder,  \* ride row lock (FIXED variant) : 0 = free
  opc, ogroup, osnap \* organiser

vars == <<committed, groups, pc, req, pend, lockHolder, opc, ogroup, osnap>>

Rows(g) == {r \in committed : r[1] = g}

Init ==
  /\ committed = {}
  /\ groups = Groups
  /\ pc = [p \in Procs |-> "start"]
  /\ req \in [Procs -> Groups \X Users]
  /\ pend = [p \in Procs |-> <<>>]
  /\ lockHolder = 0
  /\ opc = "idle" /\ ogroup = (CHOOSE g \in Groups : TRUE) /\ osnap = {}

Start(p) ==
  /\ pc[p] = "start"
  /\ IF FIXED THEN /\ lockHolder = 0 /\ lockHolder' = p
              ELSE UNCHANGED lockHolder
  /\ pc' = [pc EXCEPT ![p] = "chkReg"]
  /\ UNCHANGED <<committed, groups, req, pend, opc, ogroup, osnap>>

Finish(p, out) ==
  /\ pc' = [pc EXCEPT ![p] = out]
  /\ lockHolder' = IF lockHolder = p THEN 0 ELSE lockHolder

\* findByUserAndRide + group lookup (group must exist: findByIdAndRide)
ChkReg(p) ==
  /\ pc[p] = "chkReg"
  /\ LET g == req[p][1] u == req[p][2] IN
     IF g \notin groups \/ \E r \in committed : r[2] = u
       THEN Finish(p, "rejected")
       ELSE /\ pc' = [pc EXCEPT ![p] = "chkCap"] /\ UNCHANGED lockHolder
  /\ UNCHANGED <<committed, groups, req, pend, opc, ogroup, osnap>>

ChkCap(p) ==
  /\ pc[p] = "chkCap"
  /\ IF Cardinality(Rows(req[p][1])) >= Cap
       THEN Finish(p, "full")
       ELSE /\ pc' = [pc EXCEPT ![p] = "insert"] /\ UNCHANGED lockHolder
  /\ UNCHANGED <<committed, groups, req, pend, opc, ogroup, osnap>>

\* INSERT: unique index waits for a concurrent uncommitted duplicate,
\* then fails if it committed; FK check fails if the group is gone.
Insert(p) ==
  /\ pc[p] = "insert"
  /\ ~\E q \in Procs : q # p /\ pend[q] = req[p]          \* blocked otherwise
  /\ ~(opc = "deleted" /\ ogroup = req[p][1])               \* FK row lock wait
  /\ IF req[p] \in committed \/ req[p][1] \notin groups
       THEN Finish(p, "error") /\ UNCHANGED pend
       ELSE /\ pend' = [pend EXCEPT ![p] = req[p]]
            /\ pc' = [pc EXCEPT ![p] = "commit"] /\ UNCHANGED lockHolder
  /\ UNCHANGED <<committed, groups, req, opc, ogroup, osnap>>

Commit(p) ==
  /\ pc[p] = "commit"
  /\ committed' = committed \cup {pend[p]}
  /\ pend' = [pend EXCEPT ![p] = <<>>]
  /\ Finish(p, "joined")
  /\ UNCHANGED <<groups, req, opc, ogroup, osnap>>

\* leaveGroup: delete own row (RideService.java:534-541)
Leave(r) ==
  /\ r \in committed
  /\ committed' = committed \ {r}
  /\ UNCHANGED <<groups, pc, req, pend, lockHolder, opc, ogroup, osnap>>

\* updateRide removing group g: snapshot, delete, commit (FK guarded)
ORead(g) ==
  /\ opc = "idle" /\ g \in groups
  /\ opc' = "read" /\ ogroup' = g /\ osnap' = Rows(g)
  /\ UNCHANGED <<committed, groups, pc, req, pend, lockHolder>>
ODelete ==
  /\ opc = "read"
  \* DELETE ride_groups row: FK check sees committed rows and waits on pending ones
  /\ ~\E q \in Procs : pend[q] # <<>> /\ pend[q][1] = ogroup
  /\ IF Rows(ogroup) \ osnap # {}
       THEN opc' = "aborted" /\ UNCHANGED <<committed, groups>>
       ELSE /\ opc' = "deleted"
            /\ UNCHANGED <<committed, groups>>
  /\ UNCHANGED <<pc, req, pend, lockHolder, ogroup, osnap>>
OCommit ==
  /\ opc = "deleted"
  /\ committed' = committed \ Rows(ogroup)
  /\ groups' = groups \ {ogroup}
  /\ opc' = "done"
  /\ UNCHANGED <<pc, req, pend, lockHolder, ogroup, osnap>>

Next ==
  \/ \E p \in Procs : Start(p) \/ ChkReg(p) \/ ChkCap(p) \/ Insert(p) \/ Commit(p)
  \/ \E r \in committed : Leave(r)
  \/ \E g \in Groups : ORead(g)
  \/ ODelete \/ OCommit

Spec == Init /\ [][Next]_vars

TypeOK == lockHolder \in Procs \cup {0}

OneGroupPerRide == \A u \in Users : Cardinality({g \in Groups : <<g, u>> \in committed}) <= 1
CapacityRespected == \A g \in Groups : Cardinality(Rows(g)) <= Cap
NoOrphan == \A r \in committed : r[1] \in groups
=============================================================================
