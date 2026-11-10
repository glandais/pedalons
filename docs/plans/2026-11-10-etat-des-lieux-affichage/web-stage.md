# Web : page d'une ÉTAPE de voyage, état des lieux

Lecture seule du code au commit `ef1fc9a99` (branche `feat/mobile-review`). Chemins relatifs à
`frontend/src/` sauf mention. Je n'ai rien lancé (ni build, ni rendu). Ce qui suit vient de la
lecture du code, et ce que je n'ai pas pu vérifier est signalé « non vérifié ».

---

## 1. Points d'entrée

### Routes

| id route | URL FR | URL EN | Page | Gabarit |
|---|---|---|---|---|
| `stage-detail` | `/equipes/{teamSlug}/voyages/{tripSlug}/etapes/{stageSlug}` | `/teams/{teamSlug}/trips/{tripSlug}/stages/{stageSlug}` | `pages/trip/StageDetailPage.tsx` | AppShell normal, `auth: 'public'` (`config/routes.config.ts:884-897`) |
| `stage-map` | `…/etapes/{stageSlug}/carte` (+ `?color=grade\|surface\|wind`) | `…/stages/{stageSlug}/map` | `pages/trip/StageFullscreenMapPage.tsx` | `layout: 'bare'` (sans AppShell), `auth: 'public'` (`routes.config.ts:898-908`) |

Source des chemins : `contracts/routes.yaml:646-665`. `stage` est `web + mobile + deeplink`,
`stageMap` est **web seulement**.

Fil d'Ariane (rendu par `Layout`, au-dessus de la page, `components/common/Layout.tsx:360`) :
chaîne `parentId` `teams` → `team-detail` → `team-agenda` → `trip-detail` → `stage-detail`, donc
« Équipes › {équipe} › Agenda › {voyage} › {étape} ». Sous `sm`, seulement les deux derniers niveaux
(« {voyage} › {étape} », `components/common/Breadcrumb.tsx:96-108`). Le libellé de l'étape vient
de `trip.stages[].name` (`hooks/useBreadcrumbData.ts:80-92`).

Méta OG/Twitter : `stageMeta` (`config/routeMeta.ts:418+`). Titre et description de l'étape, alt
« {étape} — {voyage} ». Sans étape, on retombe sur l'aperçu du voyage.

### Données (`pages/trip/stageDetailData.ts`)

`useStageDetailData(teamSlug, tripSlug, stageSlug)` (`stageDetailData.ts:53-75`) :

| Requête | Hook / endpoint | Ce que la page en tire |
|---|---|---|
| Équipe | `useGetTeam` → `TeamDetailDto` | `enableTrips`, `enableRoutes`, nom, droits (`teamAccess`) |
| Voyage | `useGetTrip` → `TripDto` | `stages[]` (l'étape est **trouvée dans le voyage**, `s.slug === stageSlug`), `name`, `registered`, `finished`, `status` |
| Parcours de l'étape | `useGetRoute(teamSlug, stage.route.slug)` → `RouteDetailDto`, avec un `refetchInterval` tant que l'altitude est en cours d'affinage (`useElevationRefetchInterval`) | tracés, waypoints, GPX/FIT, `elevationState`, nom |
| Météo du voyage | `useGetTripWeather` (`TRIP_WEATHER_REQUEST`) → `TripWeatherDto` | `stages[]` (`TripStageWeatherDto` : `stageId`, `leg`, `departure`, `summary`), `attribution` |

Prefetch SSR `prefetchStageDetail` (`stageDetailData.ts:86-114`) : il fait les mêmes requêtes, plus
les services GPS (si l'utilisateur est authentifié) et les commentaires de l'étape (membres
seulement), via `listTripStageComments`.

Champs de `TripStageDto` (`api/dto/tripStageDto.ts`) : `id, slug, name, dateTime (Instant),
timezone (IANA), averageSpeed?, route? (RouteDto), startPlace?, endPlace?, media (MediaDto),
sortOrder, stageIndex, stageCount, commentCount?`.

### Redirections et états avant rendu (`StageDetailPage.tsx:72-122`)
- Équipe introuvable une fois chargée : `Navigate` vers `paths.teams()`.
- Équipe sans `enableTrips` **ou** sans `enableRoutes` : `Navigate` vers la page de l'équipe (`:78-80`).
- Chargement : `DetailPageSkeleton`. Erreur : `QueryStateBoundary` avec bouton de nouvel essai.
  Voyage absent : « Voyage introuvable » (clés `trips.detail.notFound.*`).
- Voyage chargé mais étape absente : « Étape introuvable » / « L'étape que vous recherchez n'existe
  pas. » / « Retour au voyage » (`:105-122`).

---

## 2. Disposition

### Composant commun avec RideGroupPage : `ChildDetailShell`

`components/publication/ChildDetailShell.tsx` (créé par 85792a9b1, WEB-155) sert de gabarit à
`StageDetailPage` (`StageDetailPage.tsx:135-260`) et à `RideGroupPage`
(`pages/ride/RideGroupPage.tsx:161-322`). Ses props : `backTo, backLabel, parentName, siblings,
currentId, siblingLabel, title, badges?, actions?, departure, notices?, error?, side, map | null,
weather, children?`.

Les pièces partagées par les deux pages : `SiblingNav`, `DepartureBlock`, `PlacesLine`,
`StatsCard` (le groupe l'utilise via `GroupStats`), `RouteCard`, `RouteMapPanel`
(`withActions={false}`, `heightVariant="sticky"`), `RouteWeatherSection` (le groupe passe par
`GroupWeatherSection`), `useWeatherFocus`, `ShareButton`, et le bouton « Modifier ».

**Ce qui est propre à l'étape, comparé au groupe :**

| Prop / bloc | Étape (`StageDetailPage`) | Groupe (`RideGroupPage`) |
|---|---|---|
| `backLabel` | « Retour au voyage » | « Retour à la sortie » (non vérifié, clé `rides.group.backToRide`) |
| `parentName` | « {voyage} · étape {i} sur {n} » (`trips.stage.parent`) | nom de la sortie, seul |
| `siblings[].label` | « {i} · {nom} » (`trips.stage.option`) | « {nom} » avec compteur de personnes, `x/max` (`rides.group.option[NoMax]`) |
| `siblingLabel` | « Choisir une étape » | `rides.group.selector` |
| `title` | `stage.name` brut | `t('rides.group.title', {name})` (« Groupe … ») |
| badges | « J'y vais » si **`trip.registered`** (inscription au voyage), puis Partager | « J'y vais » si `group.registered`, **sinon « Complet »** si `group.full`, puis Partager |
| actions | « Modifier » seulement (organisateur), qui mène à **l'édition du voyage** | `GroupJoinActions` (rejoindre / quitter / changer) + « Modifier » (édition de la sortie) |
| departure | `DepartureBlock(stage.dateTime, stage.timezone, stage.startPlace)` + `PlacesLine(end)` | `DepartureBlock(startFor(ride, group), ride.timezone, ride.startPlace)` + `PlacesLine(end)` + **`GroupPlaces`** |
| notices | `AccessAlerts kind="trip"` (composant partagé) | alertes écrites sur place (« inscrit dans un autre groupe », connexion, non-membre) |
| `error` | jamais passé | erreur d'inscription au groupe |
| side | `StatsCard` → **`InstructionsBlock`** (consignes de l'étape) → `RouteCard` | `GroupStats` → **`GroupLeader`** → **`GroupParticipantsSection`** → `RouteCard` |
| titre de `RouteCard` | `route.name ?? stage.route.name`. **Pas de carte sans nom** | `route.name ?? « Parcours du groupe »` |
| `RouteMapPanel` | `subject="stage"`, plein écran vers `stageMap` | `subject` par défaut (`group`), plein écran vers `rideGroupMap` |
| weather | `RouteWeatherSection subject="stage"` en direct | `GroupWeatherSection` (qui enveloppe `RouteWeatherSection subject="group"`) |
| children | **`CommentSection entityType="stages"`** (membres et admins de la plateforme) | aucun : le groupe n'a pas de commentaires |

Donc l'étape n'a ni personnes, ni capitaine, ni inscription, ni « Complet », ni lieux propres au
groupe. Elle a en plus les consignes et les commentaires.

### Desktop (≥ 64em = 1024 px), de haut en bas

0. **Fil d'Ariane** (Layout, hors page) : « Équipes › {équipe} › Agenda › {voyage} › {étape} ».
   Il fait doublon avec le lien retour juste en dessous (voir §6).

1. **Lien retour** (`ChildDetailShell.tsx:64-71`). Toujours affiché. `IconArrowLeft` et
   « Retour au voyage », texte `sm`, couleur atténuée, lien vers `paths.trip`.

2. **En-tête** : `Paper` bordé, `shadow xs`, `p="lg"`, `component="header"`
   (`ChildDetailShell.tsx:73-106`), qui contient dans l'ordre :
   - 2a. **SiblingNav** (`SiblingNav.tsx:29-82`). Affiché seulement si le voyage a **au moins 2
     étapes**. À gauche `‹` (`IconChevronLeft`, ActionIcon `default lg`), désactivé sur la première
     étape. Au milieu, un **SegmentedControl pleine largeur** pour ≤ 4 étapes, un **Select**
     (max 420 px) au-delà. Options « 1 · Rennes → Vannes », etc. À droite `›`, désactivé sur la
     dernière. aria : « Précédent : {label} » / « Suivant : {label} », groupe « Choisir une étape ».
   - 2b. **Ligne titre** (`:77-94`), en `space-between` :
     - à gauche, « {voyage} · étape 2 sur 5 » (`sm`, atténué), puis le **h1** (taille h2) =
       `stage.name`, suivi des badges : « J'y vais » (Badge `primary light`, si
       `trip.registered`) puis le bouton **Partager** (`IconShare`, ActionIcon `default input-sm`).
       Le partage passe par `navigator.share` ou, à défaut, copie l'URL (« Lien copié »).
     - à droite, « Modifier » (`IconPencil`, Button `outline`) si `canEdit` (organisateur ou admin
       de la plateforme), lien vers `paths.tripEdit`.
   - 2c. **DepartureBlock** (`components/common/DepartureBlock.tsx:33-118`), `section`
     aria-label « Date et heure de départ ». Surface grise bordée. À gauche le **DayBox** `lg`, ton
     indigo (`primary`) : « mar. / 12 / mai » et l'année en 4e ligne hors de l'année courante. Au
     milieu : « Départ 08:30 » (24 px, gras), le badge « Aujourd'hui » / « Demain » si c'est le cas,
     puis la mention de fuseau si le lecteur est sur un autre décalage (« heure de Lisbonne (09:30
     chez vous) »), puis la ligne lieu de départ `IconMapPin` vert, **nom** en 500 et « (adresse) »
     atténuée, si `stage.startPlace`. **Pas** de colonne « Votre groupe » (prop `group` non passée).
   - 2d. **PlacesLine** (`components/publication/PlacesLine.tsx`), avec `end` seulement :
     `IconMapPin` rouge, « **Arrivée :** {nom} (adresse) », si `stage.endPlace`. Le départ n'y est
     pas répété.
   - 2e. **AccessAlerts** (`components/publication/AccessAlerts.tsx`) :
     - anonyme : Alert bleue « Connectez-vous et rejoignez cette équipe pour participer aux
       voyages. **Se connecter** » (lien de connexion qui ramène ici) ;
     - connecté sans être membre : Alert jaune « Rejoignez cette équipe pour participer aux voyages.
       **Voir l'équipe** » ;
     - membre : rien.

3. **Corps en deux colonnes** `.detail-layout` (`index.css:267-317`) : grille
   `minmax(380px,440px) | 1fr`, zones `'side map'`, gap `lg`. Sans parcours :
   `.detail-layout--no-map`, une seule colonne pleine largeur.
   - **Colonne gauche `.detail-side`** (Stack gap `lg`) :
     - 3a. **StatsCard** (`components/publication/StatsCard.tsx:59-120`, `data-testid="stage-stats"`).
       Paper bordé `p=lg` avec une grille **en container query** : 2 colonnes, 4 à partir de 560 px
       de **conteneur**. La colonne faisant au plus 440 px, c'est **toujours 2 colonnes sur
       desktop**. Les tuiles, chacune seulement si la valeur est connue :
       - `IconBolt` « ALLURE MOYENNE » `25 km/h` (si `averageSpeed` est non nul), avec en dessous
         « Arrivée estimée 14:05 » si le leg météo est OK ou STALE ;
       - `IconArrowsMaximize` « DISTANCE » `82 km` (`stage.route.distance`) ;
       - `IconArrowUp` « DÉNIVELÉ POSITIF » `1 240 m` (`stage.route.elevationGain`).
       Il n'y a **pas** de tuile « Départ » : `departure` n'est pas passé, le DepartureBlock suffit.
     - 3b. **InstructionsBlock** (`components/publication/InstructionsBlock.tsx`,
       `data-testid="stage-instructions"`). Affiché si `stage.media.markdown` n'est pas vide ou s'il
       y a des pièces jointes. Paper bordé **sans titre** (aria-label « Consignes »), contenu
       `MediaDisplay` (markdown, images référencées, pièces jointes).
     - 3c. **RouteCard** (`components/publication/RouteCard.tsx`). Affiché si l'étape a un parcours
       **et** que celui-ci a un nom. Paper bordé `p=md`, h3 (taille h5) = nom du parcours, puis la
       rangée `RideGroupRouteActions` (`components/ride/RideGroupRouteActions.tsx`) :
       `IconMap` « Voir le parcours » (lien vers la page du parcours), `IconDownload` « GPX » et
       `IconDownload` « FIT » (si les fichiers existent), puis `IconDeviceMobile` « Envoyer vers
       l'appareil » (menu Garmin, Wahoo… si l'utilisateur est connecté **et** a un service
       connecté).
   - **Colonne droite `.detail-map.detail-map--fill.detail-map--solo`**, **sticky**
     (`top: header + md`), hauteur `max(360px, 100svh − header − 2·md − 2px − 130px)`, avec
     `max-height` = la hauteur visible et `overflow-y: auto` : la carte, ses contrôles et la liste
     des points défilent **à l'intérieur** de la colonne. Rendue seulement si l'étape a un
     parcours. Contenu (`components/route/RouteMapPanel.tsx:100-161`) :
     - 3d. **Carte** `RouteMapView` (MapLibre, chargée à la demande, squelette en attendant). Le
       tracé est coloré selon le mode, avec bornes kilométriques, ou badges météo en mode Météo. Le
       **profil altimétrique est en overlay** sur le bas de la carte (`profilePlacement="overlay"`).
       Dans la colonne de contrôles : zoom, fond de carte et le bouton `IconArrowsMaximize` « Carte
       plein écran », qui ouvre `stageMap?color={mode}`. Échelle en bas à droite (commit
       0fe23357a). Popups des badges en mode Météo : « {lieu} · {heure} ».
     - 3e. « Profil d'altitude provisoire » (xs, atténué), si `route.elevationState === PENDING`.
     - 3f. **ColorModeControls** (`components/route/ColorModeControls.tsx`) :
       - commande segmentée « Pente | Revêtement | Météo », seulement s'il y a au moins 2 modes.
         « Météo » n'est proposé que si `stageWindLeg` renvoie un leg (voyage ni terminé ni annulé,
         leg avec des prévisions) ;
       - en mode Météo, la **WindMapLegend** : « Vent sur le tracé : Dos x km · Travers y km ·
         Face z km », la mention de vitesse par défaut (« Heures de passage estimées à 25 km/h,
         vitesse par défaut (l'étape n'en indique pas) ») et le crédit « Prévisions {source} » ;
       - **RouteSurfaceSummary**, la répartition des revêtements.
     - 3g. **RouteWaypointList** (`components/route/RouteWaypointList.tsx`). Affichée s'il y a des
       waypoints : « Points du parcours (n) », lignes avec icône de type, « Hors tracé » le cas
       échéant, et « Voir les n autres points » au-delà d'un seuil. Cliquer sur une ligne
       sélectionne le point sur la carte et le profil.
     - Pas de bloc d'actions sous la carte (`withActions={false}`) : les actions sont dans la
       RouteCard.

4. **Météo du parcours, pleine largeur** `#meteo` (`ChildDetailShell.tsx:115-121`, avec
   `scrollMarginTop`, et défilement automatique sur l'ancre via `useScrollToAnchor`).
   `RouteWeatherSection` (`components/weather/RouteWeatherSection.tsx:50-129`), dans un
   `ErrorBoundary inline` :
   - Paper bordé, `section` étiquetée par le h3 « Météo du parcours » (id `stage-weather-title`),
     éventuellement suivi du badge jaune `IconHistory` « Prévision ancienne » (STALE). À droite,
     **WeatherAttribution** : « Prévisions {source} » et « Mise à jour à 10:42 » (ou « Mise à jour
     le 9 novembre 2026 à 10:42 »). Masquée en NO_LOCATION.
   - **WeatherStatusNotice** selon le statut :
     - NOT_YET_AVAILABLE : `IconCalendarTime` « La météo sera disponible à partir du 5 mai 2026. »
       ou « … sept jours avant le départ de l'étape. » ;
     - UNAVAILABLE : `IconCloudOff` « La météo n'est pas disponible pour le moment. » et le bouton
       « Réessayer » ;
     - NO_LOCATION (organisateurs seulement) : `IconMapPinOff` « Ajoutez un parcours à cette étape
       pour afficher sa météo. »
   - Statut OK/STALE avec des checkpoints : **RouteWeather** (`components/weather/RouteWeather.tsx:126-235`) :
     1. **RouteVerdicts** (`RouteVerdicts.tsx`), 4 tuiles « L'essentiel du parcours », 2 colonnes
        puis 4 à partir de `md` : **Températures** (`IconTemperature`, « 9 °C → 17 °C », « 9 °C au
        départ, ressenti 7 °C. Le plus chaud vers 13:00. »), **Pluie** (`IconUmbrella`, « Sec » ou
        alerte « Dès 11:00 (km 34), 60 %. »), **Vent** (`IconWind`, « Surtout de face… », « Vent
        dominant : ↗ … »), **Jour** (`IconSunset2`, « 2 h 10 de marge » ou « Arrivée de nuit »,
        « Lever 07:58, coucher 17:31. Arrivée estimée 14:05. »). Une icône d'alerte apparaît si un
        seuil est franchi.
     2. h4 « Heure par heure, à votre passage », puis « Passages estimés à 25 km/h · un point tous
        les 10 km » (ou la variante « vitesse par défaut (l'étape n'en indique pas) »).
     3. ≥ sm : **WindTotals** (« Dos x km · Travers y · Face z ») puis **DesktopTimeline** : une
        rangée « Tronçons » (blocs de vent, heures « 09:00–10:00 »), puis par colonne-checkpoint :
        heure, icône, courbe de température, temp., barre de pluie et %, bande de vent relatif,
        flèche, vent (km/h), rafales, km. Les colonnes sont cliquables et sélectionnent le point.
     4. < sm : **PhoneStrip** (bande compacte, graduations horaires, curseur « Glisser pour choisir
        un passage »).
     5. **CheckpointDetail** : Paper « {lieu} {heure} », puis 4 cellules Température / Pluie / Vent
        (« rafales x · secteur ↗ ») / Tronçon (« Face du km 12 au km 30 »).
     6. < sm seulement : **PhaseList** « Par tronçon ».
   - La sélection est partagée entre le tableau et la carte (`useWeatherFocus`) : cliquer une
     colonne allume le badge sur la carte, ouvrir un badge sélectionne la colonne.

5. **Commentaires** (`StageDetailPage.tsx:249-259`, `ChildDetailShell.tsx:123`), si
   `isMember || isPlatformAdmin`. `CommentSection` : h4 « Commentaires (n) », formulaire
   « Écrivez un commentaire... », liste (date relative « il y a environ 2 heures »), réponses,
   « Charger plus de commentaires », état vide « Aucun commentaire ». Suppression possible par
   l'auteur ou un organisateur.

### Viewport étroit (< 64em)

- L'en-tête (1-2) ne change pas : `Group wrap`, donc « Modifier » passe sous le titre si la place
  manque. Le DepartureBlock est en container query, mais sans colonne « groupe » rien ne passe à la
  ligne.
- `.detail-layout` passe à **une colonne** avec `grid-template-areas: 'map' 'side'` : **la carte
  passe AVANT la colonne** (stats, consignes, parcours), alors qu'elle la suit dans le DOM. Elle
  **n'est plus sticky**. Sa hauteur `sticky` retombe sur `clamp(300px, 52svh, 560px)` parce que
  `--detail-map-height` n'est défini qu'à partir de 64em (`hooks/useResponsive.ts:97`). Le défilement
  interne de `--solo` disparaît.
- StatsCard : 4 colonnes si la carte fait au moins 560 px (tablette), 2 sur téléphone.
- Météo : verdicts en 2 colonnes sous `md` (62em). Tableau horaire remplacé par la bande et le
  curseur, et « Par tronçon » en liste sous `sm` (48em).
- Fil d'Ariane réduit à « {voyage} › {étape} » sous `sm`.
- Pas d'onglets : un seul flux.

### Plein écran (`StageFullscreenMapPage.tsx` → `MapColorFullscreenView` → `RouteFullscreenView`)

Barre du haut (`MapFullscreenShell`) : bouton retour `IconArrowLeft` (retour à l'étape en gardant
`?color`), titre = `stage.name` (ou nom du parcours), sous-titre **DepartureLine** `withDay`
(« `IconClock` mar. 12 mai · 08:30 », icône de mention de fuseau), stats `IconRoute` distance,
`IconArrowUp` D+ et `IconArrowDown` D− (les deux derniers à partir de `sm`), commande « Pente |
Revêtement | Météo ». Ensuite la carte sur toute la hauteur (badges météo en mode Météo, bornes
kilométriques sinon), en mode Météo une bande de légende vent et le crédit, puis le **profil
altimétrique fixe de 160 px** sous la carte, sans recouvrement. Une étape sans parcours (ou une
étape inconnue) **redirige** vers la page de l'étape. `document.title` = « {étape} — {app} ».

---

## 3. Variantes

| Variante | Effet bloc par bloc |
|---|---|
| **Sans parcours** (`stage.route` absent) | Pas de requête de parcours. **Pas de carte** (`map=null`), donc `.detail-layout--no-map` : la colonne prend toute la largeur. **Pas de RouteCard**. StatsCard sans distance ni dénivelé : il reste « Allure moyenne » si `averageSpeed`, **sinon un Paper bordé vide** (le composant rend toujours son Paper, `StatsCard.tsx:73`). Météo : le backend renvoie leg et départ en `NO_LOCATION` même avec un lieu de départ (`backend/.../RideWeatherCalculator.java:316-317`, `TripWeatherService.java:92-93`). Les **organisateurs** voient donc « Ajoutez un parcours à cette étape pour afficher sa météo. » (sans crédit), **tous les autres rien**. Le plein écran redirige vers l'étape. |
| **Parcours sans nom** | `routeName` indéfini : la RouteCard disparaît (avec GPX, FIT, envoi). La carte reste. Cas rare, non vérifié côté contrat. |
| **Parcours en cours d'affinage** | « Profil d'altitude provisoire » sous la carte, et le parcours est relu périodiquement. |
| **Première étape** | `‹` désactivé (`aria-hidden`), `›` actif. |
| **Dernière étape** | `›` désactivé. |
| **Intermédiaire** | Les deux flèches sont actives. |
| **≤ 4 étapes / > 4** | SegmentedControl pleine largeur, ou Select limité à 420 px. |
| **Voyage d'une seule étape** | La page **existe toujours** : `TripStageCard` y mène toujours (`components/trip/TripStageCard.tsx:40`), comme le calendrier et l'accueil membre. **SiblingNav absent** (`siblings.length < 2`). Le parent devient « {voyage} · étape 1 sur 1 ». Et depuis ef1fc9a99, la page du voyage affiche **la même « Météo du parcours »** pleine largeur (`TripDetailPage.tsx:236-260`) : la section est en double entre les deux pages. |
| **Anonyme** | Alert bleue de connexion. Ni « Modifier » ni commentaires. Pas de « J'y vais » (`trip.registered` est faux). Pas d'envoi vers l'appareil. GPX et FIT restent visibles. NO_LOCATION est muet. Pour un voyage privé, comportement côté API non vérifié (probablement « Voyage introuvable »). |
| **Connecté, non-membre** | Alert jaune « Rejoignez cette équipe… Voir l'équipe ». Pas de commentaires (sauf admin de la plateforme). L'envoi vers l'appareil est possible si un service est connecté. |
| **Membre** | Aucune alerte. Commentaires. « J'y vais » si l'utilisateur est inscrit **au voyage**. Il n'y a **aucune action d'inscription sur la page d'étape** : on rejoint le voyage, pas l'étape. |
| **Organisateur / admin de la plateforme** | « Modifier » (édition du **voyage**). Notice NO_LOCATION. Suppression de n'importe quel commentaire. |
| **À venir, au-delà de 7 jours** | Météo : NOT_YET_AVAILABLE, avec « La météo sera disponible à partir du {date}. ». Pas de mode Météo sur la carte. Pas d'« Arrivée estimée » dans StatsCard (leg sans prévision). |
| **À venir, dans les 7 jours** | Météo complète (verdicts, tableau). Mode Météo sur la carte. « Arrivée estimée » sous l'allure (seulement si `averageSpeed` est renseigné). |
| **Aujourd'hui / demain** | Badge « Aujourd'hui » / « Demain » à côté de « Départ 08:30 ». |
| **Étape passée, voyage en cours** | Leg OUT_OF_RANGE : `showsDetailBlock` faux, **la section Météo disparaît** (pas même le titre). Pas de mode Météo. **Rien n'indique sur la page que l'étape est passée.** |
| **Voyage terminé ou annulé** | `tripOffersWind` faux : section Météo et mode Météo absents. **Aucun badge « Terminé » / « Annulé »** sur l'étape (KIND_LABELS en a, ils ne sont pas utilisés ici). |
| **Météo en cours de chargement** | Section non rendue (`isLoading`), puis apparition, avec défilement vers `#meteo` une fois chargée si l'ancre est dans l'URL. |
| **Météo du voyage qui ne liste plus l'étape** | `offered` faux : rien (`StageDetailPage.tsx:228`). |
| **Équipe sans `enableRoutes`** | Redirection vers l'équipe, même si l'étape n'a pas de parcours. |

---

## 4. Dates et heures

Règle (frontend/CLAUDE.md) : un **rendez-vous** se lit dans le fuseau de l'entité
(`useRendezvousFormat(stage.timezone)`), un **horodatage** dans celui du lecteur
(`useFormattedDate()`). Le fuseau lecteur est `user.timezone`, sinon celui du navigateur
(`utils/dateFormat.ts:57-58`) ; en SSR c'est `UTC` (`SERVER_FALLBACK_TIMEZONE`, `dateFormat.ts:15`)
et la mention est supprimée. Formats FR de date-fns : `p` = « 08:30 », `PPP` = « 12 mai 2026 »,
`dateFormats.departureDay` = `EEE d MMM` (« mar. 12 mai »).

| # | Emplacement | Champ source | Formatage (`fichier:ligne`) | Exemple FR | Fuseau | Particularités |
|---|---|---|---|---|---|---|
| 1 | DayBox, ligne 1 | `stage.dateTime` | `DayBox.tsx:73` `formatPattern(…,'EEE')` | « mar. » | étape (`start.zone`), lecteur si fuseau inconnu | |
| 2 | DayBox, ligne 2 | `stage.dateTime` | `DayBox.tsx:76` `'d'` | « 12 » | étape | |
| 3 | DayBox, ligne 3 | `stage.dateTime` | `DayBox.tsx:79` `'MMM'` | « mai » | étape | |
| 4 | DayBox, ligne 4 (année) | `stage.dateTime` | `DayBox.tsx:55-56,81-85` `'yyyy'` | « 2027 » | étape | seulement hors de l'année courante |
| 5 | Heure de départ | `stage.dateTime` | `DepartureBlock.tsx:57` `departure.block.time` + `formatTime` (`p`) | « Départ 08:30 » | étape | **c'est la seule ligne qui donne l'heure de départ sur la page** |
| 6 | Pastille relative | `stage.dateTime` | `DepartureBlock.tsx:43,59-63` `formatRelativeDay` | « Aujourd'hui » / « Demain » | étape (jour jugé dans le fuseau de l'étape) | absente pour tous les autres jours, passés compris |
| 7 | Mention de fuseau | `stage.dateTime` | `DepartureBlock.tsx:44,74` → `utils/rendezvous.ts:33-55` | « heure de Lisbonne (09:30 chez vous) », « heure de Tokyo (lun. 01:30 chez vous) » | étape vs lecteur | seulement si les **décalages** diffèrent à cet instant. Jamais en SSR. Seule sur sa ligne (sans `dayLine`) |
| — | Date longue « mardi 12 mai » | — | — | **absente** (`DepartureBlock.tsx:46-47`) | — | le DayBox donne le jour |
| 8 | Arrivée estimée (StatsCard) | `leg.arrivalTime` (`TripStageWeatherDto.leg`) | `StatsCard.tsx:91-94` `rides.group.stats.arrival` + `formatTime` | « Arrivée estimée 14:05 » | étape | seulement si le leg est OK/STALE **et** `averageSpeed` non nul (c'est un *hint* de la tuile Allure) |
| 9 | Verdict Températures | `checkpoint.time` du plus chaud | `RouteVerdicts.tsx:71-72` | « Le plus chaud vers 13:00. » | étape | |
| 10 | Verdict Pluie | `checkpoint.time` (alerte, pic, fenêtre) | `RouteVerdicts.tsx:93-122` | « Dès 11:00 (km 34), 60 %. » / « 40 % au plus, de 11:00 à 12:00 (km 30 à km 45). » | étape | |
| 11 | Verdict Jour, lever et coucher | `departure.sunrise`, `departure.sunset` | `RouteVerdicts.tsx:224-228` | « Lever 07:58, coucher 17:31. » | **étape** | |
| 12 | Verdict Jour, arrivée | `leg.arrivalTime` | `RouteVerdicts.tsx:229` | « Arrivée estimée 14:05. » | étape | **doublon de #8** |
| 13 | Verdict Jour, marge | `arrivalTime` vs `sunset` | `RouteVerdicts.tsx:206-213` (`rides.weather.route.duration.*`) | « 3 h 26 de marge » / « Arrivée 40 min après le coucher » | durée | |
| 14 | Tronçons (rangée du tableau, liste mobile) | `checkpoints[first/last].time` | `RouteWeather.tsx:88-100` `phaseTimes` | « 09:00–10:30 » (une seule heure si le tronçon tient sur un point) | étape | |
| 15 | Colonnes du tableau horaire (≥ sm) | `checkpoint.time` | `RouteWeather.tsx:475` `formatTime`, espaces → retour à la ligne | « 09:40 » (en anglais « 1:00 / PM » sur 2 lignes) | étape | heures de **passage estimées** (vitesse de l'étape, sinon 25 km/h), pas des heures rondes |
| 16 | Graduations de la bande (< sm) | `checkpoint.time` | `RouteWeather.tsx:609` | « 08:30 … 14:05 » | étape | quelques graduations seulement |
| 17 | Détail du point | `checkpoint.time` | `RouteWeather.tsx:672-683` | « km 34 09:40 » (lieu puis heure) | étape | annonce aria-live « {lieu}, {heure} » |
| 18 | Popup / badge sur la carte (mode Météo) | `checkpoint.time` | `WeatherCheckpointMarkers.tsx:75,234,444` | « km 34 · 09:40 » | étape (`timezone={stage.timezone}`, `StageDetailPage.tsx:211`) | |
| 19 | « Mise à jour » (crédit) | `leg.fetchedAt` | `WeatherAttribution.tsx:26-31` (`useFormattedDate`) | « Mise à jour à 10:42 » (aujourd'hui) / « Mise à jour le 9 novembre 2026 à 10:42 » | **lecteur** (horodatage) | `formatDate` = `PPP` (format long avec année) |
| 20 | Météo pas encore disponible | `leg.availableFrom` | `WeatherStatusNotice.tsx:51-52` `formatDate` (`PPP`) | « La météo sera disponible à partir du 5 mai 2026. » | **lecteur** | |
| 21 | Fallback « Au départ » (leg OK sans checkpoint) | `stage.dateTime` (`departureTime`) | `DepartureWeather.tsx:53-54` `formatTime` | « 08:30 · 12 °C » | étape | branche a priori inatteignable pour une étape (sans parcours, le statut est NO_LOCATION) |
| 22 | Fallback, lever et coucher | `departure.sunrise/sunset` | `DepartureWeather.tsx:85-96` `<FormattedTime>` | « 07:58 » | **lecteur** | **incohérent avec #11** (voir §6) |
| 23 | Commentaires | `comment.createdAt` | `CommentItem.tsx:97` `formatRelative` (date-fns `formatDistanceToNow`) | « il y a environ 2 heures » | sans fuseau (relatif) | |
| 24 | Plein écran, sous-titre | `stage.dateTime` | `DepartureLine.tsx:62-63` `formatDeparture` (`withDay`) | « mar. 12 mai · 08:30 », « Demain · 08:30 », « mar. 11 mai 2027 · 08:30 » | étape | icône de mention de fuseau (`ZoneMentionIcon`) au lieu du texte |
| 25 | Libellés SiblingNav | — | — | « 2 · Vannes → Lorient » | — | **aucune date** dans les options de navigation |

Remarques :
- L'heure de départ n'apparaît qu'une fois en texte (#5). StatsCard n'a pas de tuile Départ.
  RouteWeather ne montre pas DepartureWeather quand il y a des checkpoints : le verdict
  Températures dit « au départ » sans heure, et la première colonne du tableau donne l'heure du
  premier point.
- Les heures de passage (#14-18) sont des rendez-vous, donc lues dans le fuseau de l'étape, mais
  sans mention de fuseau : seul le DepartureBlock en porte une.
- `stage.timezone` peut différer de `trip.timezone`. La page lit tout dans celui de l'étape.

---

## 5. Wireframe ASCII

### Desktop (≥ 1024 px)

```
Équipes › Les Rouleurs › Agenda › Tour de Bretagne › Vannes → Lorient      (fil d'Ariane, Layout)
← Retour au voyage                                                         (1 lien retour)
┌─ EN-TÊTE (Paper) ───────────────────────────────────────────────────────────────────────────┐
│ [‹] [ 1 · Rennes→Vannes | 2 · Vannes→Lorient | 3 · … | 4 · … ] [›]          (2a SiblingNav)  │
│ Tour de Bretagne · étape 2 sur 4                                              [✎ Modifier]   │
│ # Vannes → Lorient  [J'y vais] [⇪]                                         (2b titre/badges) │
│ ┌──────────────────────────────────────────────────────────────────────────────────────────┐ │
│ │ ┌─────┐  Départ 08:30  [Demain]                                     (2c DepartureBlock)  │ │
│ │ │ mar.│  heure de Lisbonne (09:30 chez vous)                                             │ │
│ │ │ 12  │  📍 Port de Vannes (quai Éric Tabarly)                                           │ │
│ │ │ mai │                                                                                  │ │
│ │ └─────┘                                                                                  │ │
│ └──────────────────────────────────────────────────────────────────────────────────────────┘ │
│ 📍 Arrivée : Gare de Lorient (place François Mitterrand)                     (2d PlacesLine) │
│ [i Connectez-vous et rejoignez cette équipe… Se connecter]                 (2e AccessAlerts) │
└──────────────────────────────────────────────────────────────────────────────────────────────┘
┌─ COLONNE 380–440 px ────────┐ ┌─ CARTE STICKY (hauteur visible − 130 px) ──────────────────┐
│ ┌ 3a StatsCard ───────────┐ │ │                                         [+][−][⧉][⤢ plein] │
│ │ ⚡ ALLURE   ↔ DISTANCE   │ │ │            (3d carte MapLibre, tracé coloré)               │
│ │ 25 km/h    82 km        │ │ │                                                            │
│ │ Arrivée estimée 14:05   │ │ │ ▁▂▃▅▆▅▃▂▁ profil altimétrique en overlay ▁▂▃▅  [échelle]   │
│ │ ↑ DÉNIVELÉ POSITIF      │ │ └────────────────────────────────────────────────────────────┘
│ │ 1 240 m                 │ │   Profil d'altitude provisoire                  (3e, si PENDING)
│ └─────────────────────────┘ │   [ Pente | Revêtement | Météo ]                 (3f contrôles)
│ ┌ 3b Consignes (sans titre)┐│   Vent sur le tracé : Dos 30 km · Travers · Face  (mode Météo)
│ │ Texte markdown, PJ…     ││   ▬▬▬ Asphalte 92 % · Gravier 8 %         (RouteSurfaceSummary)
│ └─────────────────────────┘│   #### Points du parcours (3)                    (3g waypoints)
│ ┌ 3c RouteCard ───────────┐ │   ◉ Ravitaillement · km 41 …
│ │ ### Vannes – Lorient     │ │   (la colonne carte défile en interne)
│ │ 🗺 Voir le parcours ⤓ GPX │ │
│ │ ⤓ FIT 📱 Envoyer vers…   │ │
│ └─────────────────────────┘ │
└─────────────────────────────┘
┌─ 4 MÉTÉO DU PARCOURS #meteo (pleine largeur) ──────────────────────────────────────────────┐
│ ### Météo du parcours [Prévision ancienne]            Prévisions Open-Meteo · Mise à jour à 10:42│
│ (notice de statut si besoin)                                                                │
│ ┌Températures┐┌Pluie────────┐┌Vent─────────┐┌Jour──────────────┐   (verdicts, 4 colonnes)   │
│ │9 → 17 °C   ││Sec          ││Surtout face ││2 h 10 de marge   │                            │
│ └────────────┘└─────────────┘└─────────────┘└──────────────────┘                            │
│ #### Heure par heure, à votre passage                                                       │
│ Passages estimés à 25 km/h · un point tous les 10 km   Dos 30 km · Travers 22 · Face 30     │
│ Tronçons │ Face 08:30–10:00   │ Travers 10:00–11:30 │ Dos …                                │
│ Heure    │08:30│09:00│09:40│10:15│ …                                                        │
│ ☁ / temp / pluie % / bande vent / flèche / vent / rafales / km                              │
│ ┌ Détail : km 34 09:40 │ Température │ Pluie │ Vent │ Tronçon ┐                             │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
┌─ 5 COMMENTAIRES (membres) ──────────────────────────────────────────────────────────────────┐
│ #### Commentaires (3)   [Écrivez un commentaire...]   Léa · il y a environ 2 heures …       │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Étroit (< 1024 px, téléphone)

```
Tour de Bretagne › Vannes → Lorient
← Retour au voyage
┌ EN-TÊTE ──────────────────────────┐
│ [‹][1 · …|2 · …|3 · …|4 · …][›]   │  (labels serrés ; Select au-delà de 4)
│ Tour de Bretagne · étape 2 sur 4  │
│ # Vannes → Lorient [J'y vais][⇪]  │
│ [✎ Modifier]                      │  (passe à la ligne)
│ ┌───┐ Départ 08:30 [Demain]       │
│ │mar│ heure de Lisbonne (…)       │
│ │12 │ 📍 Port de Vannes (…)       │
│ └───┘                             │
│ 📍 Arrivée : Gare de Lorient      │
│ [alerte d'accès]                  │
└───────────────────────────────────┘
┌ 3d CARTE (52svh, 300–560 px) ─────┐  ← la carte passe AVANT la colonne
│ profil en overlay  [⤢]            │
└───────────────────────────────────┘
[ Pente | Revêtement | Météo ]  légende vent · revêtements
#### Points du parcours (3)
┌ 3a StatsCard (2 colonnes) ────────┐
┌ 3b Consignes ─────────────────────┐
┌ 3c RouteCard ─────────────────────┐
┌ 4 Météo du parcours ──────────────┐
│ verdicts 2×2                      │
│ Heure par heure…                  │
│ bande + graduations 08:30 … 14:05 │
│ [=====o========] curseur          │
│ Détail du point                   │
│ #### Par tronçon (liste)          │
└───────────────────────────────────┘
┌ 5 Commentaires ───────────────────┐
```

### Plein écran (`/carte`)

```
[←] Vannes → Lorient                         ⤳ 82 km ↑ 1 240 m ↓ 1 180 m [Pente|Revêtement|Météo]
    🕐 mar. 12 mai · 08:30 ⓘ
┌──────────────────────────────── carte plein écran ────────────────────────────────────────┐
└───────────────────────────────────────────────────────────────────────────────────────────┘
 Vent sur le tracé : Dos · Travers · Face — Prévisions …                  (mode Météo seulement)
 ▁▂▃▅▆▅▃▂▁ profil altimétrique 160 px (fixe, sous la carte) ▁▂▃▅▆▅▃▂▁
```

---

## 6. Étonnements

1. **Double navigation retour** : le fil d'Ariane du Layout (« … › Tour de Bretagne › Vannes →
   Lorient ») est suivi du lien « ← Retour au voyage » du shell, puis de « Tour de Bretagne · étape
   2 sur 4 ». Le nom du voyage apparaît donc 2 à 3 fois au-dessus du h1.
2. **Arrivée estimée en double** : « Arrivée estimée 14:05 » dans StatsCard (#8) et « Arrivée
   estimée 14:05. » dans le verdict Jour (#12).
3. **Arrivée estimée liée à l'allure** : c'est un *hint* de la tuile « Allure moyenne ». Sans
   `averageSpeed`, l'arrivée disparaît de StatsCard, alors que le leg est calculé à 25 km/h par
   défaut et qu'il a une `arrivalTime` (seul le verdict Jour la donne alors).
4. **StatsCard vide possible** : sans parcours et sans allure, le Paper bordé est rendu sans aucune
   tuile.
5. **Lever et coucher dans deux fuseaux** : dans les verdicts, ils sont lus dans le fuseau de
   l'étape (`RouteVerdicts.tsx:225-228`). Dans le fallback `DepartureWeather`, ils passent par
   `<FormattedTime>`, donc dans le fuseau du lecteur (`DepartureWeather.tsx:89,94`), alors que
   l'heure de départ du même bloc est lue dans celui de l'étape.
6. **Une étape passée ne dit pas qu'elle est passée** : pas de badge « Terminée », la section
   Météo disparaît sans rien dire (OUT_OF_RANGE), et l'en-tête ne change pas. Pas de badge non plus
   pour un voyage **annulé** ou **terminé**, alors que `KIND_LABELS.trip` en a. On peut donc
   arriver sur l'étape d'un voyage annulé par un lien direct sans le savoir.
7. **Badge « J'y vais » au niveau du voyage** : il reflète `trip.registered` et s'affiche donc à
   l'identique sur toutes les étapes, alors qu'il n'y a aucune action d'inscription sur la page.
   Le libellé est « J'y vais » (`rides.detail.groups.joined`), pas « Vous participez ».
8. **« Modifier » ouvre l'édition du voyage entier**, pas celle de l'étape.
9. **Météo d'un voyage à une étape en double** : la même `RouteWeatherSection` est rendue sur la
   page du voyage (ef1fc9a99) et sur celle de l'étape, qui reste accessible et sans SiblingNav
   (« étape 1 sur 1 »).
10. **Étape sans parcours** : la notice météo n'est visible que des organisateurs. Les autres n'ont
    aucune météo, même avec un lieu de départ (le backend ne calcule la météo de départ d'une étape
    qu'à partir du premier point de son parcours). Le texte `trips.weather.noRoute` (« Cette étape
    n'a pas de parcours… ») semble donc inatteignable : il demande un leg OK/STALE sans checkpoint.
11. **La RouteCard dépend du nom du parcours** : sans `routeName`, GPX, FIT et « Envoyer vers
    l'appareil » disparaissent alors que le parcours existe. Le groupe, lui, retombe sur « Parcours
    du groupe ».
12. **Redirection si `enableRoutes` est faux**, même pour une étape sans parcours (`:78`).
13. **L'ordre change sur mobile** : la carte passe devant les stats, les consignes et les actions
    (`grid-template-areas: 'map' 'side'`), alors qu'elle les suit sur desktop. Les consignes
    arrivent donc après la carte et la liste des points.
14. **StatsCard toujours en 2 colonnes sur desktop** (container query à 560 px pour une colonne de
    440 px max), mais en 4 colonnes sur tablette.
15. **La colonne carte défile en interne** sur desktop (`.detail-map--solo` avec `overflow-y:
    auto`) : contrôles, légende et liste des points y sont cachés sous la carte quand la fenêtre
    est courte.
16. **Conteneurs imbriqués** : la page pose `Container size="xl"` à l'intérieur du `Container
    size="lg" px={0}` du Layout (`Layout.tsx:358`), donc la largeur utile est plafonnée par `lg`.
    La règle `.detail-map` « span 2 à 90em » ne s'applique pas ici, `grid-area` l'emporte. Effet
    visuel non vérifié.
17. **`stageIndex` / `stageCount` du DTO ne sont pas utilisés** : « étape i sur n » et la
    numérotation des options viennent de la position dans `trip.stages`. C'est cohérent tant que la
    liste ne contient que les étapes vivantes et triées (non vérifié).
18. **Les options de SiblingNav n'ont aucune date** : on change d'étape par numéro et nom
    seulement. Avec 4 étapes en SegmentedControl pleine largeur, les libellés « n · nom » sont
    serrés sur un téléphone (risque non vérifié visuellement).
19. **Les consignes ne sont pas en tête de colonne**, contrairement à ce que dit le JSDoc
    d'`InstructionsBlock` (« at the head of the side column ») : StatsCard passe avant.
20. **Formats de date longs différents** : `fetchedAt` et `availableFrom` utilisent `PPP` (« 5 mai
    2026 »), alors que `formatDateTime` dit que « le site a un format long date+heure »
    (« mar. 5 mai · 10:42 »).
21. **Le bouton Partager porte un `title`** HTML (`ShareButton.tsx:50`) sur l'ActionIcon, pas sur
    l'icône : conforme à la règle Tabler. Le titre partagé est `stage.name` seul, sans le nom du
    voyage.
