---
id: LEGAL-9
title: "Métadonnées des fichiers téléversés retirées à l'import"
status: done
done: 2026-09-29
---

## Livré

`LEGAL-9` **Métadonnées des fichiers téléversés retirées à l'import** (2026-09-29) — les photos
perdent EXIF, XMP, IPTC et commentaires, orientation gardée (`API-43`) ; les GPX ne gardent que
la trace et les waypoints (`API-44`) ; les deux rattrapages nettoient ce qui était déjà stocké.
Le §1 de la politique (« Fichiers GPX que vous importez », « Photos et images », fichiers
téléchargés par l'app mobile) dit désormais ce qui est retiré et ce qui est gardé, à la place des
avertissements sur l'EXIF, les photos d'annonce et les données de santé ; il dit aussi que les
formats non nettoyables sont refusés et que les autres pièces jointes (vidéos, documents, GPX
joints) sont gardées telles quelles (`API-46`, `API-47`, `API-49`). Opportunités #5 et #6.
