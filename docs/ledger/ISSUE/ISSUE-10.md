---
id: ISSUE-10
title: "Staging sert publiquement ses sourcemaps"
status: open
verified: 2026-11-16
---

## Reste à faire

`ISSUE-10` **Staging sert publiquement ses sourcemaps** — `FRONTEND_SOURCEMAP=true`
dans le `.env` de staging : le conteneur frontend contient 408 `.js.map`, servis en 200 sous
`/assets/` (constaté le 16 octobre 2026). Décider : les retirer de l'image servie et les
archiver à part (`ISSUE-1`), ou l'assumer, le dépôt étant public. Taille : XS.
