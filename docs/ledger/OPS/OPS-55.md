---
id: OPS-55
title: "Le heap du backend de prod ne se remplit plus de tuiles d'altitude décodées"
status: done
done: 2026-10-31
---

## Livré

`OPS-55` **Le heap du backend de prod ne se remplit plus de tuiles d'altitude décodées**
(2026-10-31 ; la vérification en prod reste ouverte sous `OPS-56`) — trois OOM de heap en prod
(le 26 octobre à 17 h 47 et 18 h 11 UTC pendant une migration biketeam, le 29 octobre à
20 h 49 UTC à la deuxième tentative de recalcul HD de « Nantes – Houtkerque »). Ce qui restait
vivant, environ 570 MiB pour une old gen de 820 MiB : l'index des fuseaux horaires timeshape
(215 MiB pour le monde), les tuiles décodées des providers vcyclist (environ 200 MiB) et environ
150 MiB pour le reste de l'application. Les providers sont des singletons et gardaient 100 tuiles
par étage (le défaut d'`ElevationProviderConfig.cacheSize`) ; une tuile Mapterhorn décodée pèse
1 MiB, une tuile IGN 256 KiB. vcyclist 6.12.0 accepte un `cacheSize` qui s'applique à chaque
étage (IGN, repli Mapterhorn, modèle de surface), et `VcyclistProducer` passe
`pedalons.elevation.tile-cache-size=20` aux providers FAST et HD. Mesuré en local, pile complète
limitée à 2 Go et cache vide : après le recalcul HD du même parcours, 137 MiB vivants au lieu de
300 MiB, dont 52 MiB de `byte[]` au lieu de 226 MiB ; durée du recalcul inchangée (2 s sur cache
disque chaud dans les deux cas). Une tuile sortie du cache mémoire est relue sur le disque
(`DemTileStore`) et redécodée, jamais retéléchargée. À ne pas défaire : **garder la taille du
cache au-dessus de 10**, le nombre de tuiles que vcyclist charge en parallèle
(`maxParallelTiles`). **timeshape reste chargé pour le monde entier** (décision du propriétaire
du 31 octobre 2026) : un index restreint à l'Europe pèserait 55 MiB et un index restreint à la
France 6 MiB, mais une sortie à l'étranger perdrait son fuseau. Rien de cela n'est couvert par un
test backend ; le test vcyclist `cacheSize reaches every tier, and null keeps the default` couvre
la propagation du `cacheSize` à chaque étage.
