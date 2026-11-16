---
id: OPS-33
title: "Publier l'extension Karoo dans l'Extension Library de Hammerhead"
status: open
group: "Extension Karoo : catalogue Hammerhead"
kind: externe
verified: 2026-11-16
---

## Reste à faire

`OPS-33` **Publier l'extension Karoo dans l'Extension Library de Hammerhead** (scindé
d'`OPS-32`) — l'app ne s'installe aujourd'hui que par sideload. Créer le compte développeur
sur dashboard.hammerhead.io, y déclarer l'URL du manifest (la GitHub directe,
`releases/download/karoo-latest/manifest.json`, modifiable là-bas à tout moment), vérifier
que l'app apparaît dans l'Extension Library des Karoo liés au compte, puis la soumettre à SRAM
(accord de licence SDK, plusieurs semaines). Le processus est décrit dans `karoo/PUBLISH.md`.
Non vérifié à cette occasion : à quelle fréquence le Karoo relit le manifest, et s'il garde
le tag `navigation`, hors des quatre que documente karoo-ext. (S, surtout de l'attente)
