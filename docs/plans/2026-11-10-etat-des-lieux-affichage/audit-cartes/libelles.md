# Audit d'homogénéité des cartes : libellés et vocabulaire

**Synthèse.** Les deux supports partagent la plupart des clés de carte (« J'y vais », « Départ {time} », « Capitaine »,
« Complet », « Secteur {place} », compteurs de personnes, groupes et étapes, mêmes valeurs mot pour mot). Les écarts qui
restent sont de trois sortes. (1) Des actions ou des informations qui ne portent pas le même nom : « GPS » contre
« Envoyer vers l'appareil », « Changer pour B » sans équivalent sur le site, « Admin » contre « Administrateur », « Équipe »
contre « Équipe uniquement », les statuts de webhook. (2) Des formulations voisines pour une même phrase : notifications,
états vides, météo, membres. (3) Des défauts de forme propres à chaque support : « ... » et « … » mélangés, un pluriel
cassé dans l'app (« 1 membres »), « Adhésion... » pour rejoindre un groupe de sortie, guillemets droits sur le site, et
« Utilisée dans » (au féminin, alors que « parcours » est masculin) des deux côtés.

Légende : *lu* = valeur et règle lues dans le code ; *déduit* = conséquence tirée de la lecture, sans l'avoir vue à
l'écran. Les clés app sont dans `mobile/assets/l10n/fr.json` et les clés site dans `frontend/src/locales/fr/common.json`.
Chemins abrégés : `m/` = `mobile/lib/features/`, `w/` = `frontend/src/components/`.

## 1. Badges et statuts

| # | Sujet | Cartes concernées | App (valeur · fichier:ligne) | Site (valeur · fichier:ligne) | Verdict | Gravité |
|---|---|---|---|---|---|---|
| 1.1 | Badge « Publié » | fil, annonce | jamais affiché : seul `status.draft` « Brouillon » (post) ou `status.cancelled` « Annulé » (sortie) sont des badges · `m/teams/presentation/widgets/publication_card.dart:387-391,502-503`, `m/ads/presentation/widgets/ad_card.dart:100-105` (commentaire : « le statut publié … ne se badge pas ») | toujours affiché, « Publié » compris · `w/card/PublicationCard.tsx:247` (`status.${status}`), `w/card/AdCard.tsx:66-68` | confirmé | moyenne |
| 1.2 | Badge de visibilité | fil, annonce | absent des cartes de publication et d'annonce ; présent sur la carte de parcours · `route_card.dart:141-149` | toujours affiché · `PublicationCard.tsx:248`, `AdCard.tsx:69`, `RouteCard.tsx:89` | confirmé | moyenne |
| 1.3 | Sortie passée | fil | badge « Terminée » (`rides.finished`) · `publication_card.dart:399-400` | aucun badge de fin sur `PublicationCard.tsx` (seulement `InProgressBadge` « En cours », l.231) | confirmé | moyenne |
| 1.4 | « Annulé » sur Ma prochaine sortie | prochaine sortie | badges « Sortie », « J'y vais », « Annulé » · `m/home/presentation/widgets/next_ride_card.dart:219-233` | ni badge de type ni statut, seul « J'y vais » sur l'image · `w/home/NextRideCard.tsx:126-133` (aucune lecture de `status` dans le fichier) | confirmé | forte (une sortie annulée qui reste « Ma prochaine sortie » sans le dire) |
| 1.5 | Statuts non publiés au calendrier | agenda, 7 jours | seul « Annulé » (`calendar.cancelled`) · `m/calendar/presentation/widgets/agenda_card.dart:244-249`, `m/home/.../week_agenda_section.dart:219-224` | tout statut ≠ PUBLISHED, « Brouillon » compris · `w/calendar/CalendarView.tsx:293-297`, `w/agenda/AgendaRow.tsx:56-60`, `w/home/WeekAgenda.tsx:167-169` | nouveau | faible |
| 1.6 | Coche de « J'y vais » | 7 jours | avec coche (`PdlIcons.check`) · `week_agenda_section.dart:213-218` | sans coche · `WeekAgenda.tsx:170-173` | confirmé (seulement sur cette carte : fil, agenda et prochaine sortie ont la coche des deux côtés ; la carte de groupe ne l'a ni d'un côté ni de l'autre, `ride_group_card.dart:221-225`, `RideGroupCard.tsx:127-131`) | faible |
| 1.7 | Ordre des badges | fil | Supprimé → type → statut / En cours / Terminée → J'y vais · `publication_card.dart:381-408` | Supprimé → En cours → J'y vais → type → statut → visibilité · `PublicationCard.tsx:226-248` | confirmé | faible |
| 1.8 | Accord des statuts | fil, annonce, parcours | « Annulé », « Publié », « Supprimé » au masculin à côté de « Sortie », « Annonce », « Publication » ; mais « Terminée » au féminin · `status.*`, `rides.finished` | « Annulé », « Publié », « Supprimé » (`status.CANCELLED`, `status.PUBLISHED`, `status.DELETED`, l.2252-2257) | nouveau (commun aux deux) | faible |

## 2. Rôles et visibilité

| # | Sujet | Cartes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| 2.1 | Rôle administrateur | équipe, membres | « Admin » (`roles.admin`, fr.json l.189) via `AppFormatters.roleName` · `m/teams/presentation/pages/teams_page.dart:278`, `team_members_page.dart:312` | « Administrateur » (`roles.ADMIN`, l.2047) · `w/card/TeamCard.tsx:45`, `w/team/TeamMemberList.tsx:69`, `w/home/MyTeamsCard.tsx:100` | confirmé | moyenne |
| 2.2 | Visibilité « équipe » | fil, parcours, modèle | « Équipe » (`visibility.team`), y compris dans les messages qui la citent (`visibility.noneAllowed`, `visibility.routeInUse.message`) · `route_card.dart:142` | « Équipe uniquement » (`visibility.team`, l.2702), même dans les messages cités · `w/card/common/VisibilityBadge.tsx:25` | confirmé | moyenne |
| 2.3 | Équipe privée sur une carte d'équipe | équipe | carte de découverte : bouton désactivé « Sur invitation » (`teams.discovery.inviteOnly`) · `team_discovery_card.dart:193-199` | badge de visibilité « Équipe uniquement » sur la carte d'une équipe · `TeamCard.tsx:39-41` | nouveau | faible (le site décrit une équipe avec le libellé prévu pour un contenu) |

## 3. Groupe d'une sortie et inscription

| # | Sujet | Cartes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| 3.1 | Passer d'un groupe à un autre | groupe | « Changer pour {group} » (`rides.groupSwitchTo`) en pied des autres cartes · `m/rides/presentation/widgets/ride_group_card.dart:174-184` | aucune action : une fois inscrite, la personne ne voit ni « Rejoindre » ni « Changer » (`canJoinRide = … && !ride.registered`) · `frontend/src/pages/ride/RideDetailPage.tsx:152`, `RideGroupCard.tsx:97-108` ; aucune clé « Changer pour » dans le fichier de traductions | confirmé | forte (action d'un seul côté) |
| 3.2 | Quitter le groupe | groupe | lien « Quitter le groupe » (`rides.groupLeaveLong`) en pied de carte · `ride_group_card.dart:187-193` | bouton « Quitter » (`rides.detail.groups.leave`) dans le coin · `RideGroupCard.tsx:97-100` | confirmé | moyenne |
| 3.3 | Groupe complet | groupe | bouton désactivé « Complet » · `ride_group_card.dart:249-255` | badge gris « Complet » · `RideGroupCard.tsx:105-108` | confirmé (même mot, forme différente) | faible |
| 3.4 | Capitaine | groupe | « Capitaine : {name} » en une phrase (`rides.leaderIs`) · `ride_group_card.dart:342` | nom, puis badge « Capitaine » · `RideGroupCard.tsx:220-233` | confirmé | faible |
| 3.5 | Chargement de « Rejoindre » un groupe | groupe | « Adhésion... » (`rides.joining`) : le mot de l'adhésion à une équipe, et trois points · `ride_group_card.dart:181,260` ; pour un voyage, « Inscription... » (`trips.joining`) | pas de libellé de chargement (bouton `disabled`) · `RideGroupCard.tsx:101-103` | nouveau | moyenne (voir aussi 9.2) |
| 3.6 | Groupe sur Ma prochaine sortie | prochaine sortie | nom du groupe seul, ligne à part, et compteur nu « 11/12 » · `next_ride_card.dart:262-263,340-344` | « {group} · {participants} » soit « A · 11/12 personnes » (`home.nextRide.groupParticipants`) · `NextRideCard.tsx:157-163` | nouveau | faible |
| 3.7 | Libellés des chiffres de Ma prochaine sortie | prochaine sortie | icônes seules (`PdlStat`) · `next_ride_card.dart:328-345` | tuiles titrées « Distance » / « Dénivelé positif » · `NextRideCard.tsx:168-185` | nouveau | faible |
| 3.8 | Se désinscrire | prochaine sortie | « Se désinscrire », chargement « Désinscription... », sans confirmation · `next_ride_card.dart:441-453` | « Se désinscrire » puis confirmation « Se désinscrire de la sortie ? » / « Votre inscription à « {name} » sera annulée… » · `NextRideCard.tsx:223-240` | confirmé | forte (une étape de plus d'un côté ; le libellé, lui, est identique) |

## 4. Compteurs et pluriels

| # | Sujet | Cartes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| 4.1 | Compteur à zéro | fil | masqué : groupes et personnes si `groupCount == 0`, commentaires si 0 · `publication_card.dart:434-451,508` | « {{count}} groupe » toujours affiché, donc « 0 groupe » ; « 0 commentaire » dès que `commentCount` est défini · `PublicationCard.tsx:100-106,120` | confirmé | moyenne |
| 4.2 | Chiffres d'un voyage | fil | étapes · distance · D+ · `publication_card.dart:620-640` | personnes · étapes · commentaires · `PublicationCard.tsx:126-136` | confirmé | moyenne |
| 4.3 | Places d'un groupe | groupe, prochaine sortie, tableau de bord | « 11/12 personnes » (`rides.participantsOf`) ; groupe plein : « 18/18 » nu · `ride_group_card.dart:379,425-437` ; tableau de bord « 11 / 12 » ou « N inscriptions » (`teams.dashboard.upcomingRides.registeredCount`) · `m/teams/presentation/widgets/dashboard/dashboard_rides.dart:605-608` | « 11/12 personnes » (`rides.detail.groups.participants`) · `RideGroupCard.tsx:90-95` ; tableau de bord « {{current}} / {{max}} » ou « N inscriptions » · `w/team/dashboard/UpcomingRideCard.tsx:188-198` ; « {{current}}/{{max}} places » (`spotsOf`) · `w/card/PublicationCardProgress.tsx:31` | confirmé : trois formes sur chaque support (« personnes », « inscriptions », chiffres nus) ; « places » sur le site seulement | moyenne |
| 4.4 | Pluriel calé sur le maximum | groupe | `'rides.participantsOf'.plural(max, …)` : « 0/1 personne » · `ride_group_card.dart:431` | `count: group.maxParticipants` : même règle · `RideGroupCard.tsx:91-94` | nouveau (commun) | faible |
| 4.5 | Nombre de membres | équipe | « {count} membres » **sans pluriel** (`teams.members`), d'où « 1 membres » (*déduit*) · `teams_page.dart:258`, `team_discovery_card.dart:119` | pluriel `memberCount_one/_other` · `TeamCard.tsx:37` | nouveau | moyenne |
| 4.6 | « Utilisée dans » : via les étapes | « Utilisée dans » | « via l'étape {names} » au singulier quel que soit le nombre (commentaire : « le type décide, pas le nombre ») · `m/routes/presentation/widgets/route_usages_section.dart:150-159` | « via les étapes : {{names}} », au pluriel même pour une seule étape · `w/route/RouteUsages.tsx:52-59` | confirmé | moyenne |
| 4.7 | Accord de « Utilisée dans » | « Utilisée dans » | « Utilisée dans » (`routes.usedIn`) · `route_usages_section.dart:48` | « Utilisée dans » (`routes.usages.title`) · `RouteUsages.tsx:26` | nouveau (commun) : le sujet est *un parcours*, il faudrait « Utilisé dans » | faible |

## 5. Météo (texte fixe)

| # | Sujet | Cartes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| 5.1 | Prévision pas encore disponible | fil, prochaine sortie, étape | « Météo dès le {date} » (`rides.weather.summaryAvailableFrom`) · `m/rides/presentation/widgets/ride_weather_summary_line.dart:105` | « Météo disponible à partir du {{date}} » (`rides.weather.summary.availableFrom`) · `w/weather/RideWeatherSummaryLine.tsx:50` | confirmé | moyenne |
| 5.2 | Alerte pluie | fil, prochaine sortie | « Pluie {probability} vers {time} » (`rides.weather.rainAlertShort`) · `ride_weather_summary_line.dart:140-147` | badge « {{condition}} dès {{time}} », par exemple « Averses dès 14:00 » (`rides.weather.summary.rainAlert`) ; la probabilité est seulement dans l'infobulle « Probabilité de pluie : {{p}} % » · `RideWeatherSummaryLine.tsx:98-112` | confirmé | moyenne (« vers » et « dès » ne disent pas la même heure) |
| 5.3 | Pluie sans alerte | fil | « Pluie {probability} » (`rides.weather.rainChance`) dès que `maxPrecipitationProbability` est renseignée · `ride_weather_summary_line.dart:148-155` | rien · `RideWeatherSummaryLine.tsx:98` (seul `rainAlert` s'affiche) | confirmé | moyenne |
| 5.4 | Plage de températures | fil | `formatTemperatureRange` (forme numérique : autre agent) · `ride_weather_summary_line.dart:125-129` | « {{min}} → {{max}} » · `RideWeatherSummaryLine.tsx:62` | confirmé (séparateur « – » contre « → », à confirmer par l'agent formats) | faible |

## 6. Export du parcours et appareils

| # | Sujet | Cartes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| 6.1 | Bouton d'export | prochaine sortie, groupe, étape | un bouton « GPS » (`routes.gpsSheet.button`) qui ouvre une feuille « Vers un appareil » / « Fichier GPX » / « Fichier FIT, pour compteur » · `m/routes/presentation/widgets/gps_button.dart:38-43` | « Envoyer vers l'appareil » (`routes.detail.sendToDevice`), « GPX », « FIT » · `NextRideCard.tsx:200`, `w/ride/RideGroupRouteActions.tsx:56-87`, `w/team/dashboard/SendToDeviceMenu.tsx:28` | confirmé | moyenne |
| 6.2 | Délier un appareil : titre | appareil appairé | « Délier {device} ? » · `m/profile/presentation/widgets/paired_devices_section.dart:47` | « Délier l'appareil » · `w/profile/PairedDevicesManager.tsx:129` | nouveau | faible |
| 6.3 | Délier : message | appareil appairé | « L'appareil n'aura plus accès… » · `paired_devices_section.dart:50` | « {{device}} n'aura plus accès… » · `PairedDevicesManager.tsx:130` | nouveau | faible |
| 6.4 | Aucun appareil | appareil appairé | « Aucun Karoo ni Garmin n'est appairé » (sans point) · `paired_devices_section.dart:141` | « Aucun Karoo ni Garmin n'est appairé à votre compte. » · `PairedDevicesManager.tsx:80` | nouveau | faible |

## 7. Notifications

| # | Sujet | Cartes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| 7.1 | Rappel | notification | « Rappel : votre sortie part demain » (`notifications.type.RIDE_REMINDER`) | « Rappel : votre sortie a lieu demain » (l.1368) | confirmé | faible |
| 7.2 | Inscription | notification | « {actor} a rejoint une sortie » (`RIDE_JOINED`) | « {{actor}} a rejoint votre sortie » (l.1366) | confirmé | moyenne |
| 7.3 | Nom du groupe | notification | « Groupe « {group} » » (`notifications.joinedGroup`) · `m/notifications/presentation/notification_display.dart:95` | « Groupe : {{group}} » (`notifications.item.group`) · `w/notification/NotificationItem.tsx:79` | confirmé | faible |
| 7.4 | Sortie modifiée | notification | le titre dit ce qui change : « Une sortie change de date / de point de départ / de date et de point de départ », sinon « Une sortie a été modifiée » (`notifications.rideUpdated.*`), puis « Nouvelle date : {date} » · `notification_display.dart:31-53,70-74` | titre unique « Une sortie à laquelle vous participez a changé » (l.1369), puis « Nouvelle date : … · Nouveau point de départ » (`notifications.change.*`) · `NotificationItem.tsx:56-64` | nouveau | moyenne |
| 7.5 | Pastille non lue | notification | pastille sans libellé · `m/notifications/presentation/widgets/notification_tile.dart:107-120` | pastille avec `aria-label` « Non lue » · `NotificationItem.tsx:121-128` | nouveau (*lu* dans la tuile ; aucune `Semantics` dans ce fichier) | faible |

## 8. Tableau de bord d'équipe

| # | Sujet | Cartes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| 8.1 | État du webhook | admin | « Actif » / « Inactif » **et** un second badge de dernier envoi · `m/teams/presentation/widgets/dashboard/dashboard_admin.dart:354-367` | un seul badge : « Désactivé » / « Échec » / « Actif » · `w/team/dashboard/AdminPanel.tsx:237-248` | confirmé | moyenne |
| 8.2 | Statut du dernier envoi | admin | « Envoyé », « Envoi... » (`…webhook.status.SENT/SENDING`) | « Réussi », « En cours » (`teams.settings.webhook.status.*`, l.2587-2588) | nouveau | moyenne |
| 8.3 | Webhook générique | admin | « Webhook générique » (`kind.GENERIC` = « générique ») | « Webhook JSON » (`teams.settings.webhook.kind.GENERIC`, l.2574) | nouveau | moyenne |
| 8.4 | Dernier envoi | admin | « Dernier envoi le {date} », ou « Aucun envoi pour le moment » · `dashboard_admin.dart:339-347` | « · dernier envoi le {date} » en minuscules ; rien s'il n'y en a jamais eu · `AdminPanel.tsx:228-234` | nouveau | faible |
| 8.5 | Lien des modèles | modèles | « Gérer les modèles » · `dashboard_admin.dart:42` | « Voir tout » (`teams.dashboard.seeAll`, par `DashboardSection`) · `w/team/dashboard/TemplatesPanel.tsx:27` | confirmé | faible |
| 8.6 | Vide « Vos prochaines sorties » | tableau de bord | « … à venir **dans cette équipe**. » · `dashboard_rides.dart:65` | « … à venir **de l'équipe**. » · `TeamDashboard.tsx:55` | confirmé | faible |
| 8.7 | Vide « Sorties à venir » | tableau de bord | « Aucune sortie n'est **prévue** pour le moment. » · `dashboard_rides.dart:397` | « Aucune sortie n'est **programmée** pour le moment. » · `TeamDashboard.tsx:67` | confirmé | faible |
| 8.8 | Vide « Nouveaux parcours » | tableau de bord | « Aucun parcours n'est disponible pour le moment. » · `dashboard_content.dart:147` | « Aucun parcours pour le moment. » · `TeamDashboard.tsx:111` | confirmé | faible |
| 8.9 | Groupe complet à traiter | « À traiter » | « {group} de « {ride} »**,** {count} inscriptions sur {max} » · `dashboard_todo.dart:139` | « {{group}} de « {{ride}} » **:** {{count}} inscriptions sur {{max}} » · `w/team/dashboard/TodoBand.tsx:141` | nouveau | faible |
| 8.10 | Nouveaux membres vides | admin | « Aucun membre pour le moment. » · `dashboard_admin.dart:125` | pas d'état vide lu · `AdminPanel.tsx:150` | nouveau | faible |

## 9. États vides, aides, chargement, ponctuation

| # | Sujet | Cartes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| 9.1 | Fil vide | fil | « Aucune publication » (`home.feed.empty`) | « Aucune publication pour le moment » (`home.feed.empty`, sans point) | confirmé | faible |
| 9.2 | Points de suspension | toutes | 14 « ... » et 39 « … » dans fr.json. Sur les cartes : « Adhésion... » (`rides.joining`) mais « Adhésion… » (`teams.discovery.joining`) ; « Désinscription... », « Inscription... », « Téléchargement... » (`routes.downloading`, bouton GPS), « Écrire un commentaire... », « Publication... », « Envoi... » (webhook) contre « Acceptation… », « Rechercher une personne… », « chargement de la suite… » | 45 « ... » et 10 « … » dans common.json : « Rechercher par nom... » (modèles), « Écrivez une réponse... » (`CommentItem.tsx:149`), « Chargement... » (`RideTemplateListPage.tsx:70`) contre « Rechercher une personne… » (`ParticipantList.tsx:90`) | confirmé (les deux supports mélangent les deux formes) | faible |
| 9.3 | Champ de commentaire | commentaire | « Écrire un commentaire... » (infinitif) · `m/comments/presentation/widgets/comment_thread.dart:370` | « Écrivez un commentaire... » / « Écrivez une réponse... » (impératif) · `comments.form.*`, `CommentItem.tsx:149` | nouveau | faible |
| 9.4 | Aucune inscription | personne inscrite | titre « Aucune inscription » et message « Aucune inscription dans ce groupe pour le moment. » · `m/participants/presentation/widgets/participant_list_view.dart:136-137` | « Aucune inscription pour le moment. » · `w/ride/ParticipantList.tsx:106` | confirmé | faible |
| 9.5 | Recherche sans résultat | personne inscrite | « Personne ne correspond » puis « Aucun nom ne correspond à « {search} ». » · `participant_list_view.dart:142-143` | « Personne ne correspond à « {{search}} ». » · `ParticipantList.tsx:106` | nouveau | faible |
| 9.6 | Erreur de chargement | personnes, membres, commentaires, accueil | « Erreur de chargement » (`common.loadError`) · `participant_list_view.dart:122` | « La liste des inscriptions n'a pas pu être chargée. Réessayez. » · `ParticipantList.tsx:100` ; « Erreur lors du chargement » (`error.loading`) · `WeekAgenda.tsx:141`, `MyTeamsCard.tsx:61` | nouveau | faible |
| 9.7 | Pagination | personnes, membres | « {loaded} personnes sur {total} » + « Afficher plus » · `participant_list_view.dart:187-201` | « {{from}}–{{to}} sur {{total}} » · `ParticipantList.tsx:175` | nouveau | faible |
| 9.8 | Mes équipes vide | mes équipes | « Vous n'êtes membre d'aucune équipe. » · `m/home/.../my_teams_section.dart:152` | « … d'aucune équipe pour le moment. » · `MyTeamsCard.tsx:66` | nouveau | faible |
| 9.9 | Lien « Mes équipes » | mes équipes | « Toutes » · `my_teams_section.dart:90` | « Voir l'équipe » / « Voir les {{count}} équipes » · `MyTeamsCard.tsx:106` | nouveau | faible |
| 9.10 | 7 prochains jours : vide | 7 jours | « Rien de prévu dans vos équipes ces **sept** prochains jours. » / « Rien d'autre de prévu… » · `week_agenda_section.dart:138` | « Aucune sortie ni étape prévue ces **7** prochains jours. » / « Aucune autre sortie ni étape… » · `WeekAgenda.tsx:145` | nouveau | faible |
| 9.11 | 7 prochains jours : lien | 7 jours | « Calendrier » · `week_agenda_section.dart:110` | « Voir le calendrier » · `WeekAgenda.tsx:93` | nouveau | faible |
| 9.12 | Aide de l'abonnement au calendrier | abonnement | « …Outlook…). » (« … » et point final) · `m/calendar/presentation/widgets/calendar_subscription_card.dart:103` | « …Outlook...) » (« ... », sans point) (`calendar.ics.description`, l.462) | nouveau | faible |
| 9.13 | Guillemets droits | modèle de sortie | (sans objet) | « supprimer le modèle \"{{name}}\" ? » (`rideTemplates.confirmations.delete`, l.2022) ; idem `teams.pages.confirmations.delete` (l.2502) ; ailleurs le site écrit « … » | nouveau | faible |

## 10. Membres et équipes

| # | Sujet | Cartes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| 10.1 | Date d'adhésion | membre | « Membre depuis {date} », mois et année · `m/teams/presentation/pages/team_members_page.dart:361-365` | « A rejoint le {{date}} », date complète ; « Inconnu » à défaut · `w/team/TeamMemberList.tsx:126-127` | confirmé | moyenne |
| 10.2 | « (vous) » | membre | absent : aucune clé « (vous) » dans fr.json ; seul l'avatar change de teinte (`isCurrentUser`) · `core/pdl/pdl_avatar.dart:76-77` | « (vous) » après le nom · `TeamMemberList.tsx:119` | confirmé | faible |
| 10.3 | Filtre « tous les rôles » | membres | « Tous » (`teams.membersList.allRoles`) · `team_members_page.dart:306` | « Tous les rôles » (`teams.detail.members.filterRoleAll`, l.2448) | nouveau (*lu* dans les traductions ; le composant du filtre côté site n'a pas été ouvert) | faible |
| 10.4 | « Publication » contre « article » | notification, fil | le type s'appelle « Publication » sur les cartes (`publicationType.post`), mais « {actor} a publié un article » et « Article publié » dans les notifications | même mélange : « Publication » (l.83 de `PublicationCard.tsx`) contre « a publié un article » / « Article publié » (l.1363, 1376) | nouveau (commun) | moyenne |

## Incohérences internes à l'app

| # | Sujet | Cartes concernées | Variantes (valeur · fichier:ligne) | Verdict | Gravité |
|---|---|---|---|---|---|
| A1 | Rôle d'une équipe à laquelle on appartient | équipe | `_TeamCard` : nom du rôle, « Admin » / « Organisateur » / « Membre » · `teams_page.dart:278` ; carte de découverte : badge « Membre » quel que soit le rôle (`teams.discovery.memberBadge`) · `team_discovery_card.dart:173-181` | nouveau | moyenne |
| A2 | Nombre de membres | équipe, tableau de bord, mes équipes | « {count} membres » sans pluriel (`teams.members`) · `teams_page.dart:258`, `team_discovery_card.dart:119` ; pluriel « Aucun membre / 1 membre / N membres » (`teams.membersList.count`) · `my_teams_section.dart:45`, `dashboard_admin.dart:115` | nouveau | moyenne |
| A3 | Chargement d'une inscription | groupe, voyage, équipe | groupe de sortie « Adhésion... » (`rides.joining`) ; voyage « Inscription... » (`trips.joining`) ; équipe « Adhésion… » (`teams.discovery.joining`, `teams.membership.joining`) | nouveau | moyenne |
| A4 | L'appareil d'export | prochaine sortie, groupe, étape | bouton « GPS » ; dans la feuille, « Vers un appareil » puis « Connecter un compteur » ; libellé lu par le lecteur d'écran : « …vers un GPS… » (`routes.gpsSheet.*`) | nouveau | faible |
| A5 | « Sept » ou « 7 » | 7 jours | titre « Les 7 prochains jours » contre texte vide « ces sept prochains jours » (`home.week.*`) · `week_agenda_section.dart:108,138` | nouveau | faible |
| A6 | Places d'un groupe | groupe, tableau de bord | « 11/12 personnes » (`rides.participantsOf`) ; plein : « 18/18 » nu · `ride_group_card.dart:379` ; tableau de bord « 11 / 12 » (avec espaces) ou « N inscriptions » · `dashboard_rides.dart:605-608` ; prochaine sortie « 11/12 » nu · `next_ride_card.dart:340-344` | confirmé | faible |
| A7 | Libellé de l'heure de départ | fil, groupe, tableau de bord, notification | « Départ {time} » (`rides.departureBlock.departs`) ; « départ {time} » (`teams.dashboard.upcomingRides.groupStart`) ; « Départ : {date} » (`notifications.startsAt`) | nouveau (même schéma sur le site : `departure.block.time`, `teams.dashboard.ride.groupStart`, `notifications.item.startsAt`) | faible |
| A8 | Écran Mes équipes hors charte | équipe | `_TeamCard` dessine le badge de rôle à la main (`Container`, `Icons.people`, `fontSize: 10`), alors que les autres cartes utilisent `PdlBadge` · `teams_page.dart:248-285` | nouveau (hors axe des libellés, signalé pour la cohérence du badge de rôle) | faible |

## Incohérences internes au site

| # | Sujet | Cartes concernées | Variantes (valeur · fichier:ligne) | Verdict | Gravité |
|---|---|---|---|---|---|
| S1 | Badge « Publié » et visibilité | fil contre agenda | `PublicationCard` : statut toujours, « Publié » compris, et visibilité toujours · `PublicationCard.tsx:247-248` ; `AgendaRow`, `WeekAgenda`, `CalendarView` : statut seulement s'il n'est pas PUBLISHED, visibilité seulement si elle n'est pas PUBLIC · `AgendaRow.tsx:56-63`, `WeekAgenda.tsx:167`, `CalendarView.tsx:293` | nouveau | moyenne |
| S2 | Heure de l'alerte pluie | fil contre groupe | « {{condition}} dès {{time}} » (`rides.weather.summary.rainAlert`) · `RideWeatherSummaryLine.tsx:109` ; « {{condition}} {{probability}} % vers {{time}} » (`rides.weather.groupLine.rain`) · `w/weather/GroupWeatherLine.tsx:68` | nouveau | moyenne |
| S3 | Coche de « J'y vais » | fil, agenda, 7 jours, groupe | avec coche · `PublicationCard.tsx:233-240`, `AgendaRow.tsx:45-52`, `NextRideCard.tsx:131` ; sans coche · `WeekAgenda.tsx:170-173`, `RideGroupCard.tsx:127-131` ; texte seul « J'y vais · {{group}} » · `CalendarView.tsx:195-196` | confirmé | faible |
| S4 | Capitaine | groupe | « Capitaine » partout (`rides.detail.groups.leader`) ; clé orpheline « Organisateur du groupe » (`groups.groupOrganizer`, l.1011), utilisée par aucun composant (*lu* par recherche dans `frontend/src`) | nouveau | faible |
| S5 | Point final des états vides | fil, tableau de bord | « Aucune publication pour le moment » sans point (`home.feed.empty`, `teams.posts.empty`) contre « Aucune publication pour le moment. » (`teams.dashboard.posts.empty`) | nouveau | faible |
| S6 | Libellé du dénivelé | prochaine sortie, parcours | « Dénivelé positif » (`home.nextRide.elevation`, `routes.detail.stats.elevationGain`) contre « Dénivelé » (`routes.detail.climbs.gain`) et « D+ : … » (`publication.facts.elevation`) | nouveau | faible |

## Restes non épicènes (hors cartes, relevés en passant)

| # | Où | Valeur | Gravité |
|---|---|---|---|
| E1 | app `notifications.push.hint` (bandeau d'activation du push dans la boîte de notifications) | « Soyez **prévenu** d'une sortie publiée ou annulée… » | moyenne |
| E2 | app `moderation.blockMessage` | « {name} n'en sera pas **prévenu**. » | moyenne |
| E3 | site `moderation.block.confirmMessage` (l.1235) | « {{name}} n'en sera pas **informé**. Vous pourrez **le** débloquer… » ; le même message dit aussi « posts » là où l'app dit « publications » | moyenne |
| E4 | site `teams.settings.dangerZone.description` (l.2537) | « Soyez **certain**. » | faible |

Aucun point médian (« ·e », « ·s ») trouvé dans l'un ou l'autre fichier.

## Non vérifié

- **Confirmation avant de quitter un groupe sur le site** : `RideDetailPage.tsx:176` passe `membership.leave` tel quel ;
  je n'ai pas ouvert le hook pour savoir s'il demande une confirmation. Le libellé (« Quitter ») est établi, le parcours
  de l'action ne l'est pas. Côté app, la doc d'en-tête de `ride_group_card.dart:46` dit « ni confirmation … pour quitter ».
- **« Voir tout »** : les règles d'affichage (carte sélectionnée dans l'app, plus de 5 personnes sur le site,
  `ride_group_card.dart:413-421` contre `RideGroupCard.tsx:171-177`) sont lues, mais c'est un écart de comportement et non
  de libellé. Je le signale seulement.
- **Rendu réel du pluriel à zéro** : « 0 groupe » et « 0 commentaire » sur le site, et « 1 membres » dans l'app, sont
  déduits des règles i18next et easy_localization ; je ne les ai pas vus à l'écran.
- **Pastille « Non lue » dans l'app** : je n'ai pas cherché de `Semantics` en dehors de `notification_tile.dart`. Un
  parent pourrait donner un libellé.
- **Bannière d'invitations du site** (`w/team/PendingInvitationsBanner.tsx`) : ses libellés sont identiques à ceux de
  l'app (titre au pluriel, « {inviter} vous invite à rejoindre {team}. », « Accepter »). Pas d'écart.
- **Carte d'étape** : la carte de l'app n'a qu'un libellé fixe, lu par le lecteur d'écran (« Étape {index} sur {total} »,
  `stage_card.dart:83`). Le site n'a aucun texte fixe en dehors de ses composants communs. Les lieux et les fichiers,
  présents sur le site seulement, relèvent du contenu et non du vocabulaire. Pas de ligne au tableau.
- **Formats de nombres et de dates** (« 92,4 km », « il y a environ 2 heures », plages de voyage) : hors axe, laissés à
  l'autre agent.
