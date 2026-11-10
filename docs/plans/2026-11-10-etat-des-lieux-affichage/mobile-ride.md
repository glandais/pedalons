# Mobile Flutter — écran de détail d'une SORTIE (état des lieux)

Dépôt : `feat/mobile-review` @ `ef1fc9a99`. Lecture seule du code, sans exécution.
Chemins relatifs à `mobile/lib/`. Libellés FR tirés de `mobile/assets/l10n/fr.json`.
NB : les trois derniers commits (« Météo du parcours avant les commentaires » pour la sortie solo et
l'étape) ne touchent que `frontend/` : **le mobile n'a pas suivi**, sa météo de leg reste *au-dessus*
de la carte (voir §6).

---

## 1. Points d'entrée

- **Route go_router** : `config/router.dart:665-677` — `GoRoute(path: _underTeam(PathVariants.ride(':teamSlug', ':rideSlug')))`,
  `parentNavigatorKey: _rootNavigatorKey` (hors du shell : **pas de barre d'onglets** sous l'écran),
  sous-routes `_rideGroupRoute` (page d'un groupe) et `_rideEditRoute`.
  Chemins (`contracts/routes.yaml:534-543`) : `/equipes/{teamSlug}/sorties/{rideSlug}` (fr),
  `/teams/{teamSlug}/rides/{rideSlug}` (en) ; deeplink oui. Les routes `rideMap` /
  `rideGroupMap` (`…/carte`) sont **web seulement** (`routes.yaml:555-574`) — le mobile fait son
  plein écran en interne (`PdlMapHero`).
- **Page** : `features/rides/presentation/pages/ride_detail_page.dart` — `RideDetailPage`
  (l.70) → `_RideDetailContent` (l.98) / `_RideDetailSkeleton` (l.743) / `_RideDetailError` (l.777).
- **Providers / DTO** :
  - `rideRegistrationProvider(RideKey)` (`providers/ride_registration_controller.dart:119`) — porte
    `ride` (`AsyncValue<RideDto>`, issu de `rideDetailProvider`), `pendingGroupId`, `failure`.
  - `rideDetailProvider` (`providers/ride_detail_provider.dart:38`) → `RideRepository.getRide` →
    **`RideDto`** (`groups[]` de `RideGroupDto`, `dateTime`, `timezone`, `endDateTime`, `status`,
    `finished`, `visibility`, `startPlace`/`endPlace`, `routeSlug`, `registeredGroupId`,
    `participantCount`, `commentCount`, `media`, `tags`, `weather` (résumé)…). Extension
    `RideTiming` (l.50-76) : `isPast` = `finished`, `isCancelled` = `status == 'CANCELLED'`,
    `joinedGroup` (via `registeredGroupId`).
  - `rideWeatherProvider` (`providers/ride_weather_provider.dart:22`) → `getRideWeather` →
    **`RideWeatherDto`** (`status`, `departure` {conditions, sunrise, sunset}, `legs[]` de
    `WeatherLegDto`, `attribution`, `fetchedAt`, `availableFrom`). Non appelé si passée/annulée.
  - `rideRouteGeometriesProvider` (`providers/ride_group_selection_provider.dart`) — un seul
    `getRoutesBulk` pour tous les parcours distincts (carte + profil + GPX/FIT), plafond 50.
  - Sélection : `selectedRideGroupProvider`, `selectedRideRouteOverrideProvider`,
    `hiddenRideRoutesProvider`, `rideMapColorModeProvider`, `rideWaypointSelectionProvider`.
  - Rôles : `teamMembershipProvider(team)` (bool? — null = inconnu),
    `canSeeMemberNamesProvider(team)`, `canManageRidesProvider(team)`,
    `watchCanSeeWeatherNoLocation` (organisateur/admin/admin plateforme).
  - Commentaires : `CommentThread` (`features/comments/presentation/widgets/comment_thread.dart`),
    sa propre pagination.
- **Domaine** : `domain/solo_group.dart` (`soloGroupOf` = exactement 1 groupe ; `rideOwnLeg` ;
  `leavesGroupPage` = ≤ 1 groupe), `domain/group_start.dart` (`groupLeavesAtOwnTime`,
  `someGroupLeavesAtOwnTime`, `formatGroupStart`, `myStartAt`), `domain/group_title.dart`
  (« Groupe {name} » sans doublon « Groupe Groupe A »).
- **Ce qui mène à la page d'un groupe** (non détaillée ici) : uniquement en multi-groupes — tap sur
  une `RideGroupCard` (`ride_groups_section.dart:223-225` → `openGroup`, `ride_detail_page.dart:201-205`,
  `context.push(Paths.rideGroup(...))`, `?tab=weather` pour les captures). Une sortie à 0 ou 1
  groupe n'a pas de page de groupe : `RideGroupPage` redirige vers le détail
  (`ride_group_page.dart:218`, `leavesGroupPage`).

---

## 2. Disposition (ordre réel, haut → bas)

Conteneur : `PdlScreenScaffold` (`ride_detail_page.dart:270`) avec `onRefresh` (pull-to-refresh
invalide détail **et** météo), `appBar`, `slivers`, et `actionBar` (solo uniquement).

### 0. App bar — `PdlAppBar`, `ride_detail_page.dart:288-327`
- **Pas de titre** (volontaire, l.289-291). Bouton retour (`common.back` « Retour »).
- Actions, de gauche à droite :
  1. **Partager** (`PdlIcons.share`, « Partager ») → `shareAppLink` lien `Paths.ride`. Toujours.
  2. **Modifier** (`PdlIcons.edit`, « Modifier la sortie ») → `Paths.rideEdit` — si
     `canManage && !ride.deleted`.
  3. **⋯ « Plus d'actions »** (`PdlIcons.more`) :
     - organisateur → feuille `PdlSheet` « Gérer la sortie » (`ride_manage_menu.dart`) : selon le
       statut — brouillon : « Publier » ; publiée : « Dépublier », « Annuler la sortie » ;
       annulée : « Rétablir » ; puis « Supprimer la sortie » (rouge) et « Signaler » ; supprimée :
       seulement « Restaurer la sortie ». Confirmations pour dépublier/annuler/supprimer ;
       snackbar de résultat.
     - sinon → `showDetailModerationMenu` (signalement).

### 1. Identité — `_identity`, `ride_detail_page.dart:450-509` (toujours)
- `PdlTeamLine` : logo (ou initiales) + nom d'équipe, tap → page équipe.
- **Nom de la sortie** en `screenTitle` (22/700).
- Rangée de badges (`Wrap`) :
  - si `isPast && !isCancelled` : « **Terminée** » (ton `done`) ; sinon badge de statut
    `status.*` : « Brouillon » / « Publié » / « Annulé » / « Supprimé ».
  - visibilité avec icône : « Public » / « Non répertorié » / « Équipe ».
  - si inscrit (`joinedGroup`) : « **J'y vais · {group}** » (icône check, ton `registered`).
- Si `tags` non vides : `ContentTagRow`.

### 2. Bloc de départ — `_departure` → `RideDepartureBlock`, `ride_detail_page.dart:522-525`, widget `widgets/ride_departure_block.dart:44-108`, rendu `core/pdl/pdl_departure_block.dart` (toujours, sauf `dateTime` illisible)
- Carte surface alternée bordée, rayon 12.
- À gauche **boîte du jour** (`core/widgets/day_box.dart`) : « sam. / 15 / nov. » (+ « 2027 » si
  l'année diffère de l'année *du lecteur*).
- Au centre : « **Départ 09:00** » (`departureTime` 22/700, `rides.departureBlock.departs`) +
  pastille grise à horloge « **Aujourd'hui** » ou « **Demain** » (seulement ces deux cas).
- Mention de fuseau `ZoneMentionLine` si le décalage de la sortie ≠ celui du lecteur :
  icône + « heure de Tokyo (ven. 01:00 chez vous) ».
- Ligne du groupe de la personne, en 600 : « **Votre groupe : B · 09:30** »
  (`rides.departureBlock.yourGroup`) — seulement si inscrite **et** si son groupe part à une autre
  heure que la sortie (`groupLeavesAtOwnTime`).
- **Aucune date en clair** visible : la date formatée (`formatDepartureDate`) n'est que dans le
  libellé sémantique (l.61-95). Aucune heure de fin (`endDateTime` n'est affiché nulle part sur
  l'écran).

### 3. Bandeaux (conditionnels, pleine largeur pour les deux premiers)
- `ride.deleted` → `PdlBanner` warn, icône poubelle : « Cette sortie est supprimée. Seul le rôle
  Administrateur de l'équipe la voit. » (l.331-340).
- `ride.isCancelled` → `PdlBanner` danger : titre « Sortie annulée. », message « Cette sortie
  n'aura pas lieu. Aucune inscription n'est possible. » (l.341-351).
- `isMember == false` (non-membre connu) → `PdlBanner` warn « Rejoignez cette équipe pour
  participer aux sorties. » + bouton contour « Voir l'équipe » (l.352-368).

### 4. Bloc méta — `_meta`, `ride_detail_page.dart:530-582` (carte plate, grille 2 colonnes `PdlMetaGrid`, 1 colonne si trop étroit ; masqué s'il n'a aucune cellule)
- Cellule « **Personnes inscrites** » : valeur « 12 personnes » (`rides.participants`, sur
  `participantCount`) + bouton texte « **Voir la liste** » → `ParticipantsSheet.openRide` si
  `canSeeNames`. **Seulement si `groups` non vide.**
- `PdlPlaceRow` départ (pastille verte, nom en gras, adresse en xs) si `startPlace`.
- `PdlPlaceRow` arrivée (pastille rouge) si `endPlace`.
- Ni distance, ni D+, ni type, ni heure ici (la date est « passée au bloc de départ », l.527).

### 5. Météo — `RideWeatherCard`, `ride_detail_page.dart:373-378`, `widgets/ride_weather_card.dart:41-139`
- **Rien** si sortie passée ou annulée (pas d'appel API).
- Chargement : squelette 96 px si `ride.weather` résumé OK/STALE ; carte « pas encore » si
  NOT_YET_AVAILABLE ; rien sinon.
- Selon `RideWeatherDto.status` (`domain/ride_weather_display.dart:44`) :
  - `NO_LOCATION` → organisateurs seulement : bandeau info « Ajoutez un lieu de départ ou un
    parcours pour afficher la météo de cette sortie. Message visible du rôle Organisateur
    seulement. » ; membres : rien.
  - `UNAVAILABLE` ou erreur réseau → bandeau « Météo indisponible pour le moment. » / « La prévision
    n'est pas encore arrivée, réessayez dans quelques minutes. » + « Réessayer ».
  - `NOT_YET_AVAILABLE` → carte « Prévision disponible à partir du lundi 16 novembre. » (ou « La
    météo sera disponible sept jours avant le départ. »).
  - `OUT_OF_RANGE` / inconnu → rien.
  - `OK` / `STALE` → **`RideDepartureWeatherCard`** (l.146-237) :
    - Carte plate : titre xs « **Météo au départ de 09:00** » (`departureWeatherTitle`,
      `departure_weather_section.dart:80`, heure de `ride.dateTime`) + badge jaune « Prévision
      ancienne » si STALE.
    - `DepartureConditionsBlock` (`departure_weather_section.dart:100-227`) : icône 40 px,
      température en grand (« 12 °C »), ciel (« Partiellement nuageux »…), puis
      « Ressenti 10 °C », « Pluie 30 % », « 1,2 mm de précipitations » (si > 0), ligne de vent
      (flèche orientée + « Vent 18 km/h, rafales 32 km/h »), puis « Lever du soleil 07:58 » /
      « Coucher du soleil 17:12 » avec icônes.
    - `WeatherAttributionBlock` : « Prévision de mardi 10 novembre 2026 à 08:30 » + lien
      « Prévisions : Open-Meteo » (icône lien externe).
    - **Si `rideOwnLeg` non nul** (sortie sans groupe à leg unique, ou solo) : déroulé du leg
      **sous** la carte, dans le même sliver (l.220-235) :
      - `WeatherLegHeader` (`weather_leg_sections.dart:130`) : en-tête de section « **Météo du
        parcours** » + compteur distance « 42,0 km » ; « Départ 09:00 · arrivée estimée 12:10 » ;
        « Passages estimés à 25 km/h » (ou « …, vitesse par défaut : le groupe n'en indique pas ») ;
        « Vent dominant : ↗ 15 km/h ».
      - `weatherLegBody` (l.75-126) : bandeau warn alerte pluie « Pluie probable (60 %) vers 11:20,
        à 28,5 km. » ; section « Exposition au vent » (carte « Le vent le long du parcours » +
        segments) ; section « **Points de passage** » : frise verticale, une ligne par point
        (heure 09:00 + distance, rail à pastilles, « Départ / En route / Arrivée », icône +
        température + ciel, badge vent relatif, vent, pluie, précipitations). Ou un seul bandeau :
        « Ce groupe n'a pas de parcours : la météo n'est donnée qu'au départ. » / « Les prévisions
        le long du parcours ne sont pas encore disponibles. »

### 6. Carte, légende, profil — `_mapAndProfile`, `ride_detail_page.dart:585-704`
**Position : 6ᵉ bloc** (après identité, départ, bandeaux, méta, météo). Rien du tout si
`groups` vide **et** `routeSlug` nul.
- Titre de section « **Parcours des groupes** » (`rides.groupsRoute`) — toujours ce libellé.
- **`RideGroupsMap`** (`widgets/ride_groups_map.dart:83-400`) :
  - **Hauteur** : `rideMapHeight` = `(hauteur écran × 0,44).clamp(260, 460)` px (l.36-37) —
    ≈ 421 px sur iPhone 17 Pro Max (956 pt), ≈ 293 px sur iPhone SE. Squelette de même hauteur
    tant que le style n'est pas résolu.
  - Si aucune couche (des groupes, mais aucun parcours) : carte `PdlEmptyState` « Aucun parcours
    disponible » / « Le tracé n'a pas encore été publié. Les lieux de départ et d'arrivée restent
    affichés ci-dessus. » (l.161-170) — sans hauteur imposée.
  - Une couche **par parcours distinct** (`rideRouteLayers`, `domain/ride_route_layers.dart`) :
    parcours de la sortie d'abord, puis ceux des groupes ; label = noms des groupes joints par
    « · », ou « Parcours principal ».
  - Encastrée : **non manipulable** (pas de pan/zoom), le tap sélectionne un parcours ;
    `PdlMapHero` donne plein écran (« Plein écran »), fond de carte (« Fond de carte »), ombrage,
    cases « Tracés » si plusieurs couches. Marqueurs départ/arrivée (`startPlace`/`endPlace`),
    points de parcours (waypoints) du parcours sélectionné, barre d'échelle, crédit ⓘ.
  - Pilule en haut à gauche (couleur + label de la couche sélectionnée) — seulement si
    plusieurs couches.
  - Bornes kilométriques si une seule couche et pas en mode Météo.
  - Mode « Météo » (solo uniquement) : tracé coloré par vent relatif, pastilles météo, goutte,
    légende `RideWindMapLegend` en bas.
- Sous la carte, l'un ou l'autre :
  - `RouteColorModeSwitch` « Pente | Revêtement | Météo » — si la carte se colore « comme un
    parcours » (`rideMapColorsLikeRoute` : solo avec 1 seule couche) et > 1 mode.
  - `WeatherMapChip` « Météo » — solo à 2 couches avec prévision.
- `PdlLegendRow` (une entrée par couche, couleur + label, tap = sélection) — si > 1 couche.
- **`RideElevationSection`** (`widgets/ride_elevation_section.dart`) — si un parcours est
  sélectionné :
  - Ligne « **Profil du groupe sélectionné** » + résumé à droite « 42,0 km · 650 m D+ »
    (distance/D+ du **groupe** sélectionné ; rien si aucun groupe).
  - Interrupteur propre au profil « Pente | Revêtement » quand la carte n'en a pas (multi,
    sans groupe, solo 2 couches) et que le parcours a un revêtement.
  - `PdlElevationProfile` hauteur `PdlMetrics.elevationMedium` (110 px d'après la doc l.25),
    barres de pente / revêtement, bande de vent en mode Météo, marqueurs de waypoints, crédit
    « Données : IGN LiDAR HD, Mapterhorn et ses sources, © OpenStreetMap ». Chargement « Chargement
    du profil altimétrique... », échec « Profil indisponible » + « Réessayer ».
  - `RouteSurfaceSection` (répartition des revêtements) si le parcours en a.
  - `RouteWaypointsSection` « Points du parcours » si waypoints.

### 7. Groupes — sliver `ride_detail_page.dart:389-417`, padding 16
Deux branches exclusives :
- **Solo** (1 groupe) → `RideSoloGroupSection` (`widgets/ride_solo_group_section.dart`) :
  1. En-tête : trait de couleur du parcours + « **Groupe {name}** » (`sectionTitle`, `groupTitle`).
  2. Bandeau d'échec d'inscription (`registrationFailureBanner`) si `failure` — défilement
     automatique vers lui (l.67-83).
  3. Bandeaux d'export (erreur/succès).
  4. `RideGroupStats` (`widgets/ride_group_stats.dart`) — carte plate, grille 2 colonnes :
     « **Départ** » `09:00` (`formatGroupStart(group.startAt)`) + mention de fuseau + « Arrivée
     estimée 12:10 » (si leg OK/STALE) ; « Allure moyenne » 25 km/h ; « Distance » 42,0 km ;
     « Dénivelé positif » 650 m.
  5. `RideGroupLeaderRow` si `leader` : avatar 32 + nom + badge « Capitaine ».
  6. `PdlAvatarStack` des inscrits (si `participants` non vide), tap → `ParticipantsSheet.open`.
  7. `RideGroupRouteActions` si parcours : section « Parcours du groupe » ; boutons texte
     « Voir le parcours » (→ `Paths.route`), « GPX », « FIT », « Envoyer vers un appareil »
     (si services GPS connectés).
- **Sinon** (0 ou ≥ 2 groupes) → `RideGroupsSection` (`widgets/ride_groups_section.dart`) :
  - 0 groupe : `PdlEmptyState` icône personnes « **Aucun groupe** » / « Aucun groupe n'est défini
    pour cette sortie. » (l.92-99).
  - ≥ 2 : en-tête « **Groupes** » + compteur « 3 groupes » ; bandeau d'échec ; bandeaux d'export ;
    **mon groupe en tête**, puis libellé « Autres groupes » ; **4 cartes max** puis bouton contour
    « Voir l'autre groupe » / « Voir les N autres groupes ».
  - **`RideGroupCard`** (`widgets/ride_group_card.dart:95-131`), carte tappable (→ page du groupe),
    bord « sélectionné » si son parcours est le parcours sélectionné :
    1. Ligne titre : trait couleur parcours, **nom brut** du groupe (`cardTitle`, 1 ligne), badge
       « J'y vais » si inscrit, bouton « Rejoindre » (plein) / « Quitter » (contour) /
       « Complet » (désactivé) (`rideGroupAction`), chevron.
    2. Bandeau de départ (fond indigo doux) « **Départ 09:30** » + jour « dim. 16 nov. » si autre
       jour que la sortie + mention de fuseau — **seulement si un groupe au moins part à une autre
       heure** (`showDeparture`, l.208-250).
    3. Rangée de stats à icônes : vitesse « 25 km/h », distance « 42,0 km », D+ « 650 m » (flèche
       montante).
    4. `RideGroupWeatherLine` (si leg du groupe OK/STALE avec checkpoints) : icône + « 12 °C » +
       ciel, badge bleu « Pluie 40 % vers 10:30 », badges « Face 12,0 km » / « Dos 8,0 km ».
    5. Capitaine si `leader` : avatar 24, icône, « Capitaine : Léa ».
    6. Participants : avatars (tap → feuille si `canSeeNames`) + « 3/12 personnes » (ou
       « 3 personnes ») ; groupe complet → barre rouge pleine + « 12/12 » ; « Voir tout » à droite
       seulement sur la carte sélectionnée.
    7. Ligne d'actions texte : « GPX », « FIT », « Envoyer vers un appareil » (si dispo).

### 8. Description — `_description`, `ride_detail_page.dart:715-734`
Si markdown non vide **ou** pièces jointes : en-tête « **Description** », `MarkdownContent` (images
inline), `MediaAttachments`.

### 9. Commentaires — `ride_detail_page.dart:424-437` → `CommentThread`
Si `commentCount != null` (sinon : pas le droit de lire, rien n'est monté). En-tête
« **Commentaires** » + « 3 commentaires » ; composeur « Écrire un commentaire... » + « Publier »
si `isMember == true` ; liste paginée (« Voir plus de commentaires »), « Répondre », vide :
« Aucun commentaire » / « Lancez la discussion. ». Date de chaque commentaire :
`formatRelative(createdAt)` (`comment_thread.dart:239-272`).

### 10. Espace final 16 px (l.438).

### Barre d'action fixe en bas — `RideGroupActionBar` (`widgets/ride_group_action_bar.dart`), **solo seulement** (l.285-287)
- À gauche : « **3/12 personnes** » (ou « 3 personnes » sans max) en gras, dessous « 9 places
  restantes » / « 1 place restante » (si max et pas complet).
- À droite : « **Rejoindre** » (plein) / « **Quitter** » (contour) / badge gris « Complet » /
  rien (passée, annulée, non-membre non inscrit).
- `onOpenGroup` nul ici → pas de « Voir mon groupe ».

### Feuilles modales
- « Gérer la sortie » (organisateur), menu de modération (autres).
- `ParticipantsSheet.openRide` (tous les inscrits) / `.open(ride, group)` (un groupe).
- Plein écran de carte (page poussée par `PdlMapHero`), feuille fond de carte / tracés,
  feuille d'un waypoint, feuille d'une pastille météo (plein écran seulement).
- Choix de destination GPX/FIT (Android : enregistrer/envoyer), choix du service GPS.
- Confirmations destructives du menu de gestion.

### États hors contenu
- Chargement : `_RideDetailSkeleton` (app bar sans action, 2 barres + 3 blocs gris 60 px).
- Erreur : `PdlEmptyState` (introuvable / erreur / hors ligne) + « Réessayer » + « Signaler un
  problème ».

---

## 3. Variantes

Règle unique : `soloGroupOf(ride)` = `groups.length == 1` (`solo_group.dart:9`).

| Bloc | a) sans groupe | b) 1 groupe (solo) | c) ≥ 2 groupes, même heure | d) ≥ 2 groupes, heures différentes |
|---|---|---|---|---|
| App bar, identité | identiques | identiques | identiques | identiques |
| Bloc de départ | heure de la sortie ; jamais de ligne groupe | heure de la sortie ; « Votre groupe : X · hh:mm » seulement si inscrit et si le groupe a son heure propre (cas rare mais possible : `startAt` ≠ `dateTime`) | heure de la sortie ; pas de ligne groupe (aucun groupe n'a d'heure propre) | heure de la sortie ; « Votre groupe : B · 09:30 » si inscrit dans un groupe à heure propre |
| Méta | **pas** de cellule « Personnes inscrites » ; lieux seuls (bloc masqué si aucun lieu) | « Personnes inscrites » + « Voir la liste » + lieux | idem b | idem b |
| Météo | conditions au départ + **leg unique déroulé** (si le serveur rend 1 leg sans `groupId`) | conditions au départ + **leg du groupe déroulé** (en-tête, alerte, exposition, frise) | conditions au départ **seules** | conditions au départ seules (titre = heure de la sortie) |
| Carte | seulement si `ride.routeSlug` ; 1 couche « Parcours principal », bornes km, pas de pilule, pas d'interrupteur sous la carte | 1 couche (parcours du groupe = de la sortie) : interrupteur « Pente \| Revêtement \| Météo », mode Météo possible, bornes km ; 2 couches (groupe ≠ sortie) : puce « Météo » seule, pilule, légende | 1 couche par parcours distinct ; si > 1 : pilule + légende cliquable + cases « Tracés » ; 1 seule couche : bornes km ; jamais de mode Météo | idem c |
| Profil | « Profil du groupe sélectionné » **sans résumé** (pas de groupe) ; interrupteur propre Pente/Revêtement | profil coloré par l'interrupteur de la carte (likeRoute) ; bande de vent en Météo ; résumé distance · D+ du groupe | profil du groupe sélectionné (mon groupe, sinon le 1ᵉʳ) ; interrupteur propre | idem c |
| Groupes | `PdlEmptyState` « Aucun groupe » | `RideSoloGroupSection` (« Groupe X », stats avec Départ + Arrivée estimée, capitaine, avatars, « Parcours du groupe ») | `RideGroupsSection` : cartes **sans** bandeau de départ | `RideGroupsSection` : **chaque** carte porte « Départ hh:mm » (+ jour si différent, + mention de fuseau) — y compris les groupes qui partent avec la sortie |
| Barre d'action bas | aucune | `RideGroupActionBar` (places + Rejoindre/Quitter/Complet) | aucune (inscription sur les cartes) | aucune |
| Lien vers page groupe | — | aucun (la page de groupe redirige ici) | tap carte | tap carte |
| Description, commentaires | identiques | identiques | identiques | identiques |

Remarques sur a) : le cas **existe** dans le contrat (`RideDto.endDateTime` documente « for a ride
with no group » ; `RideDto.java:452-461` traite `groups.isEmpty()`), et l'éditeur mobile écarte les
groupes sans nom (`domain/ride_form.dart:312-326`), donc une requête à zéro groupe est possible.
Non vérifié : que le serveur rende bien un leg unique sans `groupId` pour une telle sortie (le code
mobile le suppose, `solo_group.dart:21-29`).

Autres conditions transverses :
- **Passée** : badge « Terminée », pas de météo (ni carte météo ni lignes météo des groupes), pas de
  bouton d'inscription (cartes et barre : rien), pas de mode Météo.
- **Annulée** : bandeau rouge, badge « Annulé », pas de météo, aucune action (pas même
  « Quitter »).
- **Non-membre** : bandeau « Rejoignez cette équipe… », pas de boutons Rejoindre, pas de « Voir la
  liste », avatars vides (le serveur n'envoie pas les noms), pas de capitaine, commentaires absents
  si `commentCount` nul.
- **Organisateur** : bouton Modifier + menu « Gérer la sortie » ; bandeau NO_LOCATION météo.

---

## 4. Dates et heures

Fuseaux : « rendez-vous » = fuseau de la sortie `RideDto.timezone` (`toZoneTime`,
`core/utils/formatters.dart:462`) ; « horodatage » = fuseau d'affichage du lecteur
(`UserDto.timezone` sinon appareil, `toDisplayTime`, l.411). 12 h/24 h suit le téléphone
(`formatTime`, l.586 : `DateFormat.Hm` « 09:00 » ou `DateFormat.jm` « 9:00 AM »).
Exemples : sortie le sam. 15 nov. 2026 09:00 Europe/Paris, lue le 10 nov. 2026 par un·e lecteur·ice à Paris.

| # | Emplacement | Champ source | Fonction (`fichier:ligne`) | Format produit (ex.) | Fuseau | Particularités |
|---|---|---|---|---|---|---|
| 1 | Bloc de départ — boîte du jour | `RideDto.dateTime` | `toZoneTime` puis `dayBoxFor` (`core/widgets/day_box.dart`), `dayAbbrev` (`formatters.dart:250`, `DateFormat.E`), `monthAbbrev` (l.639, `DateFormat.MMM`) | « sam. » / « 15 » / « nov. » (+ « 2027 ») | sortie | l'année s'affiche si ≠ année de `displayNow()` (**fuseau du lecteur**) |
| 2 | Bloc de départ — titre | `RideDto.dateTime` | `formatTime(wall)` (`ride_departure_block.dart:52`) + `rides.departureBlock.departs` | « Départ 09:00 » | sortie | toujours l'heure de **la sortie**, même si mon groupe part à une autre heure (décision BRAND-8) |
| 3 | Bloc de départ — pastille relative | `RideDto.dateTime` | `formatDepartureRelative` (`formatters.dart:669`) | « Aujourd'hui » / « Demain » / rien | sortie (jour civil apprécié dans le fuseau de la sortie) | aucun autre relatif (ni « hier », ni « dans 3 jours ») |
| 4 | Bloc de départ — date en clair | `RideDto.dateTime` | `formatDepartureDate` (`formatters.dart:689`, `DateFormat.MMMEd`/`yMMMEd`) | « sam. 15 nov. » | sortie | **lecteur d'écran seulement**, pas visible |
| 5 | Bloc de départ — mention de fuseau | `RideDto.dateTime` | `ZoneMentionLine` → `formatZoneMention` (`formatters.dart:557`) | « heure de Tokyo (ven. 01:00 chez vous) » | compare décalage sortie/lecteur | rien si même décalage à cet instant |
| 6 | Bloc de départ — « Votre groupe » | `joinedGroup.startAt` | `formatGroupStart` (`group_start.dart:44`) | « Votre groupe : B · 09:30 » | sortie | seulement si `startAt` ≠ `dateTime` (comparaison d'instants, `group_start.dart:23`) ; **pas de mention de fuseau ni de jour** pour cette heure |
| 7 | Carte météo — titre | `RideDto.dateTime` (`departureAt`) | `departureWeatherTitle` (`departure_weather_section.dart:80`) → `formatWeatherTime` (`ride_weather_display.dart:185`) | « Météo au départ de 09:00 » | sortie, sans mention | heure de la sortie, pas du groupe (la prévision est calculée à cette heure) |
| 8 | Carte météo — lever / coucher | `departure.sunrise` / `sunset` | `formatWeatherTime` (`departure_weather_section.dart:152-165`) | « Lever du soleil 07:58 », « Coucher du soleil 17:12 » | sortie, sans mention | |
| 9 | Carte météo — heure de la prévision | `RideWeatherDto.fetchedAt` | `formatLongDateTime` (`formatters.dart:614`) dans `WeatherAttributionBlock` (`weather_leg_sections.dart:581-589`) | « Prévision de mardi 10 novembre 2026 à 08:30 » | **lecteur** (horodatage) | format long, sans abréviation, avec année — différent de tous les autres |
| 10 | Météo « pas encore » | `availableFrom` (DTO météo ou `ride.weather`) | `notYetAvailableMessage` → `formatFullDate` (`ride_weather_widgets.dart:215`, `formatters.dart:598`) | « Prévision disponible à partir du lundi 16 novembre. » | **lecteur** | jour complet, sans heure ni année |
| 11 | Leg (sans groupe / solo) — en-tête | `leg.startTime`, `leg.arrivalTime` | `formatWeatherTime` (`weather_leg_sections.dart:167-175`) | « Départ 09:00 · arrivée estimée 12:10 » | sortie, sans mention | `startTime` = départ **du groupe** (son `start_at`) |
| 12 | Leg — alerte pluie | `rainAlert.time` | `formatRainAlert` (`ride_weather_display.dart:193`) | « Pluie probable (60 %) vers 11:20, à 28,5 km. » | sortie | |
| 13 | Leg — frise | `checkpoint.time` | `formatWeatherTime` (`weather_leg_sections.dart:333`) | « 10:12 » (au-dessus de la distance) | sortie | |
| 14 | Carte météo (sans leg) STALE | — | — | badge « Prévision ancienne » sans heure | — | le message avec heure (`WeatherStaleBanner`) n'est pas utilisé sur ce détail |
| 15 | Carte de groupe — bandeau départ (variante d) | `group.startAt` | `toZoneTime` + `formatTime` (`ride_group_card.dart:213-221`) | « Départ 09:30 » | sortie | affiché pour **tous** les groupes dès qu'un seul a une heure propre |
| 16 | Carte de groupe — jour | `group.startAt` vs `ride.dateTime` | `formatDepartureDate` (`ride_group_card.dart:222-224`) | « dim. 16 nov. » | sortie | seulement si autre jour que la sortie ; jamais « Demain » |
| 17 | Carte de groupe — mention | `group.startAt` | `ZoneMentionLine.maybe` (`ride_group_card.dart:245`) | « heure de Tokyo (…) » | | |
| 18 | Carte de groupe — ligne météo | `rainAlert.time` | `formatWeatherTime` (`ride_group_weather_line.dart:67-74`) | badge « Pluie 40 % vers 10:30 » | sortie | |
| 19 | Solo — stat « Départ » | `group.startAt` | `formatGroupStart` (`ride_group_stats.dart:63-71`) | « 09:00 » | sortie | + `ZoneMentionLine` ; **double** l'heure du bloc de départ |
| 20 | Solo — « Arrivée estimée » | `leg.arrivalTime` | `groupLegArrival` → `formatWeatherTime` (`ride_group_stats.dart:18-27`) | « Arrivée estimée 12:10 » | sortie | seulement leg OK/STALE ; **double** l'en-tête du leg (#11) |
| 21 | Commentaires | `comment.createdAt` | `formatRelative` (`formatters.dart:730`) | « il y a 2 heures », « à l'instant » ; au-delà de 7 jours « lundi 3 novembre 2026 » | lecteur | seul relatif « il y a… » de l'écran |
| 22 | Profil, carte plein écran, pastilles météo | `checkpoint.time` | `weatherMarkersOnRoute(..., timezone: ride.timezone)` (`ride_groups_map.dart:442-447`) | heures « 10:12 » sur les pastilles (non vérifié dans le détail du widget) | sortie | mode Météo (solo) uniquement |

Non affichés sur cet écran : `RideDto.endDateTime` (fin estimée de la sortie), `createdAt`,
`publishAt` (publication programmée d'un brouillon), `RideGroupDto.time` (déprécié, jamais lu).

---

## 5. Wireframes ASCII (portrait)

### a) Sortie sans groupe
```
┌──────────────────────────────────┐
│ ←                     ⤴  ✎  ⋯   │ App bar (pas de titre)
├──────────────────────────────────┤
│ (logo) Vélo Club Nord            │ 1 Identité
│ Sortie du samedi                 │
│ [Publié] [◎ Équipe] #tags        │
│┌────────────────────────────────┐│
││┌────┐ Départ 09:00 [⏱ Demain]  ││ 2 Bloc de départ
│││sam.│ (heure de Tokyo …)        ││
│││ 15 │                           ││
│││nov.│                           ││
││└────┘                           ││
│└────────────────────────────────┘│
│ [bandeaux supprimée/annulée/     │ 3 Bandeaux (cond.)
│  non-membre]                     │
│┌────────────────────────────────┐│
││● Fonderies      ● Gare          ││ 4 Méta (lieux seuls,
││  12 rue …         av. …         ││   pas de « Personnes »)
│└────────────────────────────────┘│
│┌────────────────────────────────┐│
││Météo au départ de 09:00         ││ 5 Météo au départ
││☁ 12 °C Partiellement nuageux    ││
││Ressenti 10 °C · Pluie 30 % · ↗ ││
││☀↑ 07:58  ☀↓ 17:12               ││
││Prévision de mardi 10 nov… · ↗OM ││
│└────────────────────────────────┘│
│ Météo du parcours        42,0 km │ 5' Leg unique déroulé
│ Départ 09:00 · arrivée est. 12:10│   (si le serveur le rend)
│ ⚠ Pluie probable (60 %) vers …   │
│ Exposition au vent [segments]    │
│ Points de passage                │
│  09:00 ●  Départ  12 °C …        │
│  10:12 ┊  En route …             │
│  12:10 ●  Arrivée …              │
│ Parcours des groupes             │ 6 Carte (si routeSlug)
│┌────────────────────────────────┐│
││   carte 1 tracé, bornes km      ││ h = 44 % écran
││   [⛶] [fond]                    ││   (260–460 px)
│└────────────────────────────────┘│
│ Profil du groupe sélectionné     │   Profil (sans résumé)
│ [Pente|Revêtement]               │
│ ▁▂▅▇▅▂▁ (110 px)                 │
│ Revêtements · Points du parcours │
│        👥                         │ 7 « Aucun groupe »
│   Aucun groupe                   │
│   Aucun groupe n'est défini …    │
│ Description                      │ 8 (cond.)
│ Commentaires     3 commentaires  │ 9 (cond.)
│ [Écrire un commentaire…][Publier]│
└──────────────────────────────────┘
  (pas de barre d'action)
```

### b) Sortie solo (1 groupe)
```
┌──────────────────────────────────┐
│ ←                     ⤴  ✎  ⋯   │
├──────────────────────────────────┤
│ Vélo Club Nord                   │ 1 Identité
│ Sortie du samedi                 │
│ [Publié][◎ Équipe][✓ J'y vais · A]│
│┌[sam.15 nov.] Départ 09:00 [Demain]┐ 2 Bloc de départ
│└──────────────────────────────────┘
│ [bandeaux cond.]                 │ 3
│┌ Personnes inscrites │ ● Départ ┐│ 4 Méta
││ 12 personnes        │   lieu   ││
││ Voir la liste       │ ● Arrivée││
│└──────────────────────────────────┘
│┌ Météo au départ de 09:00 ───────┐│ 5 Météo au départ
││ ☁ 12 °C … lever/coucher         ││
││ Prévision de … · Prévisions : … ││
│└─────────────────────────────────┘│
│ Météo du parcours        42,0 km │ 5' Leg du groupe
│ Départ 09:00 · arrivée est. 12:10│   (long : frise
│ Passages estimés à 25 km/h       │    complète)
│ Vent dominant : ↗ 15 km/h        │
│ ⚠ alerte pluie                   │
│ Exposition au vent               │
│ Points de passage  (N lignes)    │
│ Parcours des groupes             │ 6 Carte
│┌────────────────────────────────┐│   (≈ 421 px sur
││ tracé coloré pente/revêt./vent  ││    Pro Max)
│└────────────────────────────────┘│
│ [ Pente | Revêtement | Météo ]   │   interrupteur
│ Profil du groupe sélectionné     │   Profil
│                42,0 km · 650 m D+│
│ ▁▂▅▇▅▂▁                          │
│ Revêtements · Points du parcours │
│ ▌Groupe A                        │ 7 Section solo
│┌ Départ        │ Allure moyenne ┐│   RideGroupStats
││ 09:00         │ 25 km/h        ││
││ Arrivée est.  │                ││
││ 12:10         │                ││
││ Distance      │ Dénivelé pos.  ││
││ 42,0 km       │ 650 m          ││
│└──────────────────────────────────┘
│ (◉) Léa  [Capitaine]             │   (si leader)
│ ◉◉◉ +9                           │   avatars
│ Parcours du groupe               │
│ Voir le parcours · GPX · FIT ·   │
│ Envoyer vers un appareil         │
│ Description                      │ 8
│ Commentaires                     │ 9
├──────────────────────────────────┤
│ 3/12 personnes        [Rejoindre]│ Barre d'action fixe
│ 9 places restantes               │
└──────────────────────────────────┘
```

### c) Plusieurs groupes, même heure
```
┌──────────────────────────────────┐
│ ←                     ⤴  ✎  ⋯   │
├──────────────────────────────────┤
│ Identité + badges                │ 1
│ [sam.15 nov.] Départ 09:00       │ 2 (pas de ligne groupe)
│ [bandeaux cond.]                 │ 3
│ Personnes inscrites │ lieux      │ 4
│┌ Météo au départ de 09:00 ───────┐│ 5 (conditions seules)
│└─────────────────────────────────┘│
│ Parcours des groupes             │ 6
│┌────────────────────────────────┐│
││[▌A · B] (pilule)                ││ carte multi-tracés
││  tracés colorés par parcours    ││
│└────────────────────────────────┘│
│ ▌A · B   ▌C   ▌Parcours principal│   légende (si >1)
│ Profil du groupe sélectionné     │
│ [Pente|Revêtement] 42 km · 650 m │
│ ▁▂▅▇▅▂▁                          │
│ Groupes                 3 groupes│ 7
│┌▌A        [J'y vais][Quitter] › ┐│   mon groupe d'abord
││ ⚡25 km/h  ↔42 km  ↗650 m       ││
││ ☁12 °C Nuageux [Pluie 40 % vers ││
││ 10:30] [Face 12 km] [Dos 8 km]  ││
││ (◉) Capitaine : Léa             ││
││ ◉◉◉ 3/12 personnes    Voir tout ││
││ GPX  FIT  Envoyer vers un app.  ││
│└──────────────────────────────────┘
│ Autres groupes                   │
│┌▌B                [Rejoindre] › ┐│
││ … (même structure)              ││
│└──────────────────────────────────┘
│ [Voir les 2 autres groupes]      │   au-delà de 4
│ Description                      │ 8
│ Commentaires                     │ 9
└──────────────────────────────────┘
  (pas de barre d'action)
```

### d) Plusieurs groupes, heures différentes
```
┌──────────────────────────────────┐
│ ←                     ⤴  ✎  ⋯   │
├──────────────────────────────────┤
│ Identité + badges [J'y vais · B] │ 1
│┌[sam.15 nov.] Départ 09:00 ─────┐│ 2 heure de la SORTIE
││   Votre groupe : B · 09:30      ││   + ligne groupe
│└─────────────────────────────────┘│
│ [bandeaux cond.] · Méta          │ 3, 4
│┌ Météo au départ de 09:00 ───────┐│ 5 (heure de la sortie)
│└─────────────────────────────────┘│
│ Parcours des groupes / carte /   │ 6
│ légende / profil                 │
│ Groupes                 3 groupes│ 7
│┌▌B          [J'y vais][Quitter] ›┐│
││┌ Départ 09:30 ──────────────────┐││ bandeau indigo
│││ (heure de Tokyo …)            │││
││└───────────────────────────────┘││
││ stats · météo · capitaine ·     ││
││ participants · GPX/FIT          ││
│└──────────────────────────────────┘
│ Autres groupes                   │
│┌▌A               [Rejoindre] ›  ┐│
││┌ Départ 09:00 ─────────────────┐││ affiché aussi pour le
││└───────────────────────────────┘││ groupe à l'heure de
│└──────────────────────────────────┘ la sortie
│┌▌C               [Rejoindre] ›  ┐│
││┌ Départ 08:00   dim. 16 nov. ──┐││ jour si ≠ sortie
│└──────────────────────────────────┘
│ Description · Commentaires       │ 8, 9
└──────────────────────────────────┘
```

---

## 6. Étonnements

1. **La carte arrive tard, et très tard en solo / sans groupe.** Elle est le 6ᵉ bloc, après le bloc
   de départ, le méta **et la météo**. En solo, le leg entier (en-tête, alerte, exposition, frise
   d'une ligne par point de passage) est rendu dans le sliver météo **au-dessus** de la carte
   (`ride_weather_card.dart:220-235`) : la carte peut se retrouver plusieurs écrans plus bas. Le web
   vient précisément de déplacer cette « Météo du parcours » après la carte, avant les commentaires
   (commit `b76185166`, frontend seul) — le mobile n'est plus aligné.
2. **Heure de départ répétée jusqu'à 4 fois en solo** : bloc de départ « Départ 09:00 », titre
   « Météo au départ de 09:00 », en-tête du leg « Départ 09:00 · arrivée estimée 12:10 », stat
   « Départ 09:00 ». **L'arrivée estimée 2 fois** (stats + en-tête du leg). La distance 3 fois
   (résumé du profil, stats, compteur du leg). Le nombre d'inscrits 3 fois (méta « 12 personnes »,
   avatars, barre « 3/12 personnes »).
3. **Deux sources d'« heure de départ » en solo pouvant diverger** : le bloc de départ et le titre
   météo lisent `ride.dateTime`, la stat « Départ » et le leg lisent `group.startAt`. Si le groupe
   unique a une heure propre, l'écran affiche « Départ 09:00 » en tête et « Départ 09:30 » plus
   bas ; la ligne « Votre groupe : … » n'apparaît qu'aux inscrit·es.
4. **Variante d : le bandeau de départ s'affiche sur toutes les cartes**, y compris celles qui
   partent à l'heure de la sortie (règle voulue, `someGroupLeavesAtOwnTime`, mais il répète alors
   l'heure du bloc de départ). La ligne « Votre groupe : B · 09:30 » du bloc n'a ni jour ni mention
   de fuseau, alors que la carte de groupe a les deux.
5. **Libellés « groupe » sans groupe** : en variante a, le titre de carte reste « Parcours des
   groupes », le profil « Profil du groupe sélectionné » (sans aucun groupe, ni résumé), et un
   `PdlEmptyState` « Aucun groupe » occupe la place de la section. En solo aussi : « Parcours des
   groupes » et « Profil du groupe sélectionné » pour un groupe unique.
6. **Pas de date en clair visible** sur la sortie : seule la boîte du jour la porte ; la date
   formatée « sam. 15 nov. » n'existe que pour le lecteur d'écran. Aucune heure de fin
   (`endDateTime`) n'est affichée nulle part, alors que le serveur la calcule.
7. **Formats de date hétérogènes sur le même écran** : « sam. 15 nov. » (boîte/carte de groupe),
   « lundi 16 novembre » (prévision disponible, sans année, fuseau lecteur), « mardi 10 novembre
   2026 à 08:30 » (prévision de…, fuseau lecteur), « il y a 2 heures » (commentaires). La boîte du
   jour décide de l'année sur l'année *du lecteur* (`day_box.dart`, `displayNow()`), alors que
   `formatDepartureDate` la décide dans le fuseau *de la sortie* (`formatters.dart:699`) — écart
   possible le 31 décembre / 1ᵉʳ janvier entre fuseaux.
8. **Badge de statut au masculin** : « Publié » / « Annulé » sur une sortie, à côté de
   « Terminée » ; et le bandeau d'annulation dit « Sortie annulée. » pendant que le badge dit
   « Annulé ».
9. **Inscription : deux modèles d'interaction** — en solo, barre fixe en bas (et le bandeau d'échec
   est loin, dans la section solo, d'où un défilement forcé) ; en multi, boutons sur chaque carte et
   aucune barre. La carte de groupe entière pousse la page du groupe ; la « sélection » d'une carte
   (bord, « Voir tout ») ne se fait donc que via la carte/légende, jamais par tap sur la carte de
   groupe.
10. **Nom de groupe incohérent** : la carte de groupe affiche le nom brut (« A »), la section solo
    « Groupe A » (`groupTitle`), le badge d'identité « J'y vais · A », la barre « Votre inscription
    est dans le groupe A. ».
11. **Météo au départ vs météo du groupe** : la carte « Météo au départ de 09:00 » est calculée à
    l'heure de la sortie, tandis que la ligne météo de chaque carte de groupe prend le 1ᵉʳ point de
    passage de *son* leg (heure du groupe) — en variante d, deux températures « au départ »
    différentes peuvent coexister sans que l'heure de la ligne de groupe soit dite.
12. **Quand des groupes existent sans aucun parcours**, la section carte est quand même montée :
    titre + carte vide « Aucun parcours disponible » dont le message renvoie « ci-dessus » aux lieux
    de départ et d'arrivée (qui peuvent ne pas exister).
13. La cellule « Personnes inscrites » est masquée sans groupe, mais rien ne la remplace : avec ni
    groupe ni lieu, le bloc méta disparaît entièrement.
14. Non vérifié : le rendu exact des pastilles météo sur la carte (heures affichées) et le titre de
    `RouteSurfaceSection` (aucune clé de titre trouvée dans le widget).
