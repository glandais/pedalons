---
id: OPS-57
title: "La surface des traces ne passe plus par Stadia Maps : osm-surface, dans la stack partagée"
status: done
done: 2026-10-31
---

## Livré

`OPS-57` **La surface des traces ne passe plus par Stadia Maps : osm-surface, dans la stack
partagée** (2026-10-31, contrat `13.0.1`, description seule) — le `trace_attributes` de Stadia
(20 crédits par tranche de 190 km, chaque trace enregistrée envoyée chez un tiers) est remplacé
par `ghcr.io/glandais/osm-surface:0.1.1` (github.com/glandais/osm-surface), qui sert le même
`POST /trace_attributes/v1` au protocole Valhalla, avec un `map_snap` refait sur les tuiles
vectorielles VersaTiles d'OpenStreetMap (téléchargées à la demande, cache dans le volume
`osm-surface-data`, 5 Go au plus). Service `osm-surface` de `docker-compose.shared.yml`, repris
par `docker-compose.local.yml` (port 18002 pour le `%dev`) ; le backend l'atteint à
`http://osm-surface:8002` sur `pedalons-shared` (`OSM_SURFACE_URL`). Côté backend, le client
s'appelle `TraceAttributesClient` (configKey `osm-surface`, plus d'en-tête `Stadia-Auth`) et le
calcul ne dépend plus de `STADIAMAPS_API_KEY` : seul `pedalons.surface.enabled` le coupe.
Accord avec Stadia de 86 à 94 % par classe, 98 à 99 % revêtu / non revêtu (README d'osm-surface) ;
les surfaces déjà calculées par Stadia restent. Couvert par `SurfaceRefreshTest`,
`SurfaceBackfillTest`, `GpxPreviewSurfaceRefreshTest` (client simulé) ; le service lui-même par
ses propres tests. À ne pas défaire : **déployer la stack partagée avant les environnements** (un
backend sans le service échoue en « injoignable » et abandonne une trace après cinq échecs) ; le
503 d'osm-surface (tuiles indisponibles) reste transitoire, ses 400 {123, 171, 443, 444, 154}
définitifs, comme chez Stadia. Exploitation : docs/OPERATIONS.md, *Surface along saved tracks*.
