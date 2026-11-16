---
id: OPS-41
title: "Mesure d'audience du site : consigner la recette, puis relire au bout d'un mois"
status: open
size: "S"
group: "Exploitation"
verified: 2026-11-16
---

## Reste à faire

`OPS-41` **Mesure d'audience du site : consigner la recette, puis relire au bout d'un mois
(S)** — plan [`2026-10-15-web-analytics.md`](../../plans/2026-10-15-web-analytics.md) (§8, étapes
5 et 6 ; scindé d'`OPS-36`). Le déploiement et l'activation sont faits et constatés le
16 octobre 2026 (au ledger des livraisons sous le même identifiant). **Reste** :
- les vérifications de l'étape 6, à faire ou refaire et à **consigner dans `OPERATIONS.md`**,
  où rien n'est écrit : une visite sans DNT comptée sous son gabarit, la même sous DNT non ;
  aucune IP de visiteur dans le journal du conteneur ; aucune ligne `/count` dans le journal
  de Caddy, **bloc par bloc** — le Caddyfile de l'hôte en a neuf (clubs et alias), et seule
  la présence de `log_skip @count` est constatée, pas son effet sur chacun ; `store` sans
  session après un redémarrage ; une panne de base simulée sans ligne `hit =` dans Loki ; la
  purge de rétention passée le lendemain ; le tunnel SSH jusqu'au tableau de bord ;
- **confirmer par écrit la précondition du §5.3** — aucun membre réel n'avait accepté la
  politique précédente (comptes hors test et équipe, inscrits bêta, équipes migrées de
  biketeam, invitations acceptées) ; sinon l'e-mail du §11 à chaque membre. Aucune trace de
  cette vérification, alors que le compteur tourne déjà ;
- mettre à jour l'en-tête du plan, qui dit encore « Rien n'est en production » ;
- relire les chiffres contre les cinq questions du §1 du plan (prévu vers le 15 novembre 2026,
  pas fait au 16),
  puis l'archiver (`docs/plans/archive/`, avec sa ligne dans le README des archives).
Taille : S, surtout manuel sur l'hôte.

## Livré

`OPS-41` **GoatCounter tourne en prod et compte** (constaté le 2026-10-16, étapes 5 et 6 du §8
de [`2026-10-15-web-analytics.md`](../../plans/2026-10-15-web-analytics.md) ; contrat inchangé, le
drapeau est `API-117`) — le service livré par `OPS-36` est déployé : `pedalons-prod_goatcounter`
à 1/1, après deux tâches tombées sur `password authentication failed`, la boucle attendue avant
`scripts/goatcounter-init.sh db`. Le site est créé et réglé (`sites.settings` : `collect = 30`,
`data_retention = 730`), ce qui atteste aussi que le conteneur jetable de `site` a atteint la
tâche Swarm de postgres. Le `.env` de prod porte les clés `GOATCOUNTER_*` et
`PEDALONS_ANALYTICS_COUNT_PATH=/count`, que `/api/config` sert (`analytics.countPath`). En base :
`hits` vide, `store` sans ligne, `hit_counts` à 178 lignes pour 502 vues (dernière heure comptée :
16 octobre, 17:00). Caddy de l'hôte en v2.11.4, avec `@count path /count` et `log_skip @count`
dans le Caddyfile. Staging : `pedalons-staging_goatcounter` à 0/0 et aucune clé `GOATCOUNTER_*`.
La politique de `LEGAL-19` (« mesure d'audience ») est en ligne, datée du 15 octobre 2026. Pas
de test automatisé (infrastructure). **Scindé** : la consignation des vérifications de l'étape 6
dans `OPERATIONS.md` (DNT, journaux sans IP, `/count` absent de chaque bloc Caddy, panne
simulée, purge, tunnel), la preuve écrite de la précondition du §5.3, l'en-tête du plan et la
relecture des chiffres au bout d'un mois restent ouverts sous le même identifiant. **À ne pas
défaire** : ceux d'`OPS-36` — réglages posés avant l'activation, prod seulement, `/count` jamais
écrit dans le journal de Caddy.
