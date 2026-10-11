---------------------------- MODULE RefreshRotation ----------------------------
(* Refresh-token rotation with grace and replay detection, as implemented in
   backend/src/main/java/fr/pedalons/service/auth/RefreshTokenRotation.java:66-100
   and AuthSessionRepository.rotate (repository/auth/AuthSessionRepository.java:28-36).

   One session row: cur (refresh_token_hash), prev (previous_refresh_token_hash),
   rotAt (rotated_at), revoked.  A request is split into
     Read   : findByRefreshTokenHash / findByPreviousRefreshTokenHash   (RTR:69, 81-82)
              + grace check and revocation for the previous-token path (RTR:88-99)
     Rotate : the conditional bulk update  ... where refreshTokenHash = presented
              and revoked = false                                        (RTR:74, ASR:28-36)
     Respond: the HTTP answer, which the network may lose (client keeps its token,
              mobile auth_provider.dart:82-92 "keep the token so we can retry").
   Clients: the owner (tabs share one cookie / one secure-storage slot) and an
   optional thief holding a stolen copy of the owner's initial token.

   Fix = TRUE models a candidate fix: an in-grace answer for the previous token
   (and the 0-row rotate answer) carries the successor token instead of nothing
   (e.g. a deterministic successor HMAC(key, presented)).                         *)
EXTENDS Naturals, FiniteSets

CONSTANTS Thief,        \* is there a thief holding a copy of token 1?
          LoseResp,     \* may the network lose a response?
          MaxLoss,      \* how many responses may be lost
          Grace,        \* grace in ticks (60 s)
          MaxTime,      \* ticks (one tick ~ an access-token lifetime, 15 min > grace)
          MaxReqs,      \* total requests
          MaxInflight,  \* concurrent requests (tabs / retries)
          Fix,
          PromptRetry   \* a client whose response was lost retries before time moves on

None == 0

VARIABLES cur, prev, rotAt, revoked, now, nextTok,
          ownTok, ownOut, thiefTok, thiefRot,
          reqs, started, losses, pendingRetry, ownUnknown

vars == <<cur, prev, rotAt, revoked, now, nextTok, ownTok, ownOut, thiefTok,
          thiefRot, reqs, started, losses, pendingRetry, ownUnknown>>

Who == {"owner", "thief"}
Req == [who: Who, tok: Nat, st: {"start", "rotate", "resp"},
        outcome: {"none", "ROTATED", "IN_GRACE", "REPLAYED", "UNKNOWN"}, next: Nat]

Init ==
  /\ cur = 1 /\ prev = None /\ rotAt = 0 /\ revoked = FALSE
  /\ now = 0 /\ nextTok = 2
  /\ ownTok = 1 /\ ownOut = FALSE
  /\ thiefTok = IF Thief THEN 1 ELSE None
  /\ thiefRot = 0
  /\ reqs = {} /\ started = 0 /\ losses = 0 /\ pendingRetry = FALSE
  /\ ownUnknown = FALSE

\* A client sends a refresh with the token it holds.
Start(w) ==
  /\ started < MaxReqs
  /\ Cardinality(reqs) < MaxInflight
  /\ IF w = "owner" THEN ~ownOut ELSE thiefTok # None
  /\ LET t == IF w = "owner" THEN ownTok ELSE thiefTok
         r == [id |-> started, who |-> w, tok |-> t, st |-> "start", outcome |-> "none", next |-> None]
     IN /\ r \notin reqs
        /\ reqs' = reqs \cup {r}
  /\ started' = started + 1
  /\ pendingRetry' = IF w = "owner" THEN FALSE ELSE pendingRetry
  /\ UNCHANGED <<cur, prev, rotAt, revoked, now, nextTok, ownTok, ownOut, thiefTok,
                 thiefRot, losses, ownUnknown>>

Upd(r, f) == reqs' = (reqs \ {r}) \cup {f}

\* RTR:69-99 (reads see committed state: READ COMMITTED)
Read(r) ==
  /\ r.st = "start"
  /\ IF r.tok = cur /\ ~revoked THEN
        /\ Upd(r, [r EXCEPT !.st = "rotate"])                       \* RTR:70-73
        /\ UNCHANGED <<revoked>>
     ELSE IF r.tok = prev /\ ~revoked THEN
        IF now < rotAt + Grace THEN                                  \* RTR:89
          /\ Upd(r, [r EXCEPT !.st = "resp", !.outcome = "IN_GRACE",
                       !.next = IF Fix THEN cur ELSE None])          \* RTR:90-91
          /\ UNCHANGED <<revoked>>
        ELSE
          /\ revoked' = TRUE                                         \* RTR:97 (own txn)
          /\ Upd(r, [r EXCEPT !.st = "resp", !.outcome = "REPLAYED"])
     ELSE
        /\ Upd(r, [r EXCEPT !.st = "resp", !.outcome = "UNKNOWN"])   \* RTR:83-84
        /\ UNCHANGED <<revoked>>
  /\ UNCHANGED <<cur, prev, rotAt, now, nextTok, ownTok, ownOut, thiefTok, thiefRot,
                 started, losses, pendingRetry, ownUnknown>>

\* ASR:28-36: update ... where id=? and refreshTokenHash = presented and revoked = false
Rotate(r) ==
  /\ r.st = "rotate"
  /\ IF cur = r.tok /\ ~revoked THEN
        /\ cur' = nextTok /\ prev' = r.tok /\ rotAt' = now /\ nextTok' = nextTok + 1
        /\ Upd(r, [r EXCEPT !.st = "resp", !.outcome = "ROTATED", !.next = nextTok])
        /\ thiefRot' = IF r.who = "thief" THEN thiefRot + 1 ELSE thiefRot
     ELSE
        \* RTR:77-78: lost the race, IN_GRACE without a token
        /\ Upd(r, [r EXCEPT !.st = "resp", !.outcome = "IN_GRACE",
                     !.next = None])
        /\ UNCHANGED <<cur, prev, rotAt, nextTok, thiefRot>>
  /\ UNCHANGED <<revoked, now, ownTok, ownOut, thiefTok, started, losses, pendingRetry,
                 ownUnknown>>

Deliver(r) ==
  /\ r.st = "resp"
  /\ reqs' = reqs \ {r}
  /\ IF r.who = "owner" THEN
        /\ ownTok' = IF r.next # None THEN r.next ELSE ownTok
        \* REPLAYED: the session is revoked, the owner is signed out.  UNKNOWN (a token
        \* two rotations old, documented in SEC-27) only fails that request: the cookie /
        \* storage still holds the live token, so it is tracked apart (ownUnknown).
        /\ ownOut' = (ownOut \/ r.outcome = "REPLAYED")
        /\ ownUnknown' = (ownUnknown \/ r.outcome = "UNKNOWN")
        /\ UNCHANGED <<thiefTok>>
     ELSE
        /\ thiefTok' = IF r.outcome \in {"REPLAYED", "UNKNOWN"} THEN None
                       ELSE IF r.next # None THEN r.next ELSE thiefTok
        /\ UNCHANGED <<ownTok, ownOut, ownUnknown>>
  /\ UNCHANGED <<cur, prev, rotAt, revoked, now, nextTok, thiefRot, started, losses,
                 pendingRetry>>

\* The owner's response is lost: committed server side, the client keeps its token.
Lose(r) ==
  /\ LoseResp /\ losses < MaxLoss
  /\ r.st = "resp" /\ r.who = "owner"
  /\ reqs' = reqs \ {r}
  /\ losses' = losses + 1
  /\ pendingRetry' = TRUE
  /\ UNCHANGED <<cur, prev, rotAt, revoked, now, nextTok, ownTok, ownOut, thiefTok,
                 thiefRot, started, ownUnknown>>

Tick ==
  /\ now < MaxTime
  /\ ~(PromptRetry /\ pendingRetry)
  /\ reqs = {}   \* a request completes well within the grace (ticks are ~15 min)
  /\ now' = now + 1
  /\ UNCHANGED <<cur, prev, rotAt, revoked, nextTok, ownTok, ownOut, thiefTok, thiefRot,
                 reqs, started, losses, pendingRetry, ownUnknown>>

Next ==
  \/ \E w \in Who : Start(w)
  \/ \E r \in reqs : Read(r) \/ Rotate(r) \/ Deliver(r) \/ Lose(r)
  \/ Tick

Spec == Init /\ [][Next]_vars

TypeOK == cur \in Nat /\ prev \in Nat /\ revoked \in BOOLEAN

\* (P1) Without a thief, the owner is never logged out by the server.
NoSpuriousLogout == ~Thief => (~revoked /\ ~ownOut)
\* (P1b) documented SEC-27 limitation, checked separately: no 403 for the owner at all.
NoOwnerUnknown == ~Thief => ~ownUnknown

\* (P2) Theft is caught: the owner is never locked out while the thief still holds a
\*      live token -- except for the documented "token two rotations old is UNKNOWN"
\*      case (LEDGER_DONE SEC-27), which needs the thief to have rotated twice.
ThiefLive == thiefTok # None /\ ~revoked /\ thiefTok \in {cur, prev}
OwnerLocked == ownOut \/ (ownTok \notin {cur, prev}) \/ revoked
ThiefContained == (OwnerLocked /\ ThiefLive) => thiefRot >= 2

\* Same, without the documented exception (expected to fail -- documented behaviour).
ThiefContainedStrict == ~(OwnerLocked /\ ThiefLive)

\* (P3) Exactly one of two racing refreshes with the same token rotates.
AtMostOneRotationPerToken ==
  \A r1, r2 \in reqs : (r1 # r2 /\ r1.tok = r2.tok /\ r1.outcome = "ROTATED")
                        => r2.outcome # "ROTATED"
=============================================================================
