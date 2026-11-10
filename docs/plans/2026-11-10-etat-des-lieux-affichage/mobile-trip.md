# Mobile Flutter : écran de détail d'un VOYAGE (« écran 24 »)

Lecture seule du code, branche `feat/mobile-review` au commit `ef1fc9a99`. Les chemins sont relatifs à `mobile/lib/`.
Rien n'a été exécuté. Les libellés FR viennent de `mobile/assets/l10n/fr.json`.

---

## 1. Points d'entrée

**Route go_router**
- `config/router.dart:809-834`, `_tripShellRoute`. Le chemin vient de `PathVariants.trip(':teamSlug', ':tripSlug')` :
  - FR : `/equipes/{teamSlug}/voyages/{tripSlug}` ;
  - EN : `/teams/{teamSlug}/trips/{tripSlug}` (`config/paths.generated.dart:393-399`).
- La route se pose sur `_rootNavigatorKey` : elle couvre la barre d'onglets.
- Sous-route : l'étape, `…/etapes/{stageSlug}` → `StageDetailPage`.
- Lien profond : la pile reconstruite est Équipes → Équipe → Agenda d'équipe (`router.dart:291-294`).
- **Pas d'accès anonyme sur mobile.** Le `redirect` (`router.dart:888-896`) renvoie vers `/login` tout visiteur non authentifié, sauf sur quelques pages d'auth et pages légales. La variante « anonyme » n'existe donc pas. Le « non-membre » est une personne connectée qui n'est pas membre de l'équipe.

**Page** : `features/trips/presentation/pages/trip_detail_page.dart`, `TripDetailPage` (l.49). Elle lit `tripParticipationProvider(key).trip` et choisit :
- `data` → `_TripDetailContent` ;
- `loading` → `_TripDetailSkeleton` (l.602-634 : app bar nue, puis 2 barres et 4 blocs gris de 64 px) ;
- `error` → `_TripDetailError` (l.636-670). Un `PdlEmptyState` « Erreur de chargement » (ou « introuvable » si `NOT_FOUND`), avec les boutons « Réessayer » et « Signaler un problème » (`ReportProblemButton`).

**Providers et DTO**

| Provider | Fichier | Appel / rôle |
|---|---|---|
| `tripDetailProvider(TripKey)` | `features/trips/providers/trip_detail_provider.dart:43` | `getTrip(team, trip)` → `TripDto` avec `stages[]`. autoDispose |
| `tripParticipationProvider` | `providers/trip_participation_controller.dart` | Adopte le détail et fait la bascule optimiste Rejoindre / Se désinscrire. C'est **la** source du `TripDto` affiché |
| `tripTracksProvider` | `providers/trip_tracks_provider.dart` | Un appel groupé `getRoutesBulk` pour les géométries des étapes ayant un parcours, plafonné à `kTripTrackStageCap` |
| `tripElevationProvider` | `providers/trip_elevation_provider.dart:40` | Aucun appel : le profil global est concaténé depuis les géométries déjà chargées |
| `tripWeatherProvider` | `providers/trip_weather_provider.dart:22` | `getTripWeather` → `TripWeatherDto` (stages[].summary, stages[].leg) |
| `selectedStageProvider` | `providers/trip_stage_selection_provider.dart:15` | `String?`, l'id de l'étape sélectionnée. Partagé par la carte, la légende et la liste. `null` à l'ouverture |
| `tripMapColorModeProvider` | `features/trips/domain/trip_weather_map.dart:31` | Mode « Étapes » / « Météo » de la carte, partagé avec la page d'étape |
| `teamMembershipProvider` / `canSeeMemberNamesProvider` | `features/teams/providers/team_providers.dart:42,62` | `bool?` membre, tiré de « Mes équipes » (`null` = inconnu). Les noms sont visibles si membre ou admin plateforme |
| `mapStyleProvider`, `defaultCenterProvider` | config | Fond de carte et centre par défaut |

DTO lus : `TripDto`, `TripStageDto`, `RouteDto`, `PlaceDetailDto`, `PublicUserDto`, `TagDto`, `MediaDto`, `TripWeatherDto`, `TripStageWeatherDto`, `RideWeatherSummaryDto`, `WeatherLegDto` et `CommentDto` (via `CommentThread`).

Les dérivés sont dans `trip_detail_provider.dart:59-113` :
- `startsAt` : `dateTime` lu dans `timezone` ;
- `endTimezone` : la zone de l'étape au `dateTime` le plus tardif ;
- `endsAt` : `endDate` lu dans `endTimezone` ;
- `isPast` = `finished` (serveur) ;
- `isCancelled` = `status == 'CANCELLED'` ;
- `orderedStages` : tri par `stageIndex`, puis `sortOrder` ;
- par étape : `startsAt` et `paletteIndex = stageIndex - 1`.

---

## 2. Disposition (de haut en bas)

Le conteneur est un `PdlScreenScaffold`, une liste de slivers avec tirer-pour-rafraîchir. Le rafraîchissement invalide la météo et le détail (l.115-121).
- **Pas d'onglets.**
- **Pas de hero ni d'image de couverture.**
- **Pas de titre dans l'app bar.**

### 0. App bar — `PdlAppBar`, `trip_detail_page.dart:122-159`
- À gauche : retour (`common.back` « Retour »).
- À droite, dans l'ordre :
  1. **Calendrier** (`PdlIcons.date`, a11y « Ajouter à mon calendrier »), **si `isMember == true`**. Il ouvre une **feuille modale** `PdlSheet` « Abonnement calendrier », qui contient `CalendarSubscriptionCard(teamSlug)`, l'abonnement à l'équipe et non un .ics du voyage (l.349-362).
  2. **Partager** (`PdlIcons.share`, « Partager ») : `shareAppLink(title: trip.name, path: Paths.trip(...))`.
  3. **⋯** (`PdlIcons.more`, « Plus d'actions ») : **feuille modale** de modération avec la seule ligne « Signaler » (`moderation_menu.dart`). Aucune action « Modifier » pour un organisateur sur cet écran.

### 1. Identité — `_identity`, `trip_detail_page.dart:412-465`
Toujours affiché, padding 16.
- `PdlTeamLine` : logo et nom de l'équipe, tapable vers la page d'équipe.
- Titre `trip.name` en style `screenTitle` (22/700 selon le commentaire l.123).
- Rangée de badges (`Wrap`) :
  - **Statut** :
    - si `isPast && !isCancelled` → « Terminé » (ton `done`) ;
    - sinon `status.<status>` → « Publié », « Brouillon » ou « Annulé ». Le ton vient de `Status.tone`.
  - **Visibilité** : « Public » (icône public), « Non répertorié » (icône unlisted) ou « Équipe » (icône team).
  - **« Je participe »** (icône check, ton `registered`), si `trip.registered`.
- **Tags** : `ContentTagRow(tags)`, si `trip.tags` n'est pas vide.
- **Bloc de départ** : `_departure`, l.473-510, widget `PdlDepartureBlock` (`core/pdl/pdl_departure_block.dart`). Il est **absent si `trip.dateTime` est illisible**. C'est un cadre `surfaceAlt` bordé, rayon 12 :
  - à gauche, la **boîte du jour** `dayBoxFor(wall)` (« sam. / 12 / avr. », plus l'année si elle n'est pas l'année en cours), teinte du type `trip` (turquoise) ;
  - **« Départ 09:00 »** (`rides.departureBlock.departs`) en style `departureTime` ;
  - pastille grise à horloge **« Aujourd'hui »** ou **« Demain »**, seulement si ni passé ni annulé ;
  - une ligne de détail en 14 atténué : la **plage du voyage** (`tripDaySpan`), par ex. « ven. 16 → dim. 18 oct. » ;
  - la `ZoneMentionLine` : icône et « heure de Tokyo (ven. 01:00 chez vous) », seulement quand le décalage diffère de celui du lecteur.

### 2. Bandeau « Voyage annulé » — `trip_detail_page.dart:162-172`
- Condition : `trip.isCancelled`.
- `PdlBanner` en ton danger, **pleine largeur** (`fullBleed`), icône `cancelled`.
- Titre « Voyage annulé. ». Message « Ce voyage n'aura pas lieu. Aucune inscription n'est possible. »

### 3. Bandeau non-membre — `trip_detail_page.dart:173-189`
- Condition : `isMember == false`. Il n'apparaît pas si l'appartenance est inconnue (`null`).
- `PdlBanner` en ton warn, padding 16 sur les côtés et en bas.
- Message « Rejoignez cette équipe pour participer aux voyages. »
- Bouton contour sm « Voir l'équipe ».

### 4. Carte de synthèse — `TripSummaryCard`, `widgets/trip_summary_card.dart:46-181`
Toujours affichée. `PdlCard` plate, padding 16. Elle contient d'abord une `PdlMetaGrid` à 2 colonnes (1 colonne en grand texte), avec 4 cellules (l.63-111) :

| Cellule | Libellé | Valeur | Icône |
|---|---|---|---|
| Durée | « Durée » | « 3 jours » / « 1 jour », ou « — » sans date de départ lisible | `date` |
| Étapes | « Étapes » | « 3 étapes », ou « — » si `stageCount == 0`. Sous-ligne xs « J1 à J3 » (`trips.summary.dayRange`) | aucune |
| Distance totale | « Distance totale » | `formatDistance(totalDistance)` « 342,5 km », ou « — » si null | `distance` |
| Dénivelé cumulé | « Dénivelé cumulé » | `formatElevationGain` « 5 230 m D+ », ou « — » si null | `elevationUp` |

Puis un séparateur, puis la **rangée participants** (l.134-181), haute de 44 px :
- `PdlAvatarStack` (3 avatars au plus, total = `participantCount`), seulement si `participants` n'est pas vide ;
- le texte « {n} personne(s) » (`trips.participants`) ;
- un chevron. La rangée n'est tapable que si `canSeeNames`, et le tap ouvre la **feuille `ParticipantsSheet`** (titre « Personnes inscrites », sous-titre = nom du voyage, liste paginée ; si vide : « Aucune inscription à ce voyage pour le moment. »).

### 5. Carte du voyage — `TripMap`, `widgets/trip_map.dart:71-291`
C'est le **5e bloc visible** : 3e quand aucun bandeau n'apparaît, après l'identité et la synthèse.
- Elle disparaît entièrement si **aucune étape n'a de `route`** (l.83-85), y compris quand le voyage n'a aucune étape.
- Titre de section « Tracé du voyage » (`sectionTitle`), padding 16/0/16/8 (l.209-212).
- **La carte fait 280 px de haut** (`_kTripMapHeight`, l.24), **sur toute la largeur de l'écran** sans marge horizontale (l.213-221).
- Tant que le style de carte n'est pas résolu, un `PdlSkeleton` de 280 px est affiché.

Contenu de la carte (`PdlMapHero` et `PdlMap`) :
- La carte est **non interactive** quand elle est encastrée : ni déplacement ni zoom, mais le tap sur un tracé sélectionne l'étape (l.183-196).
- **Une couche par étape**, colorée selon son rang (`multiTrackColor(paletteIndex)`). L'étape sélectionnée est dessinée en dernier.
- Marqueurs de départ (première étape, `startPlace`) et d'arrivée (dernière étape, `endPlace`).
- **Bornes kilométriques** de chaque étape (`_kmMarkers`), sauf en mode Météo.
- Cadrage sur l'emprise servie (`tracks.extent`), sinon sur les tracés.
- Crédit, barre d'échelle, ombrage du relief.
- Colonne de boutons centrée verticalement à droite (`pdl_map_hero.dart:295-312`) :
  - « Plein écran » (`fullscreen`) ;
  - « Choisir le fond de carte » (`layers`), qui ouvre une **feuille** « Fond de carte » avec l'interrupteur « Ombrage du relief ».
- **Pastille** en haut au centre, si une étape est sélectionnée : trait couleur et « {nom d'étape} · {départ} → {arrivée} », ou le nom seul (l.160-168, 493-498).
- **En mode Météo** : la légende du vent `RideWindMapLegend.combined` se superpose **en bas de la carte encastrée** (`foreground`, `routeMapBottomLayer`, l.148-159). Note de portée possible :
  - « Parts additionnées des {n} étapes » ;
  - « Parts de la seule étape avec prévision : {stage} » ;
  - « Parts additionnées des étapes avec prévision : {n} sur {total} ».

Sous la carte :
- **Interrupteur « Étapes | Météo »** (`MapColorModeSwitch`, a11y « Colorer le tracé selon »), si au moins une étape a un vent montrable (`windLegs.isNotEmpty`) (l.222-235). Il est sur « Étapes » par défaut.
- **Légende des étapes** `PdlLegendRow` : une rangée défilante horizontale (trait couleur et nom d'étape, tap = sélection, entrée active en gras), **seulement si `stages.length > 1`** (l.236-252).
- **Avertissement** (icône info, xs) :
  - « Tracé partiel : {shown} étapes sur {total} sont affichées. », ou
  - « {count} tracé(s) n'ont pas pu être chargés. » avec un bouton texte « Réessayer » (l.253-288).

**Plein écran** : `TripMap(fullscreen: true)`, la carte seule, interactive. En bas à gauche : l'interrupteur et la légende du vent. En mode Météo, les **pastilles météo de toutes les étapes**, tapables pour ouvrir le détail du marqueur (l.103-105, 411-434).

### 6. Profil altimétrique global — `TripElevationSection`, `widgets/trip_elevation.dart:50-130`
- Enveloppé par `Padding(all: 16)` dans la page (l.209-214).
- Il **disparaît** (`SizedBox.shrink`) quand il n'y a rien à profiler : aucune étape routée, ou moins de 2 points.
- En-tête :
  - à gauche, « Profil altimétrique global » (xs/600) ;
  - à droite, en xs, « 342,5 km · 5 230 m D+ » (`totalDistance` · `totalElevationGain`).
- Le graphique `PdlElevationProfile` fait **110 px** (`elevationMedium`) :
  - il n'a **pas de réticule** ni de lien avec la carte ;
  - l'axe est en quarts de la distance ; seul le dernier repère porte l'unité ;
  - une bulle donne « 120,3 km · 1 245 m » ;
  - crédit « Données : IGN LiDAR HD, Mapterhorn et ses sources, © OpenStreetMap ».
- Si des étapes manquent : un avertissement « Profil incomplet : {stages} n'a pas pu être chargée. »
- En chargement : « Chargement du profil altimétrique... ». En échec : « Profil indisponible » avec « Réessayer ».

### 7. Étapes — `_stages`, `trip_detail_page.dart:539-580`
- Toujours affiché.
- `PdlSectionHeader` « Étapes », avec un compteur s'il y a des étapes.
- Si aucune étape : `PdlEmptyState` « Aucune étape » / « Aucune étape n'a encore été définie pour ce voyage. »
- Sinon, une `StageCard` par étape (écart de 8 px). Elle est décrite ci-dessous.

**Carte d'étape** — `widgets/stage_card.dart:62-186`. C'est une `PdlCard` serrée, en rangée horizontale :
1. `PdlNumberPill(stageIndex)` (a11y « Étape 2 sur 5 ») ;
2. une colonne :
   - **Nom** de l'étape (`cardTitle`, 1 ligne) suivi d'un **trait couleur** 14×3 (même couleur que le tracé) ;
   - **Ligne de départ** `PdlDepartureLine` : horloge indigo, **« 09:00 »** en 700 (sans « Départ »), puis **« sam. 12 avr. »** atténué. Elle n'apparaît que si `dateTime` est lisible ;
   - `ZoneMentionLine` de l'étape, si le lecteur est dans un autre décalage ;
   - **Trajet** « Clermont-Ferrand → Issoire ». Si un lieu manque, le seul lieu connu s'affiche ; s'il n'y en a aucun, rien ;
   - **Stats** (icônes 14), si `route` ou `averageSpeed` existe : distance « 86,2 km », D+ « 1 240 m D+ » (si route), vitesse « 22 km/h » (si `averageSpeed`) ;
   - **Ligne météo** `RideWeatherSummaryLine` (`features/rides/presentation/widgets/ride_weather_summary_line.dart`), si `shows(weather)`. Elle contient : icône de condition et plage « 12–18 °C », flèche du vent et vitesse, puis « Pluie 60 % vers 14:00 » (alerte, icône warning) ou « Pluie 40 % », et une icône « prévision ancienne » si STALE. En NOT_YET_AVAILABLE : « Météo dès le 15 janvier » ;
3. une **vignette** du parcours de 80 px (`PdlThumb`), avec l'icône `stage` en repli sans parcours ;
4. un chevron.

Interactions de la carte d'étape :
- **tap** → ouvre l'étape (`Paths.stage`) ;
- **appui long** → sélectionne l'étape sans naviguer ;
- sélectionnée, elle prend une bordure indigo (`selected`).

### 8. Description — `_description`, `trip_detail_page.dart:583-597`
- Condition : `media.markdown.trim()` non vide.
- En-tête « Description », puis `MarkdownContent` avec les images inline.

### 9. Pièces jointes — `trip_detail_page.dart:228-237`
- Condition : `media.assets.attachments` non vide.
- `MediaAttachments`, sans en-tête propre dans cette page (le widget partagé n'a pas été vérifié).

### 10. Personnes inscrites (pastilles) — `_participants`, `trip_detail_page.dart:367-409`
- Condition : `canSeeNames && participants` non vide.
- En-tête « Personnes inscrites », avec le compteur `participantCount` et un bouton texte « Voir tout » qui ouvre `ParticipantsSheet`.
- Un `Wrap` de **badges lg aux noms** (`displayName`, ton `registered`). L'aperçu montre au plus 8 personnes ; au-delà, un badge « +N ».

### 11. Bandeau d'échec de participation — `trip_detail_page.dart:240-246, 311-341`
- Condition : `participation.failure != null`.
- Ton danger, titre « Participation impossible », message de l'erreur, croix « Fermer ».
- Action : « Voir l'équipe » si le motif est `notMember`, sinon « Réessayer ».

### 12. Commentaires — `CommentThread`, `trip_detail_page.dart:249-262`
- Condition : `trip.commentCount != null` (le serveur l'omet aux non-membres). Padding 16.
- En-tête « Commentaires » avec le compte « 3 commentaires ».
- Le composeur (« Écrire un commentaire... », « Publier ») n'apparaît que si `isMember == true`.
- Chaque commentaire : nom en gras et **date relative**, « Répondre », menu ⋯.
- Liste vide : « Aucun commentaire » / « Lancez la discussion. ». Pagination : « Voir plus de commentaires ».

### 13. Espace final de 16 px — l.263

### 14. Barre d'action fixe — `_actionBar`, `trip_detail_page.dart:274-309`
- **Absente** si le voyage est annulé, passé (`finished`) ou si `isMember == false`.
- Sinon, un `PdlActionBar` contenant un seul bouton pleine largeur :
  - non inscrit → **« Rejoindre »**, plein (pendant l'appel : « Inscription... ») ;
  - inscrit → **« Se désinscrire »**, contour (pendant l'appel : « Désinscription... »).

**Feuilles modales accessibles depuis l'écran** :
- Abonnement calendrier ;
- Modération (Signaler) ;
- Participants ;
- Fond de carte ;
- Détail d'un marqueur météo (plein écran uniquement).

---

## 3. Variantes

| Variante | Ce qui change |
|---|---|
| **Voyage d'une seule étape** | **Aucune disposition dédiée sur mobile.** Aucune branche `stages.length == 1` dans la page. Seule différence : la **légende des étapes sous la carte est masquée** (`trip_map.dart:236`). La légende vent n'a pas de note de portée quand l'unique étape est colorée (l.456-461). Tout le reste est identique : la synthèse affiche « 1 étape » et « J1 à J1 », la section Étapes contient une seule carte, et la « Météo du parcours » n'est pas déroulée dans la page (elle reste sur l'écran d'étape). Le web, lui, a depuis le commit `ef1fc9a99` une « Météo du parcours » pleine largeur avant les commentaires pour ce cas ; cet écart n'est pas porté côté mobile |
| **Voyage sans étape** | Synthèse : Étapes « — », sans « J1 à J… ». Durée « 1 jour » (`endDate` null → fin = début). Distance et D+ « — ». **Pas de carte** ni de profil, **même si le voyage a son propre `routeSlug`** : `TripMap` et `tripElevationProvider` ne lisent que les routes des étapes. Section Étapes en état vide. Plage du bloc de départ : `endDateTime` = départ + 3 h, d'où un seul jour en général |
| **Plusieurs étapes** | Légende défilante sous la carte, une couleur par étape. Sélection croisée carte / légende / liste. Profil concaténé |
| **Étape avec parcours** | Tracé sur la carte, vignette, distance et D+ sur la carte d'étape, segment du profil, éventuelle ligne météo |
| **Étape sans parcours** | Pas de tracé, et l'étape n'est pas sélectionnable sur la carte (elle l'est par appui long ou par la légende). Vignette de repli (icône étape). Ni distance ni D+ (la vitesse reste si renseignée). Pas de ligne météo en pratique (« next stage without a route » d'après le DTO ; non vérifié pour le résumé par étape). Si **toutes** les étapes sont sans parcours : ni carte ni profil, mais 32 px de padding vide restent (voir §6) |
| **Sélection d'étape** (`selectedStageProvider`) | Elle se fait par tap sur le tracé, tap sur la légende ou appui long sur la carte d'étape. Effets : la pastille apparaît sur la carte, l'entrée de légende passe en gras, la carte d'étape prend une bordure indigo, le tracé passe au premier plan. Pas de défilement automatique vers la carte d'étape, pas de recadrage de la carte. Aucune sélection à l'ouverture |
| **Membre** | Bouton calendrier, rangée participants tapable, section pastilles, commentaires avec composeur, barre d'action |
| **Non-membre connecté** (`isMember == false`) | Ni bouton calendrier, ni barre d'action. Bandeau warn « Rejoignez cette équipe… ». La rangée participants montre le seul compte, sans avatars (le serveur envoie `participants` vide) ni chevron. Pas de section pastilles. **Pas de commentaires du tout** (`commentCount` absent) |
| **Appartenance inconnue** (`null` : « Mes équipes » en chargement ou en échec) | Ni bandeau ni bouton calendrier, mais **la barre d'action s'affiche** (seul `false` la masque). Les noms sont masqués. Les commentaires dépendent de `commentCount` ; s'ils sont montés, c'est sans composeur |
| **Anonyme** | N'existe pas : redirection vers la connexion (`router.dart:894`) |
| **À venir** | Badge statut « Publié ». Pastille « Aujourd'hui » / « Demain » quand le départ (première étape) tombe ce jour-là dans la zone du voyage. Météo par étape et interrupteur Météo dès qu'une prévision existe. Barre d'action |
| **En cours** (départ passé, dernière étape pas encore partie) | **Rien ne le signale** : `isUnderWay` (`teams/domain/publication_timing.dart:15`) n'est pas utilisé ici. Le badge reste « Publié », la pastille relative disparaît (le départ est passé) et la barre « Rejoindre » reste proposée. Les étapes déjà parties n'ont plus de météo, ce qui est attendu (`OUT_OF_RANGE`, non vérifié côté serveur) |
| **Dernière étape partie** (`finished`) | Badge « Terminé ». Ni pastille relative, ni barre d'action, ni météo (aucun appel), ni interrupteur Météo. « Je participe » reste affiché si inscrit. Commentaires toujours là |
| **Annulé** | Bandeau danger pleine largeur sous l'identité. Badge « Annulé », y compris quand le voyage est aussi passé. Ni pastille relative, ni barre, ni météo |
| **Brouillon** | Badge « Brouillon ». Météo `OUT_OF_RANGE` d'après la doc du DTO, donc rien. La barre d'action est présente si membre |
| **Chargement / erreur** | Squelette ou état d'erreur plein écran (§1) |

---

## 4. Dates et heures

Rappel de la règle (`mobile/CLAUDE.md`) : un **rendez-vous** se lit dans le fuseau de l'entité (`toZoneTime`), avec une mention si le décalage diffère. Un **horodatage** se lit dans le fuseau d'affichage du lecteur (préférence `UserDto.timezone`, sinon l'appareil). Le 12 h / 24 h suit le téléphone (`formatTime`, `formatters.dart:586`).

| # | Emplacement | Champ source | Formatage (`fichier:ligne`) | Exemple FR | Fuseau | Particularités |
|---|---|---|---|---|---|---|
| 1 | Boîte du jour (bloc départ) | `TripDto.dateTime` | `toZoneTime` (`formatters.dart:462`) → `dayBoxFor` (`core/widgets/day_box.dart:15`), `dayAbbrev` + jour + `monthAbbrev` (`formatters.dart:639`, `DateFormat.MMM`) | « sam. / 12 / avr. », « 2027 » ajouté hors année en cours | `TripDto.timezone` (= première étape) | L'année est comparée à `displayNow().year` (zone lecteur), alors que les autres formateurs comparent dans la zone de l'entité |
| 2 | « Départ 09:00 » | `TripDto.dateTime` | `rides.departureBlock.departs` + `formatTime(wall)` (`trip_detail_page.dart:480-482`) | « Départ 09:00 » / « Départ 9:00 AM » | Zone du voyage | Heure de la **première étape** |
| 3 | Pastille relative | `TripDto.dateTime` | `formatDepartureRelative` (`formatters.dart:669`) | « Aujourd'hui », « Demain » | Le jour civil est jugé **dans la zone du voyage**, contrairement à la règle CLAUDE.md « aujourd'hui reste celui du lecteur » (choix documenté l.632-635) | Masquée si passé ou annulé. Utilise `DateTime.now()`, pas `displayNow()` |
| 4 | Plage du voyage (détail du bloc) | `TripDto.dateTime` → `TripDto.endDateTime` | `tripDaySpan` (`features/teams/domain/publication_timing.dart:41-67`), qui s'appuie sur `formatDepartureDate` (`formatters.dart:689`, `DateFormat.MMMEd` / `yMMMEd`) | Même mois : « ven. 16 → dim. 18 oct. ». Mois différents : « ven. 30 oct. → dim. 1 nov. ». Un jour : « ven. 16 oct. ». Hors année : « ven. 16 → dim. 18 oct. 2027 ». Repli si `endDateTime` illisible : « ven. 16 oct. » | Début dans `timezone`, fin dans `endTimezone` (zone de l'étape au `dateTime` le plus tardif, `trip_detail_provider.dart:70-82`) | La fin est `endDateTime`, l'**instant de fin estimé** (départ de la dernière étape + parcours / vitesse, ou + 3 h), et **pas** `endDate`. Jamais relatif |
| 5 | Mention de fuseau du bloc | `TripDto.dateTime` | `ZoneMentionLine` (`core/widgets/zone_mention_line.dart`), qui appelle `formatZoneMention` (`formatters.dart:557`) et `readerEquivalent` (`formatters.dart:542`) | « heure de Tokyo (ven. 01:00 chez vous) » | Compare le décalage voyage / lecteur | Rien quand les décalages sont égaux. Ne porte que sur l'heure de départ ; la fin de plage n'a pas sa mention |
| 6 | Synthèse « Durée » | `dateTime` (zone `timezone`) et `endDate` (zone `endTimezone`) | `_duration` (`trip_summary_card.dart:117-131`) : écart en jours civils + 1, `trips.summary.days` | « 3 jours », « 1 jour » | Zone d'entité | Repose sur `endDate`, **pas** sur `endDateTime` (cf. #4). « — » si le départ est illisible |
| 7 | Synthèse « J1 à J{n} » | `TripDto.stageCount` | `trips.summary.dayRange` (`trip_summary_card.dart:65-69`) | « J1 à J3 » | — | Dérivé du **nombre d'étapes**, pas des jours réels (cf. §6) |
| 8 | Carte d'étape : heure | `TripStageDto.dateTime` | `stage.startsAt` (`trip_detail_provider.dart:109`) → `formatTime` (`stage_card.dart:108`) | « 09:00 » | `TripStageDto.timezone` | Pas de « Départ » devant l'heure |
| 9 | Carte d'étape : date | `TripStageDto.dateTime` | `formatDepartureDate(instant, stage.timezone)` (`stage_card.dart:109-112`) | « sam. 12 avr. », « sam. 10 avr. 2027 » | Zone de l'étape | **Jamais « Aujourd'hui » / « Demain »** à l'écran, mais la lecture a11y utilise `formatDeparture`, qui les produit (« Aujourd'hui · 09:00 ») |
| 10 | Carte d'étape : mention de fuseau | `TripStageDto.dateTime` | `ZoneMentionLine.maybe` (`stage_card.dart:121`) | « heure de Lisbonne (10:00 chez vous) » | Zone de l'étape | Une mention par étape |
| 11 | Carte d'étape, météo : alerte pluie | `RideWeatherSummaryDto.rainAlert.time` | `formatWeatherTime(alert.time, s.timezone ?? stage.timezone)` (`ride_weather_summary_line.dart:122` ; `rides/domain/ride_weather_display.dart:185`) | « Pluie 60 % vers 14:00 » | Zone du résumé, sinon de l'étape, **sans mention** | — |
| 12 | Carte d'étape, météo : ouverture de la prévision | `RideWeatherSummaryDto.availableFrom` | `formatDayMonth` (`formatters.dart:592`, `toDisplayTime`) | « Météo dès le 15 janvier » | **Fuseau du lecteur** (`toDisplayTime`) | Format « 15 janvier », sans jour de semaine ni abréviation, différent de toutes les autres dates de l'écran |
| 13 | Plein écran, mode Météo : pastilles et détail | `WeatherLegDto` (passages) | `weatherMarkersOnRoute(…, timezone: stage.timezone)` / `openWeatherMapMarker` (`trip_map.dart:393-434`) | « 10:30 » (non détaillé ici) | Zone de **chaque étape** | Non lu en détail : relève de l'écran d'étape et de la sortie |
| 14 | Commentaires | `CommentDto.createdAt` | `formatRelative` (`formatters.dart:730`) ; au-delà de 7 jours, `formatLongDate` (`formatters.dart:610`) | « à l'instant », « il y a 3 heures », « il y a 2 jours », « lundi 15 janvier 2026 » | Fuseau du lecteur (horodatage) | L'année est **toujours** écrite en absolu, même l'année en cours |
| 15 | Participants (feuille) | — | Aucune date affichée dans `participants_sheet.dart` (grep « DateTime/format » vide) | — | — | — |

Champs de date du DTO **non affichés** sur cet écran : `publishAt`, `createdAt` du voyage et `TripDto.endDate` en tant que tel (il ne sert qu'à la durée).

---

## 5. Wireframes ASCII (portrait)

### 5.a Voyage à venir, plusieurs étapes, membre non inscrit

```
┌──────────────────────────────────────┐
│ ←                         📅  ⇪  ⋯   │ App bar (sans titre)
├──────────────────────────────────────┤
│ [logo] Les Rouleurs du Dimanche      │ 1 Identité · PdlTeamLine
│ Traversée du Massif central          │   titre 22/700
│ [Publié] [🌐 Public]                 │   badges
│ #montagne #bivouac                   │   tags (si présents)
│ ┌──────────────────────────────────┐ │   bloc de départ
│ │┌────┐ Départ 09:00 [⏱ Demain]    │ │
│ ││sam.│ ven. 16 → dim. 18 oct.     │ │
│ ││ 16 │ 🌐 heure de … (si ailleurs) │ │
│ ││oct.│                            │ │
│ │└────┘                            │ │
│ └──────────────────────────────────┘ │
│ ┌──────────────────────────────────┐ │ 4 Synthèse (PdlCard plate)
│ │ 📅 Durée        │ Étapes         │ │
│ │ 3 jours         │ 3 étapes       │ │
│ │                 │ J1 à J3        │ │
│ │ ↔ Distance tot. │ ↗ Dénivelé cum.│ │
│ │ 342,5 km        │ 5 230 m D+     │ │
│ │──────────────────────────────────│ │
│ │ (A)(B)(C)+2  5 personnes       › │ │ rangée participants → feuille
│ └──────────────────────────────────┘ │
│ Tracé du voyage                      │ 5 Carte : titre
│██████████████████████████████████████│
│██  carte 280 px, pleine largeur  [⛶]█│   boutons à droite
│██  tracés J1/J2/J3 colorés       [≡]█│
│██  bornes km, départ ▶ arrivée ■ ████│
│██████████████████████████████████████│
│   [ Étapes | Météo ]                 │   interrupteur (si prévision)
│ ━ J1 Clermont  ━ J2 Issoire  ━ J3 …→ │   légende défilante (>1 étape)
│                                      │
│ Profil altimétrique global  342,5 km │ 6 Profil (110 px)
│ ▁▂▄▆█▆▄▃▂▁▂▄▆▇▆▄▂▁▂▃▅▇█▆▄▂▁          │   · 5 230 m D+
│ 0      85      170     255   342 km  │
│ Données : IGN LiDAR HD, …            │
│                                      │
│ Étapes                             3 │ 7 Étapes
│ ┌──────────────────────────────────┐ │
│ │(1) J1 Clermont ━        ┌────┐ › │ │   StageCard
│ │    ⏱ 09:00 sam. 16 oct. │vign│   │ │
│ │    Clermont-Ferrand → Issoire    │ │
│ │    ↔ 86,2 km ↗ 1 240 m D+ ⚡22 km/h│ │
│ │    ☀ 12–18 °C ➚ 15 km/h ☂ 40 %   │ │   ligne météo (si dispo)
│ └──────────────────────────────────┘ │
│ ┌ (2) J2 … ┐  ┌ (3) J3 … ┐           │
│                                      │
│ Description                          │ 8 Description (si markdown)
│ Lorem ipsum…                         │
│ [📎 roadbook.pdf]                    │ 9 Pièces jointes (si présentes)
│ Personnes inscrites    5   Voir tout │ 10 Pastilles noms (membres)
│ [Léa] [Marc] [Sami] [Zoé] [Paul]     │
│ Commentaires          3 commentaires │ 12 Commentaires
│ [Écrire un commentaire...] [Publier] │
│ Léa · il y a 2 heures                │
│ …                                    │
├──────────────────────────────────────┤
│ [           Rejoindre              ] │ 14 Barre d'action fixe
└──────────────────────────────────────┘
```

### 5.b Voyage d'une seule étape (à venir, membre inscrit)

```
┌──────────────────────────────────────┐
│ ←                         📅  ⇪  ⋯   │
│ [logo] Équipe                        │ 1 Identité
│ Grand tour du lac                    │
│ [Publié] [👥 Équipe] [✓ Je participe]│
│ ┌┌────┐ Départ 08:00 [⏱ Aujourd'hui]┐│   bloc de départ
│ ││sam.│ sam. 12 avr.                ││   (plage d'un seul jour)
│ │└────┘                             ││
│ └───────────────────────────────────┘│
│ ┌ Durée 1 jour │ Étapes 1 étape     ┐│ 4 Synthèse
│ │              │ J1 à J1            ││
│ │ Dist. 120 km │ D+ 1 450 m D+      ││
│ │ (A)(B) 2 personnes              › ││
│ └───────────────────────────────────┘│
│ Tracé du voyage                      │ 5 Carte 280 px
│██████████████████████████████████████│
│██████████████████████████████████████│
│   [ Étapes | Météo ]                 │   (si prévision)
│                                      │   PAS de légende d'étapes
│ Profil altimétrique global  120 km · │ 6 Profil
│ ▁▂▄▆█▆▄▂▁                            │
│ Étapes                             1 │ 7 Une seule StageCard
│ ┌(1) Grand tour ━ ⏱08:00 sam.12 avr ┐│
│ │    ↔120 km ↗1 450 m D+ ☀ 14–19 °C ││
│ └───────────────────────────────────┘│
│ Description / PJ / Personnes inscr.  │ 8-10
│ Commentaires                         │ 12
├──────────────────────────────────────┤
│ [          Se désinscrire          ] │ 14 (contour)
└──────────────────────────────────────┘
```
Aucune « Météo du parcours » dans la page (≠ web).

### 5.c Voyage sans parcours (ou sans étape)

```
┌──────────────────────────────────────┐
│ ←                         📅  ⇪  ⋯   │
│ Identité + bloc de départ            │ 1
│ ┌ Durée 1 jour │ Étapes —           ┐│ 4 (sans étape : « — »,
│ │ Dist. —      │ D+ —               ││    pas de « J1 à J… »)
│ │ 0 personne                        ││
│ └───────────────────────────────────┘│
│                                      │ (carte absente : 0 px)
│                                      │ 6 profil absent, mais 32 px
│                                      │   de padding vide
│ Étapes                               │ 7
│        [icône étape]                 │
│        Aucune étape                  │
│  Aucune étape n'a encore été définie │
│  pour ce voyage.                     │
│ Description …                        │
│ Commentaires …                       │
├──────────────────────────────────────┤
│ [           Rejoindre              ] │
└──────────────────────────────────────┘
```

### 5.d Non-membre connecté

```
┌──────────────────────────────────────┐
│ ←                              ⇪  ⋯  │ (pas de 📅)
│ Identité + bloc de départ            │ 1
│ ┌⚠ Rejoignez cette équipe pour      ┐│ 3 bandeau warn
│ │  participer aux voyages.          ││
│ │                  [Voir l'équipe]  ││
│ └───────────────────────────────────┘│
│ Synthèse : « 5 personnes » sans      │ 4
│ avatars ni chevron                   │
│ Tracé du voyage / carte 280 px       │ 5
│ Profil                               │ 6
│ Étapes                               │ 7
│ Description / PJ                     │ 8-9
│ (pas de pastilles, pas de comment.)  │
└──────────────────────────────────────┘   (pas de barre d'action)
```

### 5.e Voyage annulé (ou terminé)

```
┌──────────────────────────────────────┐
│ ←                         📅  ⇪  ⋯   │
│ Identité · [Annulé] [Public]         │ 1 (terminé : [Terminé])
│ bloc de départ SANS pastille relative│
│██ ⊘ Voyage annulé.                 ██│ 2 bandeau danger pleine largeur
│██ Ce voyage n'aura pas lieu. Aucune██│    (absent si seulement terminé)
│██ inscription n'est possible.      ██│
│ Synthèse                             │ 4
│ Carte (pas d'interrupteur Météo)     │ 5
│ Profil                               │ 6
│ Étapes (pas de ligne météo)          │ 7
│ Description / PJ / Pers. / Comment.  │ 8-12
└──────────────────────────────────────┘   (pas de barre d'action)
```

---

## 6. Étonnements

1. **Pas de disposition « voyage d'une étape »** sur mobile, alors que le web en a une depuis `ef1fc9a99` (« Météo du parcours » pleine largeur avant les commentaires). La seule différence mobile est la légende masquée. La synthèse affiche « 1 étape », « J1 à J1 » et « 1 jour », soit trois informations redondantes.
2. **Un voyage sans étape mais avec son propre parcours (`TripDto.routeSlug`) n'a ni carte ni profil.** `TripMap` (l.83) et `tripElevationProvider` ne regardent que `stages[].route`. Le DTO prévoit pourtant ce cas (`weather` : « else the trip itself when it has no stage »), et le commit web le traite.
3. **Durée et plage de dates n'ont pas la même source de fin.**
   - La durée (`_duration`) utilise `endDate`, le départ de la dernière étape.
   - La plage du bloc de départ (`tripDaySpan`) utilise `endDateTime`, la fin estimée de la dernière étape.
   - Exemple : une dernière étape partant à 21:00 pour 4 h affiche « 3 jours » dans la synthèse et « ven. 16 → **lun. 19** oct. » dans le bloc.
4. **« J1 à J{stageCount} »** suppose une étape par jour. Deux étapes le même jour donnent « J1 à J2 » à côté de « 1 jour ».
5. **Les libellés du code et des traductions ne concordent pas.** Le commentaire de `_actionBar` (l.270-273) parle de « Participer » / « Ne plus participer ». Les clés rendent « **Rejoindre** » / « **Se désinscrire** » (et « Inscription... » / « Désinscription... »). « Rejoindre » se confond avec « rejoindre l'équipe » du bandeau non-membre. Le badge, lui, dit « Je participe ».
6. **La doc de `_departure` (l.467-472) promet « le retour quand la fin est connue »**, mais le code ne passe qu'une ligne de détail (`details: [span]`). Aucune heure de retour n'est affichée.
7. **Participants en double pour un membre** : la rangée « avatars + 5 personnes › » de la synthèse, puis plus bas la section « Personnes inscrites 5 · Voir tout » avec les noms en badges. Les deux ouvrent la même feuille.
8. **Distance et D+ en double** : dans la synthèse, puis répétés dans l'en-tête du profil (« 342,5 km · 5 230 m D+ »).
9. **Le bouton calendrier et la cellule « Durée » ont la même icône** `PdlIcons.date`. Le bouton n'ajoute pas le voyage : il ouvre l'abonnement d'équipe.
10. **Aucun état « en cours »** : `isUnderWay` existe (`publication_timing.dart:15`) mais n'est pas utilisé. Pendant le voyage, le badge reste « Publié » et la barre « Rejoindre » reste proposée jusqu'au départ de la dernière étape.
11. **Le badge « Publié » est toujours affiché** pour un voyage publié, ce qui n'apprend rien à un lecteur.
12. **Le profil masqué laisse 32 px vides** : `Padding(all: 16)` enveloppe un `SizedBox.shrink` (`trip_detail_page.dart:209-214`). Sans aucun parcours, cela fait environ 48 px blancs entre la synthèse et « Étapes ».
13. **Les formats de date sont hétérogènes** sur l'écran :
    - « sam. 12 avr. » pour le départ et les étapes ;
    - « ven. 16 → dim. 18 oct. » pour la plage ;
    - « 15 janvier » pour l'ouverture de la météo, **dans le fuseau du lecteur** et non celui de l'étape ;
    - « lundi 15 janvier 2026 » pour un commentaire de plus de 7 jours, avec l'année toujours écrite.
14. **Sur la carte d'étape, « Aujourd'hui » n'apparaît pas à l'écran** : la date est toujours absolue. Le lecteur d'écran, lui, entend « Aujourd'hui · 09:00 » (`formatDeparture` dans `semanticLabel`), ce qui ne correspond pas à ce qui est affiché.
15. **La pastille relative du bloc juge « aujourd'hui » dans la zone du voyage** et utilise `DateTime.now()`, pas `displayNow()`. C'est documenté comme un choix (`formatters.dart:632-635`), mais cela contredit la phrase de `mobile/CLAUDE.md` selon laquelle « Aujourd'hui, demain … restent ceux du lecteur ».
16. **La sélection d'étape est peu découvrable** : sur la carte d'étape, elle passe par un **appui long**, le tap navigue. Sélectionner sur la carte ne fait pas défiler jusqu'à la carte d'étape. Le commentaire de `_pillLabel` annonce « J1 · Clermont → Issoire », mais le code utilise `stage.name`, pas « J{n} ».
17. **La carte d'ensemble est non interactive** (ni zoom ni déplacement) mais tapable pour sélectionner. Le plein écran passe par le bouton seul (`tapOpensFullscreen` reste à `false` par défaut).
18. **La barre d'action apparaît quand l'appartenance est inconnue** (`isMember == null`, « Mes équipes » en échec), alors que le bandeau et le bouton calendrier sont masqués. La logique n'est pas symétrique.
19. **Un non-membre ne voit aucun bloc commentaires** : la section entière disparaît, sans mention du type « réservé aux membres ».
20. **La carte arrive en 3e bloc visible** (identité → synthèse → carte), ou en 5e avec les deux bandeaux. Sur un téléphone, le bloc de départ et la synthèse (4 cellules et les participants) repoussent la carte sous la ligne de flottaison. Le titre « Tracé du voyage » est en `sectionTitle`, mais le profil « Profil altimétrique global » est en xs/600 : deux niveaux de titre différents pour deux blocs voisins.
21. `trips.profileGaps` est au singulier (« {stages} n'a pas pu être chargée ») même quand plusieurs étapes sont listées.
22. Pour `trips.participants` à 0 (« 0 personne(s) »), il n'y a pas de clé `zero` : le rendu exact dépend des règles de pluriel d'easy_localization en français. **Non vérifié.**
