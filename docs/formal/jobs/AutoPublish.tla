---------------------------- MODULE AutoPublish ----------------------------
(* PublicationPublishScheduler.autoPublishPublications on two backends (rolling deploy), against
   a user editing the draft (entity update, @Version) or publishing it by hand.
   - find DRAFT & publishAt<=now (AllPublicationRepository.java:34-40)
   - claimAutoPublish: update ... where id and version=read and status=DRAFT, version+1 (:48-59)
   - notification in the same transaction (PublicationPublishScheduler.java:58-71)
   - user: read (version v), then commit "update ... where version=v" -> version+1; may set
     status PUBLISHED itself (one notification from the user path) or move publishAt away. *)
EXTENDS Naturals

CONSTANTS Instances

VARIABLES status, ver, due, notifs, spc, sver, upc, uver

vars == <<status, ver, due, notifs, spc, sver, upc, uver>>

Init == /\ status = "DRAFT" /\ ver = 0 /\ due = TRUE /\ notifs = 0
        /\ spc = [i \in Instances |-> "idle"] /\ sver = [i \in Instances |-> 0]
        /\ upc = "idle" /\ uver = 0

SRead(i) == /\ spc[i] = "idle" /\ status = "DRAFT" /\ due
            /\ sver' = [sver EXCEPT ![i] = ver] /\ spc' = [spc EXCEPT ![i] = "read"]
            /\ UNCHANGED <<status, ver, due, notifs, upc, uver>>

\* claim + refresh + notify + commit (row lock held from the claim to the commit: atomic here)
SClaim(i) == /\ spc[i] = "read"
             /\ IF ver = sver[i] /\ status = "DRAFT"
                  THEN /\ status' = "PUBLISHED" /\ ver' = ver + 1 /\ notifs' = notifs + 1
                  ELSE UNCHANGED <<status, ver, notifs>>
             /\ spc' = [spc EXCEPT ![i] = "done"]
             /\ UNCHANGED <<due, sver, upc, uver>>

URead == /\ upc = "idle" /\ uver' = ver /\ upc' = "read"
         /\ UNCHANGED <<status, ver, due, notifs, spc, sver>>

\* save: publish by hand, or postpone publishAt; refused (409) on a stale version
UCommit == /\ upc = "read"
           /\ \/ /\ ver = uver /\ status = "DRAFT"
                 /\ \/ status' = "PUBLISHED" /\ notifs' = notifs + 1 /\ UNCHANGED due
                    \/ due' = FALSE /\ UNCHANGED <<status, notifs>>
                 /\ ver' = ver + 1
              \/ /\ ~(ver = uver /\ status = "DRAFT")
                 /\ UNCHANGED <<status, ver, due, notifs>>
           /\ upc' = "done"
           /\ UNCHANGED <<spc, sver, uver>>

Next == \/ \E i \in Instances : SRead(i) \/ SClaim(i)
        \/ URead \/ UCommit

Spec == Init /\ [][Next]_vars

OneNotification == notifs <= 1
PublishedOnlyIfDueOrByHand == notifs = (IF status = "PUBLISHED" THEN 1 ELSE 0)
==========================================================================
