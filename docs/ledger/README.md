# Le ledger : une entrée, un fichier

Ce répertoire porte tout ce qui reste à faire, tout ce qui a été livré depuis la v2 et tout ce qui a
été écarté exprès. Chaque entrée a un identifiant stable `PRÉFIXE-n` (`API-21`, `MOB-7`…) et son
propre fichier, `docs/ledger/<PRÉFIXE>/<ID>.md`. Les deux index
[`LEDGER_NEXT.md`](../LEDGER_NEXT.md) et [`LEDGER_DONE.md`](../LEDGER_DONE.md) sont **générés** à
partir de ces fichiers : une ligne par entrée, jamais modifiée à la main.

Rien ici ne bloque quoi que ce soit : la v2 est livrable en l'état, et chaque entrée ouverte supprime
une dégradation nommée plutôt que de réparer une panne.

## Où lire

| Question | Lire |
|---|---|
| Ce qui reste à faire, par domaine, et ce qui a été écarté | [`LEDGER_NEXT.md`](../LEDGER_NEXT.md) |
| Ce qui a été livré | [`LEDGER_DONE.md`](../LEDGER_DONE.md) |
| Une entrée précise | `docs/ledger/<PRÉFIXE>/<ID>.md` |
| Le contexte d'un domaine (recettes passées, tables d'audit, ce que les entrées supposent connu) | `docs/ledger/<PRÉFIXE>/README.md` |

## Une entrée

```markdown
---
id: WEB-139
title: "Aperçu de partage (OG/SSR) : la date disparaît dès qu'il y a une description"
status: open
size: "S"
group: "Heure de départ : audit du 7 novembre 2026"
verified: 2026-11-16
---

## Reste à faire

…

## Livré

…
```

`size` (XS, S, M, L) et `group` (un sous-titre dans l'index) sont facultatifs ; `verified` va avec une
entrée ouverte, `done` (la date de livraison) avec une entrée livrée. Pas de commentaire dans
l'en-tête : le script le lit ligne à ligne.

- `status: open` : il reste quelque chose à faire, décrit sous « Reste à faire ». Une entrée
  dont une part est livrée garde les deux sections dans le même fichier.
- `status: done` : tout est livré. « Livré » s'écrit au passé, avec la date, la version d'API si
  le contrat a changé, le test qui la couvre, et les décisions qu'il ne faut pas défaire.
- `status: out` : écartée exprès, avec son motif sous « Écarté ». À relire avant de rouvrir :
  plusieurs sont des invariants que le code garde. Rouverte, elle repasse à `open` sous le même
  identifiant.
- `verified` se met à jour chaque fois qu'on relit une entrée ouverte contre le code, qu'on la
  modifie ou non. `node scripts/ledger.mjs stale` liste celles qu'on n'a pas relues depuis
  trente jours.

## Les gestes

```bash
node scripts/ledger.mjs new API "Titre de l'entrée" --size S   # crée docs/ledger/API/API-<n>.md
node scripts/ledger.mjs next API                               # le prochain numéro libre, sans rien créer
node scripts/ledger.mjs index                                  # régénère LEDGER_NEXT.md et LEDGER_DONE.md
node scripts/ledger.mjs check                                  # ce que la CI vérifie
node scripts/ledger.mjs stale 30                               # entrées ouvertes non relues depuis 30 jours
```

- **Créer** : `new`, puis écrire sous « Reste à faire » la dégradation que l'entrée supprime et où
  elle vit dans le code. Un gros chantier a son plan dans `docs/plans/` et une entrée d'un
  paragraphe qui y renvoie.
- **Livrer** : dans le commit du travail, passer `status` à `done`, poser `done:`, retirer
  `verified:` et réécrire le texte au passé sous « Livré ». S'il reste une part ouverte, garder
  `status: open` et les deux sections ; une scission en deux sujets donne un numéro neuf à l'un
  des deux.
- **Écarter** : `status: out`, le motif sous « Écarté ». Jamais de suppression silencieuse.
- Dans tous les cas, finir par `node scripts/ledger.mjs index` et commiter les deux index avec.

## La nomenclature

- **L'identifiant ne change jamais.** Il suit l'entrée quand elle est reformulée, livrée ou
  écartée : c'est le nom de son fichier.
- **Un numéro ne sert qu'une fois.** Un numéro abandonné n'est pas recyclé, un fichier d'entrée ne
  se supprime pas.
- **Un renvoi cite l'identifiant seul** : « ledger `WEB-3` » dans une doc,
  `docs/LEDGER_*.md WEB-14` dans un commentaire de code. Cette seconde forme reste juste : les deux
  index nomment chaque identifiant et pointent vers son fichier. `grep -rn 'WEB-14'` retrouve
  l'entrée et tous ses renvois ; `check` refuse un renvoi de code vers un identifiant qui n'existe
  pas.
- **Le préfixe dit le domaine**, et le répertoire. Un préfixe nouveau s'ajoute à la table
  ci-dessous, qui fixe aussi l'ordre des sections des index ; un préfixe existant ne se renomme pas.

| Préfixe | Domaine |
|---|---|
| `MOB` | Application mobile (Flutter), dont la recette sur appareil |
| `WEB` | Site web (React, SSR), dont la suite e2e Playwright |
| `API` | Contrat d'API et backend |
| `OPS` | Exploitation, déploiement, recette du backend en conditions réelles |
| `NOTIF` | Notifications (in-app, e-mail, push, webhook d'équipe) |
| `MOD` | Modération et signalement de contenu |
| `ISSUE` | « Signaler un problème » et remontée des erreurs vers GitHub |
| `MIG` | Migration biketeam → Pédalons |
| `BRAND` | Charte, code couleur métier |
| `SEC` | Sécurité applicative, dont les suites de l'audit de septembre 2026 ([`plans/archive/2026-09-security-audit.md`](../plans/archive/2026-09-security-audit.md)) |
| `AUD` | Suivi de l'audit d'infrastructure de février ([`plans/2026-02-14-project-audit.md`](../plans/2026-02-14-project-audit.md)) |
| `LEGAL` | Politique de confidentialité, CGU, déclarations des stores |
| `BILL` | Monétisation : paliers, facturation Qonto, suivi des abonnements, droits par équipe ([`plans/2026-10-17-monetisation.md`](../plans/2026-10-17-monetisation.md)) |

Toute évolution d'API listée dans une entrée demande un bump de `pedalons.api.version` dans
`backend/src/main/resources/application.properties`, puis la régénération des deux clients
(compétence `contract-first-api`).

## Les autres sources

Le ledger ne couvre que les suites de la v2 et des chantiers qui l'ont suivie. D'autres sources
restent ouvertes :

- [`BACKLOG.md`](../BACKLOG.md) : la roadmap produit (P0 → Icebox), les idées qui n'ont pas encore
  d'entrée ici. Une idée qui reçoit un identifiant quitte ce fichier-là ; rien de livré n'y reste.
- [`plans/archive/`](../plans/archive/) : les plans exécutés, qui gardent le **pourquoi** détaillé
  des décisions ; [`plans/archive/audit-ux/BRIEF.md`](../plans/archive/audit-ux/BRIEF.md) est
  l'entrant de design de la v2.
- [`plans/2026-02-14-project-audit.md`](../plans/2026-02-14-project-audit.md) : audit
  d'infrastructure, CI/CD et qualité des modules. Ses lignes ouvertes sont suivies sous `AUD`.
- [`plans/archive/2026-09-security-audit.md`](../plans/archive/2026-09-security-audit.md) : audit de
  sécurité de septembre 2026, archivé le 9 octobre 2026 ; ses ouverts sont suivis sous `SEC`, qui
  fait foi.
- [`plans/2026-07-28-migration-vcyclist.md`](../plans/2026-07-28-migration-vcyclist.md) : gpx2web
  remplacé par vcyclist dans le backend, exécuté (fusionné le 14 octobre 2026) et déployé. Suivi
  sous `OPS-31` ; plan à archiver.
- [`plans/2026-07-25-privacy-improvement-opportunities.md`](../plans/2026-07-25-privacy-improvement-opportunities.md) :
  les options d'amélioration de la vie privée ; ce qui en reste ouvert, le chiffrement des jetons
  Karoo, est suivi sous `SEC-12`.

## D'où vient ce format

Jusqu'au 16 novembre 2026 le ledger tenait dans deux fichiers, `LEDGER_NEXT.md` et
`LEDGER_DONE.md`, de 200 Ko et 930 Ko. Les entrées y ont été relues une à une contre le code ce
jour-là (d'où le `verified` commun), puis découpées telles quelles : le texte d'une entrée est celui
qu'elle avait, tables d'audit comprises, et la prose qui les entourait est dans le `README.md` de
chaque préfixe.
