---
id: API-43
title: "Les images perdent leurs métadonnées au stockage"
status: done
group: "Vie privée : les métadonnées retirées à l'import"
done: 2026-09-29
---

## Livré

`API-43` **Les images perdent leurs métadonnées au stockage** (2026-09-29, contrat inchangé) —
`S3StorageService.store`, le seul chemin par lequel un fichier atteint le bucket (upload
d'asset, pièce jointe, avatar et son original temporaire, vignettes, import biketeam via
`addAsset`/`uploadAssetFile`, `uploadTempFileToS3`), **fait réencoder toute image par imgproxy**
(`ImgProxyClient.reencode` : `sm:1`, `kcr:0` — imgproxy garde le copyright par défaut —,
`ar:1`, `q:90`, format imposé par l'extension) : seuls les pixels sont réécrits, redressés selon
l'orientation, et rien de l'envoi ne subsiste (EXIF, GPS, XMP, IPTC, MPF, commentaires,
miniatures, octets après la fin de l'image, polyglottes). JPEG, PNG, WebP et GIF (animé compris)
gardent leur format ; TIFF (et les RAW qui en dérivent), HEIF/HEIC/AVIF et JPEG XL deviennent des
JPEG, l'asset prenant `image/jpeg` et l'extension `.jpg` (`ImageFormat.storedFileName`). Seul le
JPEG 2000, qu'imgproxy ne lit pas, est **refusé** (`FILE_TYPE_REJECTED`) ; une image qu'imgproxy
refuse de décoder (4xx) est refusée en `INVALID_FORMAT`, une panne d'imgproxy (5xx) remonte en
500. imgproxy lisant ses sources dans S3, l'original est déposé sous `tmp/reencode/<uuid>` le
temps de l'appel et effacé dans un `finally` (orphelins en cas de JVM tuée : `OPS-17`) ; Varnish
laisse passer ces URL sans les cacher. `FileTypeDetector` reconnaît ces images à leurs premiers
octets **avant** Magika, qui n'a pas d'étiquette HEIC/AVIF/JXL, et les accepte pour les
catégories `IMAGE` et `ATTACHMENT` avec le type sous lequel elles seront stockées. Rattrapage :
V47 ajoute `assets.metadata_pending` (images et types `LOGO`/`IMAGE`/`ATTACHMENT`, index
partiel) ; `AssetMetadataBackfillScheduler` (toutes les 5 min, lots de 100, curseur en mémoire)
lit l'en-tête par une lecture partielle (`StorageService.retrieveHead`), ne télécharge que les
images, les réécrit sous la même clé par `store`, met à jour nom et type de l'asset si le format
change, puis efface le drapeau ; une erreur de stockage ou d'imgproxy transitoire le laisse posé.
Tests : `StorageImageReencodingTest` (un corpus réel de huit formats chargés de métadonnées dans
`src/test/resources/images/metadata`, rotation, animation, orphelin effacé), `ImageFormatTest`,
`FileTypeCategoryTest`, `AssetServiceTest.MetadataRemoval`, `AssetMetadataBackfillTest`.
**Décisions à ne pas défaire** : le nettoyage reste dans la couche de stockage, pas dans
`AssetService` ni `UserAvatarService` (un futur chemin d'écriture le contournerait) ; le format se
lit sur les octets (`ImageFormat.sniff`), jamais sur le type déclaré ni l'étiquette de Magika —
un JPEG envoyé en `application/octet-stream` est réencodé aussi ; **réencoder plutôt que
nettoyer** : un premier nettoyeur maison sans perte (`ImageMetadataStripper`, par liste blanche
de segments et de chunks, ~700 lignes) a été livré puis retiré le même jour, jugé trop
compliqué et pas assez sûr sur tous les cas ; la perte de qualité d'un réencodage à `q:90` est
acceptée. Limites connues : les vidéos (`API-46`), documents (`API-47`), SVG/ICO (`API-48`)
restent tels quels ; un GIF de plus de `IMGPROXY_MAX_ANIMATION_FRAMES` (100) images est
tronqué ; un JPEG tronqué, que les navigateurs affichaient, est refusé ; la restauration d'une
vieille sauvegarde MinIO est `OPS-15`. Les exports déjà générés (7 jours) et les sauvegardes
antérieures (30 jours) gardent les originaux jusqu'à leur expiration.
