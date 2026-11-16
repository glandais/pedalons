---
id: OPS-7
title: "Journal d'accès Traefik coupé"
status: done
done: 2026-09-29
---

## Livré

`OPS-7` **Journal d'accès Traefik coupé** (2026-09-29, audit de février I13) — il n'était pas
persisté (pas de volume : il mourait avec le conteneur) et Traefik ne sait pas masquer un
paramètre de requête. `docker-compose.yml` passe `--accesslog=false` : le journal du Caddy de
l'hôte est le seul, et c'est lui que la politique décrit (`LEGAL-10`, application sur l'hôte :
`OPS-6`). Ne pas le rallumer sans filtre ni rotation : il redoublerait, en clair et sans borne,
ce que la politique promet de masquer. Pas de test (configuration).
