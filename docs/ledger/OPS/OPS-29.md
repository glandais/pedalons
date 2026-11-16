---
id: OPS-29
title: "Météo des sorties en production : ce qui reste"
status: open
size: "S"
group: "Recette du backend en conditions réelles"
verified: 2026-11-16
---

## Reste à faire

`OPS-29` **Météo des sorties en production : ce qui reste (S)** — la recette technique est
faite (V61 passée le 6 octobre 2026 sur `de205e4d`) et tient le 16 octobre : 63 cellules en
prod et 12 en staging, fraîches, toutes à `attempts = 0`. Seuls échecs dans les journaux sur
48 h : des `Open-Meteo answered 503: The service is overloaded` intermittents (6 en prod,
au moins 4 en staging), sans dommage puisque le cache reste frais. Restent : **régler les
budgets de staging**, dont le `.env` n'a toujours aucune clé `OPEN_METEO_*` ni `WEATHER_*` —
prod et staging sortent par la même adresse IP et, à leurs défauts (5 000 appels par jour
chacun, `application.properties`), atteignent ensemble les 10 000 appels par jour du plan
gratuit (voir [OPERATIONS](../../OPERATIONS.md#ride-weather-open-meteo)) ; **voir** la météo d'une
sortie à J+2 sur le web — sur la page de groupe refaite par `WEB-94` et `API-123` — et dans
l'app (les sorties à venir sont en visibilité `TEAM`, non vérifiables sans session).
**À trancher par le propriétaire** : l'offre gratuite d'Open-Meteo est réservée à un usage non
commercial ; si Pédalons ne s'y range pas, un plan payant ne demande que `OPEN_METEO_URL` et
`OPEN_METEO_API_KEY`.
