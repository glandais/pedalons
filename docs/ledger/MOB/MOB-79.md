---
id: MOB-79
title: "Créer, modifier et supprimer un parcours dans l'app (17 octobre 2026, contrat d'API inchangé)"
status: done
group: "Tableau de bord d'équipe"
done: 2026-10-17
---

## Livré

### `MOB-79` Créer, modifier et supprimer un parcours dans l'app (17 octobre 2026, contrat d'API inchangé)

`MOB-79` **Éditeur de parcours par import de fichier GPX, à parité avec le site sauf le
planificateur** — détaché de `MOB-24`. Un organisateur ou un administrateur de l'équipe (et
l'admin de plateforme), module parcours actif — la règle de `RouteAccessChecker`, qui n'exige
**pas** le module sorties —, crée, modifie et supprime un parcours. La règle de rôle est celle de
`canManageRides` ; `canManageTeamRoutes`
(`mobile/lib/features/rides/domain/ride_permissions.dart`) y ajoute le seul module parcours, et
`canManageRoutesProvider` (`…/routes/providers/route_editor_providers.dart`) la sert à l'écran
sur la même base que `canManageRidesProvider` (`teamManagePermission`, extraite). **Le tracé ne
se dessine pas dans l'app** : `points` n'est jamais envoyé, le planificateur reste au site.
Écrans : « Ajouter » à droite de la recherche de la section Parcours d'une équipe
(`routes_page.dart`, rien pour un simple membre ni sur l'onglet de toutes les équipes) ;
`RouteEditorPage` (`…/routes/presentation/pages/route_editor_page.dart`) — étape 1 de la
création : `GpxPickStep` (« Envoyer un fichier GPX »), puis le formulaire : section Tracé
(`RouteTrackSection`), nom repris du GPX (`<name>` de `<metadata>`, sinon de la première
`<trk>`, sinon le nom du fichier) sans jamais écraser un nom tapé, adresse (slug,
`showSlugEditSheet`) en modification, surface, visibilité (masquée pour une équipe `TEAM`),
tags, description markdown, logo, images et pièces jointes (`RideMediaSection`), confirmation
avant d'abandonner. La fiche porte le crayon et le menu « Gérer le parcours »
(`route_manage_menu.dart` : modifier, remplacer le fichier GPX, supprimer après confirmation,
restaurer, signaler) ; un parcours supprimé n'offre que « Restaurer ». Un fichier refusé
(extension, contenu, taille, ou 400 `GPX_FAILURE`/`GPX_EMPTY`/`GPX_TOO_LONG`/`FILE_TOO_LARGE` du
serveur) s'affiche en bandeau « Fichier refusé » avec « Choisir un autre fichier ». Extractions
partagées avec l'éditeur de sortie, sans changement de comportement : `EditorMediaActions`
(images, logo, pièces jointes) et `showSlugEditSheet`. `routeNew` et `routeEdit` sont devenus des
écrans de l'app et des deeplinks dans `contracts/routes.yaml` (hiérarchie Équipe › Parcours :
la création sous la liste, l'édition sous la fiche, `routeNew` **avant** le détail dans le
routeur et dans les hiérarchies, `…/parcours/nouveau` étant aussi le parcours de slug
`nouveau`). `notifyRouteChanged` (`route_changes.dart`) invalide fiche, usages, listes, aperçus,
compteurs, emprises, tableau de bord, compteurs de tags et caches de l'éditeur de sortie.
**Confidentialité** : l'app gagne l'**import** d'un GPX — `data-safety.md` (§1, #23, §3 à §5, §7,
§8, « How to re-verify »), commentaire de `PrivacyInfo.xcprivacy` ; aucune catégorie nouvelle
(*Fichiers et documents* et `OtherUserContent` sont déclarés), pas de *Precise Location* : le
fichier peut venir d'une sortie enregistrée, mais l'organisateur le publie comme parcours d'équipe,
l'app ne lit pas la position de l'appareil, et le serveur ne garde que la géométrie : horodatages,
mesures de capteurs et métadonnées sont retirés avant stockage (`GpxSanitizer`) ; `data-safety.csv` et `app-privacy.json` inchangés, la politique
(§ « GPX files you import ») couvre déjà le cas. **Correctif de l'intercepteur** :
`AuthInterceptor` rejouait une requête 401 avec le même `FormData`, déjà finalisé ; le
`StateError` était pris pour un échec du rafraîchissement et **déconnectait** l'organisateur qui
envoyait un GPX avec un jeton expiré (même risque pour l'avatar et les assets) —
`retryableOptions` clone le `FormData` avant chaque rejeu. **Et le rejeu sort du `try` du
rafraîchissement** : une erreur du rejeu (400 `GPX_FAILURE`, 413, coupure réseau pendant
l'envoi) remonte telle quelle, sans déconnecter, et l'écran reçoit la vraie erreur, pas le 401
d'origine (`auth_interceptor_retry_test.dart`, rejeu refusé puis rejeu réussi). Tests : `gpx_check_test.dart`,
`route_form_test.dart`, `ride_permissions_test.dart`, `route_repository_write_test.dart`,
`auth_interceptor_retry_test.dart`, `route_editor_page_test.dart`,
`route_manage_menu_test.dart`, `routes_add_button_test.dart`, `ride_editor_page_test.dart`,
`link_launcher_test.dart`, `deep_link_hierarchy_test.dart`, `team_web_paths_test.dart` ;
`flutter analyze` sans remarque, `flutter test` vert (1 213 tests). Tests Patrol
`route_editor_test` et `route_editor_member_test`, verts sur le simulateur iOS et l'émulateur
Android : ils ont révélé que seul un **administrateur** de l'équipe relit un élément supprimé
(`IncludeDeletedService`), d'où les textes « Un administrateur de l'équipe pourra le
restaurer » (parcours et sorties), et qu'une carte notifiait un contrôleur détruit quand sa fiche
se fermait avant la fin du chargement de son style (`PdlMap` / `PdlMapController`, corrigé) ; le
sélecteur natif n'y est jamais exercé, le fichier arrive par `gpxFilePickerProvider`. **À ne pas
défaire** : la forme du multipart est celle du site — le champ `route` est le JSON de la requête,
le fichier la partie `gpxFile` en `application/gpx+xml` — et `route_repository_write_test` la
fige contre une régénération du client ; le refus d'un membre est tranché **avant** de lire le
parcours (sinon un parcours d'équipe privé donne un 403 au lieu du refus) ; `tagIds` part
toujours, `[]` compris, nul laisserait les tags en place ; « Remplacer le GPX » passe par le
formulaire de modification, parce que le PUT exige la requête entière (nom, médias, surface,
visibilité, tags) et qu'un envoi du seul fichier ne relirait rien ; le sélecteur est
`FileType.any` suivi d'un contrôle local (`.gpx` et `<gpx`), `gpx` n'ayant pas de type uniforme
sur iOS ; `gpxFilePickerProvider` reste un `StateProvider`, c'est ce qui laisse Patrol le
remplacer ; un `FormData` est cloné avant tout rejeu après un 401, et seul l'échec du
rafraîchissement déconnecte ; un fichier refusé par le serveur est oublié (retour au tracé actuel
en modification, à l'étape 1 en création, formulaire gardé), alors qu'un refus local garde le
fichier précédent, accepté ; aucun tracé ni retouche sur carte. Sur la fiche, l'overlay d'un
organisateur porte retour, partager, crayon et `⋯` (maquette) ; le partage du pied de la fiche
reste, pour tous. Limite assumée : `routeCount` de l'équipe se rafraîchit
au prochain chargement, et les tuiles `.mvt` de la carte restent en cache MapLibre : un tracé
remplacé n'y apparaît qu'à l'expiration du cache.
