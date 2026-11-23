---
id: OPS-67
title: "Générateur de parcours : osm-route-details 1.15.0, part de chemins visée et bornes de roulabilité"
status: done
size: "S"
done: 2026-11-23
---

## Livré

`OPS-67` **Générateur de parcours : osm-route-details 1.15.0, part de chemins visée et bornes de roulabilité** — le
23 novembre 2026 vers 16:10 UTC, la pile partagée est passée de `1.14.0` à `1.15.0` (API 1.14, lot 5 du générateur,
ledger `API-207`), sur le même graphe planète : les surcouches d'équipe restent valides, aucun dépôt n'est à refaire.

- **Ce qui change sans Pédalons :** les bornes de roulabilité sont actives par défaut (`generator.offroad.rideability` =
  `on`) : en gravel et en VTT, le moteur écarte les arêtes que le type ne peut pas rouler, sauf celles que l'équipe a
  roulées. Les parcours de route ne changent pas. La consigne `offroad_target` n'est envoyée par aucun backend tant que
  Pédalons n'a pas son contrat `16.3.0`.
- **Contrôle :** service prêt en 1,7 s sur le graphe `916dceff034038a9`, sain, sans redémarrage. Des générations en
  découverte depuis le réseau partagé rendent 200 avec et sans consigne, en route, gravel et VTT, en France et à Tokyo
  (0,4 à 10,1 s), et la consigne est atteinte en gravel à 0,25, 0,47 et 0,60 dans un secteur qui le permet. Mémoire
  anonyme 436 Mo, le reste en cache de pages. Seul avertissement côté backends : les capacités injoignables pendant le
  redémarrage.
- **Retour arrière :** remettre `1.14.0` dans `docker-compose.shared.yml` et relancer `scripts/deploy.sh --shared`. Un
  backend en `16.3.0` le supporte : il redemande sans consigne quand le moteur la refuse.

Mesures et validation sur le poste : notes `ord-loops-lot5.md` et `ord-loops-lot5-mesures.md` d'osm-route-details.
