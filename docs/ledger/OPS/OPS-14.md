---
id: OPS-14
title: "Recette des deux rattrapages de métadonnées"
status: done
done: 2026-10-06
---

## Livré

`OPS-14` **Recette des deux rattrapages de métadonnées** (2026-10-06) — en production :
`SELECT count(*) FROM assets WHERE metadata_pending` vaut 0 ; le marqueur
`maintenance/api-49-gpx-sanitized` est dans le bucket depuis le 1er octobre 2026 (04:15 UTC),
à côté de celui d'`api-44` ; dernier passage `GPX sanitization backfill: 28 file sets checked, 0
rewritten, 0 failed`. Aucun `left as is`, `cannot be re-encoded` ni `imgproxy cannot decode`
dans Loki depuis le 28 septembre : aucune pièce jointe ni image à supprimer ou convertir à la
main. Varnish a redémarré au déploiement du 6 octobre, il porte le `pass` des réencodages. La
phrase du §1 sur les photos antérieures (`API-43`, `API-44`) est donc vraie. Pas de test
automatisé (recette sur l'hôte).
