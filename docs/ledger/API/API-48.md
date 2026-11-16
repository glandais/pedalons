---
id: API-48
title: "Une icône est réencodée en PNG"
status: done
group: "Vie privée : les métadonnées retirées à l'import"
done: 2026-09-30
---

## Livré

`API-48` **Une icône est réencodée en PNG** (2026-09-30, contrat inchangé, pas de migration) —
un ICO passait la liste blanche `IMAGE` sans être réencodé, et ses images peuvent être des PNG
avec leurs blocs `tEXt`/`eXIf`. `ImageFormat` le reconnaît à son en-tête (réservé 0, type 1, au
moins une image, octet réservé de la première entrée à 0 — pour ne pas le confondre avec un flux
MPEG qui s'ouvre aussi sur `00 00 01`) et `S3StorageService.store` le fait réencoder par imgproxy
**en PNG** : `favicon.ico` est stocké `favicon.png`, `image/png`. L'autre moitié de l'entrée,
les SVG, est réglée par `SEC-1` (refusés à l'envoi). **Rien d'existant à rattraper** : la
production ne contenait encore aucun fichier (décision de l'utilisateur, pas de rattrapage ni de
migration). **La politique de confidentialité ne change pas** : son §1 disait déjà que toute image
est réencodée ou refusée, ce qui devient exact pour les icônes. Couvert par
`ImageFormatTest.anIconBecomesAPng`, `StorageImageReencodingTest` (`photo.ico`, le `photo.png` de
test et ses métadonnées dans un conteneur ICO) et `AssetServiceTest.storesAnIconAsAPngWithoutItsMetadata`.
