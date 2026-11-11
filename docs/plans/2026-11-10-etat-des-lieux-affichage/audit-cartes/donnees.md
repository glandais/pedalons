# Audit d'homogénéité des cartes — axe « données affichées »

Chemins abrégés : `m/` = `mobile/lib/`, `f/` = `frontend/src/`. « Lu » = vérifié dans le code ; « déduit » = conclusion
tirée du code sans exécution.

## Synthèse

Les deux clients lisent les mêmes champs du contrat. Ils ne les montrent pas de la même façon. Les écarts les plus lourds :
1. **Bandeau de la carte de sortie ou de voyage dans le fil.** L'app y met la carte du tracé, et la répète en vignette à
   droite. Le site y met une photo de `media`, en pratique un dégradé en vue COMPACT, et pose la carte du tracé à droite.
2. **Voyage.** L'app montre étapes, distance et D+. Le site montre personnes, étapes et commentaires. Le site ne donne
   pas non plus l'heure de départ du voyage.
3. **Compteurs.** L'app masque ceux qui valent zéro ; le site affiche « 0 commentaire » et « 0 groupe ».
4. **Cartes qui n'ont pas les mêmes champs** : modèle de sortie, équipe, parcours, étape. Exemples : statut et
   « prochaine #42 » dans l'app seulement ; description, visibilité, groupes et tags sur le site seulement.
5. **Dans chaque support, la même sortie change de chiffres d'une carte à l'autre** : distance du parcours de la sortie
   contre distance du groupe, nombre de groupes affiché ou non, avec deux icônes. Sur 98 écarts : 8 forts, 45 moyens,
   45 faibles. S'y ajoutent 13 pistes vérifiées et trouvées alignées (verdict « réfuté »).

## 1. Fil : sortie, voyage, publication (`PublicationCard`)

App : `m/features/teams/presentation/widgets/publication_card.dart` (PC). Site : `f/components/card/PublicationCard.tsx` (PCw).

| # | Sujet | Cartes concernées | App (valeur · fichier:ligne) | Site (valeur · fichier:ligne) | Verdict | Gravité |
|---|---|---|---|---|---|---|
| 1.1 | Image du bandeau (sortie, voyage) | fil | `thumbnailLightUrl`/`DarkUrl`, la **carte du tracé**, selon le thème · PC:369, 567 | `CardImage` lit d'abord `thumbnailUrl`, que PCw force à `undefined` pour une sortie ou un voyage. Il prend alors `media.assets.images[0]`, sinon le dégradé du type · PCw:180-195, `f/components/card/common/CardImage.tsx:49-83`. En COMPACT `assets` est vide (déduit des commentaires), donc dégradé | nouveau | forte |
| 1.2 | Vignette carrée du parcours à droite | fil, sortie | `ride.thumbnailUrl`, seulement si `routeSlug != null`. C'est la même image que le bandeau, montrée deux fois · PC:412 | `RouteThumbnail` light/dark, dès qu'une variante existe, même sans `routeSlug` (un parcours porté par un groupe seulement) · PCw:273-279 | nouveau | moyenne |
| 1.3 | Vignette du parcours d'un voyage | fil, voyage | aucune (`trailingThumbnailUrl` non passé) · PC:563-641 | `RouteThumbnail` du voyage · PCw:167-173, 273 | nouveau | moyenne |
| 1.4 | Compteurs d'un voyage | fil | « N étapes » (si >0) · distance totale · D+ total · PC:620-640 | « N personnes » · « N étapes » · « N commentaires » · PCw:125-136 | confirmé | forte |
| 1.5 | Personnes d'un voyage en texte | fil | aucun compteur ; seulement la grappe d'avatars avec « +N », vide pour un non-membre (`participants` vide), qui ne voit donc aucun nombre · PC:598-604 | « N personnes » toujours · PCw:129-131 | nouveau | forte |
| 1.6 | Heure de départ d'un voyage | fil, voyage | « Départ 09:00 » puis la plage « ven. 16 → dim. 18 oct. » · PC:544-556, 694-716 | la plage seule, sans heure (`formatPublicationSpan` pour TRIP) · `f/components/common/DepartureLine.tsx:117-127`, `f/utils/publicationTiming.ts:65-71` | nouveau | moyenne |
| 1.7 | Zone du dernier jour d'un voyage | fil | `trip.timezone` pour les deux bornes · PC:549-553 | `tripEndZone(publication)`, la zone de la dernière étape quand elle est connue · `publicationTiming.ts:58` | nouveau | faible |
| 1.8 | « N groupes » à zéro | fil, sortie | masqué si `groupCount == 0` · PC:442 | toujours affiché : « 0 groupe » (`groups.groupCount_one` avec count 0) · PCw:120 | confirmé | moyenne |
| 1.9 | « N commentaires » à zéro | fil, tous types | masqué si `commentCount` est nul ou vaut 0 · PC:447, 508 | affiché dès que `commentCount` est défini : « 0 commentaire » · PCw:101-107 | confirmé | moyenne |
| 1.10 | Barre de remplissage de la sortie | fil, sortie | aucune : choix commenté dans le code · PC:295-300 | barre plus « 8/12 places » ou « Complet » à partir de `maxParticipants` · `f/components/card/PublicationCardProgress.tsx:15-34` | confirmé | moyenne |
| 1.11 | Logo de l'entité près du titre | fil | aucun ; le logo **de l'équipe** est sur la ligne d'équipe · PC:205-212 | `EntityLogo` (`media.assets.logo` de la publication) à gauche du titre ; ligne d'équipe sans logo (`IconUsers`) · PCw:214, `CardTeamLink.tsx:24` | nouveau | faible |
| 1.12 | Troncature du titre | fil | 1 ligne · PC:221-226 | sans limite (`CardTitle`, `truncate=false`) · `Card.tsx:64-69` | nouveau | faible |
| 1.13 | Repli de l'extrait | fil | `excerpt` seul, 2 lignes · PC:231-239 | `excerpt` sur 2 lignes, sinon aperçu Markdown de `media.markdown` (150 caractères) · `Card.tsx:89-101` | nouveau | faible |
| 1.14 | Ordre des blocs | fil | titre → départ → extrait │ badges ; tags ; avatars + vignette ; stats ; météo · PC:205-276 | identique, mais tags limités à 3 des deux côtés (`kCardTagLimit = 3` contre `max={3}`) · PCw:252 | réfuté (ordre aligné) | — |
| 1.15 | Météo d'une sortie terminée ou annulée | fil | masquée (`finished`, `cancelled`) · PC:417-429 | aucun filtre client : affichée si le serveur l'envoie · PCw:287-292 | nouveau | faible |
| 1.16 | Pastille « Aujourd'hui / Demain » | fil | absente pour une sortie passée ou annulée · PC:362, 555 | toujours calculée (`formatRelativeDay`), annulée comprise · `CardDayOverlay.tsx:31-34` | nouveau | moyenne |
| 1.17 | Badges de statut (« Terminée », « Annulé », « Publié », visibilité) | fil | voir l'axe Badges. Ici seulement : l'état « passé » n'a un badge que dans l'app · PC:399-400 | rien pour le passé · PCw:229-248 | confirmé | moyenne |

## 2. Accueil : prochaine sortie, 7 prochains jours, mes équipes

| # | Sujet | Cartes concernées | App (valeur · fichier:ligne) | Site (valeur · fichier:ligne) | Verdict | Gravité |
|---|---|---|---|---|---|---|
| 2.1 | Statut « Annulé » sur « Ma prochaine sortie » | prochaine sortie | badges type « Sortie », « J'y vais », « Annulé » si annulée · `m/features/home/presentation/widgets/next_ride_card.dart:216-235` | seulement « J'y vais » sur l'image ; ni type ni annulation · `f/components/home/NextRideCard.tsx:126-134` | nouveau | forte |
| 2.2 | Personnes inscrites | prochaine sortie | stat nue « 8/12 » (ou le total de la sortie), grappe d'avatars du groupe, barre de places · next_ride_card.dart:340-345, 350-383 | « Groupe A · 8/12 personnes » en une ligne ; ni avatars ni barre · NextRideCard.tsx:92-99, 157-164 | nouveau | moyenne |
| 2.3 | Nom du groupe | prochaine sortie | sa propre ligne (icône personnes + nom) · next_ride_card.dart:265-266 | fusionné avec le compteur · NextRideCard.tsx:158-163 | nouveau | faible |
| 2.4 | Lieu de départ | prochaine sortie | `PdlPlaceRow` : nom **et adresse** · next_ride_card.dart:267-274 | nom seul · NextRideCard.tsx:155 | nouveau | moyenne |
| 2.5 | Ordre des blocs | prochaine sortie | badges → équipe → titre → départ → groupe → lieu → stats (distance, D+, personnes) → météo → avatars · next_ride_card.dart:165-198 | titre de section → titre → équipe → départ → lieu → météo → personnes → tuiles distance / D+ · NextRideCard.tsx:140-186 | nouveau | moyenne |
| 2.6 | Repli de l'image | prochaine sortie | groupe (thème, puis l'autre variante) → sortie (idem) → dégradé · next_ride_card.dart:35-49 | en sombre : `group.dark ?? ride.dark` (jamais `group.light`), puis `group.thumbnailUrl`, `ride.thumbnailUrl`, photo `media`, dégradé · NextRideCard.tsx:71-76 | nouveau | faible |
| 2.7 | Titre | prochaine sortie | sans limite de lignes · next_ride_card.dart:174-177 | 2 lignes · NextRideCard.tsx:143 | nouveau | faible |
| 2.8 | Météo et pastille d'une sortie annulée | prochaine sortie | masquées · next_ride_card.dart:77-79, 182-194 | affichées · NextRideCard.tsx:126, 156 | nouveau | faible |
| 2.9 | Nom du groupe dans une ligne des 7 jours | 7 jours | absent : « 09:00 · Équipe » · `m/features/home/presentation/widgets/week_agenda_section.dart:173-176` | « 09:00 · Équipe · Groupe A » · `f/components/home/WeekAgenda.tsx:199` | nouveau | moyenne |
| 2.10 | Statut brouillon dans une ligne des 7 jours | 7 jours | seulement « Annulé » · week_agenda_section.dart:219-224 | tout statut ≠ PUBLISHED (Brouillon, Annulé) · WeekAgenda.tsx:167-169 | nouveau | faible |
| 2.11 | Au-delà de 5 lignes | 7 jours | « N autres événements au calendrier » · week_agenda_section.dart:73-82 | les lignes en trop disparaissent sans mention · WeekAgenda.tsx:149 | nouveau | moyenne |
| 2.12 | Bandeau des 7 jours avec points | 7 jours | absent | présent (7 jours, un point par jour occupé, la prochaine sortie comprise) · WeekAgenda.tsx:97-131 | nouveau | faible |
| 2.13 | Ligne d'activité d'une équipe | mes équipes | « 2 sorties à venir · 1 nouvelle publication », zéros omis, repli sur le nombre de membres · `my_teams_section.dart:16-29` | même règle · `f/components/home/memberHomeHelpers.ts:11-27` | réfuté (aligné) | — |
| 2.14 | Nombre d'équipes listées | mes équipes | 5 au plus, puis « Toutes » · my_teams_section.dart:3, 58-71 | toutes celles reçues, puis « Voir les N » si `total` est plus grand · MyTeamsCard.tsx:84-108 | nouveau | faible |

## 3. Agenda et calendrier

L'app n'a pas de « Lignes » d'agenda d'équipe. Son agenda montre des cartes de fil et le calendrier (`AgendaCard`). Le
site a trois vues : cartes, lignes (`AgendaRow`) et calendrier (`CalendarView`). Les deux comparaisons utiles sont
`AgendaCard` face au calendrier du site, et `AgendaRow` face à la carte de fil de l'app.

| # | Sujet | Cartes concernées | App (valeur · fichier:ligne) | Site (valeur · fichier:ligne) | Verdict | Gravité |
|---|---|---|---|---|---|---|
| 3.1 | Ligne résumé d'un événement | calendrier | heure en gras, puis « Équipe · Lieu » · `m/features/calendar/presentation/widgets/agenda_card.dart:112-117, 174-197` | « Équipe · Heure · Lieu » · `f/components/calendar/CalendarView.tsx:165-177` | nouveau | moyenne |
| 3.2 | Distance et D+ | calendrier | toujours sur la carte · agenda_card.dart:119-130 | dans l'info-bulle et le corps du mois sur bureau ; **absents** de la vue mobile · CalendarView.tsx:211, 285-289, 336-372 | nouveau | moyenne |
| 3.3 | Statut | calendrier | badge « Annulé » seulement · agenda_card.dart:243-248 | tout statut ≠ PUBLISHED dans l'info-bulle ; rien dans la vue mobile · CalendarView.tsx:295-299, 336-372 | nouveau | moyenne |
| 3.4 | Groupe rejoint | calendrier | badge « J'y vais · Groupe A » · agenda_card.dart:227-239 | « J'y vais · Groupe A » en texte, plus un filet gauche · CalendarView.tsx:189-199, 254-256 | réfuté (même donnée) | — |
| 3.5 | Vignette | calendrier | aucune | vignette thémée 200×80 dans l'info-bulle (bureau) · CalendarView.tsx:241-273 | nouveau | faible |
| 3.6 | Passé | calendrier | opacité 0,55 · agenda_card.dart:223 | opacité 0,55 · CalendarView.tsx:235-253 | réfuté (aligné) | — |
| 3.7 | Ligne d'agenda du site face à la carte de fil de l'app | agenda d'équipe | carte de fil : ni lieu de départ, ni visibilité (cf. §1) | `AgendaRow` : lieu de départ, « N groupes » même à 0, visibilité si ≠ PUBLIC · `f/components/agenda/AgendaRow.tsx:61-80` | nouveau | moyenne |

## 4. Groupe d'une sortie et étape d'un voyage

| # | Sujet | Cartes concernées | App (valeur · fichier:ligne) | Site (valeur · fichier:ligne) | Verdict | Gravité |
|---|---|---|---|---|---|---|
| 4.1 | Ordre des chiffres | groupe, étape | distance · D+ · vitesse · `m/core/widgets/publication_stats_line.dart:46-58` | vitesse · distance · D+ · `f/components/publication/ChildCard.tsx:135-171` | confirmé | moyenne |
| 4.2 | Vitesse à 0 | groupe, étape | affichée (« 0 km/h ») dès qu'elle n'est pas nulle · publication_stats_line.dart:57 | masquée si `averageSpeed` vaut 0 · ChildCard.tsx:147 | nouveau | faible |
| 4.3 | D+ sans distance | groupe | affiché seul · `ride_group_card.dart:142-147` | masqué quand `distance` est absente · `f/components/ride/RideGroupCard.tsx:143` | nouveau | faible |
| 4.4 | Groupe complet | groupe | grappe d'avatars remplacée par une barre rouge pleine et « 18/18 » · ride_group_card.dart:368-382 | badge « Complet » dans le coin ; avatars et « 18/18 personnes » conservés · RideGroupCard.tsx:105-109, 153-181 | confirmé | moyenne |
| 4.5 | Barre de places d'un groupe non complet | groupe | aucune (seulement le cas complet) · ride_group_card.dart:384-423 | aucune | réfuté (aligné) | — |
| 4.6 | Capitaine | groupe | avatar + icône + « Capitaine : Léa » · ride_group_card.dart:326-352 | avatar + « Léa » + badge « Capitaine » · RideGroupCard.tsx:219-234 | confirmé | faible |
| 4.7 | « Voir tout » les personnes | groupe | sur la carte sélectionnée seulement · ride_group_card.dart:413-421 | dès que `countParticipants > 5` · RideGroupCard.tsx:174-178 | confirmé | faible |
| 4.8 | Lieux de départ et d'arrivée | étape | absents · `m/features/trips/presentation/widgets/stage_card.dart:91-153` | départ (vert) et arrivée (rouge) · `f/components/trip/TripStageCard.tsx:74-92` | confirmé | forte |
| 4.9 | Fichiers et envoi du parcours | étape, groupe | aucun sur l'étape ; « GPS » sur la carte de son propre groupe · stage_card.dart ; ride_group_card.dart:163-171 | `RideGroupRouteActions` sur chaque étape et chaque groupe qui a un parcours · TripStageCard.tsx:63-72, RideGroupCard.tsx:186-195 | confirmé (sous l'axe Boutons) | moyenne |
| 4.10 | Repère de couleur du tracé | étape | `PdlColorTrack` sur `paletteIndex` · stage_card.dart:106-109 | aucun repère ; numéro ou logo à la place · TripStageCard.tsx:42-50 | nouveau | moyenne |
| 4.11 | Numéro d'étape | étape | `stage.stageIndex` (le contrat) · stage_card.dart:81-89 | `index + 1` (position dans la liste reçue) ; remplacé par le logo s'il existe · TripStageCard.tsx:43-48 | nouveau | faible |
| 4.12 | Heure de l'étape | étape | sous le titre, horloge devant · stage_card.dart:112-130 | dans le coin droit (« sam. 12 avr. · 09:00 ») · TripStageCard.tsx:52 | nouveau | faible |
| 4.13 | Groupe d'une sortie solo | sortie solo | pas de carte de groupe : bloc de départ de la fiche (non relu en détail) | `RideSoloGroupPanel` : nom, couleur, lieux du groupe (`GroupPlaces`), capitaine, fichiers · `f/components/ride/RideSoloGroupPanel.tsx:67-109` | non vérifié côté app | — |

## 5. Parcours et « Utilisée dans »

| # | Sujet | Cartes concernées | App (valeur · fichier:ligne) | Site (valeur · fichier:ligne) | Verdict | Gravité |
|---|---|---|---|---|---|---|
| 5.1 | Extrait | parcours (vignettes) | absent · `m/features/routes/presentation/widgets/route_card.dart:68-110` | `CardDescription` (`excerpt`, sinon Markdown) · `f/components/card/RouteCard.tsx:60` | confirmé | moyenne |
| 5.2 | Commentaires | parcours | absents | « N commentaires », 0 compris, si défini · RouteCard.tsx:67-71 | confirmé | moyenne |
| 5.3 | Pas de vignette | parcours (vignettes) | dégradé et icône · route_card.dart:54-63 | aucune image : la carte commence au contenu · RouteCard.tsx:42-51 | confirmé | moyenne |
| 5.4 | Ligne d'équipe | parcours | toujours montrée · route_card.dart:76-80 | seulement si `showTeam` · RouteCard.tsx:55 | nouveau | faible |
| 5.5 | Logo du parcours | parcours | aucun | `EntityLogo` (`media.assets.logo`) · RouteCard.tsx:58 | nouveau | faible |
| 5.6 | Titre | parcours | 1 ligne · route_card.dart:82-86 | sans limite (vignettes) ; 1 ligne (ligne dense) · RouteCard.tsx:59, `RouteRow.tsx` | nouveau | faible |
| 5.7 | Ligne dense | parcours | badges et 2 tags toujours là · `compact_route_row.dart:61-81` | identique en `compact=false` ; en `compact` : revêtement seul, ni visibilité ni tags · RouteRow.tsx:66-97 | réfuté (aligné hors aperçu de cul-de-sac) | — |
| 5.8 | « via … » d'un voyage | utilisée dans | « via l'étape J1, J3 » (singulier, même pour plusieurs) · `route_usages_section.dart:142-151` + `routes.viaStage` | « via les étapes : J1, J3 » · `RouteUsages.tsx:53-61` + `routes.usages.viaTrip` | confirmé | moyenne |
| 5.9 | Usage d'un type autre que sortie ou voyage | utilisée dans | repli « Publication », lien vers la publication · route_usages_section.dart:153-180 | tout ce qui n'est pas TRIP devient une sortie (libellé et lien) · RouteUsages.tsx:43-50. Le contrat ne connaît que RIDE et TRIP · `contracts/openapi.yaml:6124-6127` | nouveau (sans effet aujourd'hui) | faible |

## 6. Annonce

| # | Sujet | Cartes concernées | App (valeur · fichier:ligne) | Site (valeur · fichier:ligne) | Verdict | Gravité |
|---|---|---|---|---|---|---|
| 6.1 | Ordre tags et chiffres | annonce | tags **avant** prix · date · lieu · `m/features/ads/presentation/widgets/ad_card.dart:108-137` | tags **après** · `f/components/card/AdCard.tsx:73-85` | confirmé | faible |
| 6.2 | Heure de publication | annonce | date seule (`formatLongDate`) · ad_card.dart:126-129 | date et heure (`FormattedDateTime`) · AdCard.tsx:78 | confirmé (le format relève de l'autre axe) | faible |
| 6.3 | Logo de l'annonce | annonce | aucun | `EntityLogo` · AdCard.tsx:56 | nouveau | faible |
| 6.4 | Période de location | annonce | ajoutée dès que `rentalPeriod` est posée, quel que soit le type · ad_card.dart:39-42 | seulement si `adType === RENTAL` · AdCard.tsx:31-36 | nouveau | faible |
| 6.5 | Statut et visibilité | annonce | type, et « Brouillon » si DRAFT · ad_card.dart:91-105 | type, statut, visibilité, toujours · AdCard.tsx:62-70 | confirmé (axe Badges) | moyenne |

## 7. Équipe, membre, personne inscrite

| # | Sujet | Cartes concernées | App (valeur · fichier:ligne) | Site (valeur · fichier:ligne) | Verdict | Gravité |
|---|---|---|---|---|---|---|
| 7.1 | Bandeau d'une équipe | liste des équipes, découverte | `_TeamCard` : aucun bandeau, logo 56 px · `teams_page.dart:220-296` ; découverte : dégradé seul, jamais la photo · `team_discovery_card.dart:64-69` | `CardImage` sur `team.about` : première photo, sinon dégradé · `f/components/card/TeamCard.tsx:23` | nouveau | moyenne |
| 7.2 | Description | équipes | `_TeamCard` : aucune ; découverte : `team.excerpt` sur 2 lignes · team_discovery_card.dart:104-110 | `CardDescription` **sans `excerpt`** : aperçu Markdown de `about.markdown` seulement · TeamCard.tsx:34 | nouveau | moyenne |
| 7.3 | Visibilité | équipes | `_TeamCard` : jamais ; découverte : toujours, « Public » compris · team_discovery_card.dart:96-100 | seulement si TEAM (privée) · TeamCard.tsx:40-42 | nouveau | moyenne |
| 7.4 | Invitations en attente | bannière | « {inviter} vous invite dans {team} » + Accepter · `pending_invitations_card.dart:85-106` | même ligne · `PendingInvitationsBanner.tsx:55-69` | réfuté (aligné) | — |
| 7.5 | Ancienneté d'un membre | membres | « Membre depuis mars 2024 » (mois et année) · `team_members_page.dart:359-367` | « A rejoint le 3 mars 2024 » (date complète) · `TeamMemberList.tsx:124-128` | confirmé | faible |
| 7.6 | « (vous) » | membres | absent ; `PdlPersonRow.isCurrentUser` non passé · team_members_page.dart:353-374 | « (vous) » après son nom · TeamMemberList.tsx:117-121 | confirmé | faible |
| 7.7 | Soi-même dans une liste d'inscrits | personnes inscrites | avatar teinté (`isCurrentUser`) · `participant_list_view.dart:162` | aucun repère · `ParticipantList.tsx:113-162` | nouveau | faible |
| 7.8 | Capitaine dans la liste d'inscrits | personnes inscrites | ligne « Organisation du groupe » sous le nom · participant_list_view.dart:166-167 | pastille bouclier sur l'avatar plus « Capitaine » sous le nom · ParticipantList.tsx:133-158 | réfuté (même donnée) | — |

## 8. Tableau de bord d'équipe

| # | Sujet | Cartes concernées | App (valeur · fichier:ligne) | Site (valeur · fichier:ligne) | Verdict | Gravité |
|---|---|---|---|---|---|---|
| 8.1 | « N groupes » à zéro | sorties à venir | « Aucun groupe » (`rides.groupCount.zero`) · `dashboard_rides.dart:502-505` | « 0 groupe » · `UpcomingRideCard.tsx:72-74` | nouveau | faible |
| 8.2 | Commentaires à zéro | sorties à venir, publications | masqués à 0 · dashboard_rides.dart:506, `dashboard_content.dart:76` | « 0 commentaire » · UpcomingRideCard.tsx:75-79, `ContentLists.tsx:60-61` | confirmé | moyenne |
| 8.3 | Son groupe dans les lignes de remplissage | sorties à venir | pas de repère · dashboard_rides.dart (`_GroupFill`) | coche devant son groupe · UpcomingRideCard.tsx:158-166 | nouveau | faible |
| 8.4 | Groupe complet | sorties à venir | barre pleine rouge et badge « Complet » · `_GroupFill` | badge « Complet » et barre · UpcomingRideCard.tsx:182-201 | réfuté (aligné) | — |
| 8.5 | Étapes d'un voyage à 0 | vos prochaines sorties | masquées · dashboard_rides.dart (`_tripStats`) | « 0 étape » · `MyUpcomingList.tsx:106-109` | nouveau | faible |
| 8.6 | Vignette d'un nouveau parcours | nouveaux parcours | `r.thumbnailUrl` sans thème · dashboard_content.dart:156 | light/dark selon le thème, puis `thumbnailUrl` · ContentLists.tsx:79-84 | nouveau | faible |
| 8.7 | Tuile Brouillons | à faire | 2 noms plus « et N autres » · `dashboard_todo.dart` (`_names`) | tous les noms de la page, chacun un lien · `TodoBand.tsx:87-101` | nouveau | faible |
| 8.8 | Tuile Sans parcours | à faire | la première sortie avec sa date · dashboard_todo.dart (`_withoutRoute`) | toutes les sorties de la page, « Nom, date » · TodoBand.tsx:116-120 | nouveau | faible |
| 8.9 | Webhook | administration | badge Actif/Inactif **et** badge du dernier statut, « Jamais » sans tentative · `dashboard_admin.dart:340-370` | un seul badge (Désactivé, Échec ou Actif) ; sans tentative, rien · `AdminPanel.tsx:225-249` | nouveau | moyenne |
| 8.10 | Sans nouveaux membres ou sans fonctionnalité | administration | lignes « Aucun nouveau membre », « Aucune fonctionnalité » · dashboard_admin.dart:125, 137 | bloc masqué · AdminPanel.tsx:146, 179 | nouveau | faible |
| 8.11 | Ligne d'un modèle | modèles | « 3 groupes · prochaine #42 » · dashboard_admin.dart:62 + `ride_template_summary.dart:11-21` | « 3 groupes » seul · `TemplatesPanel.tsx:44-48` | nouveau | moyenne |

## 9. Notification, modèle de sortie, appareil, commentaire

| # | Sujet | Cartes concernées | App (valeur · fichier:ligne) | Site (valeur · fichier:ligne) | Verdict | Gravité |
|---|---|---|---|---|---|---|
| 9.1 | Ce qui a changé (sortie modifiée) | notification | dans le **titre**, sous forme de variante (`rideUpdated.both/dateTime/startPlace/other`), puis « Nouvelle date : … » sur la ligne de date · `notification_display.dart:23-84` | titre générique ; les changements forment la ligne de détail (« Lieu de départ modifié · Nouvelle date … ») · `NotificationItem.tsx:56-76` | nouveau | moyenne |
| 9.2 | Champs de la ligne | notification | titre, sujet, date, extrait, « Équipe · il y a … » · `notification_tile.dart:52-86` | mêmes champs, même ordre · NotificationItem.tsx:99-123 | réfuté (aligné) | — |
| 9.3 | Champs d'un modèle | modèle de sortie | nom, **statut**, « 3 groupes · prochaine sortie n° 42 » (ou « sans numérotation ») · `ride_template_card.dart:36-64` | nom, **description Markdown**, « 3 groupes », **visibilité**, **puces des groupes avec allure**, **tags** ; ni statut ni numéro · `RideTemplateListPage.tsx:138-179` | nouveau | forte |
| 9.4 | Appareil appairé | appareil | type, « Appairé le … · Utilisé … » · `paired_devices_section.dart:58-70` | mêmes champs · `PairedDevicesManager.tsx:100-106` | réfuté (aligné) | — |
| 9.5 | Corps d'un commentaire | commentaire | rendu en Markdown (`MarkdownContent`) · `comment_thread.dart:297` | texte brut, `pre-wrap` : `**gras**` reste en astérisques · `CommentItem.tsx:111-113` | nouveau | moyenne |
| 9.6 | Nombre de réponses masquées | commentaire | « Voir les N réponses » avec N = `replyCount` moins celles déjà affichées · comment_thread.dart:218-228 | N = `replyCount` total · CommentItem.tsx:150-161 | nouveau | faible |
| 9.7 | Soi-même | commentaire | avatar teinté (`isCurrentUser: mine`) · comment_thread.dart:251-256 | aucun repère · CommentItem.tsx:89 | nouveau | faible |

## 10. Météo (ligne de carte, données seulement)

| # | Sujet | Cartes concernées | App (valeur · fichier:ligne) | Site (valeur · fichier:ligne) | Verdict | Gravité |
|---|---|---|---|---|---|---|
| 10.1 | Pluie sans alerte | fil, prochaine sortie, étape | « Pluie 20 % » (`maxPrecipitationProbability`) · `ride_weather_summary_line.dart:139-154` | rien : seule l'alerte fait un badge · `f/components/weather/RideWeatherSummaryLine.tsx:100-117` | confirmé | moyenne |
| 10.2 | Contenu de l'alerte pluie | idem | « Pluie 60 % vers 11:00 » : la probabilité est dans le texte, la condition n'est pas nommée · ride_weather_summary_line.dart:139-146 | « Averses dès 11:00 » : la condition est nommée, la probabilité seulement dans l'info-bulle · RideWeatherSummaryLine.tsx:100-117 | nouveau | moyenne |
| 10.3 | Sans température | idem | le libellé de la condition remplace la température · ride_weather_summary_line.dart:180-184 | icône seule · RideWeatherSummaryLine.tsx:79-92 | nouveau | faible |

## Incohérences internes à l'app

| # | Sujet | Cartes concernées | Valeur par variante (fichier:ligne) | Verdict | Gravité |
|---|---|---|---|---|---|
| A.1 | Distance et D+ de la même sortie | fil, prochaine sortie, agenda, tableau de bord | fil : aucun chiffre de distance (PC:432-452). Prochaine sortie : ceux du **groupe** (next_ride_card.dart:325-347). Calendrier : `CalendarEventDto.distance`, le parcours **de la sortie** (agenda_card.dart:119-130). Tableau de bord : `ride.distance`, le parcours de la sortie ou du premier groupe (dashboard_rides.dart). Une même sortie peut montrer trois distances, ou aucune | nouveau | forte |
| A.2 | Nombre de groupes | fil, tableau de bord | fil : masqué à 0, icône `terrain` (PC:442-446). Tableau de bord : « Aucun groupe », icône `people` (dashboard_rides.dart:502-505) | confirmé | moyenne |
| A.3 | Personnes inscrites | fil, prochaine sortie, groupe, tableau de bord | « 11 personnes » (fil, PC:436) ; « 8/12 » nu (prochaine sortie, :341-343) ; « 11/12 personnes » (groupe, ride_group_card.dart:426-437) ; « 11 / 16 » ou « N inscriptions » (tableau de bord, `_GroupFill`) | confirmé | moyenne |
| A.4 | Lieu de départ | fil, prochaine sortie, agenda, tableau de bord | fil : absent. Prochaine sortie : nom et adresse. Calendrier : nom dans la méta. 7 jours : absent. Vos prochaines sorties : nom | nouveau | moyenne |
| A.5 | Nom du groupe rejoint | fil, prochaine sortie, 7 jours, calendrier, tableau de bord | fil : absent. Prochaine sortie : ligne. 7 jours : absent (week_agenda_section.dart:173-176). Calendrier : dans le badge (agenda_card.dart:232-236). Vos prochaines sorties : « Groupe B · 26 km/h » | nouveau | moyenne |
| A.6 | Image d'une même sortie | fil, prochaine sortie, 7 jours, calendrier | fil : carte de la sortie, deux fois. Prochaine sortie : carte du parcours du groupe. 7 jours et calendrier : aucune image | nouveau | faible |
| A.7 | Logo d'équipe | onglet Équipes, accueil, découverte | `_TeamCard` lit `team.about.assets.logo?.url` (teams_page.dart:216) ; « Mes équipes » et la découverte lisent `team.logoUrl` (my_teams_section.dart, team_discovery_card.dart:75) | nouveau | moyenne |
| A.8 | Champs d'une équipe | onglet Équipes, découverte, accueil | `_TeamCard` : logo, nom, « N membres », rôle. Découverte : visibilité, extrait, membres. Accueil : rôle et activité. Trois cartes pour un même `TeamDetailDto` | nouveau | moyenne |
| A.9 | Date d'une annonce | liste, tableau de bord | liste : date de création (ad_card.dart:126-129). Tableau de bord : pas de date (dashboard_content.dart) | nouveau | faible |
| A.10 | Lieu d'une annonce | liste, tableau de bord | liste : icône `place` (`location_on`, une épingle, ad_card.dart:135). Tableau de bord : « Secteur {lieu} » sans icône, dont le commentaire écarte « même une icône d'épingle » | nouveau | faible |
| A.11 | Commentaires d'un voyage | fil | ni compteur pour le voyage (PC:620-640) ni pour la publication à 0 ; la sortie en a un (PC:447) | nouveau | faible |

## Incohérences internes au site

| # | Sujet | Cartes concernées | Valeur par variante (fichier:ligne) | Verdict | Gravité |
|---|---|---|---|---|---|
| S.1 | Distance et D+ de la même sortie | fil, prochaine sortie, calendrier, tableau de bord | même schéma que A.1 : aucun chiffre dans le fil ; ceux du groupe sur la prochaine sortie (NextRideCard.tsx:65-66) ; ceux du parcours de la sortie au calendrier (CalendarView.tsx:149-158) ; `ride.distance` au tableau de bord (UpcomingRideCard.tsx:65-70) | nouveau | forte |
| S.2 | Ordre de la ligne résumé | 7 jours, calendrier | « Heure · Équipe · Groupe » (WeekAgenda.tsx:177-199) contre « Équipe · Heure · Lieu » (CalendarView.tsx:167-174) | nouveau | moyenne |
| S.3 | Personnes inscrites | fil, prochaine sortie, groupe, tableau de bord | « 11 personnes » plus « 11/40 places » (fil) ; « Groupe A · 8/12 personnes » (prochaine sortie) ; « 8/12 personnes » (groupe) ; « 11 / 16 » ou « N inscriptions » (tableau de bord) | confirmé | moyenne |
| S.4 | Champs d'une sortie au calendrier selon l'écran | calendrier bureau, calendrier mobile | bureau : distance, D+, statut, vignette (info-bulle). Mobile : titre, résumé, mention, inscription seulement (CalendarView.tsx:336-372) | nouveau | moyenne |
| S.5 | Visibilité d'une équipe | `TeamCard` | badge seulement si privée, sans icône (TeamCard.tsx:40-42), alors que publications, parcours et annonces l'affichent toujours | nouveau | faible |
| S.6 | « N groupes » | fil, agenda en lignes, tableau de bord | toujours affiché, 0 compris (PCw:120, AgendaRow.tsx:70-74, UpcomingRideCard.tsx:72-74), alors que le compteur de personnes est masqué sans groupe | réfuté (cohérent dans le site) | — |

## Non vérifié

- **Contenu réel de `media.assets.images` en vue COMPACT** (1.1, 7.1). L'affirmation que le bandeau de sortie du site
  est presque toujours un dégradé repose sur deux commentaires : celui de `CardImage` (« a compact row does not
  carry ») et celui du CLAUDE.md du site (« `media.assets` shrinks »). Je n'ai pas lu le code serveur qui vide ces images.
- **`thumbnailLightUrl` de `RideDto` est la carte du tracé** : je m'appuie sur le commentaire de PCw:180-181 (« it is
  the map preview »), pas sur la construction côté serveur.
- **Météo d'une sortie passée** (1.15, 2.8) : je n'ai pas vérifié si le serveur cesse d'envoyer `weather` une fois le
  départ passé. Si c'est le cas, l'écart n'a pas d'effet.
- **Lignes météo de groupe** (`RideGroupWeatherLine` contre `GroupWeatherLine`) : non lues.
- **Sortie solo dans l'app** (4.13) : le site lui donne un panneau de groupe avec ses lieux. Je n'ai pas relu le bloc
  de départ de l'app en détail pour savoir s'il montre les lieux du groupe ou ceux de la sortie.
- **Carte d'abonnement au calendrier** (`calendar_subscription_card.dart` contre `IcsFeedSettings.tsx`) : non comparée.
  Elle ne présente pas d'objet métier.
- **Répartition par rôle dans « Administration »** : présente des deux côtés (`_RoleSplit` contre `Progress.Root`),
  champs non comparés un à un.
- **Rendu de l'extrait sur le site quand il est absent** : la carte retombe sur `media.markdown`, vide en COMPACT. Je
  n'ai pas vérifié combien de lignes réelles restent sans extrait.
