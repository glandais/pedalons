---
id: OPS-48
title: "Le routage passe de Valhalla auto-hébergé à l'API Stadia Maps"
status: done
done: 2026-10-17
---

## Livré

`OPS-48` **Le routage passe de Valhalla auto-hébergé à l'API Stadia Maps** (2026-10-17, contrat
`11.5.2` : seules les descriptions OpenAPI de `RouterResource` changent) — le service `valhalla`
de la stack partagée (17 Go de tuiles OSM, des heures de rebuild, aucune limite mémoire) est
remplacé par `POST https://api-eu.stadiamaps.com/route/v1` (hôte européen de Stadia Maps : les
requêtes restent sur des serveurs de l'Union européenne ; `/route/v2` n'existe pas, 404), API compatible Valhalla (mêmes
`locations`, `costing`, `costing_options`, même `shape` en polyline6) : le package
`fr.pedalons.infrastructure.valhalla` garde son nom (celui du protocole), `Polyline6Decoder` et
les records ; le client devient `StadiaMapsClient` (`configKey` `stadiamaps`), en-tête
`Authorization: Stadia-Auth ${pedalons.routing.stadiamaps.api-key}`, timeouts 3 s / 15 s comme
Open-Meteo. Clé `STADIAMAPS_API_KEY` : sans défaut en `%prod` et reprise avec `:?` dans le bloc
`environment` du backend de `docker-compose.yml` (un déploiement sans clé s'arrête avant de
démarrer quoi que ce soit — l'en-tête étant résolu à chaque requête, le backend seul démarrerait
et répondrait 500 à chaque tracé), vide en `%dev` et `%test` (aucun test backend
n'appelle le routeur), exportée par `scripts/dev-env.sh`, lue par `scripts/e2e.sh` dans
l'environnement puis dans le `.env` du poste, secret GitHub du même nom en CI — où
`gpx-planner.e2e.ts` tourne désormais, `E2E_NO_ROUTING` ne restant que pour un poste sans clé.
`.env.e2e` ne porte aucune clé. Le tileserver reste dans `docker-compose.shared.yml`, et le
backend sur le réseau `shared` ; `docker-compose.local.yml` perd son valhalla et le port 8002.
Bascule d'un hôte, dans l'ordre (« Stadia Maps: routing and geocoding » dans
[`OPERATIONS.md`](../../OPERATIONS.md#stadia-maps-routing-and-geocoding)) : clé dans le `.env` de chaque
environnement, `deploy.sh` par environnement, `deploy.sh --shared`, puis suppression à la main de
`data/valhalla` et de la copie froide (`OPS-9`). Limites publiées : 50 points, 500 km à vol
d'oiseau en `bicycle` ; au-delà du quota, 429, logué par son statut seul (l'URL et l'en-tête ne
sont jamais logués). Les coordonnées du planificateur quittent désormais le serveur : politique
et CGU mises à jour (`LEGAL-23`). Pas de test backend réseau (`Polyline6DecoderTest` reste, hors réseau ;
aucun test n'appelle le routeur) ; le test réel est `gpx-planner.e2e.ts` en CI. **À ne pas défaire** : la clé n'a pas de défaut en `%prod`,
et aucun log n'imprime l'URL ni l'en-tête `Authorization` ; `.env.e2e` reste sans clé (la CI le
vérifie par grep) ; le réseau partagé reste au backend pour le tileserver.
