---
id: MOB-88
title: "Mode mono-équipe dans l'app"
status: out
---

## Écarté

| ID | Sujet | Décision | Ce que ça implique |
|---|---|---|---|
| `MOB-88` | **Mode mono-équipe dans l'app** (masquer l'onglet Équipes, ouvrir l'équipe épinglée, lire `pinnedTeamSlugProvider`) | Non (24 octobre 2026) | L'app ne sert que `pedalons.fr`, et ce domaine n'est jamais mono-équipe : le mode n'y a pas de cas d'usage. `pinnedTeamSlugProvider` (`core/config/config_provider.dart`) reste sans lecteur. Le web garde son `hideWhenSingleTeam`, qui sert les autres domaines. À rouvrir si l'app devait un jour servir un domaine mono-équipe |
