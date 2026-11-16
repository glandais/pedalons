---
id: SEC-6
title: "Le traitement GPX est borné avant d'allouer : M3"
status: done
done: 2026-10-01
---

## Livré

`SEC-6` **Le traitement GPX est borné avant d'allouer : M3** (2026-10-01, **API 9.2.0**, mineur :
code d'erreur `GPX_TOO_LONG`, `minimum`/`maximum` sur `GeoPoint`, `maxItems` sur les points du
planificateur) — la chaîne GPX rééchantillonne chaque tracé à un point tous les 10 m : ce qu'elle
alloue suit la *distance* du tracé, pas la taille de la requête, si bien que quelques points très
éloignés suffisaient à épuiser la mémoire du backend partagé. Trois bornes, réunies dans
`GpxLimits` et vérifiées avant toute allocation : **10 Mo** par fichier téléversé, désormais sur
toutes les routes HTTP qui en prennent un (création *et* mise à jour d'un aperçu des outils GPX,
création et mise à jour d'un parcours d'équipe — seule la création d'aperçu l'appliquait), refus
`FILE_TOO_LARGE` ; **4 000 km** de longueur cumulée pour tous les tracés d'un GPX, quelle que soit
sa source (fichier, points du planificateur, routeur, import biketeam), soit au plus ~400 000
points rééchantillonnés, refus `GPX_TOO_LONG` — vérifié dans `parseGpx` et `fromPoints`, avant
tout travail, puis répété dans `computeGpx`, l'entonnoir, et dans `RouterService` ; **100 000
points** par requête du planificateur (`@Size` sur `RouteRequest.points`,
`GpxPreviewFromPointsRequest.points`, `GpxPreviewUpdateRequest.points`), chacun validé dans les
bornes WGS84 (`@DecimalMin`/`@DecimalMax` sur `GeoPoint`, `@Valid` en cascade, routeur compris) ;
un point hors bornes ou non numérique dans un fichier est un `GPX_FAILURE`. Les plafonds visent
le vélo réel : 4 000 km couvrent un brevet d'ultra-distance d'un seul tenant (Paris-Brest-Paris,
London-Edinburgh-London), un périple plus long est un voyage en étapes. Au passage, la mise à jour
d'un parcours lit le nouveau tracé *avant* son `try` : un fichier refusé garde son code d'erreur
(tout devenait `GPX_FAILURE`) et ne supprime plus les fichiers actuels du parcours. L'import
biketeam n'est pas soumis aux 10 Mo (il lit ses fichiers de serveur à serveur) mais l'est aux
4 000 km, rangés en avertissement `GPX_FAILURE`. Correction sur le code actuel, pas sur la
bibliothèque vcyclist (migration non planifiée). À ne pas défaire : la vérification de la
distance avant `computeOnePointPerDistance` (elle s'écrit `!(total <= max)` pour refuser aussi
un NaN) ; relever `MAX_TRACK_DISTANCE_METERS` relève d'autant la mémoire qu'une requête peut
prendre. Tests (verts au 16 octobre 2026) : `GpxLimitsResourceTest` (fichier trop gros sur les
quatre routes, tracé trop long par fichier et par points, trop de points, latitude et longitude
hors bornes, parcours intact après un refus) et `GpxLimitsTest` (unitaire : tracé réaliste
accepté, somme sur plusieurs tracés, coordonnée hors bornes ou NaN).
