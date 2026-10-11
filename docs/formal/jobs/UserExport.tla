---------------------------- MODULE UserExport ----------------------------
(* One user_exports row, processed by UserExportScheduler on one or two backend
   instances (rolling deploy). Faithful to UserExportService:
   - claim CAS PENDING->PROCESSING, attempts+1        (UserExportService.java:325-338, repo claim)
   - build + upload archive                            (:236-246)
   - markReady: READY, token hash, emailSentAt null    (:248, :373-386)
   - sendExportReady, may throw (EmailService rethrows) (:252, EmailService.java:146-157)
   - markEmailSent                                     (:253)
   - catch(Exception): markFailed -> PENDING/FAILED, storageKey null; safeDelete(storageKey)
                                                        (:255-259, :388-399)
   - retryPendingEmails, same tick, after processOne:  find READY & emailSentAt null (:270-279),
     rotate token if still READY (:286-298), send (:303), markEmailSent (:304)
   Fixed=TRUE models the documented intent: a mail failure leaves the row READY. *)
EXTENDS Naturals, FiniteSets

CONSTANTS Workers, MaxAttempts, MailCanFail, Fixed, MaxTok

VARIABLES status, attempts, stored, tokenRow, emailSent, nextTok,
          pc, myTok, mails, everReady

vars == <<status, attempts, stored, tokenRow, emailSent, nextTok, pc, myTok, mails, everReady>>

Init ==
  /\ status = "PENDING" /\ attempts = 0 /\ stored = FALSE
  /\ tokenRow = 0 /\ emailSent = FALSE /\ nextTok = 1
  /\ pc = [w \in Workers |-> "idle"] /\ myTok = [w \in Workers |-> 0]
  /\ mails = {} /\ everReady = FALSE

\* ---------------- processOnePendingExport ----------------
Claim(w) == /\ pc[w] = "idle" /\ status = "PENDING"
            /\ status' = "PROCESSING" /\ attempts' = attempts + 1
            /\ pc' = [pc EXCEPT ![w] = "claimed"]
            /\ UNCHANGED <<stored, tokenRow, emailSent, nextTok, myTok, mails, everReady>>

Upload(w) == /\ pc[w] = "claimed" /\ stored' = TRUE
             /\ pc' = [pc EXCEPT ![w] = "uploaded"]
             /\ UNCHANGED <<status, attempts, tokenRow, emailSent, nextTok, myTok, mails, everReady>>

MarkReady(w) == /\ pc[w] = "uploaded" /\ nextTok <= MaxTok
                /\ status' = "READY" /\ tokenRow' = nextTok /\ myTok' = [myTok EXCEPT ![w] = nextTok]
                /\ nextTok' = nextTok + 1 /\ emailSent' = FALSE /\ everReady' = TRUE
                /\ pc' = [pc EXCEPT ![w] = "ready"]
                /\ UNCHANGED <<attempts, stored, mails>>

SendOk(w) == /\ pc[w] = "ready" /\ mails' = mails \cup {myTok[w]}
             /\ pc' = [pc EXCEPT ![w] = "sent"]
             /\ UNCHANGED <<status, attempts, stored, tokenRow, emailSent, nextTok, myTok, everReady>>

SendFail(w) == /\ pc[w] = "ready" /\ MailCanFail
               /\ pc' = [pc EXCEPT ![w] = IF Fixed THEN "retry" ELSE "failed"]
               /\ UNCHANGED <<status, attempts, stored, tokenRow, emailSent, nextTok, myTok, mails, everReady>>

MarkEmailSent(w) == /\ pc[w] = "sent" /\ emailSent' = TRUE
                    /\ pc' = [pc EXCEPT ![w] = "retry"]
                    /\ UNCHANGED <<status, attempts, stored, tokenRow, nextTok, myTok, mails, everReady>>

\* catch (Exception e): markFailed + safeDelete(storageKey)
MarkFailed(w) == /\ pc[w] = "failed"
                 /\ status' = IF attempts >= MaxAttempts THEN "FAILED" ELSE "PENDING"
                 /\ stored' = FALSE
                 /\ pc' = [pc EXCEPT ![w] = "retry"]
                 /\ UNCHANGED <<attempts, tokenRow, emailSent, nextTok, myTok, mails, everReady>>

\* ---------------- retryPendingEmails (same tick, after processOne) ----------------
NothingToClaim(w) == /\ pc[w] = "idle" /\ status # "PENDING"
                     /\ pc' = [pc EXCEPT ![w] = "retry"]
                     /\ UNCHANGED <<status, attempts, stored, tokenRow, emailSent, nextTok, myTok, mails, everReady>>

RetryFind(w) == /\ pc[w] = "retry"
                /\ IF status = "READY" /\ ~emailSent
                     THEN pc' = [pc EXCEPT ![w] = "r_found"]
                     ELSE pc' = [pc EXCEPT ![w] = "idle"]
                /\ UNCHANGED <<status, attempts, stored, tokenRow, emailSent, nextTok, myTok, mails, everReady>>

RetryRotate(w) == /\ pc[w] = "r_found" /\ nextTok <= MaxTok
                  /\ IF status = "READY"
                       THEN /\ tokenRow' = nextTok /\ myTok' = [myTok EXCEPT ![w] = nextTok]
                            /\ nextTok' = nextTok + 1
                            /\ pc' = [pc EXCEPT ![w] = "r_rotated"]
                       ELSE /\ pc' = [pc EXCEPT ![w] = "idle"]
                            /\ UNCHANGED <<tokenRow, myTok, nextTok>>
                  /\ UNCHANGED <<status, attempts, stored, emailSent, mails, everReady>>

RetrySend(w) == /\ pc[w] = "r_rotated"
                /\ \/ /\ mails' = mails \cup {myTok[w]} /\ emailSent' = TRUE   \* send + markEmailSent
                   \/ /\ MailCanFail /\ UNCHANGED <<mails, emailSent>>          \* caught, logged
                /\ pc' = [pc EXCEPT ![w] = "idle"]
                /\ UNCHANGED <<status, attempts, stored, tokenRow, nextTok, myTok, everReady>>

Next == \E w \in Workers :
          \/ Claim(w) \/ Upload(w) \/ MarkReady(w) \/ SendOk(w) \/ SendFail(w)
          \/ MarkEmailSent(w) \/ MarkFailed(w) \/ NothingToClaim(w)
          \/ RetryFind(w) \/ RetryRotate(w) \/ RetrySend(w)

Spec == Init /\ [][Next]_vars

\* ---------------- properties ----------------
TypeOK == status \in {"PENDING","PROCESSING","READY","FAILED"}

\* A build that reached READY (archive stored, committed) is never thrown away.
GoodExportKept == everReady => (status = "READY" /\ stored)

\* Every "ready" e-mail the user received carries the live link, i.e. at most one e-mail and it works.
EveryMailedLinkWorks == \A t \in mails : t = tokenRow /\ status = "READY" /\ stored
==========================================================================
