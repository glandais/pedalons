------------------------------ MODULE Throttle ------------------------------
(* AuthThrottle.checkPassword / recordPasswordFailure (AuthThrottle.java:76-90, 127-130)
   around AuthService.loginWithPassword (AuthService.java:423-450):
     Check : countSince(...) >= max -> 429                 (committed rows, no lock)
     Guess : bcrypt compare (the costly, guess-revealing step)
     Record: insert an auth_failures row in its own transaction (requiringNew)
   Several instances / worker threads; Fix = TRUE serialises Check..Record per subject.  *)
EXTENDS Naturals, FiniteSets
CONSTANTS Reqs, Max, Fix
VARIABLES failures, pc, guesses
vars == <<failures, pc, guesses>>
Init == failures = 0 /\ pc = [r \in Reqs |-> "check"] /\ guesses = 0
Busy(r) == Fix /\ \E q \in Reqs \ {r} : pc[q] = "record"
Check(r) == /\ pc[r] = "check" /\ ~Busy(r)
            /\ pc' = [pc EXCEPT ![r] = IF failures >= Max THEN "done" ELSE "record"]
            /\ guesses' = IF failures >= Max THEN guesses ELSE guesses + 1  \* bcrypt runs
            /\ UNCHANGED failures
Record(r) == /\ pc[r] = "record"
             /\ failures' = failures + 1 /\ pc' = [pc EXCEPT ![r] = "done"]
             /\ UNCHANGED guesses
Next == \E r \in Reqs : Check(r) \/ Record(r)
Spec == Init /\ [][Next]_vars
GuessBound == guesses <= Max
=============================================================================
