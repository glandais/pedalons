---
id: API-46
title: "Les vidéos ne sont plus acceptées"
status: done
group: "Vie privée : les métadonnées retirées à l'import"
done: 2026-09-30
---

## Livré

`API-46` **Les vidéos ne sont plus acceptées** (2026-09-30, contrat inchangé, pas de migration) —
une pièce jointe MP4/MOV était stockée telle quelle, avec le lieu de la prise dans `udta`/`meta`.
Décision de l'utilisateur : **refuser les vidéos plutôt que les nettoyer**. Retirer `udta`/`meta`
(même en les remplaçant par des boîtes `free` de même taille) aurait laissé les dates de `mvhd` et
surtout les **pistes GPS temporisées** des caméras d'action (GoPro `gpmd`, DJI), qui sont des
pistes du `moov` et non des boîtes de métadonnées : les retirer demande de réécrire `moov` et les
tables d'offsets (`stco`/`co64`). Refus sur deux lignes : les étiquettes Magika `mp4`, `qt`, `3gp`,
`mkv`, `webm` et `flv` entrent dans la liste noire `ATTACHMENT` ; et `FileTypeDetector.refuseVideo`
refuse, en image comme en pièce jointe, tout conteneur vidéo lu à ses premiers octets, quels que
soient l'étiquette et le nom : ISO base media (`ftyp`) qui n'est pas une image fixe (HEIF et AVIF
sont reconnus avant par `ImageFormat`), EBML (Matroska, WebM), AVI, FLV. **Effet de bord
assumé** : l'audio M4A, qui partage le conteneur ISO base media, est refusé avec eux. **Rien
d'existant** : la production ne contenait aucune vidéo. **Politique de confidentialité modifiée**
(§1, français et anglais ensemble) : les vidéos ne sont pas acceptées, et pourquoi ; les autres
pièces jointes restent conservées telles quelles. Couvert par `FileTypeDetectorTest.Videos` (MP4,
MOV, 3GP, WebM, AVI, FLV, un conteneur MP4 nommé `.pdf`, une WebP qui n'en est pas une) et
`FileTypeCategoryTest.Attachment.rejectsVideoLabels`.
