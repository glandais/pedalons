---
id: API-55
title: "Un FIT joint en pièce jointe est réécrit en parcours"
status: done
group: "Vie privée : les métadonnées retirées à l'import"
done: 2026-09-30
---

## Livré

`API-55` **Un FIT joint en pièce jointe est réécrit en parcours** (2026-09-30, contrat inchangé,
scindé d'`API-49`) — même chemin que le GPX. Le FIT est décodé par le SDK Garmin (déjà sur le
classpath, par gpx2web), réduit à ses enregistrements positionnés (latitude, longitude,
altitude) et à ses `course_point`, puis réécrit par le `FitFileWriter` de `route.fit` : tours,
séances, informations d'appareil, VFC et tous les autres messages d'une activité disparaissent,
le fichier se charge toujours sur un GPS, comme parcours à suivre. Le rédacteur date le fichier à
sa création, donc un FIT propre n'est pas reconnu aux octets : `isClean` le tient pour propre
quand c'est un parcours de notre rédacteur (même `file_id`), fait des seuls messages qu'il écrit,
sans heure ni capteur sur aucun enregistrement — et `sanitize` le rend alors tel quel. Couvert par
`AssetServiceTest.shouldStripClockAndSensorsFromAnAttachedFit` et
`GpxSanitizationBackfillTest.sanitizeAll_rewritesAFitAttachmentStoredAsUploaded` (réécrit une
fois, laissé la seconde), **écrits sans avoir été lancés**. Ne pas comparer un FIT aux octets pour
décider de le réécrire : il serait réécrit à chaque passe.
**Porté sur vcyclist** (migration gpx2web → vcyclist) : le SDK Garmin Java ne vient plus avec
gpx2web, et `fit-kotlin-sdk` (amené par vcyclist) occupe le même package `com.garmin.fit` — les
deux ne cohabitent pas. Le FIT est décodé par `FitDecoder` et réécrit par `FitExporter`, comme
`route.fit`. Ce rédacteur est **déterministe** (chaque enregistrement et la création du fichier à
l'epoch FIT) : la règle ci-dessus s'inverse, un FIT est propre exactement quand sa réécriture le
rend octet pour octet, comme un GPX, et le test de forme (`file_id`, messages, capteurs) disparaît.
Perte assumée : vcyclist n'écrit pas de `course_point`, les points d'intérêt d'un FIT joint
disparaissent, et un FIT qui n'a qu'eux est refusé (`GPX_EMPTY`). Ne pas redonner au SDK Garmin
Java une place à côté de `fit-kotlin-sdk`.
