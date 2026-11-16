---
id: API-33
title: "`GET /api/rides` et listes mono-type"
status: out
---

## Écarté

| ID | Sujet | Décision | Ce que ça implique |
|---|---|---|---|
| `API-33` | **`GET /api/rides` et listes mono-type** | Non créées ; `/api/publications?type=RIDE` est la surface canonique | Deux surfaces = deux jeux de filtres à garder cohérents. `RideListResponse` / `TripListResponse` existent encore comme records retournés par **aucun endpoint** (schémas orphelins du contrat, que rien ne référence) : ils auraient pu partir avec l'une des MAJOR 9.0.0 à 15.0.0, et y sont encore au 16 novembre 2026. À supprimer avec la prochaine MAJOR, pas pour eux seuls |
