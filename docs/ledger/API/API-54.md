---
id: API-54
title: "exiftool pour retirer les métadonnées des images"
status: out
---

## Écarté

| ID | Sujet | Décision | Ce que ça implique |
|---|---|---|---|
| `API-54` | **exiftool pour retirer les métadonnées des images** | Écarté le 29 septembre 2026, après mesure sur un corpus synthétique (métadonnées marquées, pixels comparés) | exiftool (micro-service ou WASM) retire ce qu'il connaît au lieu de ne garder que ce qui est autorisé : il a laissé passer un chunk PNG privé et les octets après le trailer GIF, et refusé un WebP valide. Il ne nettoie pas les PDF, il a des CVE répétées (dont CVE-2026-7580, qui touche la 13.50) et il ajoute un conteneur. En WASM (zeroperl sur Chicory), sa sortie est identique mais il prend 17 à 19 s par image. imgproxy, écarté le même jour parce qu'il n'a pas de mode sans perte, a finalement été retenu : la perte d'un réencodage a été acceptée pour un code plus simple, qui ne laisse rien passer par construction et lit aussi HEIC, AVIF, TIFF et JPEG XL (`API-43`) |
