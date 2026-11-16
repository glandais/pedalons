---
id: MOB-80
title: "Créer et modifier une sortie dans l'app (17 octobre 2026, contrat d'API inchangé)"
status: done
group: "Tableau de bord d'équipe"
done: 2026-10-17
---

## Livré

### `MOB-80` Créer et modifier une sortie dans l'app (17 octobre 2026, contrat d'API inchangé)

`MOB-80` **Éditeur de sortie, à parité avec le site sauf la création de parcours** — détaché de
`MOB-24`, qui reste dehors pour le reste du contenu. Un organisateur ou un administrateur de
l'équipe (et l'admin de plateforme), modules sorties **et** parcours actifs — la règle de
`RideAccessChecker`, recopiée dans `canManageRides` / `canManageTeamRides`
(`mobile/lib/features/rides/domain/ride_permissions.dart`) et `canManageRidesProvider` —, crée et
modifie une sortie dans `RideEditorPage` (`…/rides/presentation/pages/ride_editor_page.dart`) :
nom, adresse (slug, `PATCH …/slug`), description markdown avec barre d'outils et aperçu, logo,
images et pièces jointes (`POST …/assets`), date et heure dans le fuseau de la sortie (lieu de
départ, sinon départ du parcours, sinon équipe, avec la mention « heure de … »), lieux de départ
et d'arrivée, tags (10 au plus), visibilité (masquée pour une équipe `TEAM`), statut,
publication programmée, parcours, et groupes (nom, heure, vitesse dans l'unité du membre, places,
**meneur**, parcours, ordre ; confirmation avant de retirer un groupe qui a des inscrits).
« Charger un modèle » et `?template=` pré-remplissent comme `templateForNewRide`. La fiche porte
un crayon et un menu « Gérer la sortie » (`ride_manage_menu.dart`) : publier, dépublier,
annuler, rétablir (`PATCH …/status`), supprimer, restaurer. Le tableau de bord (« Créer une
sortie », « Modifier », brouillons, sorties sans parcours, modèles) ouvre ces écrans au lieu du
site. `rideNew` et `rideEdit` sont devenus des écrans de l'app et des deeplinks dans
`contracts/routes.yaml` ; l'édition est une route enfant du détail, et un lien froid reconstruit
Agenda › fiche dessous. Nouvelle dépendance `file_picker` (pièces jointes) : déclarée dans
`mobile/store-metadata/data-safety.md` (#21, #22), le CSV Google Play (*Fichiers et documents*)
et `PrivacyInfo.xcprivacy` ; la phrase d'accès aux photos d'iOS nomme l'éditeur. Tests :
`ride_form_test.dart`, `markdown_edit_test.dart`, `ride_permissions_test.dart`,
`ride_editor_page_test.dart`, `link_launcher_test.dart`, `deep_link_hierarchy_test.dart`,
`team_web_paths_test.dart` ; `bash check.sh` vert (1 081 tests). Pas encore de recette sur
appareil ni de test Patrol : ledger `MOB-77`. **À ne pas défaire** : la description reste du
**markdown brut** (`markdown_edit.dart`) — un éditeur riche mobile réécrirait à l'enregistrement
ce que Tiptap a produit, directives `::asset{id="…"}` comprises, qui placent les images (levé par
`MOB-160` : l'éditeur riche de l'app *est* celui du site, sa sérialisation comprise) ; une
image ajoutée s'insère comme au site (`createAssetDirective`) et une image retirée emporte ses
directives. Le PUT réécrit **tous** les champs : `RideForm.fromRide` renvoie l'id de chaque
groupe, son `leaderId` et les deux lieux, sinon le serveur les efface (et supprime les
inscriptions d'un groupe sans id). Les dates partent en heure murale sans offset
(`EventDateTime`). Le meneur n'est que `leaderId`, jamais le créateur (`API-30`). Les
changements de statut passent par `PATCH …/status`, pas par un PUT recopié du détail (tags
supprimés entre-temps : `TAG_INVALID`). Après chaque écriture, `notifyRideChanged`
(`ride_changes.dart`) invalide fiche, fil, tableau de bord, accueil et calendrier.
