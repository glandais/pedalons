---
id: API-19
title: "`GET /api/search?q&types=&limit` unifié"
status: out
group: "Petites évolutions d'API qui suppriment chacune une dégradation nommée"
---

## Écarté

| ID | Sujet | Décision | Ce que ça implique |
|---|---|---|---|
| `API-19` | **`GET /api/search?q&types=&limit` unifié** (né de la suppression de `GET /api/users/search` en `3.0.0`, `API-39`) | Non (décidé le 17 novembre 2026 avec le propriétaire) | Aucun écran ne l'appelle : la recherche passe par chaque liste, qui a son paramètre `search` — `GET /api/publications` (sorties, publications et voyages de toutes les équipes accessibles), `GET /api/teams`, les annonces, les parcours, les sorties, les modèles, les lieux, le trombinoscope d'une équipe. Une recherche de personnes hors de ses équipes est exclue par `API-144` (les noms de membres n'atteignent jamais un non-membre). À rouvrir avec une barre de recherche globale dessinée pour le site et l'app ; les recherches actuelles sont des `lower(…) like`, sans `unaccent` ni `pg_trgm` |
