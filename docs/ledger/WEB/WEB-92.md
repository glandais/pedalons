---
id: WEB-92
title: "Interrupteur « envoi automatique » par service GPS connecté (16 octobre 2026, contrat `11.5.0`)"
status: done
group: "Mesure d'audience du site"
done: 2026-10-16
---

## Livré

### `WEB-92` Interrupteur « envoi automatique » par service GPS connecté (16 octobre 2026, contrat `11.5.0`)

`WEB-92` **Chaque service GPS connecté porte l'interrupteur d'envoi automatique et son état** —
suite web d'`API-120`, plan
[`2026-10-16-gps-route-autosync.md`](../../plans/2026-10-16-gps-route-autosync.md) §7. Dans
`components/profile/GpsConnectionsManager.tsx`, un `Switch` par service connecté (mutation
générée `useSetGpsAutoSync`, `hooks/useGpsConnections.ts`), l'état d'après `autoSyncState`
(« À jour · N parcours », envoi en cours, échec, reconnexion nécessaire avec un bouton
« Reconnecter » qui relance l'OAuth), une phrase de plus dans la confirmation de déconnexion ;
rien quand `ConfigDto.gpsAutoSyncEnabled` est faux (`isGpsAutoSyncEnabled`, `config/appConfig.ts`).
Clés `gps.autoSync.*` en français et en anglais, `gps.description` et `profileStatus.ts` revus.
Tests vitest : `GpsConnectionsManager.test.tsx` (interrupteur du seul service connecté, mutation,
chaque état, masqué si le déploiement n'envoie rien), `profileStatus.test.ts`. **À ne pas
défaire** : la reconnexion relance l'OAuth sur la connexion existante, jamais une déconnexion ; la
phrase d'échec ne promet pas de nouvel essai automatique.
