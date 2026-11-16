---
id: API-69
title: "Résumé du profil en un appel (contrat `10.7.0`)"
status: done
group: "Vie privée : les métadonnées retirées à l'import"
done: 2026-10-04
---

## Livré

### `API-69` Résumé du profil en un appel (contrat `10.7.0`)

Livré le 4 octobre 2026 (10.6.0 → 10.7.0, mineur, rétrocompatible) : `GET
/api/users/me/profile-summary` (`getMyProfileSummary`, `Cache-Control: private, no-store`) rend un
`ProfileSummaryDto` — `participations` (`upcomingCount`, `pastCount`, `next` : 0 ou 1 sortie en vue
COMPACT), `teams` (slug, nom, rôle, équipes du domaine triées par nom), `passkeyCount`,
`pairedDevices`, `blockedUserCount` (comptes non supprimés), `notifications` (`channels` que le
serveur sait envoyer, `enabledChannels`, `emailDigest` à false sans `EMAIL`). Il nourrit les lignes
d'état de la vue d'ensemble du profil (`WEB-55`, `MOB-48`) avec `/me`. Avec lui :
`NotificationLinks.PREFERENCES_PATH` = `/profile/notifications` (lien des e-mails) et
`GpsConnectReturn.PROFILE` revient sur `/profile/devices` (enum inchangé). Tests :
`ProfileSummaryResourceTest` (compteurs, filtre de domaine, bloqués supprimés, e-mail coupé côté
serveur), `ProfileSummaryQueryCountTest`, `GpsResourceTest.handleCallback_withoutReturnTo_shouldRedirectToProfileDevices`,
helper `TestDataService.createPairedDevice` — verts le 4 octobre 2026 (`API-70`). **À ne pas
défaire** : chaque compteur reste une requête `count`, jamais le chargement de la liste ; la
prochaine sortie passe par `listMyParticipations` (taille 1, lookups par page) ; `teams` filtré
par domainId ; `emailDigest` à false quand `EMAIL` n'est pas disponible (le champ brut de
`NotificationPreferencesDto.emailDigest`, lui, ne l'est pas : les clients le masquent) ; les
préférences d'affichage, `contactableByMembers` et `connectedServices` restent dans `/me`, sans
doublon. Le compteur « à venir » est borné par `Instant.now()`, l'onglet web par
`hourAlignedNowIso()` : un écart d'au plus une heure est accepté.
