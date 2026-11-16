---
id: LEGAL-12
title: "Purges des conservations sans borne"
status: done
done: 2026-09-29
---

## Livré

`LEGAL-12` **Purges des conservations sans borne** (2026-09-29) — nettoyage nocturne : codes
d'appairage et challenges WebAuthn expirés (`AuthCleanupScheduler`, 3 h), inscriptions bêta après
un an (`BetaSignupScheduler`, 3 h 45, `pedalons.beta.signups.retention-days`), demandes de
transfert biketeam un an après leur fin (`BiketeamMigrationRetentionScheduler`, 3 h 50,
`pedalons.biketeam.retention-days`) — fin = `finishedAt` des jobs `SUCCEEDED`/`FAILED`,
`grantExpiresAt` des `EXPIRED` ; jamais un `GRANTED`, `QUEUED` ou `RUNNING`, et
`biketeam_migration_map` n'est pas touchée (le rejeu en dépend). La purge biketeam tourne même
migration désactivée. §6 mis à jour, la phrase « pas encore couverts par un nettoyage » a disparu.
Tests : `AuthCleanupSchedulerTest.CleanupAbandonedPairingsAndChallenges`,
`BetaSignupSchedulerTest`, `BiketeamMigrationRetentionSchedulerTest`. Le chiffrement des
sauvegardes, relevé en chemin (hôte au domicile, copies en clair), est `OPS-13`.
