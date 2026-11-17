---
id: OPS-62
title: "Métriques du frontend SSR"
status: out
---

## Écarté

| ID | Sujet | Décision | Ce que ça implique |
|---|---|---|---|
| `OPS-62` | **Métriques du frontend SSR** (reliquat de `OPS-21`) : ni métriques Node (heap, boucle d'événements) ni temps de rendu par route | Non (décidé le 17 novembre 2026 avec le propriétaire) | Le frontend n'est vu que de l'extérieur : Caddy donne, par hôte, le débit, les 5xx et la latence (`HighErrorRate`, `SlowResponses`), cAdvisor sa mémoire (`ContainerNearMemoryLimit`, `OomKill`). Un rendu lent se voit donc dans la latence du site sans dire quelle route ; à rouvrir si `SlowResponses` se déclenche sans que le backend soit en cause |
