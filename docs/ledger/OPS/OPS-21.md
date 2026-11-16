---
id: OPS-21
title: "Ce que le monitoring ne voit pas encore"
status: open
group: "Exploitation"
verified: 2026-11-16
---

## Reste à faire

`OPS-21` **Ce que le monitoring ne voit pas encore** — PostgreSQL (connexions, taille, bloat,
requêtes lentes : un `postgres_exporter` par environnement, sur `pedalons-shared`), le
frontend SSR (ni métriques Node ni temps de rendu : seul Caddy le voit, par hôte), et les
erreurs côté client web et mobile (un GlitchTip, compatible Sentry, pèserait une base et un
Redis de plus : à ne faire que si le besoin se confirme). Taille : M.
