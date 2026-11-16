---
id: OPS-34
title: "Faire revalider la Search Console après `WEB-85`, `WEB-86` et `API-109`"
status: open
group: "Exploitation"
kind: externe
verified: 2026-11-16
---

## Reste à faire

`OPS-34` **Faire revalider la Search Console après `WEB-85`, `WEB-86` et `API-109`** — le
rapport du 15 octobre 2026 sur pedalons.fr listait 122 URL non indexées. Les trois entrées
sont en production, et les vérifications à la main sont faites le 16 octobre :
`https://pedalons.fr/robots.txt` (redirigé vers www) porte les `Allow` d'images et la ligne
`Sitemap`, une page servie sous `/teams/…` a son `<link rel="canonical">` vers `/equipes`, et
`/api/version` répond `X-Robots-Tag: noindex`. **Reste** : dans la Search Console, cliquer
« Valider la correction » sur les motifs « Introuvable (404) », « Page en double sans URL
canonique sélectionnée par l'utilisateur » et « Explorée, actuellement non indexée », puis
revenir sur le rapport quelques semaines plus tard. Le 404 d'`auth.pedalons.fr` est traité à
part (`OPS-47`). Taille : XS (surtout de l'attente).
