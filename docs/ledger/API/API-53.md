---
id: API-53
title: "HEIC, HEIF, AVIF, TIFF et JPEG XL acceptés, stockés en JPEG"
status: done
group: "Vie privée : les métadonnées retirées à l'import"
done: 2026-09-29
---

## Livré

`API-53` **HEIC, HEIF, AVIF, TIFF et JPEG XL acceptés, stockés en JPEG** (2026-09-29, contrat
inchangé) — refusés un temps par `API-43` faute de savoir en retirer les métadonnées sans perte,
alors qu'iOS produit du HEIC par défaut. Le réencodage par imgproxy d'`API-43` les lit tous
(conversion vérifiée sur un corpus réel) et les écrit en
JPEG : format lu partout, y compris par les apps et les visionneuses de téléchargement, et sans
la limite de 16 383 px du WebP qui aurait refusé les panoramas. Une transparence (AVIF, TIFF)
est aplatie. Tests : `AssetServiceTest.MetadataRemoval.acceptsAHeicPhotoAndStoresAJpeg` et
`acceptsATiffAnAvifAndAJpegXl`, `StorageImageReencodingTest`.
