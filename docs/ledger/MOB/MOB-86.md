---
id: MOB-86
title: "Points de parcours : recette sur appareil"
status: open
verified: 2026-11-16
---

## Reste à faire

`MOB-86` **Points de parcours : recette sur appareil** — à faire sur Android et iOS, rien ne
se teste sans carte native : `icon-image: ['get','icon']` et l'`interpolate` de `icon-size`
posés en `layout` (jusqu'ici les expressions n'étaient qu'en `paint`) ; types des `properties`
rendues par `featuresInRect` ; `padding` d'`animateCamera` sur iOS (le point doit se centrer
au-dessus de la feuille) ; coût de 500 images d'étiquettes au premier chargement ;
contraste des noms en sombre sur fond satellite ; bande haute du profil sur écran étroit.
Repli si les expressions en `layout` cassent : une `SymbolStyleLayer` par type, `icon-image`
constant et filtre `['==',['get','icon'],id]`. Livré par `MOB-84`.
