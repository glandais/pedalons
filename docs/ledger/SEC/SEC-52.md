---
id: SEC-52
title: "La clé de cloisonnement du moteur de parcours circule en clair sur le réseau partagé des piles, et le moteur…"
status: open
verified: 2026-11-16
---

## Reste à faire

| ID | Priorité (audit) | Audit | Sévérité | Constat |
|---|---|---|---|---|
| `SEC-52` | — | Lot 3b du générateur de parcours (16 novembre 2026) | Faible | La clé de cloisonnement du moteur de parcours circule en clair sur le réseau partagé des piles, et le moteur n'a pas de liste de clés admises : un conteneur de ce réseau peut l'appeler avec une clé à lui. Chiffrer le réseau ou configurer la liste du moteur (`docker-compose.shared.yml`) ; taille S |
