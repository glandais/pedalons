---
id: SEC-29
title: "Les ports Swarm fermés aussi en IPv6"
status: done
done: 2026-09-30
---

## Livré

`SEC-29` **Les ports Swarm fermés aussi en IPv6** (2026-09-30, contrat inchangé, relevé en
vérifiant V3 sous `SEC-16`) — en IPv6, Traefik (8089, 8090) et Grafana (3300) répondaient depuis
Internet : sans NAT IPv6 dans le routing mesh, Docker sert un port publié par un `docker-proxy` qui
écoute sur l'hôte, si bien que le trafic passe par `INPUT` et jamais par `DOCKER-USER`, où
`pedalons-firewall.sh` posait ses règles. Caddy était contourné : pas de journal filtré, des
`X-Forwarded-*` forgés crus par Traefik (`forwardedHeaders.insecure`, `AUD-6`), et la limite de
débit de `SEC-28` sans effet. Le script pose désormais, pour chacun de ces ports, un DROP dans
`INPUT` en plus de `DOCKER-USER`, v4 et v6 (sans effet en IPv4, que le mesh fait passer par
`FORWARD`). Installé sur l'hôte et vérifié le même jour depuis une autre machine : 8089, 8090,
3300 et 2020 ne répondent plus ni en IPv4 ni en IPv6, le site et le staging répondent par Caddy,
Grafana et Traefik restent joignables sur la boucle locale (tunnel SSH, Caddy). **À ne pas
défaire** : toute vérification du pare-feu se fait aussi en IPv6 et d'une autre machine — l'absence
d'enregistrement AAAA ne protège pas ; un nouveau port publié par Swarm s'ajoute à
`TRAEFIK_PORTS` ou `MONITORING_PORTS`, qui le ferment sur les deux chemins. Pas de test
automatisé (pare-feu de l'hôte) : `OPERATIONS.md`, « Only Caddy may reach traefik », donne les
contrôles.
