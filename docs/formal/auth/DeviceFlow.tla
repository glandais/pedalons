------------------------------ MODULE DeviceFlow ------------------------------
(* RFC 8628 device flow, DeviceAuthService.java.  One device_codes row.
   complete  (133-177): SELECT ... FOR UPDATE filtered on domain and expiresAt > now
                        (DeviceCodeRepository:300-307), check, authorize, commit.
   deny      (286-306): plain SELECT (no lock), setExpiresAt(now): whole-row UPDATE at commit
                        (DeviceCode has no @Version / @DynamicUpdate) from the stale snapshot.
   exchange  (186-212): plain SELECT by device_code_hash, checks, em.remove -> DELETE ... WHERE id=?
                        (Hibernate checks the row count: 0 rows -> StaleObjectStateException,
                        rollback, so no session), session INSERT in the same transaction.
   Polls may be duplicated (device retry after a lost response).                     *)
EXTENDS Naturals, FiniteSets
CONSTANTS Users, Polls, Deniers, NoUser
VARIABLES exists, authorized, user, expired,   \* committed row
          lockHolder,                          \* complete holding FOR UPDATE
          cpc, dpc, dsnap, epc, esnap,
          sessions,                            \* set of [poll, user]
          firstApprover
vars == <<exists, authorized, user, expired, lockHolder, cpc, dpc, dsnap, epc, esnap, sessions, firstApprover>>

Row == [authorized: BOOLEAN, user: Users \cup {NoUser}, expired: BOOLEAN]
Init == /\ exists = TRUE /\ authorized = FALSE /\ user = NoUser /\ expired = FALSE
        /\ lockHolder = NoUser
        /\ cpc = [u \in Users |-> "idle"] /\ dpc = [d \in Deniers |-> "idle"]
        /\ dsnap = [d \in Deniers |-> [authorized |-> FALSE, user |-> NoUser, expired |-> FALSE]]
        /\ epc = [p \in Polls |-> "idle"]
        /\ esnap = [p \in Polls |-> [authorized |-> FALSE, user |-> NoUser, expired |-> FALSE]]
        /\ sessions = {} /\ firstApprover = NoUser

\* complete: FOR UPDATE read (blocks while another holds it or a write is in progress)
CLock(u) == /\ cpc[u] = "idle" /\ lockHolder = NoUser
            /\ IF exists /\ ~expired
                 THEN lockHolder' = u /\ cpc' = [cpc EXCEPT ![u] = "locked"]
                 ELSE UNCHANGED lockHolder /\ cpc' = [cpc EXCEPT ![u] = "done"]  \* TOKEN_INVALID
            /\ UNCHANGED <<exists, authorized, user, expired, dpc, dsnap, epc, esnap, sessions, firstApprover>>
CCommit(u) == /\ cpc[u] = "locked"
              /\ cpc' = [cpc EXCEPT ![u] = "done"] /\ lockHolder' = NoUser
              /\ IF authorized
                   THEN UNCHANGED <<authorized, user, firstApprover>>      \* 164-170
                   ELSE /\ authorized' = TRUE /\ user' = u                  \* 172
                        /\ firstApprover' = IF firstApprover = NoUser THEN u ELSE firstApprover
              /\ UNCHANGED <<exists, expired, dpc, dsnap, epc, esnap, sessions>>
\* deny: unlocked read, then whole-row write from the snapshot
DRead(d) == /\ dpc[d] = "idle"
            /\ IF exists /\ ~expired
                 THEN dpc' = [dpc EXCEPT ![d] = "read"]
                      /\ dsnap' = [dsnap EXCEPT ![d] = [authorized |-> authorized, user |-> user, expired |-> expired]]
                 ELSE dpc' = [dpc EXCEPT ![d] = "done"] /\ UNCHANGED dsnap
            /\ UNCHANGED <<exists, authorized, user, expired, lockHolder, cpc, epc, esnap, sessions, firstApprover>>
DWrite(d) == /\ dpc[d] = "read" /\ lockHolder = NoUser
             /\ dpc' = [dpc EXCEPT ![d] = "done"]
             /\ IF exists
                  THEN authorized' = dsnap[d].authorized /\ user' = dsnap[d].user /\ expired' = TRUE
                  ELSE UNCHANGED <<authorized, user, expired>>   \* 0 rows -> stale state, rollback
             /\ UNCHANGED <<exists, lockHolder, cpc, dsnap, epc, esnap, sessions, firstApprover>>
\* exchange
ERead(p) == /\ epc[p] = "idle"
            /\ IF exists /\ ~expired /\ authorized /\ user # NoUser
                 THEN epc' = [epc EXCEPT ![p] = "read"]
                      /\ esnap' = [esnap EXCEPT ![p] = [authorized |-> authorized, user |-> user, expired |-> expired]]
                 ELSE epc' = [epc EXCEPT ![p] = "idle"] /\ UNCHANGED esnap   \* pending/expired: poll again
            /\ UNCHANGED <<exists, authorized, user, expired, lockHolder, cpc, dpc, dsnap, sessions, firstApprover>>
ECommit(p) == /\ epc[p] = "read" /\ lockHolder = NoUser
              /\ epc' = [epc EXCEPT ![p] = "done"]
              /\ IF exists
                   THEN exists' = FALSE /\ sessions' = sessions \cup {[poll |-> p, user |-> esnap[p].user]}
                   ELSE UNCHANGED <<exists, sessions>>   \* DELETE hit 0 rows: rollback
              /\ UNCHANGED <<authorized, user, expired, lockHolder, cpc, dpc, dsnap, esnap, firstApprover>>
Expire == /\ ~expired /\ expired' = TRUE
          /\ UNCHANGED <<exists, authorized, user, lockHolder, cpc, dpc, dsnap, epc, esnap, sessions, firstApprover>>
Next == \/ \E u \in Users : CLock(u) \/ CCommit(u)
        \/ \E d \in Deniers : DRead(d) \/ DWrite(d)
        \/ \E p \in Polls : ERead(p) \/ ECommit(p)
        \/ Expire
Spec == Init /\ [][Next]_vars
AtMostOneSession == Cardinality(sessions) <= 1
SessionForFirstApprover == \A s \in sessions : s.user = firstApprover
===============================================================================
