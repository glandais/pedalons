---
id: SEC-10
title: "L'expression régulière des directives d'image est linéaire"
status: done
done: 2026-09-30
---

## Livré

`SEC-10` **L'expression régulière des directives d'image est linéaire** (2026-09-30, audit M6,
contrat inchangé) — `AssetService` repérait les `::asset{…}` du markdown, à chaque enregistrement
d'un contenu, par un motif qui cherchait `id="…"` entre deux suites gourmandes : sur une suite de
directives non fermées, son temps croissait au cube de la longueur (mesuré : 7 Ko, 0,9 s ; 14 Ko,
7,4 s ; 28 Ko, 78 s de CPU par requête). Le motif est désormais possessif et arrêté par une
accolade ouvrante comme par la fermante (`::asset\{([^{}]*+)\}`), l'`id` étant lu à part dans
les attributs — le dernier, comme avant. 280 Ko piégés : 12 ms. Même garde sur le motif
d'`MarkdownExcerpt`, qui était quadratique. Ne pas revenir à un motif qui cherche l'attribut dans
la directive d'un seul tenant. Reste la borne de taille du markdown : `SEC-19`. Test :
`AssetMarkdownDirectiveTest` (identifiants lus, directive non fermée ignorée, dernier `id` gardé,
entrée piège sous 2 s) — **écrit sans avoir été lancé** (`mvn test
-Dtest=AssetMarkdownDirectiveTest,MarkdownExcerptTest`) ; la logique a été vérifiée à la main
sur les classes compilées.
