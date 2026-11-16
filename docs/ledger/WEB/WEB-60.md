---
id: WEB-60
title: "Météo des sorties au web"
status: done
group: "Accueil et page Fonctionnalités"
done: 2026-10-05
---

## Livré

`WEB-60` **Météo des sorties au web** (5 octobre 2026, contrat `10.9.0`, `API-74`). Le détail
d'une sortie lit `getRideWeather` dans `useRideDetailData`, préfetché en phase 1 de
`prefetchRideDetail` (même clé, `skipErrorToast`), et montre `RideWeatherSection` sous un
`ErrorBoundary variant="inline"`, entre l'en-tête et la carte : météo au départ (lever et coucher
du soleil compris), choix du groupe (celui de l'inscrit, sinon le premier ; `SegmentedControl`
jusqu'à 4 groupes, `Select` au-delà), frise des points, bandeau pluie, barre d'exposition au vent
dans les couleurs générées `RELATIVE_WIND_COLORS`, mention de la vitesse par défaut, attribution
Open-Meteo.com en lien. `STALE` porte un badge « Prévision ancienne », `NOT_YET_AVAILABLE` la date
d'ouverture, `UNAVAILABLE` (ou une lecture en échec) un « Réessayer » ; `NO_LOCATION` n'apparaît
qu'avec `canEdit`. `RideWeatherSummaryLine` est dans `PublicationCard` (sorties) et `NextRideCard`.
Température dans `unitFormat.ts` / `useUnits` (°F en impérial, jamais « -0 »), `formatTime` et
`FormattedTime`. `invalidateRideWeather` est appelé après chaque action sur la sortie et après
`EditRidePage` (sa clé ne commence pas par celle de la sortie). Tests : `weatherDisplay.test.ts`,
`RideWeatherSummaryLine.test.tsx`, `RideWeatherSection.test.tsx`, cas de température de
`unitFormat.test.ts`. **À ne pas défaire** : une seule table `weatherDisplay.ts` (condition ×
jour/nuit → icône Tabler, repli `IconCloud`) ; les icônes de condition n'ont **pas de teinte**
(elles prennent la couleur du texte, comme au mobile) : une teinte passerait par
`contracts/brand-colors.yaml`, jamais par une table locale ; le vent relatif est toujours doublé du
libellé et de la flèche ; le client ne calcule rien d'autre que l'affichage ; le bloc est masqué
pour une sortie terminée ou annulée et pour un statut inconnu ; la requête part quand même (le
serveur répond `OUT_OF_RANGE` sans rien lire), pour garder la clé du préfetch.
