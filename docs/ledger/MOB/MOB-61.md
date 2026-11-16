---
id: MOB-61
title: "Recherche et tags des anciennes adresses du fil dans l'app"
status: out
---

## Écarté

| ID | Sujet | Décision | Ce que ça implique |
|---|---|---|---|
| `MOB-61` | **Recherche et tags des anciennes adresses du fil dans l'app** (`team?tab=publications&type=…&q=…&tags=…`) | Non (décidé le 11 octobre 2026 avec le propriétaire) | Aucune de ces anciennes adresses n'a été partagée : l'app garde le type et la période (`resolveTeamRootSection`, `agendaTarget` dans `team_sections.dart`) et ignore `q` et `tags`, que seul le site reporte (`teamLegacyRedirects.ts`). À rouvrir seulement si une telle adresse circule |
