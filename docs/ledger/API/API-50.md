---
id: API-50
title: "Le rédacteur GPX n'écrit plus de `creator` trompeur ni d'heure epoch"
status: done
group: "Vie privée : les métadonnées retirées à l'import"
done: 2026-09-29
---

## Livré

`API-50` **Le rédacteur GPX n'écrit plus de `creator` trompeur ni d'heure epoch** (2026-09-29,
migration vers vcyclist) — gpx2web écrivait `creator="https://www.mapstogpx.com/strava"` et, depuis
`API-44`, `<time>1970-01-01T00:00:00Z</time>` sur chaque point. vcyclist écrit
`creator="@glandais/vcyclist"` et omet `<time>` pour un point sans horloge. Test :
`GpxSanitizerTest` (aucun `<time>` dans les deux sérialisations).
