---
id: WEB-91
title: "Statistiques d'audience pour les admins de club"
status: out
---

## Écarté

| ID | Sujet | Décision | Ce que ça implique |
|---|---|---|---|
| `WEB-91` | **Statistiques d'audience pour les admins de club** | Non : tableau de bord pour le seul responsable du traitement, par tunnel SSH (décidé le 15 octobre 2026, plan §7) | La condition 1 de l'exemption CNIL limite la finalité à l'éditeur ; il n'y a qu'un site GoatCounter pour tous les hôtes, si bien qu'il faudrait soit un site par domaine, soit une page Pédalons qui lirait l'API de GoatCounter (aujourd'hui sans jeton) en filtrant par hôte et par slug ; et sur une petite équipe privée, un admin qui connaît ses membres pourrait rapprocher une page vue d'une personne. À rouvrir sur une demande réelle, après relecture de la condition 1 |
