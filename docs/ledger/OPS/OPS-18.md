---
id: OPS-18
title: "Rotation des secrets exposés par les sauvegardes en clair"
status: out
---

## Écarté

| ID | Sujet | Décision | Ce que ça implique |
|---|---|---|---|
| `OPS-18` | **Rotation des secrets exposés par les sauvegardes en clair** (`ENCRYPTION_KEY`, clé JWT, compte de service FCM) | Non (décidé le 29 septembre 2026, avec `OPS-13`) | Les 30 copies antérieures à `OPS-13` les contenaient en clair sur l'hôte de sauvegarde. Rotation jugée disproportionnée : ces copies sont supprimées et le SSD trimé. Reste un résidu physique possible sur le SSD de l'hôte ; à rouvrir si le matériel est perdu ou volé |
