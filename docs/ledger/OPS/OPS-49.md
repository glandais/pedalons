---
id: OPS-49
title: "Le géocodeur passe de Nominatim à l'API Stadia Maps"
status: done
done: 2026-10-17
---

## Livré

`OPS-49` **Le géocodeur passe de Nominatim à l'API Stadia Maps** (2026-10-17, contrat `11.5.3` :
seules les descriptions OpenAPI de `GeocodeResource` changent — plus de « proxied to OpenStreetMap
Nominatim », crédit « Stadia Maps, © OpenStreetMap contributors & others ») — `GET
/api/geocode/search?q=` garde tout son contrat (`GeocodeResultDto` id / displayName / lat / lon,
`@RolesAllowed("user")`, 3 caractères minimum, 5 résultats, normalisation, cache Caffeine
`geocode-search` 24 h, liste vide en cas de panne) mais le serveur interroge désormais `GET
https://api-eu.stadiamaps.com/geocoding/v1/autocomplete?text=…&size=5&lang=…` (hôte européen,
même clé `STADIAMAPS_API_KEY` et même en-tête `Authorization: Stadia-Auth …` qu'`OPS-48`), par un
client REST de géocodage distinct du client de routage (un `configKey` par interface, URL et
timeouts repris de celui du routage : deux interfaces sur un même `configKey`, on ne parie pas
dessus). La réponse est un FeatureCollection GeoJSON : `features[].geometry.coordinates` =
[lon, lat], `properties.gid` sert d'`id`, `properties.label` de `displayName`. **L'autocomplétion
`v1`, pas la `v2`** : vérifié en direct, `/geocoding/v2/autocomplete` renvoie `geometry: null` et
demande un second appel `/geocoding/v2/place?ids=` par sélection ; la `v1` donne coordonnées et
libellé en un appel, ce que le contrat promet. À revoir seulement si Stadia retire la `v1`.
*(Revu le jour même : la `v1` coûte 20 crédits par requête, la `v2` 1 ; le passage à la `v2`
avec résolution à la sélection est `API-129`, contrat `11.7.0`.)*
Disparaissent avec Nominatim : `NOMINATIM_URL`, `GEOCODE_USER_AGENT` et le `User-Agent` imposé
par la politique d'usage d'OSM (le client Open-Meteo, qui réutilisait cette valeur, reçoit son
propre `User-Agent` `Pedalons/<version> (+https://www.pedalons.fr)`) ; le bloc « Geocoding »
d'`.env.example` ne porte plus rien à configurer. Pas de biais `focus.point` vers le centre par
défaut du déploiement : la clé de cache devrait alors inclure le focus, le gain ne le vaut pas
pour des formulaires. Le package `infrastructure.nominatim` devient `infrastructure.stadiamaps`
(`StadiaMapsGeocodingClient`, `GeocodingLookup`, records `GeocodingResponse` / `GeocodingFeature`).
Tests : `GeocodingLookupTest` (ex-`NominatimLookupTest`), `GeocodingResponseJsonTest` (le GeoJSON
relevé en direct) et `GeocodeResourceTest`, client mocké ; aucun test n'appelle Stadia Maps. Les textes légaux suivent (`LEGAL-24`), la
barre de recherche des cartes est `WEB-99`. **À ne pas défaire** : le proxy par le serveur reste
pour les formulaires (Stadia Maps n'y voit que le texte, la langue et l'IP du serveur — c'est ce
que promet la politique) ; ~~la `v1` tant qu'elle existe~~ (remplacé par `API-129`) ; l'hôte EU ; aucune clé ne descend dans
un client ; une panne de la recherche reste une liste vide, jamais une erreur (la résolution du
lieu choisi, `API-129`, répond 503).
