---
id: OPS-39
title: "Mesure d'audience par les journaux d'accès"
status: out
---

## Écarté

| ID | Sujet | Décision | Ce que ça implique |
|---|---|---|---|
| `OPS-39` | **Mesure d'audience par les journaux d'accès** (GoAccess, `goatcounter import` des journaux Caddy) | Écartée le 15 octobre 2026 | Les journaux vivent sur l'hôte, hors dépôt ; ils ne voient que le premier chargement d'une page, pas les navigations côté client du routeur ; ils portent les chemins concrets (`/outils-gpx/{previewId}`, les slugs des sorties, parcours et pages), qu'il faudrait réécrire après coup au lieu de ne jamais les envoyer |
