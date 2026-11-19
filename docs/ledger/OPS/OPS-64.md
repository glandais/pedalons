---
id: OPS-64
title: "Générateur de parcours : osm-route-details 1.12, formes organiques et profil de goût en service"
status: open
size: "S"
kind: recette
verified: 2026-11-19
---

## Reste à faire

`OPS-64` **Générateur de parcours : osm-route-details 1.12, formes organiques et profil de goût en service** —
passer la pile partagée de `1.9.2` à `1.12.0` (lot 4 d'`API-207`, plan §12 septies), sans changement de contrat côté
Pédalons ni de limite du conteneur (3G). Au premier démarrage, toutes les surcouches déposées par un moteur plus ancien
passent `stale` (raison `profile`) et la table commune les sert jusqu'à la passe de la nuit, qui les redépose avec un
profil de goût appris. À voir en production : la passe de nuit sans échec ni délai dépassé (un dépôt prend jusqu'à
~10 min pour la plus grande équipe, sous les 16 min du backend), la mémoire du service après les dépôts, et quelques
générations réelles en triangle.
