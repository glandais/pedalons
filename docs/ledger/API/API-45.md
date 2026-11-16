---
id: API-45
title: "Plus de jeton dans un chemin d'URL"
status: done
group: "Vie privée : les métadonnées retirées à l'import"
done: 2026-09-30
---

## Livré

`API-45` **Plus de jeton dans un chemin d'URL** (2026-09-30, **API 6.5.0**) — le masquage du
journal d'accès (`LEGAL-10`) ne porte que sur les paramètres de requête : deux jetons passaient
en clair, dans le chemin, pendant 14 jours.
- **Jeton FCM** : `POST /api/push-devices/unregister`, jeton dans le corps
  (`PushDeviceUnregistration`, `operationId` `unregisterPushDevice`) ; le web (`webPush.ts`) et
  le mobile (`PushDeviceRepository.unregister`) s'en servent.
- **Jeton d'export** : `GET /api/export/download?token=`, que Caddy masque (`token`). Le
  courriel et la redirection vers la connexion (`UserExportService.downloadPath`, seule source du
  lien) prennent cette forme. Pas d'en-tête : le lien s'ouvre depuis un client de messagerie, par
  une navigation.

Les anciennes formes restent servies et marquées `deprecated` au contrat
(`unregisterPushDeviceByPath`, `downloadDataExportByPath`) pour les builds mobiles installés et
les liens déjà envoyés : elles ont été retirées le 1er octobre 2026 en 10.0.0 (`API-56`). En chemin, deux fuites que le chemin masquait
aussi : sans session, le jeton d'export repart dans `/login?next=…`, et les ressources de cette
page le portent en `Referer` ; le snippet Caddy d'`OPERATIONS.md` les couvre désormais, appliqué
sur l'hôte le 30 septembre 2026 (`OPS-24`). Tests : `PushDeviceResourceTest`
(corps, ancienne forme encore servie, jeton vide refusé) et `UserExportResourceTest` (requête,
redirection, ancienne forme, jeton absent) — **écrits sans avoir été lancés** : `mvn test
-Dtest=PushDeviceResourceTest,UserExportResourceTest,UserExportServiceTest` ; e2e `pwa.e2e.ts`
(la déconnexion envoie le jeton dans le corps, pas dans l'URL) et `flow-account.e2e.ts` (lien du
courriel, aller-retour par la connexion) ; `mobile/check.sh` (684 tests).
