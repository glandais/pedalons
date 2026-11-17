---
id: OPS-34
title: "Faire revalider la Search Console après `WEB-85`, `WEB-86` et `API-109`"
status: open
group: "Exploitation"
kind: externe
verified: 2026-11-17
---

## Reste à faire

`OPS-34` **Faire revalider la Search Console après `WEB-85`, `WEB-86` et `API-109`** — le
rapport du 15 octobre 2026 sur pedalons.fr listait 122 URL non indexées. Les trois entrées
sont en production, et les vérifications à la main sont faites le 16 octobre :
`https://pedalons.fr/robots.txt` (redirigé vers www) porte les `Allow` d'images et la ligne
`Sitemap`, une page servie sous `/teams/…` a son `<link rel="canonical">` vers `/equipes`, et
`/api/version` répond `X-Robots-Tag: noindex`. **Validations lancées le 17 novembre 2026** sur les trois motifs (« Commencé » dans le
rapport du 13 novembre : 2,16 k pages indexées, 2,57 k non indexées dont 1 934 bloquées exprès par
`robots.txt`). **Reste** : revenir sur le rapport début décembre et lire l'issue de chaque
validation. Attendu :
- **Introuvable (404)**, 44 pages : surtout des gabarits `…/images/…/{size}` explorés avant le
  13 octobre, désormais interdits par `robots.txt` (le gabarit figure toujours dans l'état JSON du
  SSR) ; les pages d'une équipe « test » supprimée (`/equipes/test`, `/teams/test/rides/…`)
  resteront en 404, à bon droit — un échec de validation sur elles n'appelle rien.
- **Page en double sans URL canonique**, 5 pages : des GPX sous `/api/download/…` (interdits et
  `noindex`) et `/forgot-password` (`noindex`) ; devrait passer.
- **Explorée, actuellement non indexée**, 268 pages et en hausse : un choix de Google sur les
  sous-pages de n-peloton (pages de groupe `/sorties/…/groupes/…`, parcours, `/carte`), pas un défaut
  technique ; la validation n'y changera probablement rien. Le levier, un `noindex` ou une
  canonique vers la sortie ou le parcours pour ces sous-pages, serait une décision à part.

Le 404 d'`auth.pedalons.fr` est traité à part (`OPS-47`). Taille : XS (surtout de l'attente).
