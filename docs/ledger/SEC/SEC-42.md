---
id: SEC-42
title: "Un envoi de fichier refusé laisse sa copie temporaire sur le disque du backend"
status: done
done: 2026-11-17
---

## Livré

`SEC-42` **Un envoi de fichier refusé laisse sa copie temporaire sur le disque du backend**
(audit de novembre, C2, faible ; contrat inchangé) — un envoi est copié dans le répertoire
temporaire du backend (`pedalons-assets/`, `pedalons-avatars/`) avant d'être validé, et seul le refus
d'une trace jointe effaçait cette copie : un type refusé par la détection, une copie interrompue ou un
échec du stockage la laissaient sur le disque, sans borne, au fil des envois refusés. Chaque chemin
l'efface maintenant dans un `finally` : `AssetService.addAssetStream` (quand l'envoi porte un contenu ;
le chemin d'écriture externe garde volontairement son fichier pour l'appelant),
`uploadTempFileToS3` et `uploadAssetFile` (stocké ou refusé), et `UserAvatarService.uploadAvatar`, qui
efface aussi l'avatar redimensionné et l'original déposé dans S3 pour imgproxy, quel que soit l'échec.
Les autres fichiers temporaires du backend (`GpxProcessingService`, `ThumbnailService`,
`RouteCopyService`, les rattrapages) les effaçaient déjà. Couvert par
`AssetResourceTest#uploadAsset_refused_leavesNoTempCopy` et
`UserResourceTest#uploadAvatar_refused_leavesNoTempCopy`.
