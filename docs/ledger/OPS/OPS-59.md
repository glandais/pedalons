---
id: OPS-59
title: "osm-surface retiré de la stack partagée"
status: done
done: 2026-11-07
---

## Livré

`OPS-59` **osm-surface retiré de la stack partagée** (2026-11-07, sans changement de contrat)
(scindé d'`OPS-58`) — le service et ses 768 Mo réservés ne servaient plus qu'une version
antérieure à la phase E d'`API-150`, que plus aucun environnement ne faisait tourner : staging et
prod passés sur `a8eda50d` le même jour, recalcul du parc allumé en prod. Retiré de
`docker-compose.shared.yml` et `docker-compose.local.yml` avec son volume, des commentaires qui le
disaient encore appelé, du README, de `backend/CLAUDE.md` et des sommes mémoire
d'`OPERATIONS.md` (environ 24 Go pour deux environnements). `scripts/deploy.sh --shared` passe
`--prune` comme les autres stacks : sans lui un service retiré du fichier continuait de tourner.
Pas de test : vérifié au déploiement
(`docker stack services pedalons-shared`). À ne pas défaire : **un retour arrière avant la phase E
(`58efaf4a`) n'a plus de revêtement** (ses demandes échouent en injoignable, le profil n'est pas
touché) ; `surface_refresh` et ses entités restent jusqu'à la phase F d'`API-151`, qui est une
autre étape. Le volume `pedalons-shared_osm-surface-data` (régénérable) se supprime à la main.
