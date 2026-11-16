---
id: API-44
title: "Les GPX importés ne gardent que la trace et les waypoints"
status: done
group: "Vie privée : les métadonnées retirées à l'import"
done: 2026-09-29
---

## Livré

`API-44` **Les GPX importés ne gardent que la trace et les waypoints** (2026-09-29, contrat
inchangé) — `GpxSanitizer`, appelé en tête de `GpxProcessingService.computeGpx` (dans son `try`,
donc une erreur donne `GPX_FAILURE`), avant l'écriture d'`original.gpx` : chaque point garde
latitude, longitude et altitude, son instant devient `Instant.EPOCH`, ses extensions (fréquence
cardiaque, cadence, puissance, température) disparaissent ; les waypoints gardent position et
nom. Tous les fichiers stockés d'un parcours et d'un aperçu de l'outil GPX (original, filtré,
FIT) en sortent : upload, planificateur, promotion d'un aperçu en parcours, import biketeam. Les
métadonnées du document (auteur, e-mail, lien, `creator`) ne survivaient déjà pas au lecteur.
Le constat d'origine était inexact : `original.gpx` était déjà une resérialisation ; la fuite
était le `<time>` de chaque point dans les deux GPX, les extensions de `filtered.gpx` (celui des
téléchargements, des routes d'appareil et des envois aux services GPS) et l'heure et la puissance
du FIT. Rattrapage : `GpxSanitizationBackfill` (`service/gpx`, 4 h 15, après la purge des aperçus,
`SKIP`) réécrit en place, sous la même clé, tout parcours (supprimés et tous domaines compris) et
tout aperçu dont un fichier porte encore `<extensions>` ou un `<time>` autre qu'epoch, en
régénérant le FIT **avant** le GPX filtré (qui est le seul signal de saleté) ; le pipeline
(SRTM, simplification, montées) n'est pas rejoué. Le marqueur `maintenance/api-44-gpx-sanitized`
n'est écrit qu'après une passe sans échec ; une restauration du bucket le fait disparaître et la
passe repart. Tests : `GpxSanitizerTest`, `GpxSanitizationBackfillTest`,
`GpxProcessingServiceTest#createTracks_shouldStripTimestampsAndSensorsFromEveryStoredFile`,
`GpxPreviewServiceTest#create_shouldStripTimestampsAndSensorsFromStoredFiles`.
**Décisions à ne pas défaire** : un seul point d'entrée (`computeGpx`), pas chez un appelant ;
nettoyage **en place** (les appelants écrivent le FIT depuis le même objet `GPX`) ; `EPOCH` et
non `null` (le rédacteur FIT et `computeArrays` exigent un instant, et c'est déjà la valeur d'un
point sans `<time>`) ; pas de rejeu du pipeline dans le rattrapage. Rien n'utilisait les
horodatages : distances, dénivelés, montées, vent, simplification sont de la géométrie. Limites
connues : un GPX/FIT déposé en pièce jointe (`API-49`, `API-55`, depuis nettoyés) ; le rédacteur de la bibliothèque
(`API-50`) ; la pose du marqueur n'a pas de test (`API-51`) ; les copies déjà envoyées à Garmin,
Wahoo ou Hammerhead avant le correctif ne se réparent pas de notre côté.
**Porté sur vcyclist** (migration gpx2web → vcyclist, rebasée sur ce correctif le 2026-09-29) :
le modèle étant immuable, `GpxSanitizer.sanitize` rend un **nouveau** `GpxDocument` (position,
altitude, noms, nature trace/route et segments ; plus aucun instant, capteur, type, largeur de
route ni champ de waypoint autre que position et nom) et `computeGpx` poursuit avec lui. Un point
sans horloge n'a plus de `<time>` du tout, et le FIT d'un parcours sans horloge part de l'epoch
FIT (1989-12-31, `FitExporter`) : partir de l'epoch Unix le datait de 2106 par débordement.
`original.gpx` reste une resérialisation — l'arbitrage « octets uploadés verbatim » de la
migration a été abandonné pour ce ledger. Le rattrapage lit et réécrit avec vcyclist ;
`isDirty` accepte l'epoch des fichiers nettoyés du temps de gpx2web comme leur absence. Les
décisions « en place » et « `EPOCH` et non `null` » ci-dessus ne valaient que pour gpx2web ;
« un seul point d'entrée » et « pas de rejeu du pipeline » restent.
