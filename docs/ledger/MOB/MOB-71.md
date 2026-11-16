---
id: MOB-71
title: "Interrupteur « envoi automatique » par service GPS connecté (16 octobre 2026, contrat `11.5.0`)"
status: done
group: "Tableau de bord d'équipe"
done: 2026-10-16
---

## Livré

### `MOB-71` Interrupteur « envoi automatique » par service GPS connecté (16 octobre 2026, contrat `11.5.0`)

`MOB-71` **Chaque service GPS connecté porte l'interrupteur « Envoi automatique des parcours » et
son état** — suite mobile d'`API-120`, plan
[`2026-10-16-gps-route-autosync.md`](../../plans/2026-10-16-gps-route-autosync.md) §8. Dans
`GpsServicesCard` (`features/profile/presentation/widgets/connected_services_section.dart`), une
`PdlSettingRow` avec `PdlSwitch` (`keys.profile.gpsAutoSyncSwitch`) sous chaque service connecté,
l'état du serveur en sous-titre (`gpsAutoSyncStatus`), mise à jour optimiste puis la connexion
rendue par `setGpsAutoSync` écrite dans l'utilisateur courant (`authProvider.setUser`), retour
arrière et bandeau sur échec ; la confirmation de déconnexion annonce le retrait des parcours
envoyés. Sur `RECONNECT_REQUIRED`, un bouton « Reconnecter » (`keys.profile.gpsReconnect`)
relance l'autorisation sur la même connexion. L'interrupteur n'apparaît pas quand
`ConfigDto.gpsAutoSyncEnabled` est faux. `profile.gps.autoSync.*` en français et en anglais,
`profile.gps.hint` revu. Tests : `gps_services_card_test.dart` (interrupteur du seul service
connecté, optimisme et retour arrière, déconnexion, masqué si le déploiement n'envoie rien,
« Reconnecter », chaque phrase d'état). **À ne pas défaire** : la valeur affichée vient de
`UserDto.connectedServices`, jamais d'une copie locale ; la reconnexion ne passe pas par une
déconnexion, qui couperait l'interrupteur et effacerait le suivi ; la ligne « échec » ne promet
pas de nouvel essai (`MAX_ATTEMPTS`). Demande une republication de l'app.
