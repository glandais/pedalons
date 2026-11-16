---
id: MOB-55
title: "La carte des parcours levait à chaque ouverture sous Android"
status: done
group: "Erreurs remontées automatiquement — 6 octobre 2026"
---

## Livré

`MOB-55` **La carte des parcours levait à chaque ouverture sous Android** (feedback #8) —
`maplibre_android` 0.3.6 ne construit un `VectorSource` que sur `url` (`source.url!`) et la
couche de masse est définie par `tiles` : `TypeError`, et toute la pile de couches qui suit
(tracés, marqueurs, réticule) n'était pas posée. Sous Android, `PdlMassTiles.platformSource`
écrit un TileJSON équivalent dans le cache de l'app et passe son URL `file://` ; iOS garde
`tiles`. Une masse qui ne se pose pas n'emporte plus le reste (`_applyMassLayer` rattrape et
journalise). Test : `pdl_mass_layer_test.dart` (le document TileJSON) ; constaté sur un Pixel 6a
(Android, build debug) le 6 octobre 2026. **À ne pas défaire** : ne pas revenir à `tiles` sous Android tant que
le greffon ne lit pas `VectorSource.tiles` (la liaison JNI sur `TileSet` existe, c'est
`style_controller.dart` qui ne l'emploie pas).
