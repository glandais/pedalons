---------------------------- MODULE AssetCleanup ----------------------------
(* AssetCleanupScheduler (one @Transactional run, AssetCleanupScheduler.java:28-41) against a user
   saving content that attaches an asset uploaded > 1 day ago (AssetService.updateAssets ->
   addAssetToEntity/findAvailableAsset, AssetService.java:598-629; @Version on BaseEntity).
   - cleanup reads orphans: teamEntity is null and updatedAt < cutoff (AssetRepository.java:26-28)
   - for each, assetRepository.delete(asset) = em.remove -> @PreRemove AssetRemoveListener runs NOW
     and deletes the S3 object (AssetRemoveListener.java:17-25), long before the flush
   - flush at commit: DELETE ... where id=? and version=? ; 0 rows -> StaleObjectState -> rollback
   - user tx: find asset, check teamEntity null, set teamEntity, flush UPDATE ... version=?
   Several orphans: Assets; the user attaches one of them (Target). Instances: 1 or 2 cleanups.
   Fixed=TRUE: delete the stored file only after the row delete committed. *)
EXTENDS Naturals, FiniteSets

CONSTANTS Assets, Target, Cleaners, Fixed

VARIABLES row, ver, file, cpc, cset, cver, removed, upc, uver

vars == <<row, ver, file, cpc, cset, cver, removed, upc, uver>>

Init == /\ row = [a \in Assets |-> "orphan"] /\ ver = [a \in Assets |-> 0]
        /\ file = [a \in Assets |-> TRUE]
        /\ cpc = [c \in Cleaners |-> "idle"] /\ cset = [c \in Cleaners |-> {}]
        /\ cver = [c \in Cleaners |-> [a \in Assets |-> 0]]
        /\ removed = [c \in Cleaners |-> {}]
        /\ upc = "idle" /\ uver = 0

\* findOrphanedAssets: snapshot of the committed state
CRead(c) == /\ cpc[c] = "idle"
            /\ cset' = [cset EXCEPT ![c] = {a \in Assets : row[a] = "orphan"}]
            /\ cver' = [cver EXCEPT ![c] = ver]
            /\ cpc' = [cpc EXCEPT ![c] = "loop"]
            /\ UNCHANGED <<row, ver, file, removed, upc, uver>>

\* assetRepository.delete(asset): @PreRemove deletes the stored object immediately
CRemove(c) == /\ cpc[c] = "loop"
              /\ \E a \in cset[c] \ removed[c] :
                   /\ removed' = [removed EXCEPT ![c] = @ \cup {a}]
                   /\ file' = IF Fixed THEN file ELSE [file EXCEPT ![a] = FALSE]
              /\ UNCHANGED <<row, ver, cpc, cset, cver, upc, uver>>

\* commit: flush DELETE where id and version; any stale row -> whole transaction rolls back
CCommit(c) == /\ cpc[c] = "loop" /\ removed[c] = cset[c]
              /\ IF \A a \in cset[c] : row[a] # "gone" /\ ver[a] = cver[c][a]
                   THEN /\ row' = [a \in Assets |-> IF a \in cset[c] THEN "gone" ELSE row[a]]
                        /\ file' = IF Fixed THEN [a \in Assets |-> IF a \in cset[c] THEN FALSE ELSE file[a]]
                                   ELSE file
                   ELSE UNCHANGED <<row, file>>
              /\ cpc' = [cpc EXCEPT ![c] = "done"]
              /\ UNCHANGED <<ver, cset, cver, removed, upc, uver>>

\* user: findAvailableAsset (teamEntity null, same team) then commit with version check
URead == /\ upc = "idle" /\ row[Target] = "orphan"
         /\ uver' = ver[Target] /\ upc' = "read"
         /\ UNCHANGED <<row, ver, file, cpc, cset, cver, removed>>

UCommit == /\ upc = "read"
           /\ IF row[Target] = "orphan" /\ ver[Target] = uver
                THEN /\ row' = [row EXCEPT ![Target] = "attached"]
                     /\ ver' = [ver EXCEPT ![Target] = @ + 1]
                ELSE UNCHANGED <<row, ver>>      \* OptimisticLock / 400: save refused
           /\ upc' = "done"
           /\ UNCHANGED <<file, cpc, cset, cver, removed, uver>>

Next == \/ \E c \in Cleaners : CRead(c) \/ CRemove(c) \/ CCommit(c)
        \/ URead \/ UCommit

Spec == Init /\ [][Next]_vars

\* No live data deleted: an attached asset has its file
AttachedHasFile == \A a \in Assets : row[a] = "attached" => file[a]
\* No zombie: a row that survived (still orphan, still attachable) has its file
SurvivingOrphanHasFile == \A a \in Assets :
    (row[a] = "orphan" /\ (\A c \in Cleaners : cpc[c] # "loop")) => file[a]
==========================================================================
