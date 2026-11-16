---
id: MOB-20
title: "Performance"
status: open
group: "Recette sur une application qui tourne"
verified: 2026-11-16
---

## Reste à faire

`MOB-20` **Performance** — liste de 200 items : rester au-dessus de 55 fps (en prod, les
parcours ou les sorties de `n-peloton` suffisent). Si le
`BackdropFilter` des barres épinglées coûte trop cher, le repli prévu (non implémenté à ce
jour — `blurToolbar` est une constante fixe à 12, aucune branche conditionnelle) serait **un
seul jeton** à faire tomber à 0 (`PdlMotion.blurToolbar`, surface opaque), aucun écran à
rouvrir.
