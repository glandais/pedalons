------------------------------ MODULE OtpVerify ------------------------------
(* AuthService.verifyOtp (AuthService.java:383-416) on one login OTP row.
   The row is an AuthToken entity: no @Version, no @DynamicUpdate (AuthToken.java:13-100),
   so the change made by recordFailedAttempt / markUsed is flushed at commit as a
   whole-row  UPDATE auth_tokens SET failed_attempts=?, used_at=?, ... WHERE id=?
   computed from the snapshot read by findValidByEmailAndType (AuthTokenRepository:222-231),
   a plain SELECT (no lock), READ COMMITTED.  The transaction commits even on the
   wrong-code BadRequestException (dontRollbackOn, AuthService.java:383).
   Fix = TRUE: the read is SELECT ... FOR UPDATE (or an atomic conditional increment),
   i.e. read-check-write is serialised per row.                                     *)
EXTENDS Naturals, FiniteSets

CONSTANTS Attackers,   \* concurrent wrong-guess requests (ids)
          MaxVerify,   \* pedalons.auth.otp.max-verify-attempts (5)
          Legit,       \* does the owner also submit the right code concurrently?
          Fix

VARIABLES failed, used,         \* committed row
          pc, snap,             \* per request: "idle" | "read" | "done", snapshot
          guesses,              \* wrong codes actually compared against the hash
          loggedIn              \* the owner's correct code has been accepted

Reqs == Attackers \cup (IF Legit THEN {"owner"} ELSE {})
vars == <<failed, used, pc, snap, guesses, loggedIn>>

Init == /\ failed = 0 /\ used = FALSE
        /\ pc = [r \in Reqs |-> "idle"]
        /\ snap = [r \in Reqs |-> [failed |-> 0, used |-> FALSE]]
        /\ guesses = 0 /\ loggedIn = FALSE

Lock == Fix /\ \E q \in Reqs : pc[q] = "read"    \* FOR UPDATE held until commit

\* AuthService.java:388-395: findValidByEmailAndType (used_at is null), else TOKEN_INVALID
Read(r) ==
  /\ pc[r] = "idle"
  /\ ~Lock
  /\ IF used
       THEN /\ pc' = [pc EXCEPT ![r] = "done"]        \* no valid code: nothing compared
            /\ UNCHANGED snap
       ELSE /\ pc' = [pc EXCEPT ![r] = "read"]
            /\ snap' = [snap EXCEPT ![r] = [failed |-> failed, used |-> used]]
  /\ UNCHANGED <<failed, used, guesses, loggedIn>>

\* AuthService.java:398-406 + commit (whole-row update from the snapshot)
Commit(r) ==
  /\ pc[r] = "read"
  /\ pc' = [pc EXCEPT ![r] = "done"]
  /\ IF r = "owner"
       THEN /\ used' = TRUE                               \* markUsed (406)
            /\ failed' = snap[r].failed                   \* stale column rewritten
            /\ loggedIn' = TRUE
            /\ UNCHANGED guesses
       ELSE /\ guesses' = guesses + 1                     \* a wrong code compared (398-400)
            /\ failed' = snap[r].failed + 1               \* recordFailedAttempt (AuthToken:95-100)
            /\ used' = (snap[r].failed + 1 >= MaxVerify) \/ snap[r].used
            /\ UNCHANGED loggedIn
  /\ UNCHANGED snap

Next == \E r \in Reqs : Read(r) \/ Commit(r)
Spec == Init /\ [][Next]_vars

\* A code is compared against at most MaxVerify wrong guesses.
GuessBound == guesses <= MaxVerify
\* Once the owner signed in with it, the code stays spent.
NoResurrection == loggedIn => used
\* The failure counter never goes backwards past an evaluated guess.
CounterSound == failed >= 0
\* Burn sticks: a code burnt by MaxVerify misses is never valid again.
BurnSticks == (failed >= MaxVerify) => used
GuessBoundX(k) == guesses <= k
GuessBound2x == guesses <= 2 * MaxVerify
\* A spent / burnt code never becomes valid again (action property).
SpentStaysSpent == [][used => used']_vars
==============================================================================
