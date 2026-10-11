---------------------------- MODULE FW_F ----------------------------
(* FeedbackGithubWorker.publishSignature on one or two backends (rolling deploy; SKIP is per
   instance, FeedbackGithubWorker.java:63), against FeedbackService.reportError on the same
   signature (FeedbackService.java:140-170).
   - tick: findPendingIds (tx), then per id: tx{findById, status==PENDING ? render}  (:99,:121-135)
   - github.createIssue outside any tx                                              (:143)
   - tx{findById; set CREATED, number, createdAt, summarizedUntil}                  (:145-153)
     ErrorSignature has neither @Version nor @DynamicUpdate: the flush rewrites EVERY column with
     what this short tx read (plain SELECT, READ COMMITTED), incl. occurrence_count.
   - reportError: lockOrCreate = SELECT ... FOR UPDATE (ErrorSignatureRepository.java:50),
     occurrenceCount+1 (:150), commit.
   FixClaim: a CAS PENDING->PUBLISHING claim before the GitHub call.
   FixDyn: the worker writes only the columns it changes. *)
EXTENDS Naturals, FiniteSets

CONSTANTS Workers, Reporters, FixClaim, FixDyn

VARIABLES status, count, truth, issues, wpc, wsnap, rpc, rsnap, lockHolder

vars == <<status, count, truth, issues, wpc, wsnap, rpc, rsnap, lockHolder>>

Init == /\ status = "PENDING" /\ count = 1 /\ truth = 1 /\ issues = 0
        /\ wpc = [w \in Workers |-> "idle"] /\ wsnap = [w \in Workers |-> 0]
        /\ rpc = [r \in Reporters |-> "idle"] /\ rsnap = [r \in Reporters |-> 0]
        /\ lockHolder = "none"

\* prepare tx: still PENDING? (with FixClaim: atomic CAS to PUBLISHING)
WPrepare(w) == /\ wpc[w] = "idle" /\ status = "PENDING"
               /\ lockHolder = "none" \/ ~FixClaim   \* a CAS update waits for the row lock
               /\ status' = IF FixClaim THEN "PUBLISHING" ELSE status
               /\ wpc' = [wpc EXCEPT ![w] = "prepared"]
               /\ UNCHANGED <<count, truth, issues, wsnap, rpc, rsnap, lockHolder>>

WCreateIssue(w) == /\ wpc[w] = "prepared" /\ issues' = issues + 1
                   /\ wpc' = [wpc EXCEPT ![w] = "created"]
                   /\ UNCHANGED <<status, count, truth, wsnap, rpc, rsnap, lockHolder>>

\* mark tx, part 1: findById — plain SELECT, reads the committed row, never blocks
WMarkRead(w) == /\ wpc[w] = "created" /\ wsnap' = [wsnap EXCEPT ![w] = count]
                /\ wpc' = [wpc EXCEPT ![w] = "marking"]
                /\ UNCHANGED <<status, count, truth, issues, rpc, rsnap, lockHolder>>

\* mark tx, part 2: flush UPDATE of every column (waits for the row lock), commit
WMarkWrite(w) == /\ wpc[w] = "marking" /\ lockHolder = "none"
                 /\ status' = "CREATED"
                 /\ count' = IF FixDyn THEN count ELSE wsnap[w]
                 /\ wpc' = [wpc EXCEPT ![w] = "idle_done"]
                 /\ UNCHANGED <<truth, issues, wsnap, rpc, rsnap, lockHolder>>

\* reportError: SELECT ... FOR UPDATE, increment, commit
RLock(r) == /\ rpc[r] = "idle" /\ lockHolder = "none"
            /\ lockHolder' = r /\ rsnap' = [rsnap EXCEPT ![r] = count]
            /\ rpc' = [rpc EXCEPT ![r] = "locked"]
            /\ UNCHANGED <<status, count, truth, issues, wpc, wsnap>>

RCommit(r) == /\ rpc[r] = "locked"
              /\ count' = rsnap[r] + 1 /\ truth' = truth + 1
              /\ lockHolder' = "none" /\ rpc' = [rpc EXCEPT ![r] = "done"]
              /\ UNCHANGED <<status, issues, wpc, wsnap, rsnap>>

Next == \/ \E w \in Workers : WPrepare(w) \/ WCreateIssue(w) \/ WMarkRead(w) \/ WMarkWrite(w)
        \/ \E r \in Reporters : RLock(r) \/ RCommit(r)

Spec == Init /\ [][Next]_vars

OneIssue == issues <= 1
NoLostOccurrence == lockHolder = "none" => count = truth
==========================================================================
