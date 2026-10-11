------------------------------ MODULE OtpIssue ------------------------------
(* AuthService.requestOtp -> createOtp (AuthService.java:327-380), one address, one window.
   Each request runs in its own transaction (QuarkusTransaction.joiningExisting, 328):
     Count : countRecentByEmailAndType (AuthTokenRepository:255-264)   -- committed rows
     Inval : invalidateByEmailAndType (AuthTokenRepository:233-240)     -- committed rows
     Insert: persist the new code, commit                               (378)
   No lock, no unique constraint on (email, type) unused (V2 schema: only token_hash unique).
   Fix = TRUE: Count..Insert serialised per address (e.g. pg_advisory_xact_lock(hash(email))). *)
EXTENDS Naturals, FiniteSets
CONSTANTS Reqs, MaxCodes, Fix
VARIABLES rows, pc, seen   \* rows: set of [id, valid] committed
vars == <<rows, pc, seen>>
Init == rows = {} /\ pc = [r \in Reqs |-> "count"] /\ seen = [r \in Reqs |-> 0]
Busy(r) == Fix /\ \E q \in Reqs \ {r} : pc[q] \in {"inval", "insert"}
Count(r) == /\ pc[r] = "count" /\ ~Busy(r)
            /\ seen' = [seen EXCEPT ![r] = Cardinality(rows)]
            /\ pc' = [pc EXCEPT ![r] = IF Cardinality(rows) >= MaxCodes THEN "done" ELSE "inval"]
            /\ UNCHANGED rows
Inval(r) == /\ pc[r] = "inval"
            /\ rows' = {[id |-> x.id, valid |-> FALSE] : x \in rows}
            /\ pc' = [pc EXCEPT ![r] = "insert"] /\ UNCHANGED seen
Insert(r) == /\ pc[r] = "insert"
             /\ rows' = rows \cup {[id |-> r, valid |-> TRUE]}
             /\ pc' = [pc EXCEPT ![r] = "done"] /\ UNCHANGED seen
Next == \E r \in Reqs : Count(r) \/ Inval(r) \/ Insert(r)
Spec == Init /\ [][Next]_vars
RateLimit == Cardinality(rows) <= MaxCodes          \* codes (and mails) per window
OneValid == Cardinality({x \in rows : x.valid}) <= 1 \* one live code per address
=============================================================================
