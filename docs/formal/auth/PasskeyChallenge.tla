--------------------------- MODULE PasskeyChallenge ---------------------------
(* PasskeyService.verifyAuthentication (PasskeyService.java:292-395), the single use of an
   AUTHENTICATION challenge, under two concurrent submissions of the same assertion
   (client retry, double submit, or a replayed captured assertion).
     Find   : findValidByChallenge (WebAuthnChallengeRepository:276-279), outer tx, no lock
     Delete : QuarkusTransaction.requiringNew().run(() -> deleteById(id))  (343)
              Panache deleteById = findById; if null return false; else em.remove (flush:
              DELETE WHERE id=?, 0 rows -> StaleObjectStateException -> caught at 391 -> 403).
              The boolean result is ignored.
     Verify : webauthn4j verify, then a session is created (AuthService.java:555-556).
   Fix = TRUE: proceed only when deleteById returned true (and the delete hit a row).   *)
EXTENDS Naturals, FiniteSets
CONSTANTS Reqs, Fix
VARIABLES exists, pc, sessions
vars == <<exists, pc, sessions>>
Init == exists = TRUE /\ pc = [r \in Reqs |-> "find"] /\ sessions = 0
Find(r) == /\ pc[r] = "find"
           /\ pc' = [pc EXCEPT ![r] = IF exists THEN "del" ELSE "done"]
           /\ UNCHANGED <<exists, sessions>>
\* findById inside the new transaction
Del(r) == /\ pc[r] = "del"
          /\ IF exists
               THEN exists' = FALSE /\ pc' = [pc EXCEPT ![r] = "verify"]
               ELSE UNCHANGED exists /\ pc' = [pc EXCEPT ![r] = IF Fix THEN "done" ELSE "verify"]
          /\ UNCHANGED sessions
Verify(r) == /\ pc[r] = "verify"
             /\ sessions' = sessions + 1 /\ pc' = [pc EXCEPT ![r] = "done"]
             /\ UNCHANGED exists
Next == \E r \in Reqs : Find(r) \/ Del(r) \/ Verify(r)
Spec == Init /\ [][Next]_vars
SingleUse == sessions <= 1
===============================================================================
