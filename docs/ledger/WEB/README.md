# WEB — Site web

Contexte des entrées `WEB-n` : la prose qui entourait ces entrées dans les deux anciens fichiers du
ledger. Les entrées elles-mêmes sont à côté, une par fichier ; leur liste est dans
[`LEDGER_NEXT.md`](../../LEDGER_NEXT.md) et [`LEDGER_DONE.md`](../../LEDGER_DONE.md).

## Reste à faire : contexte

La recette du web est automatisée par une suite Playwright depuis le 25 septembre 2026
(`WEB-13` à `WEB-22`, livrés, avec ce que l'automatisation ne voit pas) : voir
`frontend/e2e/README.md`.


### Heure de départ : audit du 7 novembre 2026

Pendant web de `MOB-111` à `MOB-116` ; la règle commune est `BRAND-8`.

### Couverture e2e — ce que l'audit du 27 septembre laisse ouvert

L'audit ([archivé](../../plans/archive/2026-09-27-e2e-coverage-audit.md), `WEB-26`) est exécuté : P0, P1
et P2 écrits, 54 défauts relevés, tous corrigés ou tranchés — le dernier, `WEB-6`, le 29 septembre. Le canal e-mail des
notifications n'a pas de test e2e : c'est `NOTIF-4`.

## Livré : contexte

### La recette web, automatisée

**Le web est automatisé depuis le 25 septembre 2026** par une suite Playwright qui tourne contre
l'application entière (SSR, backend, postgres, MinIO, mailpit) sur une base vide :
`scripts/e2e.sh up` puis `scripts/e2e.sh test`, voir `frontend/e2e/README.md`. Elle a trouvé onze
défauts, tous corrigés sauf un arbitré (la page d'équipe, `WEB-18`).

Chaque ligne est couverte par un fichier de `frontend/e2e/`, sur desktop et sur mobile (Pixel 7).
Ce qui reste hors de portée de l'automatisation est dit sous la ligne concernée : c'est ce qu'une
recette à la main aurait encore à regarder.











### Agenda et Publications

Plan [`2026-10-06-team-agenda.md`](../../plans/archive/2026-10-06-team-agenda.md) §4, §5 et §7.





### Navigation à deux niveaux : analyse du 24 octobre 2026 (contrat d'API inchangé)

L'existant a été comparé aux motifs de GitLab, Tines, Bitbucket, GitHub et Heja, à NN/g (fil
d'Ariane) et aux guides Apple HIG et Material 3. Il était conforme sur l'essentiel : niveau global
et niveau équipe séparés, fil d'Ariane hiérarchique, canonique et raccourci sous `sm`. Les écarts
relevés sont `WEB-111` à `WEB-114` et `MOB-87` à `MOB-90`. `MOB-88` et `MOB-89` sont dans
« Délibérément dehors », et `API-137` reste ouvert.
