---
id: OPS-12
title: "Commentaire du cache gpx2web corrigé"
status: done
done: 2026-09-30
---

## Livré

`OPS-12` **Commentaire du cache gpx2web corrigé** (2026-09-30, scindé de `OPS-10`) —
`.env.example` disait encore que gpx2web écrit les tuiles directement à leur chemin final ; depuis
gpx2web 1.5.1 les tuiles de carte sont écrites puis renommées. Le commentaire le dit, et garde
l'interdiction de partager `DATA_CACHE_PATH` entre environnements tant que les tuiles d'élévation
ne sont pas revues (`OPS-10`, toujours ouvert) : ne pas la lever avant. Pas de test (commentaire).
