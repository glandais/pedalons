---
id: AUD-33
title: "Pagination des routes côté Karoo"
status: out
---

## Écarté

| ID | Sujet | Décision | Ce que ça implique |
|---|---|---|---|
| `AUD-33` | **Pagination des routes côté Karoo** (audit de février, K10, scindé d'`AUD-24`) | Non (16 octobre 2026) : bornée côté serveur à la place | `PedalonsApiClient.getRoutes` lit une seule page, mais `DeviceRouteService` plafonne la réponse à 20 sorties, 20 routes, 20 groupes et 20 étapes (`MAX_*_IN_RESPONSE`, commits `9f23df4d` et `007bdf3a`, `API-118`), pour tenir sous la limite de 100 Ko d'une réponse sur le Karoo — le risque que K10 nommait. À rouvrir si un écran de l'appareil doit montrer plus que ces plafonds |
