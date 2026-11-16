---
id: OPS-31
title: "Le cache de tuiles et le débit vers l'IGN et Mapterhorn tiennent"
status: done
done: 2026-10-16
---

## Livré

`OPS-31` **Le cache de tuiles et le débit vers l'IGN et Mapterhorn tiennent** (2026-10-16,
recette sur l'hôte, contrat inchangé ; §11 de
[`plans/2026-07-28-migration-vcyclist.md`](../../plans/2026-07-28-migration-vcyclist.md)) — la
récupération d'élévation devenue concurrente (10 tuiles en parallèle) puis l'IGN en premier
(`API-104`, MNT + MNS en zoom 15) faisaient craindre un ×10 vers `tiles.mapterhorn.com`, des 429
de `data.geopf.fr` et un disque qui se remplit. Constaté le 16 octobre : aucun 429 lié à
l'IGN, à Mapterhorn ou à l'élévation dans les journaux du backend de prod sur 72 h ; sous
`~/prod/data/cache`, `ign-lidar-hd-mnt` et `ign-lidar-hd-mns` pèsent 3,4 Go chacun et
`mapterhorn` 165 Mo ; disque à 15 % (131 Go sur 928). Pas de test automatisé (recette sur
l'hôte). Le cache IGN n'a ni plafond ni éviction : la veille manuelle est remplacée par une
tâche optionnelle d'alerte, `OPS-46`. **À ne pas défaire** : le rythme de 20 requêtes/s
vers l'IGN, commun à tout le processus (`API-105`).
