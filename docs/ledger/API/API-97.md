---
id: API-97
title: "`AssetCleanupScheduler` ne supprime plus le fichier S3 avant le commit"
status: done
group: "Concurrence : constats de la modélisation formelle du 11 octobre 2026"
done: 2026-10-11
---

## Livré

`API-97` **`AssetCleanupScheduler` ne supprime plus le fichier S3 avant le commit** (2026-10-11, contrat inchangé, constat de la modélisation formelle TLA+/Lean) — `AssetRemoveListener` effaçait l'objet S3 dans `@PreRemove`, donc dès `em.remove()` et avant le flush. Pendant le balayage nocturne, une sauvegarde qui rattachait un asset orphelin committait, le DELETE versionné du balayage échouait (`OptimisticLockException`) et tout le lot était annulé. L'asset rattaché gardait sa ligne sans fichier (image cassée pour de bon), et chaque autre orphelin du lot restait une ligne sans fichier qu'une sauvegarde pouvait encore rattacher. Même chose pour tout rollback après un `orphanRemoval` ou dans `AccountErasureService`. Désormais le listener calcule la clé tout de suite, puis inscrit une `Synchronization` (`TransactionSynchronizationRegistry`) qui ne supprime le fichier qu'en `afterCompletion(STATUS_COMMITTED)`. Sans transaction JTA, la suppression reste immédiate ; une transaction déjà marquée pour rollback ne supprime rien. Couvert par `AssetCleanupPreCommitFileDeleteRaceTest` et, dans `AssetServiceTest`, par `shouldDeleteS3WhenAssetIsDeleted` (fichier présent jusqu'au commit), `shouldKeepS3WhenAssetDeleteRollsBack` et `shouldDeleteS3WhenOrphanRemoved`. **À ne pas défaire** : ne jamais supprimer un fichier de stockage depuis un callback JPA ou avant le commit de la transaction qui supprime sa ligne. Un fichier orphelin après un échec S3 vaut mieux qu'une ligne sans fichier.
