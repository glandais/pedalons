---
id: API-89
title: "Fin stockée pendant le déploiement à chaud"
status: out
---

## Écarté

| ID | Sujet | Décision | Ce que ça implique |
|---|---|---|---|
| `API-89` | **Fin stockée pendant le déploiement à chaud** | Acceptée le 6 octobre 2026 (`API-85`) | Pendant la minute où l'ancien et le nouveau backend partagent la base, une sortie ou un voyage **modifié** par l'ancien garde sa fin précédente, non nulle, que le remplissage au démarrage (`PublicationEndBackfill`, lignes vides seulement) ne corrige pas ; seules les lignes **créées** par l'ancien profitent du repli départ + 3 h. Fenêtre d'une minute, corrigée au prochain enregistrement. À rouvrir si un déploiement long ou un retour arrière le rendait visible |
