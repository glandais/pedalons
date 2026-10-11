------------------------------- MODULE DeliveryQueue -------------------------------
(*
  Stage 3 (per-channel sends) and the daily digest, two backend instances, each with its own
  Quarkus schedulers (tick, digests, recoverStuck run concurrently inside one instance too).

  Code modelled:
   - NotificationDeliveryService.sendDue (service/notification/NotificationDeliveryService.java:61-97):
     claim tx = lockDue (FOR UPDATE SKIP LOCKED, `not digest`) + markSending (attempts+1) — atomic,
     claims of two workers are disjoint; then send each message outside any tx and mark it (156-185).
   - NotificationDigestService.sendOne (service/notification/NotificationDigestService.java:257-290):
     claim all due digest rows of the recipient (lockDueDigest, SKIP LOCKED) + markSending; ONE e-mail;
     then mark every row SENT, or every row PENDING/FAILED on failure.
   - mark(): PENDING-with-cause -> FAILED if attempts >= max else PENDING (backoff); no check of the
     current status.
   - recoverStuck -> NotificationDeliveryRepository.resetStuck (repository/.../NotificationDeliveryRepository.java:234-248):
     SENDING with lastAttemptAt older than 15 min -> FAILED if attempts >= max, else PENDING.
     Modelled as: the owner crashed (CRASH), or, with SLOW, an owner still alive but slower than 15 min.
  The single recipient owns every digest row.
*)
EXTENDS Naturals, FiniteSets

CONSTANTS Rows, DigestRows, Instances, MaxAttempts, CRASH, SLOW

Workers == Instances \X {"send", "digest"}
NoW == <<"none", "none">>

VARIABLES st, att, owner, delivered, emails,   \* per row
          wpc, wbatch, wcur, wok, alive

vars == <<st, att, owner, delivered, emails, wpc, wbatch, wcur, wok, alive>>

Init == /\ st = [r \in Rows |-> "PENDING"] /\ att = [r \in Rows |-> 0]
        /\ owner = [r \in Rows |-> NoW] /\ delivered = [r \in Rows |-> 0] /\ emails = 0
        /\ wpc = [w \in Workers |-> "idle"] /\ wbatch = [w \in Workers |-> {}]
        /\ wcur = [w \in Workers |-> "none"] /\ wok = [w \in Workers |-> FALSE]
        /\ alive = [i \in Instances |-> TRUE]

Live(w) == alive[w[1]]
Kind(r) == IF r \in DigestRows THEN "digest" ELSE "send"

\* claim tx: SKIP LOCKED + markSending, committed together
Claim(w) == /\ Live(w) /\ wpc[w] = "idle"
            /\ LET due == {r \in Rows : st[r] = "PENDING" /\ Kind(r) = w[2]} IN
               /\ due # {}
               /\ \E b \in SUBSET due : /\ b # {}
                                        \* the digest claims every due row of the recipient
                                        /\ (w[2] = "digest" => b = due)
                                        /\ wbatch' = [wbatch EXCEPT ![w] = b]
                                        /\ st' = [r \in Rows |-> IF r \in b THEN "SENDING" ELSE st[r]]
                                        /\ att' = [r \in Rows |-> IF r \in b THEN att[r] + 1 ELSE att[r]]
                                        /\ owner' = [r \in Rows |-> IF r \in b THEN w ELSE owner[r]]
            /\ wpc' = [wpc EXCEPT ![w] = "claimed"]
            /\ UNCHANGED <<delivered, emails, wcur, wok, alive>>

\* ordinary sender: one provider call per row, outside any tx
SendOne(w) == /\ Live(w) /\ w[2] = "send" /\ wpc[w] = "claimed" /\ wbatch[w] # {}
              /\ \E r \in wbatch[w], ok \in BOOLEAN :
                   /\ wcur' = [wcur EXCEPT ![w] = r] /\ wok' = [wok EXCEPT ![w] = ok]
                   /\ delivered' = IF ok THEN [delivered EXCEPT ![r] = @ + 1] ELSE delivered
                   /\ wbatch' = [wbatch EXCEPT ![w] = @ \ {r}]
              /\ wpc' = [wpc EXCEPT ![w] = "sent"]
              /\ UNCHANGED <<st, att, owner, emails, alive>>

MarkRow(r, ok) ==
  IF ok THEN st' = [st EXCEPT ![r] = "SENT"]
  ELSE st' = [st EXCEPT ![r] = IF att[r] >= MaxAttempts THEN "FAILED" ELSE "PENDING"]

MarkOne(w) == /\ Live(w) /\ w[2] = "send" /\ wpc[w] = "sent"
              /\ MarkRow(wcur[w], wok[w])
              /\ wpc' = [wpc EXCEPT ![w] = IF wbatch[w] = {} THEN "idle" ELSE "claimed"]
              /\ UNCHANGED <<att, owner, delivered, emails, wbatch, wcur, wok, alive>>

\* digest: one e-mail for the whole claimed set
SendDigest(w) == /\ Live(w) /\ w[2] = "digest" /\ wpc[w] = "claimed"
                 /\ \E ok \in BOOLEAN :
                      /\ wok' = [wok EXCEPT ![w] = ok]
                      /\ delivered' = [r \in Rows |-> IF ok /\ r \in wbatch[w] THEN delivered[r] + 1 ELSE delivered[r]]
                      /\ emails' = IF ok THEN emails + 1 ELSE emails
                 /\ wpc' = [wpc EXCEPT ![w] = "marking"]
                 /\ UNCHANGED <<st, att, owner, wbatch, wcur, alive>>

\* each row marked in its own tx
MarkDigestRow(w) == /\ Live(w) /\ w[2] = "digest" /\ wpc[w] = "marking" /\ wbatch[w] # {}
                    /\ \E r \in wbatch[w] :
                         /\ MarkRow(r, wok[w])
                         /\ wbatch' = [wbatch EXCEPT ![w] = @ \ {r}]
                    /\ wpc' = [wpc EXCEPT ![w] = IF Cardinality(wbatch[w]) = 1 THEN "idle" ELSE "marking"]
                    /\ UNCHANGED <<att, owner, delivered, emails, wcur, wok, alive>>

Crash(i) == /\ CRASH /\ alive[i] /\ \E j \in Instances \ {i} : alive[j]
            /\ alive' = [alive EXCEPT ![i] = FALSE]
            /\ UNCHANGED <<st, att, owner, delivered, emails, wpc, wbatch, wcur, wok>>

\* resetStuck, any instance's recoverStuck
Recover(r) == /\ \E i \in Instances : alive[i]
              /\ st[r] = "SENDING"
              /\ (SLOW \/ ~alive[owner[r][1]])
              /\ st' = [st EXCEPT ![r] = IF att[r] >= MaxAttempts THEN "FAILED" ELSE "PENDING"]
              /\ UNCHANGED <<att, owner, delivered, emails, wpc, wbatch, wcur, wok, alive>>

Final == \A r \in Rows : st[r] \in {"SENT", "FAILED"}
Done == Final /\ UNCHANGED vars

Next == \/ \E w \in Workers : Claim(w) \/ SendOne(w) \/ MarkOne(w) \/ SendDigest(w) \/ MarkDigestRow(w)
        \/ \E i \in Instances : Crash(i)
        \/ \E r \in Rows : Recover(r)
        \/ Done

Spec == Init /\ [][Next]_vars

\* (a) a row reached once at most, without crash or a send slower than the stuck window
AtMostOnce == \A r \in Rows : delivered[r] <= 1
\* (b) never lost: SENT means it really left
SentMeansDelivered == \A r \in Rows : st[r] = "SENT" => delivered[r] >= 1
\* (c) FAILED only after every attempt was used
FailedOnlyAtCeiling == \A r \in Rows : st[r] = "FAILED" => att[r] >= MaxAttempts
\* (d) at the end, a row that was never delivered is FAILED, never silently dropped
NoSilentLoss == Final => \A r \in Rows : delivered[r] = 0 => st[r] = "FAILED"
=============================================================================
