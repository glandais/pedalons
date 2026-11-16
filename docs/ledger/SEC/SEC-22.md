---
id: SEC-22
title: "Recherches sans jokers, nom de fichier d'appareil sûr : L12 et L13"
status: done
done: 2026-09-30
---

## Livré

`SEC-22` **Recherches sans jokers, nom de fichier d'appareil sûr : L12 et L13** (2026-09-30,
contrat inchangé, scindé de `SEC-12`) — **L12** : les cinq recherches qui bâtissaient un motif
`LIKE` à partir de la saisie (`SearchClause`, donc publications, annonces, parcours… ;
trombinoscope, lieux, gabarits de sortie, comptes de l'admin plateforme) passent par
`LikePatterns.contains`, qui échappe `%`, `_` et le caractère d'échappement lui-même avec `!`,
déclaré par `escape '!'` (`LikePatterns.ESCAPE`) dans chaque clause. `%` renvoyait tout, `_`
n'importe quel caractère. **Ne pas compter sur l'échappement par défaut de PostgreSQL** (la barre
oblique inverse) : essayé d'abord, il n'est pas en vigueur dans le SQL que génère Hibernate — un
`%` littéral n'était plus trouvé du tout. Toute nouvelle clause qui prend un motif de
`LikePatterns` doit porter `ESCAPE`. **L13** : `DeviceRoutesResource` construit le nom du fichier
FIT/GPX de `Content-Disposition` à partir du slug de l'URL ; il est ramené à `[a-zA-Z0-9._-]`
(un vrai slug n'y perd rien). Test : `search-wildcards.e2e.ts` (vu échouer avant le correctif :
`%` et `_` sur le trombinoscope, `_` et `100%` sur les publications, recherche ordinaire
intacte) ; les suites de listes, filtres, pagination, trombinoscope, admin plateforme et
appareils passent (169 tests). L13 n'a pas de test dédié.
