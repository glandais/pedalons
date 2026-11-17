---
id: API-47
title: "Les documents joints gardent leurs métadonnées"
status: out
group: "Vie privée : ce que la politique doit encore décrire faute de mieux"
---

## Écarté

| ID | Sujet | Décision | Ce que ça implique |
|---|---|---|---|
| `API-47` | **Les documents joints gardent leurs métadonnées** : PDF (auteur, dictionnaire Info, XMP, JPEG embarqués avec leur EXIF), fichiers bureautiques (`docProps`), PSD (EXIF/IPTC) | Gardés tels quels (décidé le 17 novembre 2026 avec le propriétaire) | La politique le dit (§4, « Photos et images » : « Les autres fichiers joints (PDF, documents…) sont conservés tels que vous les envoyez, avec leurs métadonnées »), en français et en anglais. Les images jointes sont réencodées (`API-43`), les GPX et FIT réécrits (`TrackAttachmentSanitizer`) : seuls les autres documents gardent leurs métadonnées. Enjeu mesuré le 17 novembre 2026 : 8 PDF (12 Mo) parmi les pièces jointes de la prod, aucun fichier bureautique ni PSD. exiftool ne nettoie pas un PDF (mesuré le 29 septembre 2026, `API-54`) ; la seule voie, une réécriture par PDFBox avec réencodage des JPEG embarqués, invaliderait les signatures, risquerait les formulaires et dégraderait les plans scannés. À rouvrir si les pièces jointes non-image deviennent courantes ; la phrase de la politique doit alors changer avec le code |
