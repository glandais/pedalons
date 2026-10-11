------------------------------- MODULE CoalesceRace -------------------------------
(*
  RIDE_UPDATED coalescing (NotificationEvent.coalescesWhilePending) vs. the dispatcher.

  Code modelled:
   - RideService.updateRide (service/ride/RideService.java:425-437): in the business tx, reads
     previousDateTime, writes the new date, and calls publisher.publish(RideUpdated(prev)) which is
     NotificationEventRepository.insertIfAbsent (repository/.../NotificationEventRepository.java:46-68):
     INSERT ... ON CONFLICT (dedup_key) DO NOTHING. The ride UPDATE is flushed at commit; the event
     INSERT is a native query executed immediately. DO NOTHING takes no lock on the existing row.
   - Ride has @Version (BaseEntity) so edits of the same ride serialise: one editor, sequential edits.
   - NotificationDispatchService.dispatchOne (service/notification/NotificationDispatchService.java:259-291):
     claim tx (SKIP LOCKED + CAS PENDING->PROCESSING) commits, then fanOut tx: resolver reads the
     ride (READ COMMITTED, NotificationRecipientResolver.java:154-156, 186-210) compares it with
     the payload's previousDateTime, and at commit sets DONE + releaseDedupKey (lines 359-365) or
     SKIPPED + release (301-306). Hibernate flushes the dedup_key change at commit.
   - recoverStuck (482-491): PROCESSING older than 15 min -> PENDING (modelled: owner crashed).
   - Two backend instances (rolling deploy) = two dispatchers.

  FIX = 0 : the code as it is.
  FIX = 1 : claim also releases the dedup key.
  FIX = 2 : FIX 1 + the publisher's fold locks the pending row until the business tx commits
            (ON CONFLICT DO UPDATE ... WHERE status='PENDING'), which SKIP LOCKED / CAS respect.
*)
EXTENDS Naturals, FiniteSets, Sequences

CONSTANTS Dates, MaxEdits, Dispatchers, MaxRows, FIX, NoOwner

VARIABLES rideDate,    \* committed ride date
          known,       \* the date the riders were last told
          rows,        \* sequence of event rows [key |-> "K"/"rel", prev, status, lock]
          epc, eprev, enew, edits,   \* the single editor
          dpc, drow, dread,          \* per dispatcher
          announced                  \* the current ride date was announced since it last changed

vars == <<rideDate, known, rows, epc, eprev, enew, edits, dpc, drow, dread, announced>>

D0 == CHOOSE d \in Dates : TRUE

Init ==
  /\ rideDate = D0 /\ known = D0 /\ rows = << >>
  /\ epc = "idle" /\ eprev = D0 /\ enew = D0 /\ edits = 0
  /\ dpc = [d \in Dispatchers |-> "idle"] /\ drow = [d \in Dispatchers |-> 0]
  /\ dread = [d \in Dispatchers |-> D0] /\ announced = FALSE

KeyHeld == {i \in 1..Len(rows) : rows[i].key = "K"}

\* ---- editor (RideService.updateRide) ----
EBegin == /\ epc = "idle" /\ edits < MaxEdits
          /\ \E nd \in Dates \ {rideDate} : enew' = nd
          /\ eprev' = rideDate /\ epc' = "began" /\ edits' = edits + 1
          /\ UNCHANGED <<rideDate, known, rows, dpc, drow, dread, announced>>

\* publisher.publish -> insert ... on conflict (dedup_key) do nothing
EInsert == /\ epc = "began"
           /\ IF KeyHeld = {}
                THEN /\ Len(rows) < MaxRows
                     /\ rows' = Append(rows, [key |-> "K", prev |-> eprev, status |-> "PENDING", lock |-> FALSE, vis |-> FALSE, dirty |-> FALSE])
                ELSE LET i == CHOOSE j \in KeyHeld : TRUE IN
                     IF FIX = 3
                       THEN /\ ~rows[i].lock   \* ON CONFLICT DO UPDATE SET dirty = true: row lock till commit
                            /\ rows' = [rows EXCEPT ![i].lock = TRUE, ![i].dirty = TRUE]
                     ELSE IF FIX = 2 /\ rows[i].status = "PENDING"
                       THEN /\ ~rows[i].lock   \* would wait on a dispatcher's FOR UPDATE; never holds it across steps here
                            /\ rows' = [rows EXCEPT ![i].lock = TRUE]
                       ELSE rows' = rows      \* folded: DO NOTHING
           /\ epc' = "inserted"
           /\ UNCHANGED <<rideDate, known, eprev, enew, edits, dpc, drow, dread, announced>>

ECommit == /\ epc = "inserted"
           /\ rideDate' = enew
           /\ announced' = FALSE
           /\ rows' = [i \in 1..Len(rows) |-> [rows[i] EXCEPT !.lock = FALSE, !.vis = TRUE]]
           /\ epc' = "idle"
           /\ UNCHANGED <<known, eprev, enew, edits, dpc, drow, dread>>

\* ---- dispatcher (NotificationDispatchService.dispatchOne) ----
Claim(d) == /\ dpc[d] = "idle"
            /\ \E i \in 1..Len(rows) :
                 /\ rows[i].status = "PENDING" /\ ~rows[i].lock /\ rows[i].vis
                 /\ rows' = [rows EXCEPT ![i].status = "PROCESSING",
                                         ![i].key = IF FIX \in {1,2} THEN "rel" ELSE rows[i].key,
                                         ![i].dirty = FALSE]
                 /\ drow' = [drow EXCEPT ![d] = i]
            /\ dpc' = [dpc EXCEPT ![d] = "claimed"]
            /\ UNCHANGED <<rideDate, known, epc, eprev, enew, edits, dread, announced>>

Resolve(d) == /\ dpc[d] = "claimed"
              /\ dread' = [dread EXCEPT ![d] = rideDate]
              /\ dpc' = [dpc EXCEPT ![d] = "resolved"]
              /\ UNCHANGED <<rideDate, known, rows, epc, eprev, enew, edits, drow, announced>>

FanOutCommit(d) ==
  /\ dpc[d] = "resolved"
  /\ LET i == drow[d] IN
     /\ rows[i].status = "PROCESSING"
     /\ ~rows[i].lock   \* FIX 3: the final UPDATE waits for an editor that marked the row dirty
     /\ IF FIX = 3 /\ rows[i].dirty
          THEN \* requeue, comparing next time with what riders were just told (or still believe)
               /\ known' = IF dread[d] # rows[i].prev THEN dread[d] ELSE known
               /\ announced' = IF dread[d] # rows[i].prev THEN (announced \/ dread[d] = rideDate) ELSE announced
               /\ rows' = [rows EXCEPT ![i].status = "PENDING", ![i].dirty = FALSE,
                                        ![i].prev = IF dread[d] # rows[i].prev THEN dread[d] ELSE rows[i].prev]
        ELSE IF dread[d] # rows[i].prev
          THEN /\ known' = dread[d]
               /\ announced' = (announced \/ dread[d] = rideDate)
               /\ rows' = [rows EXCEPT ![i].status = "DONE", ![i].key = "rel"]
          ELSE /\ known' = known /\ announced' = announced
               /\ rows' = [rows EXCEPT ![i].status = "SKIPPED", ![i].key = "rel"]
  /\ dpc' = [dpc EXCEPT ![d] = "idle"]
  /\ UNCHANGED <<rideDate, epc, eprev, enew, edits, drow, dread>>

\* a deploy kills the instance between claim and fan-out commit
Crash(d) == /\ dpc[d] \in {"claimed", "resolved"}
            /\ dpc' = [dpc EXCEPT ![d] = "dead"]
            /\ UNCHANGED <<rideDate, known, rows, epc, eprev, enew, edits, drow, dread, announced>>

\* recoverStuck: PROCESSING row nobody alive owns -> PENDING
Recover == /\ \E i \in 1..Len(rows) :
                /\ rows[i].status = "PROCESSING"
                /\ \A d \in Dispatchers : ~(dpc[d] \in {"claimed","resolved"} /\ drow[d] = i)
                /\ rows' = [rows EXCEPT ![i].status = "PENDING"]
           /\ UNCHANGED <<rideDate, known, epc, eprev, enew, edits, dpc, drow, dread, announced>>

Next == EBegin \/ EInsert \/ ECommit \/ Recover
        \/ \E d \in Dispatchers : Claim(d) \/ Resolve(d) \/ FanOutCommit(d) \/ Crash(d)

Spec == Init /\ [][Next]_vars

\* Once every edit is committed and the queue is drained, riders know the ride's real date.
Quiescent == /\ epc = "idle"
             /\ \A i \in 1..Len(rows) : rows[i].status \in {"DONE", "SKIPPED"}
             /\ \A d \in Dispatchers : dpc[d] # "claimed" /\ dpc[d] # "resolved"
RidersInformed == Quiescent => known = rideDate
\* Weaker: riders either already believe the current date, or were told it after it was set.
RidersToldCurrent == Quiescent => (known = rideDate \/ announced)

\* At most one live row holds the key (unique constraint).
UniqueKey == Cardinality(KeyHeld) <= 1
=============================================================================
