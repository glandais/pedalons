---
id: API-49
title: "Un GPX joint en pièce jointe ne garde que sa trace"
status: done
group: "Vie privée : les métadonnées retirées à l'import"
done: 2026-09-30
---

## Livré

`API-49` **Un GPX joint en pièce jointe ne garde que sa trace** (2026-09-30, contrat inchangé) —
`API-44` ne couvrait que les parcours et l'outil GPX ; un `.gpx` déposé comme `ATTACHMENT` était
stocké tel quel, horodatages et capteurs compris. `AssetService.addAssetStream` le passe
maintenant par `TrackAttachmentSanitizer` avant le stockage : lu, nettoyé par `GpxSanitizer`,
réécrit, **sans** rééchantillonnage ni correction d'altitude — une pièce jointe n'est pas un
parcours, elle garde tous ses points. Un fichier `.gpx` illisible est refusé (`GPX_FAILURE`), un
GPX sans trace ni point d'intérêt aussi (`GPX_EMPTY`) : le réécrire ne garderait rien. Les pièces
jointes déjà stockées passent par `GpxSanitizationBackfill`, dont le marqueur devient
`maintenance/api-49-gpx-sanitized` pour que la passe tourne une fois de plus là où
`maintenance/api-44-gpx-sanitized` existe (parcours et aperçus déjà propres n'y sont que lus). Une
pièce jointe y est jugée propre par `TrackAttachmentSanitizer.isClean`, pas par `isDirty` (un
auteur ou un appareil n'est pas un `<time>`) ; une pièce jointe illisible est laissée et
journalisée, **sans** faire échouer la passe, sinon le marqueur ne serait jamais posé. La politique
(§1, FR et EN) dit désormais que ces fichiers sont nettoyés. Couvert par `AssetServiceTest`
(`shouldStripClockSensorsAndAuthorFromAnAttachedGpx`, `shouldRefuseAGpxAttachmentThatIsNotAGpx`)
et `GpxSanitizationBackfillTest` (`sanitizeAll_rewritesAGpxAttachmentStoredAsUploaded`,
`sanitizeAll_leavesAnUnreadableAttachmentWithoutFailingThePass`), **écrits sans avoir été
lancés** ; nettoyage idempotent vérifié hors suite sur la fixture `activity_with_sensors.gpx`.
