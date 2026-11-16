---
id: WEB-99
title: "Barre de recherche de lieux sur les cartes à navigation libre (17 octobre 2026, contrat inchangé)"
status: done
group: "Mesure d'audience du site"
done: 2026-10-17
---

## Livré

### `WEB-99` Barre de recherche de lieux sur les cartes à navigation libre (17 octobre 2026, contrat inchangé)

`WEB-99` **Les trois cartes qui s'ouvrent sur `useDefaultMapView()` — le planificateur
(`RoutePlanner`), la carte des parcours (`RoutesTileMap`) et la carte vierge de l'outil GPX
(`GpxBlankMapPage`) — ont une barre de recherche de lieux** : le composant
`components/map/MapSearchControl.tsx` monte `MapLibreSearchControl` de
`@stadiamaps/maplibre-search-box` 3.2.0 via `useControl` de react-map-gl/maplibre, langue de
`i18n.language`, `placeholder` / `noResults` traduits (`map.search.placeholder`,
`map.search.noResults`, fr/en en parité), `baseUrl` sur l'hôte européen
`https://api-eu.stadiamaps.com`. Le contrôle interroge Stadia Maps **depuis le navigateur**
(autocomplete `v2` + search `v1`), authentifié par le domaine de la page (`Origin`/`Referer` ;
pedalons.fr et tous ses sous-domaines sont déclarés côté Stadia, localhost passe sans clé sous
quota strict) — **aucune clé côté client** —, affiche lui-même « Powered by Stadia Maps,
© OpenStreetMap contributors & others » sous ses résultats et cadre la carte à la sélection.
Les cartes cadrées sur une trace ou une annonce n'en ont pas. `frontend/server/csp.js` ajoute
`https://api-eu.stadiamaps.com` à `connect-src` comme origine fixe (cas ajouté dans
`csp.test.js`) ; les icônes du paquet sont des SVG embarqués par Vite, rien pour `img-src`. SSR :
le paquet s'importe sans toucher au DOM, `pnpm build` (client + SSR) passe. Le mode sombre est
repris dans `index.css`. `gpx-planner.e2e.ts` ne dépend pas de la barre, qui n'appelle Stadia que
si l'on tape. Le géocodage des formulaires (`GeocoderAutocomplete` → `/api/geocode/search`)
reste côté serveur (`OPS-49`) ; seuls son commentaire et la clé `geocoder.attribution` changent.
La politique dit ce qui part de l'appareil (`LEGAL-24`). **À ne pas défaire** : aucune clé Stadia
dans le bundle ; l'hôte EU dans `baseUrl` ; la barre ne va que sur les cartes à navigation libre ;
un nouveau nom d'hôte de déploiement se déclare dans le tableau de bord Stadia, sinon la barre ne
répond rien (« Stadia Maps: routing and geocoding » dans
[`OPERATIONS.md`](../../OPERATIONS.md#stadia-maps-routing-and-geocoding)).
