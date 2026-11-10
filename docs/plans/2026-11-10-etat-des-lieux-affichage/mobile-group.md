# Mobile Flutter : écran d'un GROUPE de sortie, état des lieux

Lecture seule, worktree `feat/mobile-review` (HEAD `ef1fc9a99`). Chemins relatifs à `mobile/lib/`.
Libellés FR tirés de `mobile/assets/l10n/fr.json`. Rien n'a été lancé (ni build, ni simulateur) : tout ce qui suit vient de la lecture du code. Ce que je n'ai pas pu vérifier est signalé.

---

## 1. Points d'entrée

**Route go_router**
- `config/router.dart:791` `_rideGroupRoute(locale)` : une route **enfant** de la route du détail de sortie (`router.dart:676`, `routes: [_rideGroupRoute(locale), _rideEditRoute(locale)]`), `parentNavigatorKey: _rootNavigatorKey`. La page s'ouvre donc **hors du shell**, sans barre d'onglets du bas.
- Chemins (`contracts/routes.yaml:544`, id `rideGroup`) : FR `/equipes/{teamSlug}/sorties/{rideSlug}/groupes/{groupId}`, EN `/teams/{teamSlug}/rides/{rideSlug}/groups/{groupId}` ; `mobile: true`, `deeplink: true`.
- Query `?tab=` (hors contrat) : `RideGroupTab.fromQuery` (`features/rides/domain/ride_group_tab.dart`). `overview` | `weather` | `participants` ; une valeur absente ou inconnue donne `overview`.
- Lien profond : `_DeepLinkHierarchy` (`router.dart:249`) reconstruit dessous Équipes → Équipe → Agenda → Détail de la sortie.
- Un anonyme ne voit pas cette page : le `redirect` (`router.dart:894`) envoie tout non-authentifié vers `Paths.login()`. Le cas « non-membre » réel est donc une personne **connectée, extérieure à l'équipe**.
- Appel interne : `ride_detail_page.dart:201` `openGroup(group, {tab})` fait `selectRideGroup` puis `context.push(Paths.rideGroup(...)[?tab=…])`.

**Fichier de page** : `features/rides/presentation/pages/ride_group_page.dart`, `RideGroupPage` (ConsumerStatefulWidget). Paramètres : `teamSlug`, `rideSlug`, `groupId`, `initialTab`.

**Règle « solo »** (`features/rides/domain/solo_group.dart`) : `leavesGroupPage(ride) => ride.groups.length <= 1`. Pour une sortie solo ou sans groupe, la page montre son squelette puis **se remplace par le détail de la sortie** (`_leaveForRide`, `ride_group_page.dart:139`), par `pop`, `pushReplacement` ou `go`, sans laisser d'entrée d'historique. `?tab=weather` devient alors un défilement du détail jusqu'à sa carte météo (`rideScrollToWeatherProvider`). **L'écran de groupe n'existe donc que pour une sortie à ≥ 2 groupes.**

**Providers / DTO chargés**
| Provider | Fichier | DTO | Rôle |
|---|---|---|---|
| `rideRegistrationProvider(RideKey)` | `providers/ride_registration_controller.dart:119` | `RideRegistrationState` (`.ride: AsyncValue<RideDto>`, `.failure`, `.pendingGroupId`) | la sortie (adossée à `rideDetailProvider`), inscription optimiste |
| `rideDetailProvider(RideKey)` | `providers/ride_detail_provider.dart` | `RideDto` (`getRide`) | invalidé au pull-to-refresh |
| `rideWeatherProvider(RideKey)` | `providers/ride_weather_provider.dart:22` | `RideWeatherDto` (`getRideWeather`) | **pas lu** si `ride.isPast` (`finished`) ou `ride.isCancelled` (`status == 'CANCELLED'`) |
| `selectedRideGroupProvider(key)` | `providers/ride_group_selection_provider.dart` | id | sélection partagée avec le détail (gardée vivante par `watch`) |
| `rideMapColorModeProvider(key)` | idem | `RouteColorBy` | Pente / Revêtement / Météo, choix partagé carte + profil |
| `rideRouteGeometryProvider(RouteRef)` / `rideRouteGeometriesProvider(key)` | `ride_detail_provider.dart` | `RouteDetailDto` (tracks, waypoints, media.assets gpx/fit) | carte, profil, export |
| `rideRouteElevationProvider`, `rideRouteClimbBarsProvider`, `rideRouteSurfaceBarsProvider`, `rideRouteWindBarsProvider` | idem | dérivés | profil altimétrique |
| `canSeeMemberNamesProvider(teamSlug)` | `features/teams/providers/team_providers.dart:62` | bool (`platformAdmin \|\| (membership ?? false)`) | onglet Inscriptions, avatars |
| `teamMembershipProvider(teamSlug)` | `team_providers.dart:42` | `bool?` (depuis `myTeamsProvider`) | barre d'action (`?? true`) |
| `participantListProvider` | `features/participants/providers/participant_list_provider.dart` | pages de `PublicUserDto` | onglet Inscriptions |
| `authProvider` | `features/auth/providers/auth_provider.dart` | `user.id`, `user.connectedServices` | « vous », « Envoyer vers un appareil » |
| `unitSystemProvider`, `mapStyleProvider`, `defaultCenterProvider`, `hillshadeEnabledProvider` | `core/...` | | unités, fond de carte |

Champs DTO lus : `RideDto` : `name`, `slug`, `team.slug`, `timezone`, `dateTime`, `groups[]`, `routeSlug`, `startPlace`/`endPlace` (carte seulement), `finished`, `status`, `registeredGroupId`/`registeredGroup`. `RideGroupDto` : `id`, `name`, `startAt`, `countParticipants`, `participants[]`, `maxParticipants`, `registered`, `full`, `routeSlug`, `averageSpeed`, `distance`, `elevationGain`, `leader`. `time` (déprécié) n'est **jamais** lu. `WeatherLegDto` : `status`, `startTime`, `arrivalTime`, `averageSpeed`, `speedIsDefault`, `distance`, `checkpoints[]`, `segments[]`, `windExposure`, `prevailingWind`, `rainAlert`, `groupId`. `RideWeatherDto` : `status`, `departure` (`conditions`, `sunrise`, `sunset`), `legs`, `attribution`, `fetchedAt`, `availableFrom`.

---

## 2. Disposition (de haut en bas)

Coquille : `PdlScreenScaffold` (`ride_group_page.dart:347`) : app bar, puis `toolbar` (un sliver **épinglé** du même défileur), puis les `slivers`, puis `actionBar` en `bottomNavigationBar`. Pull-to-refresh (`_refresh`) : invalide détail, météo et liste des inscriptions.

### B0. App bar : `ride_group_page.dart:236` `_appBar`
- Bouton retour (`common.back` = « Retour »), qui `pop` sinon `go(Paths.ride)`.
- Titre sur deux lignes : `groupTitle(group.name, 'rides.groupPage.title')` = « Groupe {name} » (`domain/group_title.dart` : le nom seul s'il commence déjà par « Groupe »), style `barTitle`, 1 ligne avec ellipse ; dessous `ride.name` en `xs`.
- Action : icône `PdlIcons.share`, libellé « Partager le groupe », qui partage le titre `'${group.name} · ${ride.name}'` (nom brut, **sans** « Groupe ») et le lien `Paths.rideGroup`.
- Aucun badge (ni « Annulée », ni « Terminée »).

### B1. Barre d'outils épinglée : `ride_group_page.dart:402` `_toolbar`
1. **Pastilles des groupes** (`PdlChipRow`, sémantique « Groupes de la sortie »), si `ride.groups.length > 1`, ce qui est toujours vrai ici. Une `PdlChip` par groupe : `'${g.name} · ${_fill(g)}'`, où `_fill` donne « 11/12 », ou « 11 » sans plafond (`:457`). Le groupe courant est sélectionné. Un tap fait `_selectGroup`, qui change de groupe **sur place** (setState, sans navigation) et met à jour la sélection partagée.
2. **Onglets** `PdlSegmented<RideGroupTab>` : « Aperçu » | « Météo » | « Inscriptions ». Le troisième n'apparaît que si `canSeeNames`. Un non-membre qui arrive avec `?tab=participants` retombe sur l'Aperçu (`_shownTab`, `:105`).

### B2. Bandeau d'échec d'inscription : `ride_group_page.dart:359` (`registrationFailureBanner`, `widgets/registration_failure_banner.dart`)
- Condition : `registration.failure != null`, quel que soit l'onglet.
- Titre selon la raison : « Inscription impossible à {group}. » / « {group} est complet. » / « Réservé aux membres de l'équipe. » ; actions possibles « Quitter {group} » (bascule), « Voir l'équipe », « Réessayer » ; fermable.

### B3. Bloc de départ : `ride_group_page.dart:377` → `widgets/ride_departure_block.dart:23` `RideDepartureBlock` → `core/pdl/pdl_departure_block.dart:24`
- Condition : **onglet Aperçu seulement** (`_shownTab == overview`).
- Surface `surfaceAlt` bordée, rayon 12, padding 12. À gauche une **boîte du jour** `dayBoxFor(wall)` (`core/widgets/day_box.dart`) : « sam. / 12 / avr. », plus l'année si elle diffère.
- Au centre : « Départ {time} » en 22/700 (`departureTime`), heure = `group.startAt` dans `ride.timezone`. À côté, la pastille grise à icône horloge « Aujourd'hui » ou « Demain » (rien d'autre).
- Détails (14 atténué) : `[arrival]`, soit « Arrivée estimée {time} » (`groupLegArrival`, `ride_group_stats.dart:18`), seulement si le leg est `OK`/`STALE`.
- Puis `ZoneMentionLine` (icône `otherTimezone` + « heure de Tokyo (ven. 01:00 chez vous) »), seulement si le décalage diffère du lecteur.
- Pas de « Votre groupe : … » (réservé au détail de sortie, `group == null`).
- **Aucune date en texte** : la boîte du jour la porte seule (le lecteur d'écran l'entend via `semanticLabel`).
- Non actionnable.

### B4. Corps de l'onglet : voir ci-dessous (Aperçu / Météo / Inscriptions)

### B5. Espace de fin : `SizedBox(height: 16)` (`:395`)

### B6. Barre d'action fixe en bas : `widgets/ride_group_action_bar.dart:30` `RideGroupActionBar` (`PdlActionBar`)
- À gauche, en colonne :
  - compte, en `bodyStrong` : « {count}/{max} personnes » (`rides.groupPage.participantsCount`, pluriel sur `max`), ou « {count} personnes » sans plafond ;
  - si `max != null && !group.full` : « N places restantes » / « 1 place restante » / « Plus aucune place » (`placesLeft`) ;
  - si la personne est inscrite **dans un autre groupe** : « Votre inscription est dans le groupe {group}. » et le bouton texte « Voir mon groupe », qui bascule la page sur ce groupe.
- À droite, `rideGroupAction` (`domain/ride_group_action.dart`) :
  - « Rejoindre » plein (chargement « Adhésion... ») ;
  - « Quitter » contour (chargement « Désinscription... ») ;
  - badge gris « Complet » (lg) ;
  - ou rien.

### Feuilles modales / pages poussées depuis l'écran
- **Plein écran de la carte** (`PdlMapHero.fullscreenBuilder`, qui reconstruit `RideGroupsMap(fullscreen: true)`), au bouton plein écran ou, dans l'onglet Météo, au tap n'importe où.
- **Feuille « Fond de carte »** (fonds servis, « Ombrage du relief »).
- **Feuille d'un point de passage météo** (`RideWeatherCheckpointDetails`, `ride_weather_map_markers.dart`, plein écran seulement) : en-tête icône du ciel + « Départ / En route / Arrivée » + « Passage vers {time} » ; corps « À {distance} du départ », « 14 °C · Ciel dégagé », « Pluie 30 % », « {amount} de précipitations », flèche + vent, « Rafales {speed} ».
- **Feuille « Pluie probable »** (`RideWeatherRainDetails`) : « Pluie probable (40 %) vers 10:15, à 23,4 km. »
- **Feuille d'un point du parcours** (`openWaypoint`, `routes/presentation/widgets/waypoint_sheet.dart`), au tap d'un waypoint sur la carte ou le profil. Contenu non détaillé ici.
- **Export** : `pickAssetDestination` (Android : « Enregistrer sur le téléphone » / « Envoyer vers une autre app » ; iOS : feuille de partage), `pickGpsService` (choix du service GPS).
- **Menu membre** dans l'onglet Inscriptions (signaler / bloquer), `_openMemberMenu`.
- Navigation : « Voir le parcours » pousse `Paths.route(teamSlug, routeSlug)`.

---

### Onglet APERÇU : `widgets/ride_group_overview_tab.dart:89` (un `SliverToBoxAdapter` qui contient une `Column`)
`routeSlug = group.routeSlug ?? ride.routeSlug`.

| # | Bloc | Widget `fichier:ligne` | Condition | Contenu |
|---|---|---|---|---|
| A1 | **CARTE** | `ride_groups_map.dart:83` `RideGroupsMap(onlyGroup: group)`, appelée à `overview_tab:96` | `routeSlug != null` | Précédée de 16 px. **Pleine largeur** (aucun Padding horizontal). **Hauteur `rideMapHeight` = 44 % de la hauteur d'écran, bornée 260–460 px** (`ride_groups_map.dart:36`), soit ≈ 420 px sur un iPhone 17 Pro Max (956 pt), ≈ 371 px sur 844 pt. Seul le tracé du groupe, cadré sur lui (`PdlMapBox.ofTracks`), coloré **comme un parcours** (pente des montées par défaut, revêtement, ou vent en mode Météo). Pins départ/arrivée = `ride.startPlace`/`ride.endPlace` (ceux **de la sortie**). Bornes kilométriques (hors mode Météo). Waypoints (symboles). En mode Météo : pastilles (icône ciel, température, flèche de vent absolue), goutte de pluie, et légende du vent en bas à gauche (`ride_wind_map_legend.dart`) « Dos 32 km · Travers 18 km · Face 40 km », « Prévision ancienne », « Heures estimées à 25 km/h », « Prévisions : Open-Meteo.com ». Colonne de boutons 44 px à droite, centrée verticalement : plein écran (« Plein écran »), fond de carte. Crédit ⓘ, barre d'échelle (`servedMapScale`). **Non manipulable** encastrée (`interactive: fullscreen`) ; un tap sur une pastille ouvre le plein écran. Pas de pilule ni de case de tracé (un seul tracé). Chargement : `PdlSkeleton` à la même hauteur. |
| A2 | Interrupteur de couleur | `overview_tab:103` `RouteColorModeSwitch` | `routeSlug != null && modes.length > 1` | « Pente » \| « Revêtement » (si le parcours en a) \| « Météo » (si le leg a une prévision). Choix partagé avec le profil et le plein écran. |
| A3 | Profil altimétrique | `ride_elevation_section.dart:30` (`overview_tab:131`) | `routeSlug != null` | Ligne d'en-tête « Profil du groupe sélectionné » (xs 600) + à droite « 52,3 km · 640 m D+ » (`group.distance`, `group.elevationGain`). `PdlElevationProfile` **110 px** (`PdlMetrics.elevationMedium`), barres colorées par pente ou revêtement, bande du vent sous l'aire en mode Météo, marqueurs de waypoints, info-bulle « 12,4 km · 345 m · 6 % … », crédit « Données : IGN LiDAR HD, Mapterhorn et ses sources, © OpenStreetMap ». Chargement « Chargement du profil altimétrique... » ; échec « Profil indisponible » + « Réessayer ». Dessous, si le parcours a des revêtements : `RouteSurfaceSection` (barre segmentée, légende « Asphalte 72 % … », lien « © contributeurs OpenStreetMap ») ou « Revêtement en cours de calcul ». Dessous, si waypoints : `RouteWaypointsSection` « Points du parcours » (liste, « Voir les N autres points » / « Réduire »). |
| A4 | Bandeaux d'export | `ride_group_route_actions.dart:92` `exportBanners()` | après un export | échec (danger), ou réussite (« Fichier enregistré » / « Parcours envoyé avec succès! »), fermables |
| A5 | Chiffres | `ride_group_stats.dart:37` `RideGroupStats(showDeparture: false)` | au moins une valeur non nulle | `PdlCard` plate, `PdlMetaGrid` sur 2 colonnes (1 si la largeur < 320) : « Allure moyenne » 25 km/h, « Distance » 52,3 km, « Dénivelé positif » 640 m. La cellule « Départ » est coupée ici (elle sert au détail d'une sortie solo). |
| A6 | Capitaine | `ride_group_leader_row.dart:20` | `group.leader != null` (null = cas courant, rien n'est rendu, **aucun repli** sur `createdBy`) | Ligne : `PdlAvatar` 32 px + nom en `bodyStrong` + badge « Capitaine » (icône `PdlIcons.leader`, ton « inscrit »). Non cliquable. |
| A7 | Résumé météo | `overview_tab:190` `_weatherSummary` + `ride_group_weather_line.dart:27` | leg `OK`/`STALE` avec ≥ 1 point de passage | `PdlCard` plate **cliquable**, qui ouvre l'onglet Météo. En-tête « Météo au départ du groupe » + chevron. Ligne : icône ciel 16 px, « 14 °C » (statValue), « Ciel dégagé » ; badge bleu doux « Pluie 40 % vers 10:15 » (si alerte) ; badges « Face 12,3 km » et « Dos 24,0 km » (si > 0 ; pas de travers). Ces valeurs viennent du **premier point de passage du leg**. |
| A8 | Inscriptions | `overview_tab:220` `_participants` | toujours | `PdlSectionHeader` « Personnes inscrites », compteur `countParticipants`. Puis, si `canSeeNames` : `PdlAvatarStack` (avatars de `group.participants`, total, tap vers l'onglet Inscriptions), ou « Aucune inscription dans ce groupe pour le moment. ». Si `countParticipants > 0` : bouton texte « Voir toutes les personnes inscrites › ». Non-membre : l'en-tête et le nombre seuls. |
| A9 | Parcours du groupe | `ride_group_route_actions.dart:120` | `routeSlug != null` | `PdlSectionHeader` « Parcours du groupe ». Boutons texte sm : « Voir le parcours » (icône route), « GPX » (si l'asset existe), « FIT » (si l'asset existe), « Envoyer vers un appareil » (si `connectedServices` n'est pas vide). |

### Onglet MÉTÉO : `widgets/ride_group_weather_tab.dart:46` (un `SliverMainAxisGroup`)
Pas de bloc de départ B3 au-dessus (réservé à l'Aperçu).

- Sortie passée ou annulée : un seul `PdlEmptyState` « Pas de météo pour cette sortie » / « Aucune prévision n'est à afficher pour cette sortie. » (`:92`).
- Chargement : deux squelettes de 120 et 240 px. Erreur : « Météo indisponible pour le moment. » / « La prévision n'est pas encore arrivée, réessayez dans quelques minutes. » + « Réessayer ».
- `rideWeatherViewOf(status)` :
  - `hidden` : l'état vide ci-dessus ;
  - `unavailable` : erreur ;
  - `noLocation` (organisateur seulement) : bandeau info « Ajoutez un lieu de départ ou un parcours pour afficher la météo de cette sortie. Message visible du rôle Organisateur seulement. » ;
  - `notYetAvailable` : bandeau info (icône date) « Prévision disponible à partir du {lundi 15 janvier}. », ou « La météo sera disponible sept jours avant le départ. ».
- Prévision (`forecast` / `stale`), dans l'ordre :

| # | Bloc | Widget | Condition | Contenu |
|---|---|---|---|---|
| W1 | **CARTE** (mode Météo imposé) | `ride_group_weather_tab.dart:205` `RideGroupsMap(forceWeatherMode: true, cursorDistance)` | groupe trouvé, `routeSlug` connu et `showsWindOnMap(leg)` | En **tête** de l'onglet, 16 px au-dessus, pleine largeur, **même hauteur 44 % (260–460 px)**. Tracé coloré par le vent, légende du vent, pastilles, goutte, réticule du point de frise choisi. Sans interrupteur. **Un tap n'importe où ouvre le plein écran** (`tapOpensFullscreen`). |
| W2 | « Prévision ancienne » | `weather_leg_sections.dart:47` `WeatherStaleBanner` | statut `STALE` | Bandeau warn : « Prévision ancienne » / « La prévision n'a pas pu être rafraîchie depuis lundi 15 janvier 2026 à 08:30. » |
| W3 | Météo au départ | `departure_weather_section.dart:22` | toujours | En-tête « Météo au départ de 09:00 », ou « Météo au départ de la sortie, 09:00 » si le groupe part à une autre heure (`ofRide`). `PdlCard` plate : icône 40 px, « 14 °C » (statBigValue), « Ciel dégagé » ; « Ressenti 12 °C », « Pluie 30 % », « 1,2 mm de précipitations », vent (`WeatherWindLine`) ; « Lever du soleil 07:58 », « Coucher du soleil 18:21 ». Sans conditions : « Météo indisponible pour le moment. » |
| W4 | En-tête du leg | `weather_leg_sections.dart:130` `WeatherLegHeader(title: group.name)` | leg du groupe trouvé | `PdlSectionHeader` = **nom brut** du groupe (« A ») + compteur « 52,3 km ». « Départ 09:30 · arrivée estimée 12:10 » ; « Passages estimés à 25 km/h » (ou « …, vitesse par défaut : le groupe n'en indique pas ») ; « Vent dominant : ↗ 18 km/h » (flèche). |
| W5 | Corps du leg | `weather_leg_sections.dart:75` `weatherLegBody` | leg | `NO_LOCATION` : bandeau « Ce groupe n'a pas de parcours : la météo n'est donnée qu'au départ. ». Pas de prévision ou aucun point : bandeau « Les prévisions le long du parcours ne sont pas encore disponibles. ». Sinon les trois blocs ci-dessous. |
| W5a | Alerte pluie | `_RainAlertBanner :219` | `leg.rainAlert` | Bandeau warn « Pluie probable (40 %) vers 10:15, à 23,4 km. » |
| W5b | Exposition au vent | `_WindSection :236` | `segments` non vide | « Exposition au vent » ; carte : « Le vent le long du parcours », barre segmentée face/travers/dos, légende « Face 12,3 km · Travers 30,1 km · Dos 24,0 km » |
| W5c | Points de passage | `_Timeline :267` / `_CheckpointRow :302` | points de passage | « Points de passage » ; une ligne par point : colonne de 64 px avec heure (bodyStrong) et distance, rail avec pastille, puis « Départ / En route / Arrivée », icône, « 14 °C », ciel, flèche relative + badge « Face/Travers/Dos », vent et rafales, « Pluie 30 % », « 0,4 mm de précipitations », ou « Prévision pas encore disponible ici ». Touchable quand la carte W1 est là : pose ou ôte le réticule, fond `primarySoft`. |
| W6 | Attribution | `weather_leg_sections.dart:565` | toujours | « Prévision de lundi 15 janvier 2026 à 08:30 » (si `fetchedAt`), bouton lien « Prévisions : Open-Meteo.com ». |

### Onglet INSCRIPTIONS : `ride_group_page.dart:325` → `features/participants/presentation/widgets/participant_list_view.dart:24`
- Condition : `canSeeNames` (membre de l'équipe ou admin plateforme).
- 16 px en tête. `PdlSearchField` toujours affiché (`alwaysSearchable`), invite « Rechercher par nom... ».
- Lignes `PdlPersonRow` : avatar, nom, « vous », flag « Capitaine » si `person.id == group.leader?.id`. Une ligne s'ouvre sur le menu signaler / bloquer, sauf la sienne. Aucune date.
- Pagination par bouton : « 20 personnes sur 43 » + « Afficher plus » ; pied `PagedListFooter` (« Vous avez tout vu », erreur « Impossible de charger la suite. »).
- États : vide « Aucune inscription » / « Aucune inscription dans ce groupe pour le moment. » ; filtre vide « Personne ne correspond » / « Personne ne correspond à votre recherche. » + « Effacer » (libellé de `common.clearSearch` non relu) ; erreur « Erreur de chargement » + « Réessayer ».
- Une liste par groupe (`ValueKey('participants_${group.id}')`).

### États de page
- Chargement (`:463`) : squelettes de 20×200, 44, 220 et 96 px.
- Erreur (`:479`) : `PdlEmptyState` (non trouvé ou erreur, icône hors ligne) + « Réessayer ».
- Groupe absent (`:505`) : « Ce groupe n'existe plus » / « Il a peut-être été retiré de la sortie. » + « Retour à la sortie ».

---

## 3. Variantes

| Variante | Ce qui change |
|---|---|
| **Groupe avec parcours** (`group.routeSlug ?? ride.routeSlug`) | Aperçu : A1 carte, A2 interrupteur, A3 profil, A9 parcours/export. Météo : W1 si le leg a une prévision. |
| **Groupe sans parcours** (ni le groupe ni la sortie) | Aperçu : **ni carte, ni profil, ni export** ; l'onglet commence à B3 puis A5 (sans doute l'allure seule, puisque distance et D+ sont vraisemblablement nuls : non vérifié côté serveur), A6, A7, A8. Météo : pas de W1 ; W5 « Ce groupe n'a pas de parcours… » quand le leg est `NO_LOCATION`. **Aucun lieu de RDV n'apparaît alors nulle part** (seule la carte portait `startPlace`). Le chemin « carte vide » de `RideGroupsMap` (« Aucun parcours disponible » / « Le tracé n'a pas encore été publié… », `ride_groups_map.dart:161`) n'est atteint que si `routeSlug` existe sans couche correspondante. |
| **Groupe héritant du parcours de la sortie** (`group.routeSlug == null`, `ride.routeSlug != null`) | Identique au cas avec parcours (`effectiveRouteSlug`). |
| **Avec capitaine** (`leader != null`) | A6 visible ; flag « Capitaine » dans l'onglet Inscriptions **seulement s'il est inscrit dans ce groupe**. |
| **Sans capitaine** (cas courant) | A6 absent, rien à la place. |
| **Membre** | Onglet Inscriptions, avatars + « Voir toutes… » en A8, barre d'action selon l'état. |
| **Non-membre connecté** | Pas d'onglet « Inscriptions » ; A8 = en-tête + nombre seuls ; B6 : compte + places, **aucun bouton** (`rideGroupAction` → `none`), sauf « Quitter » s'il est inscrit (`registered` est testé avant `isMember`). Aucun bandeau « rejoignez l'équipe » sur cette page, contrairement à ce que dit le commentaire de `ride_group_action.dart` : seul l'échec d'inscription en produit un. Le capitaine (A6) reste affiché. Je suppose que l'API masque `leader` aux non-membres (invariant `MemberNamesVisibility`) ; non vérifié côté serveur. |
| **Appartenance inconnue** (`myTeams` pas chargé ou en échec) | B6 suppose « membre » (`?? true`) et montre « Rejoindre » ; noms masqués (`?? false`). Les deux defaults sont contraires. |
| **Anonyme** | Impossible sur mobile : redirection vers la connexion (`router.dart:894`). |
| **Inscrit dans ce groupe** | B6 « Quitter » (contour). |
| **Inscrit dans un autre groupe** | B6 : pas de bouton, « Votre inscription est dans le groupe {X}. » + « Voir mon groupe ». La bascule « quitter puis rejoindre » est réservée aux cartes du détail. |
| **Groupe complet** (`full`) | B6 badge « Complet », la ligne « places restantes » disparaît ; la pastille de groupe en B1 dit « 12/12 ». Un inscrit dans ce groupe voit quand même « Quitter ». |
| **Sans plafond** | « 11 personnes », ni places restantes ni « /max » dans la pastille. |
| **Sortie passée** (`finished`) | Météo jamais demandée : l'onglet Météo reste offert mais montre l'état vide ; A7 absent ; carte sans mode Météo. B6 sans bouton, mais **compte et « N places restantes » restent affichés**. B3 inchangé (il peut afficher « Aujourd'hui » pour une sortie finie le jour même). Aucun badge « Terminée ». |
| **Sortie annulée** | Comme une sortie passée, y compris l'absence de « Quitter ». **Aucune mention « Annulée » nulle part sur la page** (app bar, B3, onglets) : vérifié par grep, `isCancelled` n'est lu que pour la météo et l'action. |
| **Prévision `STALE`** | W2 ; mention dans la légende de carte ; A7 et l'arrivée de B3 restent affichés. |
| **Prévision `NOT_YET_AVAILABLE` / `UNAVAILABLE`** sur le leg | B3 sans arrivée estimée, A7 absent, pas de mode Météo, W1 absent, bandeau W5. |
| **Solo (1 groupe) / sans groupe** | La page n'est pas rendue : redirection vers le détail de sortie (`leavesGroupPage`). Les widgets `RideGroupStats` (avec la cellule Départ), `RideGroupLeaderRow`, `RideGroupRouteActions`, `RideGroupActionBar(onOpenGroup: null)` et `RideDepartureBlock` sont réutilisés par ce détail (couvert ailleurs). |
| **Multi-groupes** | Seul cas réel de l'écran. B1 a toujours ≥ 2 pastilles. |

**Partage avec l'écran d'étape** (`features/trips/presentation/pages/stage_detail_page.dart`) : il n'y a **pas de page commune** côté mobile (contrairement au web). Briques partagées :
- `RideWindMapLegend` (`stage_detail_page.dart:315`), `weather_map_layer.dart` (couleurs du vent, pastilles), `ride_weather_map_markers.dart` (feuilles de passage) ;
- `PdlDepartureBlock` + `dayBoxFor` + `ZoneMentionLine` (bloc de départ de l'étape, `stage_detail_page.dart:438`, avec sa propre composition : date et vitesse en détail, boîte turquoise, relatif masqué si passé ou annulé) ;
- `RouteColorModeSwitch`.
- L'écran météo d'étape (`stage_weather_page.dart`) partage `weather_leg_sections.dart` (`WeatherStaleBanner`, `WeatherLegHeader`, `weatherLegBody`, `WeatherAttributionBlock`, `weatherUnavailableSliver`).

L'étape utilise en revanche `EmbeddedRouteSheet` (`routes/presentation/widgets/embedded_route_sheet.dart`), **pas** `RideGroupsMap` ni `RideElevationSection`. La mise en page carte + profil diffère donc entre groupe et étape. `embedded_route_sheet` n'est pas utilisé par la page de groupe.

---

## 4. Dates et heures

Règles générales :
- `AppFormatters.formatTime` (`core/utils/formatters.dart:586`) applique `DateFormat.Hm()` en 24 h, `DateFormat.jm()` en 12 h. **En `fr`, le motif `jm` d'intl 0.20.3 vaut `HH:mm`** : le réglage 12 h n'a aucun effet en français.
- Conversion vers le fuseau de l'entité : `toZoneTime` / `tryParseZoneTime` (`:462`/`:471`). Fuseau d'affichage : `toDisplayTime` (`:411`), qui vaut `UserDto.timezone` sinon l'appareil.

| # | Emplacement | Champ source | Fonction (`fichier:ligne`) | Format, exemple FR | Fuseau | Particularités |
|---|---|---|---|---|---|---|
| 1 | B3 titre « Départ » | `RideGroupDto.startAt` | `ride_departure_block.dart:50-55` : `toZoneTime(instant, ride.timezone)` + `formatTime` + `rides.departureBlock.departs` | « Départ 09:30 » | **sortie** (`RideDto.timezone`) | Heure **du groupe**, pas `ride.dateTime`. |
| 2 | B3 boîte du jour | `startAt` | `day_box.dart` `dayBoxFor(wall)` : `dayAbbrev` (`DateFormat.E`), `monthAbbrev` (`DateFormat.MMM`) | « sam. » / « 12 » / « avr. » (+ « 2027 ») | jour du fuseau sortie | L'année se compare à `displayNow().year` (fuseau **lecteur**), alors que `formatDepartureDate` compare dans le fuseau de la sortie. |
| 3 | B3 pastille relative | `startAt` | `formatDepartureRelative` (`formatters.dart:669`) | « Aujourd'hui » / « Demain », sinon rien | maintenant et départ tous deux dans le fuseau sortie | Pas de « hier ». Pas de garde passé/annulé ici (l'étape en a une). |
| 4 | B3 (sémantique seule) | `startAt` | `formatDepartureDate` (`:689`, `MMMEd` → `EEE d MMM`) | « sam. 12 avr. » | sortie | Lu par le lecteur d'écran, **invisible** à l'écran. |
| 5 | B3 arrivée estimée | `WeatherLegDto.arrivalTime` | `groupLegArrival` (`ride_group_stats.dart:18`) → `formatWeatherTime` (`domain/ride_weather_display.dart:185`) | « Arrivée estimée 12:10 » | sortie, **sans mention** | Seulement leg `OK`/`STALE` ; jamais `RideDto.endDateTime`. |
| 6 | B3 mention de fuseau | `startAt` | `ZoneMentionLine` (`core/widgets/zone_mention_line.dart`) → `formatZoneMention` (`:557`) + `readerEquivalent` (`:542`) | « heure de Tokyo (ven. 01:00 chez vous) » | compare le décalage sortie / lecteur | Rien quand les décalages sont égaux (cas courant). |
| 7 | Résumé météo A7, alerte | `WeatherRainAlertDto.time` | `ride_group_weather_line.dart:72` `formatWeatherTime` | « Pluie 40 % vers 10:15 » | sortie, sans mention | |
| 8 | W2 « Prévision ancienne » | `RideWeatherDto.fetchedAt` | `formatLongDateTime` (`:614`) | « …depuis lundi 15 janvier 2026 à 08:30. » | **lecteur** (horodatage) | |
| 9 | W3 titre « Météo au départ » | **`RideDto.dateTime`** (pas le groupe) | `departureWeatherTitle` (`departure_weather_section.dart:80`) → `formatWeatherTime` | « Météo au départ de 09:00 » / « Météo au départ de la sortie, 09:00 » | sortie, sans mention | La prévision est calculée côté serveur à l'heure de la **sortie** ; « de la sortie » s'ajoute si `groupLeavesAtOwnTime`. |
| 10 | W3 lever / coucher | `DepartureWeatherDto.sunrise/sunset` | `departure_weather_section.dart:152-165` `formatWeatherTime` | « Lever du soleil 07:58 », « Coucher du soleil 18:21 » | sortie | |
| 11 | W4 horaires du leg | `leg.startTime`, `leg.arrivalTime` | `weather_leg_sections.dart:167` `formatWeatherTime` | « Départ 09:30 · arrivée estimée 12:10 » | sortie | Doublon de B3 (autre onglet). |
| 12 | W5a alerte pluie | `rainAlert.time` | `formatRainAlert` (`ride_weather_display.dart:193`) | « Pluie probable (40 %) vers 10:15, à 23,4 km. » | sortie | |
| 13 | W5c frise | `WeatherCheckpointDto.time` | `_CheckpointRow` `weather_leg_sections.dart:333` | « 10:42 » au-dessus de « 23,4 km » | sortie | Heure seule, sans date. |
| 14 | Pastilles carte (sémantique) | `checkpoint.time` | `weatherCheckpointSummary` (`ride_weather_map_markers.dart:133`) | « En route, 10:42, 23,4 km, 14 °C… » | sortie | Pas d'heure **visible** sur la pastille (icône, température, flèche). |
| 15 | Feuille de point de passage | `checkpoint.time` | `ride_weather_map_markers.dart:334` | « Passage vers 10:42 » | sortie | |
| 16 | Feuille pluie | `rainAlert.time` | `formatRainAlert` | idem n° 12 | sortie | |
| 17 | W6 attribution | `fetchedAt` | `formatLongDateTime` | « Prévision de lundi 15 janvier 2026 à 08:30 » | lecteur | Formule un peu bancale (« de lundi… »). |
| 18 | Bandeau « pas encore » | `RideWeatherDto.availableFrom` | `notYetAvailableMessage` (`ride_weather_widgets.dart:215`) → `formatFullDate` (`:598`) | « Prévision disponible à partir du lundi 15 janvier. » | **lecteur** (`toDisplayTime`) | Ce jour est lié au départ mais se lit dans le fuseau lecteur, sans année. |
| 19 | (Non affiché ici) `RideGroupStats` cellule « Départ » | `startAt` | `formatGroupStart` (`domain/group_start.dart`) | « 09:30 » + mention + « Arrivée estimée » | sortie | Coupée sur cette page (`showDeparture: false`) ; utilisée par le détail solo. |

**RDV et départ** : il n'y a **pas d'heure de rendez-vous distincte** dans `RideGroupDto` ; le seul instant est `startAt`, toujours renseigné (= `RideDto.dateTime` pour un groupe qui part avec la sortie). L'écran ne montre donc jamais l'heure de la sortie, sauf dans le titre W3 « Météo au départ de la sortie, 21:30 » quand le groupe part à une autre heure. Heures de passage météo : toutes en fuseau sortie, sans mention de fuseau, heure seule.

---

## 5. Wireframes ASCII (portrait)

### Aperçu (groupe avec parcours, membre, prévision OK)
```
┌──────────────────────────────────────┐
│ ←  Groupe A                    [⇪]   │ B0 app bar
│    Sortie du samedi                  │
├──────────────────────────────────────┤
│ (A · 11/12) (B · 8) (C · 5/10)  →    │ B1 pastilles  ┐ épinglé
│ [ Aperçu | Météo | Inscriptions ]    │ B1 onglets    ┘
├──────────────────────────────────────┤
│ [bandeau échec inscription]          │ B2 (si échec)
│ ┌────┐ Départ 09:30  (⏱ Demain)      │
│ │sam.│ Arrivée estimée 12:10         │ B3 bloc de départ
│ │ 12 │ 🌐 heure de Tokyo (…chez vous)│    (mention si ailleurs)
│ │avr.│                               │
│ └────┘                               │
│══════════════════════════════════════│
│                                  [⛶] │
│        CARTE (tracé du groupe)   [▦] │ A1 CARTE pleine largeur
│        ≈ 44 % de l'écran             │    260–460 px
│ [légende vent, mode Météo]     ⓘ ─── │
│══════════════════════════════════════│
│ [ Pente | Revêtement | Météo ]       │ A2 interrupteur (si >1)
│ Profil du groupe sélectionné  52,3 km · 640 m D+ │
│ ▁▂▃▅▇▅▃▂▁▂▃▅▃▂▁  (110 px)            │ A3 profil
│ ▬▬▬▬▬▬▬▬▬ Asphalte 72 % · Gravier…   │    revêtement (si connu)
│ Points du parcours …                 │    waypoints (si présents)
│ [bandeau export]                     │ A4 (après un export)
│ ┌──────────────────────────────────┐ │
│ │ Allure moyenne   Distance        │ │ A5 chiffres
│ │ 25 km/h          52,3 km         │ │
│ │ Dénivelé positif                 │ │
│ │ 640 m                            │ │
│ └──────────────────────────────────┘ │
│ (●) Léa Martin  [★ Capitaine]        │ A6 (si leader)
│ ┌──────────────────────────────────┐ │
│ │ Météo au départ du groupe      › │ │ A7 résumé météo (→ Météo)
│ │ ☀ 14 °C Ciel dégagé [☂ Pluie 40 %│ │
│ │ vers 10:15] [Face 12,3 km][Dos …]│ │
│ └──────────────────────────────────┘ │
│ Personnes inscrites              11  │ A8
│ (●)(●)(●)(●)(+7)                     │
│ Voir toutes les personnes inscrites ›│
│ Parcours du groupe                   │ A9
│ Voir le parcours  GPX  FIT  Envoyer… │
├──────────────────────────────────────┤
│ 11/12 personnes          [Rejoindre] │ B6 barre d'action fixe
│ 1 place restante                     │
└──────────────────────────────────────┘
```

### Météo (prévision OK, parcours)
```
┌──────────────────────────────────────┐
│ ←  Groupe A                    [⇪]   │ B0
│    Sortie du samedi                  │
├──────────────────────────────────────┤
│ (A · 11/12) (B · 8) (C · 5/10)       │ B1 épinglé
│ [ Aperçu | Météo | Inscriptions ]    │
├──────────────────────────────────────┤
│ [bandeau échec inscription]          │ B2 (si échec)
│══════════════════════════════════════│
│  CARTE mode Météo imposé         [⛶] │ W1 CARTE en tête
│  pastilles ☀14° ↗ · goutte 💧    [▦] │    260–460 px
│  [Dos 32 km · Travers 18 · Face 40]  │    tap = plein écran
│  [Prévisions : Open-Meteo.com]   ⓘ   │
│══════════════════════════════════════│
│ ⚠ Prévision ancienne …               │ W2 (si STALE)
│ Météo au départ de la sortie, 09:00  │ W3
│ ┌──────────────────────────────────┐ │
│ │ ☀  14 °C                         │ │
│ │    Ciel dégagé                   │ │
│ │ Ressenti 12 °C  Pluie 30 %  Vent…│ │
│ │ 🌅 Lever 07:58   🌇 Coucher 18:21│ │
│ └──────────────────────────────────┘ │
│ A                           52,3 km  │ W4 en-tête du leg
│ Départ 09:30 · arrivée estimée 12:10 │
│ Passages estimés à 25 km/h           │
│ Vent dominant : ↗ 18 km/h            │
│ ⚠ Pluie probable (40 %) vers 10:15,… │ W5a (si alerte)
│ Exposition au vent                   │ W5b
│ ┌ Le vent le long du parcours ─────┐ │
│ │ ▬▬▬▬▬▬▬▬▬▬▬▬▬ (face/trav./dos)   │ │
│ │ Face 12,3 km · Travers … · Dos … │ │
│ └──────────────────────────────────┘ │
│ Points de passage                    │ W5c frise
│ 09:30 ●  Départ  ☀ 14 °C Ciel dégagé │
│ 0,0 km │  ↗[Dos] Vent SO 18 km/h…    │
│ 10:42 •  En route ⛅ 16 °C …          │
│ 23,4km │  …                          │
│ 12:10 ●  Arrivée …                   │
│ Prévision de lundi 15 janvier 2026 à 08:30 │ W6
│ ↗ Prévisions : Open-Meteo.com        │
├──────────────────────────────────────┤
│ 11/12 personnes          [Rejoindre] │ B6
│ 1 place restante                     │
└──────────────────────────────────────┘
```
(Sortie passée ou annulée : sous B1, un seul état vide « Pas de météo pour cette sortie ».)

### Inscriptions (membre)
```
┌──────────────────────────────────────┐
│ ←  Groupe A                    [⇪]   │ B0
│    Sortie du samedi                  │
├──────────────────────────────────────┤
│ (A · 11/12) (B · 8) (C · 5/10)       │ B1 épinglé
│ [ Aperçu | Météo | Inscriptions ]    │
├──────────────────────────────────────┤
│ [bandeau échec inscription]          │ B2 (si échec)
│ 🔍 Rechercher par nom...             │ recherche
│ (●) Léa Martin        [Capitaine]    │ PdlPersonRow ×N
│ (●) Vous (Paul D.)                   │
│ (●) Sam K.                        ›  │
│ …                                    │
│     20 personnes sur 43              │
│        [ Afficher plus ]             │
│      Vous avez tout vu               │ pied
├──────────────────────────────────────┤
│ 11/12 personnes            [Quitter] │ B6
│ 1 place restante                     │
└──────────────────────────────────────┘
```

---

## 6. Étonnements

1. **La carte n'est pas tout en haut de l'Aperçu** : elle vient après le bloc de départ (B3, ≈ 90–110 px estimés), et en Météo elle est en tête. Les deux onglets n'ont donc pas la même première vue. Hauteur identique (44 %, 260–460 px), mais l'Aperçu la laisse manipuler (via le plein écran), alors qu'en Météo un tap n'importe où ouvre le plein écran.
2. **Le bloc de départ (B3) disparaît sur l'onglet Météo** : l'heure du groupe n'y figure plus que dans l'en-tête du leg W4 (« Départ 09:30 · arrivée estimée 12:10 »), qui n'existe que si le leg existe.
3. **Deux « météo au départ » qui peuvent se contredire** : A7 « Météo au départ du groupe » (premier point de passage du leg, à l'heure du groupe) et W3 « Météo au départ de la sortie, 09:00 » (point de RDV, à l'heure de la sortie). Le tap sur A7 mène à W3 en tête, qui montre une autre température si les heures diffèrent.
4. **Triple compte des inscriptions** : pastille B1 « A · 11/12 », en-tête A8 « Personnes inscrites 11 », barre B6 « 11/12 personnes ». À cela s'ajoutent la progression de l'onglet Inscriptions et le libellé « Inscriptions » de l'onglet (qui ne dit pas « Personnes »).
5. **Distance et D+ affichés deux fois dans l'Aperçu** : en-tête du profil A3 (« 52,3 km · 640 m D+ ») et chiffres A5 (« Distance », « Dénivelé positif »). L'heure d'arrivée apparaît aussi deux fois sur deux onglets (B3 et W4).
6. **Libellé « Profil du groupe sélectionné »** (`rides.selectedGroupProfile`) repris tel quel de la page multi-groupes : sur la page d'**un** groupe, « sélectionné » ne veut rien dire.
7. **Nom du groupe incohérent** : « Groupe A » en app bar (`groupTitle`), mais « A · 11/12 » dans les pastilles, « A » en titre du leg W4, « A · Sortie… » dans le partage, « Votre inscription est dans le groupe B. » (nom brut ; avec un club qui nomme « Groupe B », cela donne « le groupe Groupe B »).
8. **Aucun lieu de RDV textuel** : `ride.startPlace` n'est rendu que comme pin de carte (`ride_groups_map.dart:496`). Un groupe sans parcours n'a **ni carte ni lieu**. Les pins sont ceux de la sortie, même si le parcours du groupe part ailleurs.
9. **Ni description, ni commentaires, ni pièces jointes** de la sortie sur cette page (vérifié : aucun import `markdown_content`, `comment_thread` ou `media_attachments`). Le web, qui partage désormais la page groupe/étape, en a peut-être (non vérifié ici).
10. **Sortie annulée invisible** : aucun badge « Annulée » ni « Terminée » sur la page (`isCancelled` ne sert qu'à couper la météo et l'action). La barre B6 continue d'afficher « N places restantes » sur une sortie finie ou annulée.
11. **Onglet Météo offert pour une sortie passée ou annulée**, qui ne mène qu'à un état vide.
12. **Appartenance inconnue** : `teamMembershipProvider ?? true` côté barre d'action (B6 propose « Rejoindre ») contre `?? false` côté noms (pas d'onglet Inscriptions). Pendant le chargement de `myTeams`, ou s'il échoue, l'écran promet l'inscription tout en cachant les noms.
13. **Non-membre** : le commentaire de `ride_group_action.dart` annonce « un bandeau prend sa place à l'échelle de l'écran », mais la page de groupe n'en a aucun, seulement la barre avec le compte, sans explication.
14. **Le flag « Capitaine » de la liste** dépend de l'inscription du capitaine dans le groupe. Un capitaine qui ne roule pas apparaît en A6 mais pas dans l'onglet (assumé dans le code, `participant_list_view.dart`).
15. **Réglage 12 h sans effet en français** : `DateFormat.jm()` `fr` = `HH:mm` (intl 0.20.3). Le choix « 12 h / 24 h suit le téléphone » ne vaut qu'en anglais.
16. **Année de la boîte du jour** comparée au fuseau lecteur (`dayBoxFor` → `displayNow()`), alors que les autres dates du départ se comparent dans le fuseau de la sortie (`_departureWalls`). Écart possible autour du Nouvel An.
17. **« Aujourd'hui » sur une sortie terminée** : `RideDepartureBlock` ne masque pas le relatif pour une sortie passée ou annulée (`stage_detail_page.dart:449` le fait pour l'étape).
18. **Code mort** : la condition `ride.groups.length > 1` des pastilles est toujours vraie ici (la page part sous 2 groupes). `RideGroupStats.showDeparture` est forcé à faux sur cette page.
19. **« Météo au départ de 09:00 »** : formulation (« de » + heure) maladroite. Idem « Prévision de lundi 15 janvier 2026 à 08:30 ».
20. **Ordre de l'onglet Météo différent de sa doc** : la docstring de `ride_group_weather_tab.dart` place « Prévision ancienne » en tête ; le code met d'abord la carte, puis la marque.
21. **Le jour de disponibilité de la prévision** (`availableFrom`) est lu dans le fuseau lecteur (`formatFullDate`), sans année, alors qu'il dépend du départ (fuseau de la sortie).
