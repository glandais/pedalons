---
id: API-67
title: "« Mes équipes » d'un admin de plateforme"
status: out
---

## Écarté

| ID | Sujet | Décision | Ce que ça implique |
|---|---|---|---|
| `API-67` | **« Mes équipes » d'un admin de plateforme** | Comportement actuel gardé (décidé le 4 octobre 2026 avec le propriétaire) | `GET /api/teams?minRole=MEMBER` renvoie à un admin de plateforme toutes les équipes du domaine, qu'il voit donc toutes dans « Mes équipes » à l'accueil (web et mobile, `WEB-42`, `MOB-42`). Ne pas restreindre la requête à ses adhésions réelles sans rouvrir ce point |
