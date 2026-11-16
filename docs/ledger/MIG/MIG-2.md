---
id: MIG-2
title: "Redirections 302 → 301"
status: open
group: "Mise en production"
verified: 2026-11-16
---

## Reste à faire

`MIG-2` **Redirections 302 → 301** : une fois les bascules stabilisées, poser
`PEDALONS_REDIRECT_STATUS=301` côté biketeam. Pas avant : un 301 est mis en cache par les
navigateurs et ne se rattrape pas.
