---
id: API-52
title: "Durcir `ImageMetadataStripper`"
status: out
---

## Écarté

| ID | Sujet | Décision | Ce que ça implique |
|---|---|---|---|
| `API-52` | **Durcir `ImageMetadataStripper`** | Sans objet depuis le 29 septembre 2026 | Le nettoyeur maison sans perte a été supprimé : le stockage fait réencoder chaque image par imgproxy (`API-43`), qui n'écrit que les pixels. Ne pas le réintroduire pour gagner la qualité perdue : c'est lui dont les branches gardaient par défaut ce qu'elles ne connaissaient pas |
