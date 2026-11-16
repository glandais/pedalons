---
id: WEB-87
title: "Carte « Fusionner des fichiers » sur le hub des outils GPX"
status: done
group: "Outils GPX (repris de biketeam)"
done: 2026-10-15
---

## Livré

`WEB-87` **Carte « Fusionner des fichiers » sur le hub des outils GPX** (2026-10-15, avec le contrat `11.2.0` d'`API-112`) — `pages/gpxtool/GpxToolsPage.tsx` : sélection multiple de `.gpx`, envoyée dès le choix ; avec un seul fichier ou plus de dix, une notification et rien n'est envoyé ; sinon `mergePreviews({ gpxFiles })`, invalidation de « mes fichiers » et redirection vers la vue de l'aperçu fusionné. Les refus du serveur (`GPX_MERGE_FILE_COUNT`, `GPX_MERGE_TOO_MANY_TRACKS`, `FILE_TOO_LARGE`…) passent par `errors.api.*`, traduits en fr et en en. Test : `GpxToolsPage.test.tsx`. **À ne pas défaire** : aucun ordre ni sens à arranger côté client, c'est le serveur qui les choisit ; les bornes du client ne sont qu'un confort, le serveur les revérifie.
