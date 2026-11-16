---
id: WEB-32
title: "Une image se glisse ou se colle dans l'éditeur"
status: done
group: "Défauts d'interface"
done: 2026-09-30
---

## Livré

`WEB-32` **Une image se glisse ou se colle dans l'éditeur** (2026-09-30, sans changement de
contrat) — seul le bouton de la barre d'outils téléversait une image. `MarkdownEditor` prend
maintenant les fichiers déposés (`handleDrop`, à l'endroit du lâcher) et collés (`handlePaste`, au
curseur) par le même téléversement : `tiptap/insertAsset.ts` (`imageFiles`, `uploadAndInsert`),
que le bouton utilise aussi. Plusieurs images arrivent dans l'ordre, **l'une après l'autre** : chaque
téléversement ajoute à la liste d'assets du formulaire, des écritures parallèles s'y
marcheraient dessus. Un fichier qui n'est pas une image, un éditeur sans équipe ou en lecture
seule laissent l'événement à ProseMirror ; un déplacement d'image à l'intérieur de l'éditeur
aussi. Couvert par `tiptap/insertAsset.test.ts` (filtre, HEIC sans type MIME, ordre, échec
isolé) ; le glisser-déposer réel n'a pas de test e2e.
