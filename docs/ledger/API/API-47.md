---
id: API-47
title: "Les documents joints gardent leurs métadonnées"
status: open
group: "Vie privée : ce que la politique doit encore décrire faute de mieux"
verified: 2026-11-16
---

## Reste à faire

`API-47` **Les documents joints gardent leurs métadonnées** — PDF (auteur, JPEG embarqués
avec leur EXIF), fichiers bureautiques (`docProps`), PSD (EXIF/IPTC) sont stockés tels quels ;
la politique (§1) le dit. À trancher : les nettoyer (dépendance nouvelle pour le PDF), ou
garder la phrase. Taille : M à L. exiftool **n'aide pas** (mesuré le 29 septembre 2026,
`API-54`) : il ajoute une mise à jour incrémentale réversible, le dictionnaire Info reste dans
les octets, et l'EXIF des JPEG embarqués est intact. Seule voie : réécriture complète (PDFBox)
en faisant réencoder les JPEG embarqués comme les images (`API-43`). L'enjeu est mince : au
16 octobre 2026, la prod compte 8 PDF parmi ses pièces jointes, et aucun fichier bureautique
ni PSD ; garder la phrase (« Délibérément dehors ») reste une issue (décision du propriétaire).
