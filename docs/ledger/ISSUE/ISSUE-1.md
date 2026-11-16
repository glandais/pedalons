---
id: ISSUE-1
title: "Piles web illisibles"
status: open
verified: 2026-11-16
---

## Reste à faire

`ISSUE-1` **Piles web illisibles** : le bundle est minifié et l'empreinte ne garde que le nom
du chunk. L'option de build existe : `FRONTEND_SOURCEMAP` dans le `.env` de la stack, que
`build.sh` passe en `VITE_BUILD_SOURCEMAP`. Elle est à `false` en production et à `true` sur
staging, qui **sert** aujourd'hui ses `.map` (voir `ISSUE-10`). Restent : ne pas
servir les `.map` mais les archiver avec l'image, l'activer en production, puis automatiser la
symbolisation côté serveur.
