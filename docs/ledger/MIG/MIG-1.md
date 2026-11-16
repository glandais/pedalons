---
id: MIG-1
title: "Passage réel"
status: open
group: "Mise en production"
verified: 2026-11-16
---

## Reste à faire

`MIG-1` **Passage réel** : les secrets sont posés des deux côtés et les essais sont faits
(part livrée sous le même identifiant) ; reste la bascule de chaque équipe : une dernière
migration, puis le bouton « Basculer vers Pédalons » de son admin sur biketeam, qui enregistre
la table d'URL de la dernière migration réussie et redirige (`MIG-16` ; aucune bascule en
production au 16 novembre 2026 : `prendslaroue.fr/<équipe>` répond 200, sans redirection, pour
les cinq équipes migrées). **Avant** : déployer le retrait de `dryRun`/`reset`, Pédalons
d'abord, biketeam ensuite (plan §10, point 5) — fait côté Pédalons (production sur `3b8a0b8`,
API `15.0.0`, qui contient `MIG-16`) ; côté biketeam le commit est poussé, son déploiement
reste à confirmer. État de la production au 16 novembre 2026 : 22 migrations `SUCCEEDED`,
aucune en échec, pour cinq équipes — `n-peloton` (16, la dernière le 13 novembre, 7 286 lignes
dans `biketeam_migration_map`), `gaby` (3, 216 lignes), `kergravoul` (1, le 28 octobre,
1 297 lignes), `numa_benamer` (1, le 26 octobre, 99 lignes) et `hibroute` (1, le 27 octobre,
20 lignes). Pour chaque équipe qui a un domaine personnalisé chez biketeam, vérifier que
la redirection fonctionne : elle se règle au proxy, au cas par cas (plan §13, décision 11).

## Livré

`MIG-1` **Mise en production : secrets posés et essais faits** (11 au 15 octobre 2026, contrat inchangé) — Constaté à la relecture du 16 octobre 2026 (production sur `ac130fc5`). La migration en direct est
configurée des deux côtés en production : les variables `PEDALONS_BIKETEAM_*` (export depuis
`https://www.prendslaroue.fr`, secrets partagés) et `PEDALONS_MIGRATION_BIKETEAM_TEAM_ID` sont posées
sur `pedalons-prod_backend`, et le biketeam de production a déclenché ses jobs vers
`https://www.pedalons.fr`, ce qui suppose ses secrets posés aussi. Staging avait été exercé le
27 septembre 2026 (`ab`, `n-peloton`, `migration-test1`, dont une bascule réelle de
`migration-test1`). En production, six essais (`dryRun`) ont réussi (`SUCCEEDED` dans
`biketeam_migrations`) : `gaby` le 11 octobre, `n-peloton` les 11, 13, 14 et 15 octobre, dont un
`reset` le 15 ; `biketeam_migration_map` compte 216 lignes pour `gaby` et 7 195 pour `n-peloton`. Un
essai migre réellement dans Pédalons, sans bascule (plan §0) : les deux équipes existent donc en
production pendant que biketeam reste la source. Pas de test propre, c'est une étape
d'exploitation ; le code qu'elle exerce est couvert par `BiketeamLiveMigrationTest` et par la suite
e2e de la migration. **Reste ouvert sous le même identifiant** : le passage réel (`dryRun` décoché ;
aucun job réel en production au 16 octobre 2026) et la vérification, équipe par équipe, de la
redirection des domaines personnalisés.
