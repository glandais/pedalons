---
id: OPS-64
title: "Générateur de parcours : osm-route-details 1.12, formes organiques et profil de goût en service"
status: done
size: "S"
done: 2026-11-20
---

## Livré

`OPS-64` **Générateur de parcours : osm-route-details 1.12, formes organiques et profil de goût en service** —
la pile partagée est passée de `1.9.2` à `1.12.0` le 19 novembre 2026 (lot 4 d'`API-207`, plan §12 septies), sans
changement de contrat côté Pédalons ni de limite du conteneur (3G). Au premier démarrage, les surcouches déposées par
l'ancien moteur sont passées `stale` (raison `profile`) et la table commune les a servies jusqu'à la passe de la nuit
du 20 novembre. Constaté en production : la passe a redéposé 9 surcouches en prod (736 s) et 4 en staging (549 s), sans
échec. Le plus long dépôt a duré 327 s en prod pour la plus grande équipe, et 521 s en staging, déposé en même temps que
la prod. Tous deux restent sous les 16 min du backend. 12 profils de goût ont été appris ; une équipe sans boucle a gardé
la table commune. osm-route-details a culminé à 1,51 Go (cgroup) pour 3G, sans OOM ni redémarrage. Ensuite, 25
générations réelles ont été faites depuis le site, toutes `ok`, avec une médiane de 0,5 s et un maximum de 1,4 s ; les
formes ont été vues par le propriétaire.
Ne pas revenir sous 1.12 sans prévoir le même redépôt.
