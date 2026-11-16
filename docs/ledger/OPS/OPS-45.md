---
id: OPS-45
title: "Les tests tournent sur le PostGIS de la prod"
status: done
done: 2026-10-25
---

## Livré

`OPS-45` **Les tests tournent sur le PostGIS de la prod** (2026-10-25) — le repli
`quarkus.datasource.devservices.image-name` d'`application.properties` passe à
`imresamu/postgis:18-3.6-alpine`. Il ne sert qu'en dehors des tests : ceux-ci lisent déjà l'image
du service `postgres` de `docker-compose.yml` par `DevServicesImageConfigSource`, ce que
l'entrée ignorait.
