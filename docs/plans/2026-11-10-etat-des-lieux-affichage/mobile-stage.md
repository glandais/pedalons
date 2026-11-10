# Mobile Flutter : écrans d'une ÉTAPE de voyage (état des lieux)

Périmètre : `StageDetailPage` (écran 25) et `StageWeatherPage` (« Météo du parcours » d'une étape), avec leurs widgets.
Chemins relatifs à `mobile/lib/`. Lecture du code seule : rien n'a été lancé, aucun rendu n'a été vu. Les hauteurs en
pixels sont celles du code (constantes). Les positions « à l'écran » sont des estimations, signalées comme telles.

---

## 1. Points d'entrée

### Routes go_router
- **Détail d'étape** : `config/router.dart:822-836`. GoRoute enfant de la route du voyage (`TripDetailPage`), chemin
  `PathVariants.stage` (`config/paths.generated.dart:411-416`) :
  - fr `/equipes/{teamSlug}/voyages/{tripSlug}/etapes/{stageSlug}`
  - en `/teams/{teamSlug}/trips/{tripSlug}/stages/{stageSlug}`
  - `parentNavigatorKey: _rootNavigatorKey` : l'écran couvre la coquille, donc **pas de barre d'onglets**.
  - Lien profond : `_DeepLinkHierarchy` (`config/router.dart:295-303`) remet dessous Équipes > Équipe > Agenda de
    l'équipe > Voyage.
  - `contracts/routes.yaml:657-664` déclare aussi `stageMap` (`…/etapes/{stageSlug}/carte`), qui n'est **pas** enregistré
    dans le router mobile. C'est le plein écran du web, comme `rideGroupMap` (« web only », `routes.yaml:555`).
- **Météo d'étape** : pas de route, pas d'URL. `StageWeatherPage.open` fait `Navigator.of(context).push(MaterialPageRoute)`
  (`features/trips/presentation/pages/stage_weather_page.dart:41-54`).

### Qui ouvre l'étape
- La carte d'étape de l'écran du voyage fait `context.push(Paths.stage(...))` (`trips/presentation/pages/trip_detail_page.dart:572-574`).
- L'agenda (calendrier, « Cette semaine » de l'accueil), pour un `CalendarEventDto` de type `TRIP_STAGE`, fait
  `context.push(Paths.stage(...))` (`calendar/presentation/widgets/agenda_card.dart:46-50`).
- Le rail de l'étape elle-même fait `context.replace(Paths.stage(...))` (`stage_detail_page.dart:360`).
- Le lien de partage (`stage_detail_page.dart:368-372`).

### Fichiers de page
- `features/trips/presentation/pages/stage_detail_page.dart` (645 lignes) : `StageDetailPage`, `_StageDetailContent`,
  `_StageNotFound`, `_StageSkeleton`, `_StageError`.
- `features/trips/presentation/pages/stage_weather_page.dart` (203 lignes).

### Providers / DTO chargés
| Provider | Fichier | Appel API | Lu par |
|---|---|---|---|
| `tripDetailProvider(TripKey)` (autoDispose) | `trips/providers/trip_detail_provider.dart:43` | `getTrip(team, trip)` → `TripDto` avec `stages[]` | page d'étape (l'étape est choisie par son slug dans `trip.orderedStages`, `stage_detail_page.dart:67-71`). **Il n'y a pas d'endpoint d'étape.** |
| `tripWeatherProvider(TripKey)` (autoDispose) | `trips/providers/trip_weather_provider.dart:22` | `getTripWeather` → `TripWeatherDto { status, stages[TripStageWeatherDto{stageId, leg, departure, summary}], attribution, availableFrom, fetchedAt }` | carte météo, mode Météo de la carte, page météo |
| `tripMapColorModeProvider(TripKey)` (StateProvider, Pente par défaut) | `trips/domain/trip_weather_map.dart:32` | n/a | interrupteur Pente/Revêtement/Météo, partagé avec la carte d'ensemble du voyage |
| `routeDetailProvider(RouteKey)` | `routes/providers/route_detail_provider.dart` | `RouteDetailDto` (géométrie, waypoints, climbs, media gpx/fit) | `EmbeddedRouteSheet` |
| `routeElevationSamplesProvider`, `routeSurfaceBarsProvider`, `routeClimbBarsProvider`, `routeWindBarsProvider` | `routes/providers/route_elevation_provider.dart` | dérivés côté client | profil |
| `teamMembershipProvider(teamSlug)` | `teams/providers/team_providers.dart:42` | `getMyTeams` | `canComment` |
| `teamRoleProvider` + `authProvider` (platformAdmin) via `watchCanSeeWeatherNoLocation` | `rides/presentation/widgets/ride_weather_widgets.dart:22-30` | n/a | affichage du bandeau `NO_LOCATION` |
| `unitSystemProvider` | `core/preferences/user_preferences_provider.dart` | n/a | toutes les unités |
| Fil de commentaires (`CommentThread`, `CommentEntity.stage`) | `comments/presentation/widgets/comment_thread.dart` | commentaires de l'étape | fil |

Champs de `TripStageDto` (`api/generated/models/trip_stage_dto.dart:17-60`) : `id, slug, name, dateTime, timezone, media,
sortOrder, stageIndex, stageCount, averageSpeed?, route?, startPlace?, endPlace?, commentCount?`. Il n'y a **ni heure
d'arrivée, ni participation, ni statut propre à l'étape** (le statut est celui du voyage).

Dérivés de `TripDto` (`trip_detail_provider.dart:59-104`) : `isPast = finished` (côté serveur : « la dernière étape a
commencé »), `isCancelled = status == 'CANCELLED'`, `orderedStages` (tri par `stageIndex` puis `sortOrder`).

---

## 2. Disposition

### 2.A `StageDetailPage`, état chargé (`_StageDetailContent.build`, `stage_detail_page.dart:101-240`)

Coquille : `PdlScreenScaffold` avec `appBar`, `toolbar` (épinglé), `slivers`, `onRefresh`. Pas de `actionBar`, pas
de `bottomTabs`.

| # | Bloc | Widget `fichier:ligne` | Condition | Contenu exact | Actions |
|---|---|---|---|---|---|
| 0 | **App bar** | `PdlAppBar`, `stage_detail_page.dart:132-145` | toujours | **Pas de titre** (commentaire l.133-135 : le corps le porte déjà). Bouton retour (libellé lu « Retour au voyage »), action icône `PdlIcons.share` (« Partager »). | Retour → `context.go(Paths.trip)` (pas `pop`). Partager → `shareAppLink(title: "{voyage} — {étape}", path: Paths.stage)` |
| 1 | **Rail d'étapes** (épinglé sous l'app bar) | `PdlStageRail`, `stage_detail_page.dart:148`, `331-363`. Composant : `core/pdl/pdl_stage_rail.dart` | toujours | Pastilles bi-ligne, hauteur minimale 64 (`PdlMetrics.stageRail`), chaque pastille ≥ 44. Pastille 0 « Aperçu ». Puis une pastille par étape : ligne haute = **nom de l'étape** (`s.name`, jamais tronqué), ligne basse = **date** `formatDepartureDate(s.dateTime, s.timezone)` (« mar. 12 août »), tronquée à 18 graphèmes. Pastille active : fond `primary`, recentrée automatiquement. | « Aperçu » → `go(trip)`. Autre étape → `context.replace(Paths.stage)`. Étape courante : rien. |
| 2 | **Identité** | `_identity`, `stage_detail_page.dart:150-152`, `375-430` | toujours | (a) `PdlTeamLine` : **nom du voyage**, icône `PdlIcons.trip` (et non l'équipe). (b) Nom de l'étape en `screenTitle` (22/700). (c) Badges : « Étape {index} sur {total} » (ton `registered`) puis **un** badge d'état : « Annulé » si annulé, sinon « Terminé » si `trip.isPast`, sinon `status.{status}` (« Publié » / « Brouillon »). (d) Bloc de départ (#2bis). | Ligne du voyage → `go(trip)` |
| 2bis | **Bloc de départ** | `_departure`, `stage_detail_page.dart:426`, `438-476`. Composant : `core/pdl/pdl_departure_block.dart` | `stage.dateTime` lisible | Surface alternée bordée. À gauche, la boîte du jour `dayBoxFor(wall, tone: trip)` (turquoise) : « mar. / 12 / août » (+ année hors de l'année en cours). Titre « Départ 08:30 » (22/700). Pastille « Aujourd'hui » / « Demain » (gris, icône horloge) si ni passé ni annulé. Ligne de détail : « mar. 12 août · 22 km/h » (la vitesse seulement si `averageSpeed`). Mention de fuseau `ZoneMentionLine` si le décalage diffère. | aucune |
| 3 | **Lieux** | `_facts`, `stage_detail_page.dart:153`, `482-516` | `startPlace` ou `endPlace` non nul (sinon `SizedBox.shrink`) | `PdlCard(flat)` : `PdlPlaceRow(start)` pastille verte + nom + adresse ; `PdlPlaceRow(end)` pastille rouge + nom + adresse. Pas d'action en bout de ligne. | aucune |
| 4a | **Carte météo** (version sans parcours) | `StageWeatherCard`, `stage_detail_page.dart:156-159` | `stage.route == null` | Voir 2.C. En pratique (étape sans parcours, donc leg `NO_LOCATION`) : le bandeau « Ajoutez un parcours à cette étape… » pour organisateur/admin, **rien** pour les autres. | n/a |
| 4b | **Fiche parcours embarquée** (avec la CARTE) | `EmbeddedRouteSheet`, `stage_detail_page.dart:160-192`. Widget : `routes/presentation/widgets/embedded_route_sheet.dart` | `stage.route != null` | Voir 2.B (carte de **240 px**, profil de **140 px**, carte météo insérée avant les cols). | voir 2.B |
| 4c | **État vide « Aucun parcours »** | `PdlEmptyState`, `stage_detail_page.dart:193-204` | `stage.route == null` | Icône `PdlIcons.route`, titre « Aucun parcours », message « Cette étape n'a pas encore de parcours associé. » | aucune |
| 5 | **Description** | `_description`, `stage_detail_page.dart:205-206`, `518-532` | `media.markdown` non vide | En-tête « Description » + `MarkdownContent` (images inline `media.assets.images`) | liens markdown |
| 6 | **Pièces jointes** | `MediaAttachments`, `stage_detail_page.dart:209-218` (`core/widgets/media_attachments.dart`) | `attachments` non vide | En-tête « Pièces jointes », une ligne par fichier | téléchargement / visionneuse d'image |
| 7 | **Commentaires** | `CommentThread`, `stage_detail_page.dart:223-236` | `stage.commentCount != null` (le serveur l'omet pour qui ne peut pas lire) | En-tête « Commentaires » + compteur (« 3 commentaires »). Composeur « Écrire un commentaire... » / « Publier » si `canComment`. Liste : auteur + date relative, « Répondre », « Voir plus de commentaires ». | commenter, répondre, menu ⋯ |
| 8 | Espace bas | `stage_detail_page.dart:237` | toujours | 16 px | n/a |

**Position de la carte** : c'est le 2e élément de la fiche parcours (#4b), après l'en-tête de parcours. Au-dessus d'elle
dans le défilement : app bar (56) + rail (64, épinglé) + identité avec bloc de départ + lieux + en-tête de parcours.
D'après les constantes, son bord haut tombe vers 520-600 px sous la barre d'état. **Estimation non vérifiée sur
appareil** : sur un iPhone de 956 pt elle est en partie visible à l'ouverture, sur un téléphone plus petit elle demande
de défiler. Hauteur fixe **240 px** (`EmbeddedRouteSheet.mapHeight`, défaut l.45), coins arrondis `PdlRadii.md`.

**Feuilles modales et pages poussées depuis l'écran**
- Plein écran de la carte (`PdlMapHero.fullscreenBuilder`, `route_map.dart:245-254`) : même `RouteMap` en interactif,
  avec en bas à gauche l'interrupteur de mode, puis la légende du vent en mode Météo (`routeMapBottomLayer`,
  `route_color_mode_switch.dart:163-196` ; `stage_detail_page.dart:300-320`).
- Pastille météo touchée **en plein écran** : `PdlSheet` `RideWeatherCheckpointDetails` (« Passage vers 10:40 », « À
  23,4 km du départ », température · condition, pluie, vent, rafales) ou `RideWeatherRainDetails` (« Pluie probable » +
  phrase d'alerte) (`ride_weather_map_markers.dart:162-200`, `291`, `446`). Touchée **dans la vignette**, elle ouvre le
  plein écran (`stage_detail_page.dart:298-299`).
- Point de parcours (waypoint) : feuille `openWaypoint` (`waypoint_sheet.dart`).
- Fond de carte : feuille « Fond de carte » (`PdlMapHero`).
- Exports : feuille « appareil » (services GPS connectés) ; sur Android, feuille « Enregistrer / Envoyer » de `share_file`.
- « Voir la météo du parcours » : pousse `StageWeatherPage` (2.D).
- « Voir la fiche complète » : `context.push(Paths.route)`, l'écran 13 du parcours.

### 2.B `EmbeddedRouteSheet` tel que l'étape l'emploie (`embedded_route_sheet.dart:160-259`)
Ce widget est **partagé avec l'écran 13** (la fiche parcours). Il n'est pas employé par la page de groupe.

| # | Bloc | Widget `fichier:ligne` | Condition | Contenu |
|---|---|---|---|---|
| B1 | En-tête de parcours | `RouteSheetHeader(extent: 1)`, `embedded_route_sheet.dart:179` → `route_sheet_header.dart:88-142` | parcours chargé | `PdlTeamLine` : **nom et logo de l'équipe du parcours** (touche → page équipe). Nom du parcours (20 px). Pile de badges : revêtement (« Route », « Gravel »…) et visibilité (« Public » / « Non répertorié » / « Équipe », avec icône). 3 stats en grand : Distance « 68,2 km », « Dénivelé positif » « 1 240 m » (vert), « Dénivelé négatif » « −1 180 m » (rouge). |
| B2 | **CARTE** | `RouteMap` dans `SizedBox(height: 240)`, `embedded_route_sheet.dart:180-195` | `route.hasGeometry` | Tracé coloré par la pente (montées teintées, le reste bleu), ou par le revêtement, ou par le vent (mode Météo). Marqueurs départ/arrivée, waypoints, bornes km (sauf en mode Météo). En mode Météo : pastilles de température aux points de passage et goutte de pluie (`weatherMarkersOnRoute`, fuseau de l'étape) + légende du vent en bas à gauche (« Dos / Travers / Face », « Prévision ancienne », vitesse par défaut, « Prévisions : Open-Meteo »). Bouton plein écran, choix du fond. Vignette **non interactive** (`interactive: !allowFullscreen \|\| fullscreen`, `route_map.dart:319`). Barre d'échelle `servedMapScale`. Chargement : `PdlSkeletonCard(media)`. |
| B3 | Interrupteur de mode | `RouteColorModeSwitch`, `embedded_route_sheet.dart:196-206` | plus d'un mode | « Pente » \| « Revêtement » (si revêtement connu) \| « Météo » (si `offersWind`, c'est-à-dire un leg montrable pour cette étape) |
| B4 | **Profil altimétrique** | `PdlElevationProfile`, `embedded_route_sheet.dart:207-214`, `287-366` | des échantillons d'altitude existent | Hauteur **140** (`PdlMetrics.elevationLarge`). Barres : pente des montées, ou revêtement ; bande du vent sous l'aire en mode Météo. Repères des waypoints, réticule synchronisé avec la carte. Axe en distance, info-bulle « 23,4 km · 812 m · 6 % » (+ vent). Crédit « Données : IGN LiDAR HD, Mapterhorn et ses sources, © OpenStreetMap ». Chargement « Chargement du profil altimétrique... », erreur « Profil indisponible » + « Réessayer ». |
| B5 | Revêtement | `RouteSurfaceSection`, `embedded_route_sheet.dart:217-221` | revêtement connu ou en calcul | Barre segmentée + légende « Asphalte 72 % … » + crédit OSM ; ou « Revêtement en cours de calcul » |
| B6 | Points du parcours | `RouteWaypointsSection`, `embedded_route_sheet.dart:222-232` | `waypoints` non vide | En-tête « Points du parcours », lignes nom / type / distance (« hors tracé »), « Voir plus » / « Réduire » |
| B2' | (sans géométrie) | `PdlEmptyState`, `embedded_route_sheet.dart:233-238` | `!hasGeometry` | « Aucune donnée de tracé » / « Ce parcours n'a pas de géométrie enregistrée… » (remplace B2 à B6) |
| B7 | Exports | `RouteDownloadActions`, `embedded_route_sheet.dart:239-240` → `route_download_actions.dart` | gpx, fit ou service connecté | « Télécharger GPX » (plein), « FIT », icône appareil, icône **partage du parcours** (`Paths.route`) |
| B8 | **Carte météo de l'étape** | `beforeClimbs: StageWeatherCard(embedded: true)`, `stage_detail_page.dart:184-189` ; inséré `embedded_route_sheet.dart:241` | voir 2.C | Voir 2.C. Elle est aussi rendue si le parcours n'a pas pu être lu (l.153). |
| B9 | Cols et montées | `RouteClimbsSection`, `embedded_route_sheet.dart:242-245` | `allClimbs` non vide | « Cols et montées (3) », par col : catégorie, de/à (distances), D+, pente moyenne, pente max |
| B10 | Voir la fiche complète | `PdlButton(outline, fullWidth)`, `embedded_route_sheet.dart:246-256` | `showOpenFullAction` (vrai) | « Voir la fiche complète » → écran 13 |

### 2.C `StageWeatherCard` (`trips/presentation/widgets/stage_weather_card.dart`)
- Rien si `trip.isPast || trip.isCancelled`, sans appel API (l.46).
- Pendant le chargement : rien, aucune place réservée (l.73).
- Erreur réseau : `WeatherUnavailableCard`, bandeau « Météo indisponible pour le moment. » / « La prévision n'est pas
  encore arrivée, réessayez dans quelques minutes. » + « Réessayer » (l.75-76).
- Statut global `OUT_OF_RANGE` ou inconnu, ou étape absente de la réponse : rien (l.78-83).
- Selon `leg.status` (`rideWeatherViewOf`, `rides/domain/ride_weather_display.dart:44-56`) :
  - `NO_LOCATION` : bandeau info « Ajoutez un parcours à cette étape pour afficher sa météo. Message visible du rôle
    Organisateur seulement. », seulement pour organisateur/admin d'équipe ou admin plateforme, sinon rien.
  - `UNAVAILABLE` : `WeatherUnavailableCard`.
  - `NOT_YET_AVAILABLE` : carte « Prévision disponible à partir du mercredi 12 novembre. » (ou « La météo sera
    disponible sept jours avant le départ. »).
  - `OUT_OF_RANGE` (étape partie) ou inconnu : rien.
  - `OK` / `STALE` : **`WeatherForecastCard`** (`rides/presentation/widgets/ride_weather_card.dart:243-343`), carte
    plate touchable :
    1. « Météo au départ » (xs) + badge jaune « Prévision ancienne » si STALE.
    2. Icône de condition (32), température en grand, condition (« Partiellement nuageux »). Puis « Ressenti 12 °C »,
       « Pluie 30 % », flèche + « Vent 18 km/h ». Source : **`leg.checkpoints.first.weather`** (le 1er point de passage).
    3. Barre du vent le long du parcours (face/travers/dos) + légende « Face 12,3 km · Travers 30,1 km · Dos 24,0 km ».
    4. Alerte pluie (icône goutte) : « Pluie probable (60 %) vers 14:00, à 42,0 km. »
    5. Bouton texte « Voir la météo du parcours › » + « Prévisions : Open-Meteo.com ».
    Touche (carte ou bouton) → `StageWeatherPage.open`.
- Marges : non embarquée, 16/0/16/16 ; embarquée, seulement 16 au-dessus (l.56-66).

### 2.D `StageWeatherPage` (`stage_weather_page.dart:77-202`)
| # | Bloc | Widget `fichier:ligne` | Condition | Contenu |
|---|---|---|---|---|
| 0 | App bar | `PdlAppBar`, l.78-82 | toujours | Titre « Météo du parcours », retour (`maybePop`). Pas d'action. |
| — | Chargement | l.86-93 | loading | squelette 240 |
| — | Erreur | `weatherUnavailableSliver`, l.94-96 (`weather_leg_sections.dart:28-44`) | erreur | état vide plein écran « Météo indisponible pour le moment. » + « Réessayer » |
| — | Vide | l.123-133 | statut global OUT_OF_RANGE/inconnu, étape absente, leg masqué | « Pas de météo pour cette étape » / « Aucune prévision n'est à afficher pour cette étape. » |
| — | NO_LOCATION | l.146-156 | organisateur | bandeau « Ajoutez un parcours à cette étape… » |
| — | NOT_YET_AVAILABLE | l.157-171 | | bandeau, icône date, « Prévision disponible à partir du {date}. » |
| 1 | Bandeau « Prévision ancienne » | `WeatherStaleBanner`, l.185 (`weather_leg_sections.dart:47-65`) | STALE | titre « Prévision ancienne », « La prévision n'a pas pu être rafraîchie depuis lundi 10 novembre 2026 à 08:30. » |
| 2 | En-tête du leg | `WeatherLegHeader`, l.186-193 (`weather_leg_sections.dart:130-217`) | OK/STALE | En-tête de section = **nom de l'étape**, avec la distance du leg en compteur (« 68,2 km »). « Départ 08:30 · arrivée estimée 12:10 ». « Passages estimés à 22 km/h » ou « …, vitesse par défaut : l'étape n'en indique pas ». « Vent dominant : » + flèche + « 18 km/h ». |
| 3 | Alerte pluie | `_RainAlertBanner`, `weather_leg_sections.dart:113-114`, `219-234` | `leg.rainAlert` | bandeau warn, icône de condition, « Pluie probable (60 %) vers 14:00, à 42,0 km. » |
| 4 | Exposition au vent | `_WindSection`, l.115, `236-263` | `segments` non vide | « Exposition au vent », carte : « Le vent le long du parcours », barre segmentée + légende Face/Travers/Dos |
| 5 | Points de passage | `_Timeline` / `_CheckpointRow`, l.116-124, `267-559` | `checkpoints` non vide | « Points de passage ». Une ligne par point : colonne gauche **heure** (gras) + distance ; rail à pastilles (extrémités en couleur primaire) ; « Départ » / « En route » / « Arrivée », icône + température + condition, badge vent relatif (« Face » / « Travers » / « Dos ») + flèche, vent + rafales, « Pluie 30 % », « 1,2 mm de précipitations » ; ou « Prévision pas encore disponible ici ». **Les lignes ne se touchent pas** (pas d'`onCheckpointTap` ici). |
| 4-5' | (repli) | `weather_leg_sections.dart:100-111` | statut ≠ OK/STALE ou aucun point | bandeau « Les prévisions le long du parcours ne sont pas encore disponibles. » |
| 6 | Attribution | `WeatherAttributionBlock`, l.195-200 (`weather_leg_sections.dart:565-600`) | toujours (OK/STALE) | « Prévision de lundi 10 novembre 2026 à 08:30 » (si `leg.fetchedAt ?? dto.fetchedAt`) + bouton texte « Prévisions : Open-Meteo.com » ↗ (ouvre l'URL) |

Pas de carte, pas de profil, pas de bloc « départ » au point de départ (lever et coucher du soleil), pas de sélecteur
d'étape.

### 2.E États secondaires de `StageDetailPage`
- Chargement `_StageSkeleton` (l.571-608) : app bar (retour `pop`), 4 pastilles 74×44, une barre de 20×180, des blocs
  de 96, 240 et 120.
- Étape introuvable `_StageNotFound` (l.537-567) : « Étape introuvable » / « Cette étape n'existe pas ou a été supprimée
  du voyage. » + « Retour au voyage ».
- Erreur `_StageError` (l.610-645) : titre résolu ou « Erreur de chargement », « Réessayer », bouton « Signaler un problème ».

---

## 3. Variantes, bloc par bloc

| Variante | Rail | Identité / départ | Lieux | Carte et fiche parcours | Météo | Description, pièces jointes, commentaires |
|---|---|---|---|---|---|---|
| **Avec parcours** | = | = | = | Fiche complète B1 à B10, carte 240 en 5e position | carte météo **dans** la fiche, entre exports et cols | = |
| **Sans parcours** | = | = | = | rien. À la place : `StageWeatherCard` (non embarquée) **puis** « Aucun parcours » | `NO_LOCATION` : bandeau pour organisateur/admin, rien pour les autres. Un autre statut serait rendu ici (non vérifié côté serveur). | = |
| Parcours sans géométrie | = | = | = | B1, « Aucune donnée de tracé », exports, météo, cols, fiche complète | = | = |
| Parcours en erreur | = | = | = | état « Chargement impossible » + « Réessayer », puis la carte météo quand même | = | = |
| **1re / intermédiaire / dernière** | seule change la pastille active (recentrée) | badge « Étape n sur N » | = | = | = | = |
| **Pas de précédent/suivant** | Aucun bouton « précédent / suivant ». La navigation entre étapes passe **uniquement** par le rail (pastille « Aperçu » = retour au voyage). | | | | | |
| **Voyage d'une seule étape** | rail à 2 pastilles : « Aperçu » + l'étape. Rien de spécial n'est codé pour ce cas (pas de saut vers le voyage). | « Étape 1 sur 1 » | = | = | = | = |
| **Membre** | = | = | = | = | bandeau `NO_LOCATION` seulement pour Organisateur/Admin d'équipe ou admin plateforme | fil visible si `commentCount` présent ; composeur si `teamMembershipProvider == true` |
| **Non-membre / anonyme** | = | = | = | = (le serveur décide de l'accès au voyage) | jamais le bandeau `NO_LOCATION` | fil absent (`commentCount` omis par le serveur). Un admin plateforme non-membre : fil visible, **sans composeur** (`canComment = isMember ?? false`). Statut d'appartenance inconnu (`null`) : pas de composeur. |
| **À venir, prévision dispo (≤ ~7 j)** | = | pastille « Aujourd'hui » / « Demain » au plus | = | interrupteur « Météo » proposé ; en mode Météo, tracé coloré par le vent, pastilles, légende, bande du vent sous le profil | `WeatherForecastCard` | = |
| À venir, trop loin | = | = | = | pas de mode Météo | « Prévision disponible à partir du … » | = |
| Étape déjà partie, voyage en cours | = | pastille « Aujourd'hui » encore possible le jour même | = | pas de mode Météo (leg `OUT_OF_RANGE`) | rien | = |
| **Voyage terminé** (`finished`) | = | badge « Terminé », pas de pastille relative | = | pas de mode Météo (météo jamais demandée) | rien, sans appel API | = |
| **Voyage annulé** | = | badge « Annulé », pas de pastille relative | = | idem | rien | = |
| Brouillon | = | badge « Brouillon » | = | = | statut global `OUT_OF_RANGE` d'après le commentaire de `tripWeatherShowsAnything` : rien | = |
| Lecteur dans un autre fuseau | sous-libellé dans le fuseau de l'étape | + ligne `ZoneMentionLine` « heure de Tokyo (ven. 01:00 chez vous) » | = | heures des pastilles et feuilles dans le fuseau de l'étape, sans mention | idem, sans mention | dates des commentaires dans le fuseau du lecteur |
| Sans `startPlace` ni `endPlace` | = | = | bloc absent | = | = | = |
| Sans `averageSpeed` | = | ligne de détail réduite à la date | = | = | « vitesse par défaut : l'étape n'en indique pas » (page météo) | = |

**Passage de `StageDetailPage` à `StageWeatherPage`** : uniquement depuis `WeatherForecastCard` (touche sur la carte ou
sur « Voir la météo du parcours »), donc seulement en `OK`/`STALE`. `Navigator.push` sur la pile racine, sans URL.
Retour par `maybePop`. Pas de lien inverse, ni de lien d'une étape à l'autre dans la page météo. Les deux écrans lisent
le même `tripWeatherProvider`, sans rechargement. Les tirer-pour-rafraîchir sont distincts : la page d'étape invalide
voyage et météo (l.125-131), la page météo invalide la météo seule (l.66-73).

### Ce qui est partagé avec `ride_group_page.dart` (page d'un groupe de sortie)
Côté mobile, les deux sont **deux pages distinctes**. Le web, lui, a désormais une page commune.

**Partagé (le même code)** :
- `weather_leg_sections.dart` : `WeatherLegHeader`, `weatherLegBody` (alerte pluie, exposition, frise),
  `WeatherStaleBanner`, `WeatherAttributionBlock`, `weatherUnavailableSliver`. Côté groupe, ils sont rendus dans
  l'**onglet Météo** (`ride_group_weather_tab.dart:220-255`) ; côté étape, dans la **page poussée** `StageWeatherPage`.
- `ride_weather_widgets.dart` (`WeatherWindSegments`, `WeatherExposureLegend`, `WeatherWindLine`,
  `WeatherConditionIcon`, `notYetAvailableMessage`, `watchCanSeeWeatherNoLocation`) et `ride_weather_display.dart`
  (`rideWeatherViewOf`, `formatWeatherTime`, `formatRainAlert`, `formatWind`).
- Couche Météo de la carte : `weatherMarkersOnRoute`, `weatherTrackColors` (`weather_map_layer.dart`),
  `openWeatherMapMarker` et ses feuilles (`ride_weather_map_markers.dart`), `RideWindMapLegend`,
  `routeMapBottomLayer`, `RouteColorModeSwitch` (« Pente | Revêtement | Météo »). Le groupe les branche via
  `RideGroupsMap` (`ride_groups_map.dart:351, 372, 442, 481`).
- Bloc de départ : `PdlDepartureBlock` + `dayBoxFor` + `ZoneMentionLine` + libellé « Départ {time} ». Le groupe passe
  par `RideDepartureBlock` (`rides/presentation/widgets/ride_departure_block.dart`), l'étape construit le bloc à la main
  (`stage_detail_page.dart:438-476`).
- `WeatherForecastCard` : partagé avec le détail d'une **sortie**, pas avec la page de groupe.

**Non partagé (deux implémentations)** :
| Bloc | Groupe (`ride_group_page.dart`) | Étape |
|---|---|---|
| Navigation | chips des groupes « B · 11/12 » + segmenté **Aperçu / Météo / Participants** épinglés (l.402-454) | `PdlStageRail` « Aperçu » + étapes |
| Titre | dans l'app bar : « Groupe X » + nom de la sortie (l.242-261) | pas de titre dans la barre, titre 22/700 dans le corps |
| Carte | `RideGroupsMap`, hauteur `0.44 × écran` bornée 260-460 (`ride_groups_map.dart:36-37`), **en tête de l'Aperçu** juste sous le bloc de départ | `RouteMap` dans `EmbeddedRouteSheet`, **240 fixe**, après identité, lieux et en-tête de parcours |
| Profil | `RideElevationSection`, hauteur 110 (`elevationMedium`) | `PdlElevationProfile` dans la fiche, hauteur 140 (`elevationLarge`) |
| Stats | `RideGroupStats` (allure, distance, D+ du groupe) | stats du parcours dans `RouteSheetHeader` (distance, D+, D−) |
| Exports | `RideGroupRouteActions` | `RouteDownloadActions` |
| Météo dans la page | carte « résumé météo » → onglet Météo ; l'onglet a une carte en mode Météo forcé, la section départ (lever/coucher), et des points de passage touchables qui placent le réticule | `WeatherForecastCard` dans la fiche → page poussée **sans carte**, sans section départ, points non touchables |
| Barre d'action fixe | `RideGroupActionBar` (inscription) | **aucune** |
| Participants | onglet (si `canSeeMemberNames`) | aucun |
| Commentaires | aucun dans la page de groupe | fil de l'étape |
| Description, pièces jointes, lieux | non | oui |

---

## 4. Dates et heures

Fonctions de `core/utils/formatters.dart` : `toZoneTime` l.462, `formatTime` l.586, `formatFullDate` l.598,
`formatLongDate` l.610, `formatLongDateTime` l.614, `formatDepartureRelative` l.669, `formatDepartureDate` l.689,
`formatZoneMention` l.557, `readerEquivalent` l.542, `formatRelative` l.730, `dayAbbrev` l.250, `monthAbbrev` l.639.
`formatWeatherTime` : `rides/domain/ride_weather_display.dart:185`. `dayBoxFor` : `core/widgets/day_box.dart`.
Le format 12 h / 24 h suit le réglage du téléphone (`setUse24HourFormat`) : « 08:30 » ou « 8:30 AM ».

| # | Emplacement | Champ source | Formatage `fichier:ligne` | Exemple FR | Fuseau |
|---|---|---|---|---|---|
| 1 | Rail, sous-libellé de chaque pastille d'étape | `TripStageDto.dateTime` (de chaque étape) | `AppFormatters.formatDepartureDate(at, s.timezone)`, `stage_detail_page.dart:344-350` → `formatters.dart:689` (`DateFormat.MMMEd`, `yMMMEd` hors année courante) | « mar. 12 août », « mar. 10 août 2027 ». Tronqué à 18 graphèmes. | **étape** (chaque pastille dans son propre fuseau). L'année courante s'apprécie dans ce fuseau. |
| 2 | Bloc de départ, boîte du jour | `stage.dateTime` | `toZoneTime(instant, stage.timezone)` (`stage_detail_page.dart:442`) puis `dayBoxFor` (`day_box.dart`) : `dayAbbrev` (`DateFormat.E`), jour, `monthAbbrev` (`DateFormat.MMM`) | « mar. » / « 12 » / « août » (+ « 2027 ») | **étape** pour la date. L'année est comparée à `displayNow()`, c'est-à-dire l'année du **lecteur**. |
| 3 | Bloc de départ, titre | `stage.dateTime` | `'rides.departureBlock.departs'` + `formatTime(wall)`, `stage_detail_page.dart:444-446` | « Départ 08:30 » | **étape** |
| 4 | Bloc de départ, pastille relative | `stage.dateTime` | `formatDepartureRelative(instant, zone)`, `stage_detail_page.dart:447-449` → `formatters.dart:669` | « Aujourd'hui » / « Demain » ; sinon rien. Masquée si voyage terminé ou annulé. | **étape** (jour civil dans son fuseau) |
| 5 | Bloc de départ, ligne de détail | `stage.dateTime` (+ `averageSpeed`) | `formatDepartureDate(instant, zone)` + `formatSpeed`, `stage_detail_page.dart:450-454` | « mar. 12 août · 22 km/h » | **étape** |
| 6 | Bloc de départ, mention de fuseau | `stage.dateTime` | `ZoneMentionLine` → `formatZoneMention` `formatters.dart:557` (`readerEquivalent` l.542) | « heure de Tokyo (ven. 01:00 chez vous) » ; rien si décalages égaux | compare étape et lecteur (`UserDto.timezone` sinon appareil) |
| 7 | Carte météo, « Météo au départ » | `leg.checkpoints.first.weather` | **aucune heure affichée** (`ride_weather_card.dart:283`) | « Météo au départ » | n/a |
| 8 | Carte météo, alerte pluie | `leg.rainAlert.time` | `formatRainAlert` → `formatWeatherTime(iso, stage.timezone)`, `ride_weather_card.dart:311`, `ride_weather_display.dart:185-210` | « Pluie probable (60 %) vers 14:00, à 42,0 km. » | **étape**, sans mention |
| 9 | Carte « pas encore disponible » (page d'étape et page météo) | `leg.availableFrom ?? summary.availableFrom` | `notYetAvailableMessage` → `formatFullDate`, `ride_weather_widgets.dart:215-222` → `formatters.dart:598` | « Prévision disponible à partir du mercredi 12 novembre. » (sans année) ; sans date : « La météo sera disponible sept jours avant le départ. » | **lecteur** (`toDisplayTime`), pas l'étape |
| 10 | Carte (mode Météo) : libellé lu des pastilles | `checkpoint.time` | `weatherCheckpointSummary` → `formatWeatherTime`, `ride_weather_map_markers.dart:132-149` | lu : « Départ, 08:30, 0 km, 14 °C, … » ; la pastille visible montre la température (d'après `ride_weather_map_markers.dart:243`, rendu non vu) | **étape** (`timezone: stage.timezone`, `stage_detail_page.dart:285`) |
| 11 | Feuille d'un point de passage (plein écran) | `checkpoint.time` | `'rides.weather.mapPassage'` + `formatWeatherTime`, `ride_weather_map_markers.dart:334` | « Passage vers 10:40 » | **étape** (`stage_detail_page.dart:296`) |
| 12 | Feuille pluie (plein écran) | `rainAlert.time` | `formatRainAlert`, `ride_weather_map_markers.dart:~484` | « Pluie probable (60 %) vers 14:00, à 42,0 km. » | **étape** |
| 13 | Page météo, en-tête du leg | `leg.startTime`, `leg.arrivalTime` | `'rides.weather.legTimes'` + `formatWeatherTime`, `weather_leg_sections.dart:167-175` | « Départ 08:30 · arrivée estimée 12:10 » | **étape** (`timezone` passé par `StageWeatherPage.open`, l.51), sans mention |
| 14 | Page météo, bandeau d'alerte pluie | `leg.rainAlert.time` | `formatRainAlert`, `weather_leg_sections.dart:231` | « Pluie probable (60 %) vers 14:00. » | **étape** |
| 15 | Page météo, frise, heure de chaque point | `checkpoint.time` | `formatWeatherTime(p.time, timezone)`, `weather_leg_sections.dart:333` | « 10:40 » (colonne gauche, gras) | **étape** |
| 16 | Page météo, bandeau « Prévision ancienne » | `leg.fetchedAt ?? dto.fetchedAt` | `formatLongDateTime`, `weather_leg_sections.dart:61` → `formatters.dart:614` | « La prévision n'a pas pu être rafraîchie depuis lundi 10 novembre 2026 à 08:30. » | **lecteur** (horodatage) |
| 17 | Page météo, attribution | idem | `formatLongDateTime`, `weather_leg_sections.dart:583-587` | « Prévision de lundi 10 novembre 2026 à 08:30 » | **lecteur** |
| 18 | Commentaires, date de chaque commentaire | `CommentDto.createdAt` | `DateTime.tryParse` puis `formatRelative`, `comment_thread.dart:239, 272` → `formatters.dart:730` | « à l'instant », « il y a 2 heures », « il y a 3 jours » ; au-delà de 7 jours, `formatLongDate` « lundi 15 janvier 2026 » | **lecteur** |
| 19 | Partage | n/a | titre « {voyage} — {étape} » | aucune date | n/a |

**Champs de date non affichés** : aucune heure d'arrivée sur la page d'étape, alors que `leg.arrivalTime` est chargé
(il n'apparaît que dans la page météo). Lever et coucher du soleil (`TripStageWeatherDto.departure.sunrise/sunset`) ne
sont lus nulle part dans `features/trips` (grep vide). `TripDto.endDate` n'est pas montré sur l'étape.

---

## 5. Wireframes ASCII

### 5.1 `StageDetailPage`, étape avec parcours, à venir, prévision OK, membre
```
┌────────────────────────────────────┐
│ ‹                              ⇪   │ App bar (sans titre) : retour au voyage, partager
├────────────────────────────────────┤
│ (Aperçu) (Col du Lautaret)(Briançon│ RAIL épinglé, 64 px : nom / « mar. 12 août »
│          ( mar. 12 août )( mer. 13 │  pastille active pleine, recentrée
├────────────────────────────────────┤
│ ✈ Traversée des Alpes          ›   │ IDENTITÉ : ligne du voyage
│ Col du Lautaret                    │  titre 22/700
│ [Étape 2 sur 5] [Publié]           │  badges
│ ┌──────┬─────────────────────────┐ │ BLOC DE DÉPART
│ │ mar. │ Départ 08:30 [⏱ Demain] │ │  boîte du jour turquoise
│ │  12  │ mar. 12 août · 22 km/h  │ │  détail (date répétée)
│ │ août │ (heure de … chez vous)  │ │  mention de fuseau, si besoin
│ └──────┴─────────────────────────┘ │
│ ┌────────────────────────────────┐ │ LIEUX
│ │ ● Bourg-d'Oisans, 38520 …      │ │  départ (vert)
│ │ ● Briançon, 05100 …            │ │  arrivée (rouge)
│ └────────────────────────────────┘ │
│ 🏢 Club Cyclo Grenoble        ›    │ FICHE PARCOURS : ligne d'équipe du parcours
│ Lautaret par l'Oisans  [Route]     │  nom du parcours + badges
│                       [Public]     │
│ ↔ 68,2 km   ↗ 1 240 m   ↘ −1 180 m │  3 stats (Distance, D+, D−)
│ ┌────────────────────────────────┐ │
│ │                                │ │ CARTE 240 px (vignette non interactive)
│ │        ~~~~ tracé ~~~~     [⛶] │ │  plein écran, fond de carte, échelle
│ │                                │ │
│ └────────────────────────────────┘ │
│ ( Pente | Revêtement | Météo )     │ interrupteur de mode
│ ▁▂▃▅▇▆▅▃▂▁▂▃▅▆▇▅▃ (140 px)        │ PROFIL ALTIMÉTRIQUE + crédit
│ ▬▬▬▬▬▬▬▬▬▬ Asphalte 72 % …        │ REVÊTEMENT (si connu)
│ Points du parcours                 │ WAYPOINTS (si présents)
│ [Télécharger GPX] [FIT] [⌚] [⇪]   │ EXPORTS
│ ┌────────────────────────────────┐ │ CARTE MÉTÉO (embarquée)
│ │ Météo au départ                │ │
│ │ ⛅ 14 °C  Partiellement nuageux│ │
│ │ Ressenti 12 °C  Pluie 30 %  ↗18│ │
│ │ ▬▬▬▬▬▬▬▬▬▬ Face … Travers … Dos│ │
│ │ 💧 Pluie probable (60 %) vers …│ │
│ │ Voir la météo du parcours ›    │ │
│ │           Prévisions : Open-Meteo│
│ └────────────────────────────────┘ │
│ Cols et montées (2)                │ COLS
│ [     Voir la fiche complète     ] │ lien vers l'écran 13
│ Description                        │ DESCRIPTION (si texte)
│ …markdown…                         │
│ Pièces jointes                     │ PIÈCES JOINTES (si présentes)
│ Commentaires          3 commentaires│ COMMENTAIRES (si commentCount)
│ [Écrire un commentaire...][Publier]│  composeur (membre)
│ Léa · il y a 2 heures              │
└────────────────────────────────────┘
 (pas de barre d'action, pas de barre d'onglets)
```

### 5.2 `StageDetailPage`, étape sans parcours
```
┌────────────────────────────────────┐
│ ‹                              ⇪   │
│ (Aperçu)(Étape 1)(Étape 2)…        │ RAIL
│ ✈ Voyage ›  / Titre / badges       │ IDENTITÉ
│ [boîte du jour | Départ 09:00 …]   │ BLOC DE DÉPART
│ [● départ / ● arrivée]             │ LIEUX (si présents)
│ ⓘ Ajoutez un parcours à cette      │ MÉTÉO : bandeau NO_LOCATION
│   étape… (Organisateur seulement)  │  (rien pour un membre)
│        ⤳                           │ ÉTAT VIDE
│   Aucun parcours                   │
│   Cette étape n'a pas encore de    │
│   parcours associé.                │
│ Description / Pièces jointes /     │
│ Commentaires                       │
└────────────────────────────────────┘
```

### 5.3 `StageWeatherPage` (OK)
```
┌────────────────────────────────────┐
│ ‹  Météo du parcours               │ App bar
├────────────────────────────────────┤
│ ⚠ Prévision ancienne               │ (STALE seulement)
│   …rafraîchie depuis lundi 10 nov… │
│ COL DU LAUTARET          68,2 km   │ EN-TÊTE DU LEG (nom de l'étape + distance)
│ Départ 08:30 · arrivée estimée 12:10│
│ Passages estimés à 22 km/h         │
│ Vent dominant : ↗ 18 km/h          │
│ ⚠ Pluie probable (60 %) vers 14:00…│ ALERTE PLUIE (si présente)
│ Exposition au vent                 │ EXPOSITION
│ ┌ Le vent le long du parcours ───┐ │
│ │ ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ │ │
│ │ ↓Face 12 km ↔Travers 30 km ↑Dos│ │
│ └────────────────────────────────┘ │
│ Points de passage                  │ FRISE (lignes non touchables)
│ 08:30 ●  Départ                    │
│ 0 km  │  ⛅ 14 °C Partiel. nuageux │
│       │  ↗[Dos] Vent 18 km/h…      │
│ 10:40 ●  En route                  │
│ 23 km │  …                         │
│ 12:10 ●  Arrivée                   │
│ Prévision de lundi 10 nov. 2026 à …│ ATTRIBUTION
│ Prévisions : Open-Meteo.com ↗      │
└────────────────────────────────────┘
```

---

## 6. Étonnements

1. **La carte arrive tard.** Avant elle : identité, bloc de départ, lieux, et tout l'en-tête du parcours (ligne d'équipe,
   nom, deux badges, trois stats). La page de groupe, elle, pose la carte juste sous le bloc de départ, avec une hauteur
   bien plus grande (44 % de l'écran, entre 260 et 460, contre 240 fixe). Les profils diffèrent aussi : 110 côté groupe,
   140 côté étape.
2. **La date de l'étape apparaît trois fois en haut d'écran** : pastille active du rail (« mar. 12 août »), boîte du jour,
   et ligne de détail du bloc de départ (« mar. 12 août · 22 km/h »). `RideDepartureBlock` (groupe) écarte exprès cette
   répétition (`ride_departure_block.dart:67-69` : « la ligne atténuée ne la répète pas »). L'étape la garde, et n'affiche
   pas non plus l'**arrivée estimée** que le groupe met à cet endroit (`groupLegArrival`), alors que `leg.arrivalTime`
   est chargé.
3. **Deux lignes de contexte et deux noms** : en haut, « ✈ {voyage} » + nom de l'étape ; dans la fiche, « {équipe du
   parcours} » avec logo + nom du parcours + badge de visibilité du parcours. L'équipe du voyage n'est jamais nommée
   en tant que telle sur la page.
4. **Deux boutons de partage** : celui de l'app bar partage l'**étape**, celui de `RouteDownloadActions` partage le
   **parcours** (`Paths.route`), avec la même icône.
5. **La météo est enfouie dans la fiche parcours**, entre les exports et les cols (`beforeClimbs`), donc loin sous la
   carte et le profil. Sans parcours, elle passe au-dessus de l'état vide.
6. **Sans parcours, un organisateur voit deux messages qui disent la même chose** : le bandeau « Ajoutez un parcours à
   cette étape… » puis l'état vide « Aucun parcours / … pas encore de parcours associé ».
7. **« Météo au départ » sans heure** : la carte de sortie dit « Météo au départ de 09:00 » (`departureWeatherTitle`,
   ledger `MOB-115`). `WeatherForecastCard` (étape) garde le libellé nu. Elle prend aussi la météo « au départ » dans le
   1er point de passage du leg, et laisse de côté `TripStageWeatherDto.departure` (avec lever et coucher du soleil), qui
   n'est lu nulle part dans `features/trips`.
8. **La page météo d'étape est plus pauvre que l'onglet Météo du groupe**, qui en partage pourtant les sections : pas de
   carte en mode Météo, pas de section départ (lever/coucher), points de passage non touchables. Elle n'a pas d'URL non
   plus, donc ni lien profond ni partage, et pas de moyen de passer à l'étape suivante.
9. **Retour incohérent** : la flèche de l'app bar fait `context.go(Paths.trip)` (`stage_detail_page.dart:136, 365-366`),
   alors que le geste système (aucun `PopScope`) fait `pop`. Ouverte depuis l'agenda, l'étape renvoie donc soit au
   voyage (flèche), soit à l'agenda (geste). Le squelette et l'écran d'erreur, eux, font `context.pop()` (l.578, 622).
10. **Le rail inverse les lignes prévues par le composant** : `PdlStageRailItem` documente une ligne haute courte
    (« J1 », « J2 ») et le nom en ligne basse, tronqué à 18 graphèmes. L'étape met le **nom** en haut (`maxLines: 1`
    sans troncature : un long nom élargit la pastille) et la **date** en bas, où la troncature ne sert à rien. Il n'y a
    pas de numéro « J2 » dans le rail. Le numéro n'existe que dans le badge « Étape 2 sur 5 ».
11. **Le badge d'état « Publié »** s'affiche sur toute étape d'un voyage publié à venir ou en cours : c'est un état
    éditorial, peu parlant pour un lecteur.
12. **« Terminé » suit le voyage, pas l'étape** : `isPast = finished` vaut vrai dès que la *dernière* étape a commencé.
    Une étape intermédiaire déjà passée n'a donc ni badge « Terminé », ni marque de passé. À l'inverse, dès le départ
    de la dernière étape, la météo disparaît de **toutes** les étapes.
13. **Fuseaux mêlés dans le bloc de départ** : `formatDepartureDate` juge l'année courante dans le fuseau de l'étape,
    `dayBoxFor` contre `displayNow()` (lecteur). Autour du 1er janvier, la boîte et la ligne de détail peuvent ne pas
    s'accorder sur l'affichage de l'année. De même, « Prévision disponible à partir du … » se lit dans le fuseau du
    lecteur et sans année, alors que le reste de la météo se lit dans celui de l'étape.
14. **Aucun espace réservé pendant le chargement de la météo** (`stage_weather_card.dart:73`). La carte météo apparaît
    après coup dans la fiche et pousse les cols vers le bas. La carte de sortie, elle, réserve un squelette quand le
    résumé annonce une prévision.
15. **Fiche d'écran 13 « telle quelle »** : le bouton « Voir la fiche complète » et le nom du parcours restent, ce qui
    fait de l'étape un écran à deux identités (étape puis parcours). Le web a désormais une page commune groupe/étape,
    alors que le mobile garde deux structures sans rien en commun pour la carte, le profil, les stats, la navigation et
    les exports (voir la fin du §3).
16. **Le texte `rides.weather.legNoRoute`** (« Ce groupe n'a pas de parcours… ») est câblé dans `weatherLegBody`. Pour
    une étape, la branche n'est pas atteignable, car `StageWeatherPage` traite `NO_LOCATION` avant (vérifié dans le
    code, l.146-156). Elle ne parlerait de toute façon que d'un « groupe ».

Non vérifié : le rendu réel (aucun simulateur lancé), le statut que le serveur renvoie pour une étape sans parcours mais
avec lieu de départ (supposé `NO_LOCATION` d'après le commentaire de `stage_weather_card.dart:26`), et le contenu exact
de la pastille météo sur la carte (seule la température a été vue dans le code).
