---
id: LEGAL-10
title: "Journaux d'accès : 14 jours, sans coordonnées ni jetons en paramètres"
status: done
done: 2026-09-29
---

## Livré

`LEGAL-10` **Journaux d'accès : 14 jours, sans coordonnées ni jetons en paramètres** (2026-09-29)
— la politique (§1 « Données de session » et « Données de localisation », §6) le dit ; le journal
de Traefik est coupé (`OPS-7`), celui du Caddy de l'hôte est décrit dans
[`OPERATIONS.md`](../../OPERATIONS.md#access-logs) : `t`, `token`, `code`, `state` remplacés par
`REDACTED`, `lat`, `lon`, `nearLat`, `nearLon` supprimés, rotation par
`scripts/caddy-access.logrotate` (quotidienne, 13 fichiers + le courant = 14 jours).
Appliqué sur l'hôte le même jour (`OPS-6`).
Les jetons dans le **chemin** (push FCM, export) restent visibles : `API-45`. Ne pas remonter la
rotation au-delà de 14 jours sans changer le §6. Pas de test (configuration hors dépôt).
