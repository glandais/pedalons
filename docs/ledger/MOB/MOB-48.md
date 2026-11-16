---
id: MOB-48
title: "Le profil en vue d'ensemble et sous-pages, même arbre que le site"
status: done
group: "Profil"
done: 2026-10-04
---

## Livré

`MOB-48` **Le profil en vue d'ensemble et sous-pages, même arbre que le site** (4 octobre 2026,
**API 10.7.0**, maquette validée du 4 octobre). L'onglet Profil est une **racine** (plus de flèche
retour sur `/profil`) : carte d'identité (vers Mon compte), puis des raccourcis groupés, chacun
avec sa **ligne d'état** — Mon activité (Mes sorties : « Prochaine : … » et compteur ; Mes équipes,
qui ouvre l'onglet Équipes), Réglages (Préférences, Notifications, Appareils et services),
Sécurité et confidentialité (Connexion et sécurité, Confidentialité), Compte (Mon compte — ligne
ajoutée le 4 octobre, clé `keys.profile.accountRow`, statut fixe « Photo, nom affiché, suppression
du compte » —, Aide et à propos, Se déconnecter). Une route par sujet dans la branche Profil du
shell (`config/router.dart`), sous `ProfileSubpage` (retour : `pop`, sinon `go` vers `/profil` ;
flèche retour de `PdlAppBar` clé `keys.profile.backButton` via le nouveau paramètre `backKey`) :
`/profil/sorties` (À venir ·
Historique), `/profil/preferences` (unités, **fuseau horaire, nouveau dans l'app**, même champ
`UserDto.timezone` que le site, feuille de recherche `timezone_sheet.dart`), `/profil/notifications`
(`notification_settings_page.dart` : une ligne par type groupée en familles Sorties, Voyages,
Publications, Équipes et modération, une **puce à bascule par canal** E-mail/Push, Annonces des
équipes, « Ouvrir mes notifications » ; la boîte de réception a un bouton Réglages),
`/profil/appareils`, `/profil/securite` (Clés d'accès, `LogoutAllCard`), `/profil/vie-privee`
(Être contacté par les membres, Utilisateurs bloqués, Rapports d'erreur, Mes données), et sa
sous-route **`/profil/vie-privee/bloques`** (EN `/profile/privacy/blocked`, déplacée de
`/profil/bloques` le 4 octobre) : route go_router **enfant** de `profilePrivacy`
(`_profilePrivacyRoutes()`), ancêtres de lien profond Profil › Confidentialité, plus de repli
spécial du retour ; `/profil/compte` (identité, `DeleteAccountSection`), `/profil/aide`. Les
lignes d'état lisent `/me` et `profileSummaryProvider` (`GET /api/users/me/profile-summary`,
`API-69`) ; `participationCountProvider` est supprimé. Tirer pour rafraîchir la vue d'ensemble
relit le résumé **et** `/me` (`refreshCurrentUser`, échec de `/me` ignoré) ;
`ProfileSummaryRefreshOnLeave` (`profile_subpage.dart`, autour de `ProfileSubpage`,
`MyParticipationsPage` et `BlockedUsersPage`) invalide `profileSummaryProvider` quand **toute**
sous-page quitte l'arbre, lien profond suivi d'un `pop` compris — la vue d'ensemble n'invalide
plus après son `push`. `PdlChip` répond sur toute sa boîte de 44 px (un `GestureDetector` opaque
autour de la pastille de 34 px), pour **toutes les puces de l'app** (tests de filtres
`route_filters`, `route_filter_chips_bar`, `route_filter_sheet`, `tag_filter`,
`team_list_tag_filter`, `publication_feed_toolbar` verts). Le lexique vaut aussi hors du profil
(`WEB-57`). Tests : `test/features/profile/profile_overview_test.dart` (ligne Mon compte,
tirer pour rafraîchir), `profile_summary_refresh_test.dart` (sous-page ouverte par lien froid
puis `pop` : le résumé est relu), `profile_subpages_test.dart`,
`profile_page_test.dart` (fuseau envoyé au serveur), `profile_summary_provider_test.dart`,
`test/features/notifications/notification_settings_page_test.dart`,
`test/deep_link_hierarchy_test.dart` (les nouvelles routes, `blockedUsers` → [profile,
profilePrivacy]), `test/core/pdl/tap_target_test.dart`
(« PdlChip répond aussi dans les 5 px autour de sa pastille »),
`test/features/rides/participation_changes_test.dart` ; Patrol `notification_settings_test`,
`profile_timezone_test`, `block_user_test` (lien froid vers les bloqués, retour sur
Confidentialité) et les tests du profil repris (modules `Profile.openX` / `backToOverview` et
`Moderation.backToPrivacy`, qui touchent `keys.profile.backButton`), verts depuis le 6 octobre
2026 (`MOB-49`). **Tranché avec le propriétaire le 4 octobre** : ligne « Mon compte » dans le groupe
Compte (en plus de la carte d'identité) ; **pas de cloche dans l'en-tête du Profil** (un `push`
d'une branche à l'autre empilerait les branches — la boîte de réception reste à un onglet) ;
Utilisateurs bloqués **sous** Confidentialité, dans l'URL comme dans la pile. **À ne pas
défaire** : pas de cloche dans l'en-tête du Profil (`MOB-50`) ; la route des bloqués reste imbriquée sous
`profilePrivacy` (c'est ce qui met Confidentialité sous elle quand elle est ouverte par `go`) ;
l'invalidation de `ProfileSummaryRefreshOnLeave` passe par `scheduleMicrotask` (invalider dans
`dispose` lève « markNeedsBuild called when widget tree was locked ») ; un **arbre unique et un
lexique commun** aux deux clients (Profil, Nom affiché, Adresse e-mail, Clés d'accès, Mon compte,
Demander mes données, Être contacté par les membres, Résumé quotidien par e-mail, Annonces des
équipes) — un sujet change de place ou de nom des deux côtés à la fois ; une route `/profil/<sujet>`
par sujet, jamais d'ancre ; les canaux affichés sont **ceux que le serveur déclare**
(`channels`) : sans `EMAIL`, ni puce E-mail ni résumé quotidien, `IN_APP` jamais réglable ; une
puce n'écrit que sa cellule ; les lignes d'état viennent de `/me` + profile-summary, jamais d'un
appel par sujet ; `notifyParticipationChanged` et `refreshAfterBlockChange` invalident
`profileSummaryProvider`, qui se recharge aussi quand l'ensemble de mes équipes change
(`myTeamsProvider`) ; Se déconnecter une seule fois dans le profil ; la navigation entre branches
(profil → boîte de réception ou Équipes, boîte → réglages) passe par `go`, jamais `push` ; l'ouverture
d'une sous-page passe par `pushLocation` (`MOB-44`), qui reprend la pile du lien profond quand on
part d'une page plein écran (`test/core/utils/push_location_test.dart`).
