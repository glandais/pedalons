---
id: OPS-42
title: "Envoi automatique des parcours : la recette sur appareil, faite après l'allumage"
status: open
size: "S"
group: "Exploitation"
verified: 2026-11-16
---

## Reste à faire

`OPS-42` **Envoi automatique des parcours : la recette sur appareil, faite après
l'allumage (S)** — `GPS_SYNC_ENABLED` est à `true` en prod et en staging depuis le 16 octobre
2026, avant la recette que le plan
[`2026-10-16-gps-route-autosync.md`](../../plans/2026-10-16-gps-route-autosync.md) prévoyait
(étape 7). Les premiers envois réels (3 connexions, 5 parcours, aucune erreur) établissent la
création chez les trois services ; reste à voir, sur un Karoo, un Edge et un ELEMNT, le
parcours arriver, changer avec sa route, disparaître après la sortie, à la désinscription, à
la désactivation et à la déconnexion, et l'état « à reconnecter » après une révocation chez
le service. Ce qui y est seulement supposé est sous `API-125`. Le drapeau est documenté
(« Automatic route sync to GPS services » dans `docs/OPERATIONS.md`) et la politique le
décrit (`LEGAL-21`).

## Livré

`OPS-42` **`GPS_SYNC_ENABLED` documenté** (2026-10-16, contrat inchangé) — le drapeau qui allume
l'envoi automatique des parcours (`API-120`) n'apparaissait que dans `.env.example`, alors qu'il
tourne en prod et en staging. `docs/OPERATIONS.md` a une section « Automatic route sync to GPS
services » : ce que fait la fonction, le planificateur (60 s) et le worker (20 s, bail de 5 min,
30 appels et 10 s par passage), la clé et son défaut, la fenêtre et la rétention qui ne sont pas
des clés d'`.env`, les journaux et les colonnes d'état (`sync_reconnect_required_at`,
`sync_paused_until`), et une requête de santé sur `gps_route_syncs`. Les commentaires
d'`application.properties` et d'`.env.example`, qui le disaient éteint, et le §12 du plan, qui
disait « rien de commité », sont corrigés. Pas de test (documentation). **À ne pas défaire** :
la doc dit que couper le drapeau **gèle** sans nettoyer — les parcours déjà envoyés restent chez
les services et ne sont plus retirés, contrairement à ce que promet la politique (`LEGAL-21`) ;
le couper durablement demande donc d'abord de retirer ces parcours ou de revoir la politique. La
recette sur appareil reste ouverte sous le même identifiant.
