---
id: MOB-77
title: "Éditeur de sortie, modèles et parcours : recette sur appareil"
status: open
size: "S"
group: "Couverture e2e Patrol — ce que les tests ne couvrent pas encore"
verified: 2026-11-16
---

## Reste à faire

`MOB-77` **Éditeur de sortie, modèles et parcours : recette sur appareil (S)** — `MOB-80` est
couvert par les tests unitaires et de widget, et par `ride_editor_test` et
`ride_editor_member_test` (Patrol, verts le 17 octobre 2026 sur le simulateur iOS et sur
l'émulateur Android, de nouveau le 16 novembre 2026 avec `ride_templates_test` et
`route_editor_test`). Reste la recette à la main : créer une sortie depuis le tableau de bord (modèle compris), y
ajouter une image depuis la photothèque et une pièce jointe depuis le sélecteur de fichiers,
la modifier depuis sa fiche, la publier puis la supprimer et la restaurer — en organisateur,
et vérifier qu'un simple membre ne voit ni le crayon ni le menu « Gérer la sortie ». Clés dans
`keys.rideEditor` / `keys.rideManage`. **Modèles de sortie (`MOB-78`)** : les tests Patrol
`ride_templates_test` et `ride_templates_member_test` sont verts (17 octobre 2026, simulateur
iOS et émulateur Android) ; reste la recette à la main des modèles
(« Gérer les modèles » du tableau de bord et de la feuille « Charger un modèle », liste,
création, modification, suppression, création d'une sortie numérotée « Nom #n »), en
organisateur, et le refus d'un simple membre. Clés dans `keys.rideTemplates` /
`keys.rideTemplateEditor`. Le formulaire *Data safety* de Google Play
(ligne *Fichiers et documents*) est poussé depuis le 16 novembre 2026, avec la 1.2.0.
**Parcours (`MOB-79`)** : `route_editor_test` et `route_editor_member_test` sont verts (18 octobre
2026, simulateur iOS et émulateur Android) ; reste la recette à la main avec le vrai sélecteur (Fichiers d'iOS, SAF d'Android), des GPX de
plusieurs outils et d'un compteur, nom repris du GPX, remplacer le GPX, supprimer et
restaurer, refus d'un simple membre. Clés dans `keys.routeEditor` / `keys.routeManage`. Le
sélecteur natif n'est jamais exercé par Patrol (le fichier arrive par
`gpxFilePickerProvider`) : la recette à la main est le seul garde. La ligne *Fichiers et
documents* de Google Play couvre aussi le GPX (`data-safety.md` #23).

**Recette du 16 novembre 2026 sur un Pixel 6a (Android, app 1.2.0 build 107, prod, administrateur de l'équipe privée « Gaby », sombre)** — sortie : création par le lien `…/sorties/nouvelle`, pièce jointe par le sélecteur de
fichiers d'Android (SAF), feuille de choix du parcours, second groupe, brouillon, publication, suppression et
restauration : conformes. Parcours : import d'un GPX par le vrai sélecteur (nom repris du fichier), remplacement du
GPX par un tracé de 686 km, suppression et « Restaurer » proposé : conformes. **Restent** : une image de la
photothèque dans une sortie, la modification depuis la fiche, les modèles de sortie (`MOB-78`), des GPX de plusieurs
outils et d'un compteur, le regard d'un simple membre, le clair et iOS.
