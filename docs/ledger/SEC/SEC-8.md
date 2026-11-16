---
id: SEC-8
title: "Le filtre de proximité des annonces mesure depuis la position floutée : M2"
status: done
done: 2026-09-30
---

## Livré

`SEC-8` **Le filtre de proximité des annonces mesure depuis la position floutée : M2**
(2026-09-30, **API 8.0.1**, patch : description d'`AdDto.locationGeometry` seulement, aucune migration) — la
décision `API-31` quantifiait la sonde et le rayon sur la grille du flou, mais le filtre mesurait
encore depuis la position **exacte** : chaque réponse coupait la cellule le long d'un cercle, et
des cercles de centres différents la découpaient plus fin qu'elle. `AdRepository` mesure
désormais depuis `coarse_location(te.locationGeometry)`, une fonction HQL
(`PedalonsFunctionContributor`) qui refait `CoarseLocation.blur` en SQL à partir des mêmes
constantes (`CoarseLocation.SQL_PATTERN`) ; la sonde et le rayon restent quantifiés. La réponse ne
dépend donc plus que de cellules publiées : deux annonces d'une même cellule reviennent toujours
ensemble. Choix de l'utilisateur : **le calcul dans la requête**, pas une colonne stockée (même
résultat, sans migration ni fenêtre de déploiement progressif). **Décisions** : aucun filtre, tri
ou calcul ne lit la position exacte d'une annonce hors de son édition ; toute modification de
`blur` se reporte dans `SQL_PATTERN`. Tests : `CoarseLocationSqlTest` (parité Java/SQL, pôles,
hémisphères, bords de cellule), `AdDetailsAndFiltersTest.list_withProximity_neverTellsApartTwoAdsOfTheSameCell`.
Le point annexe de l'audit, la position exacte servie aux admins par l'édition, est `SEC-26` (corrigé).
