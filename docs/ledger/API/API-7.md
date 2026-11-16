---
id: API-7
title: "Poids des pièces jointes"
status: done
group: "Petites évolutions d'API"
done: 2026-09-30
---

## Livré

| ID | Livré | Écrans |
|---|---|---|
| `API-7` | **Poids des pièces jointes** (2026-09-30) — **API 6.3.0** : `AssetDto.size`, nullable, en octets, **le poids du fichier tel que stocké** — donc de ce qu'un téléchargement renvoie, une image comptée après son ré-encodage (`API-43`), pas telle qu'envoyée. Colonne `assets.file_size` (V49, nullable ; l'attribut s'appelle `fileSize` parce que `size` est une fonction HQL). `StorageService.store` rend désormais le nombre d'octets écrits, et chaque chemin d'écriture le relève : envoi (`addAssetStream`), fichier temporaire (`uploadAssetFile` : vignettes, import biketeam), GPX/FIT d'un parcours (`uploadTempFileToS3` → `persistAsset`), ré-encodage par `AssetMetadataBackfill`, réécriture par `GpxSanitizationBackfill`. L'existant est rempli par `AssetSizeBackfill` (un HEAD par asset, rien de téléchargé, 200 par minute) ; son curseur **ne revient jamais en arrière** — un fichier manquant n'est regardé qu'une fois par démarrage — et les lignes qu'une release précédente écrit pendant un déploiement roulant, d'id plus grand, sont prises au passage suivant. Sa mise à jour ne s'applique **que si la taille est encore nulle** (`recordSizeIfUnknown`) : ne pas la rendre inconditionnelle, un ré-encodage concurrent verrait sa taille écrasée par une lecture antérieure. Nul = inconnu : **les clients omettent le poids, ne l'estiment jamais**. Le mobile (`media_attachments.dart`, les huit écrans à pièces jointes) rend « PDF · 240 ko », « JPG · 1,2 Mo · 1920 × 1080 » ; le web (`MediaDisplay`) le poids à droite du nom. Unités décimales, « ko » en français (`AppFormatters.formatFileSize`, `formatFileSize` web). Couvert par `AssetSizeBackfillTest`, les assertions de taille d'`AssetServiceTest` (envoi, image ré-encodée ≠ taille envoyée, fichier temporaire), `AssetMetadataBackfillTest.aTiffBecomesAJpegAndItsAssetFollows`, `GpxSanitizationBackfillTest.sanitizeAll_rewritesARouteStoredWithTimestampsAndSensors` (import puis réécriture), `formatters_test.dart` et `unitFormat.test.ts` | 31, 32 |
