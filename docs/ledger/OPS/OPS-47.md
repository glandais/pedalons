---
id: OPS-47
title: "Un `robots.txt` pour `auth.pedalons.fr`"
status: open
group: "Exploitation"
verified: 2026-11-16
---

## Reste à faire

`OPS-47` **Un `robots.txt` pour `auth.pedalons.fr`** (extrait d'`OPS-34`) — la
Search Console signale le sous-domaine en 404 : il répond 404 à sa racine comme à
`/robots.txt`. Il sert encore — le Caddyfile de l'hôte l'envoie vers `127.0.0.1:8091` et le
conteneur `strava-auth-proxy-proxy-1` tourne (constaté le 16 octobre 2026) —, donc pas de
retrait du DNS : lui servir un `robots.txt` `Disallow: /`, depuis son bloc du Caddyfile ou
depuis le proxy. Taille : XS.
