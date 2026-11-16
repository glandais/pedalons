---
id: ISSUE-1
title: "Piles web illisibles"
status: open
verified: 2026-11-16
---

## Reste à faire

`ISSUE-1` **Piles web illisibles** : le bundle est minifié et l'empreinte ne garde que le nom
du chunk. L'option de build existe : `FRONTEND_SOURCEMAP` dans le `.env` de la stack, que
`build.sh` passe en `VITE_BUILD_SOURCEMAP`. Elle est à `true` sur staging comme en production
(relu le 16 novembre 2026), qui **servent** toutes deux leurs `.map` — assumé, le dépôt étant
public (`ISSUE-10`, écartée) : une pile lue dans le navigateur est donc déjà lisible. Reste :
automatiser la symbolisation côté serveur des piles remontées par les clients.
