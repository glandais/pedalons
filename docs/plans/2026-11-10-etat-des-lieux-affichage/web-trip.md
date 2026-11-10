# Frontend web : page de détail d'un VOYAGE (trip)

Périmètre : `frontend/src/pages/trip/TripDetailPage.tsx` et ce qu'elle rend, état du code sur la branche `feat/mobile-review` (HEAD `ef1fc9a99`). Le code a seulement été lu : rien n'a été lancé ni rendu dans un navigateur. Tous les chemins ci-dessous partent de `frontend/src/`.

---

## 1. Points d'entrée

### Route

- Contrat : `contracts/routes.yaml:626-632`, id `trip`.
  - FR : `/equipes/{teamSlug}/voyages/{tripSlug}`
  - EN : `/teams/{teamSlug}/trips/{tripSlug}`
- Config : `config/routes.config.ts:863-872`, id `trip-detail`.
  - `auth: 'public'`, donc visible des anonymes.
  - `parentId: 'team-agenda'`. Le fil d'Ariane vaut donc Équipes > {équipe} > Agenda > {nom du voyage} (`breadcrumb: dynamic trip`).
  - SSR : `prefetch: prefetchTripDetail`, plus `meta: tripMeta` pour l'Open Graph.
- Fil d'Ariane : il est rendu par le Layout (`components/common/Layout.tsx:360`, `components/common/Breadcrumb.tsx:96-110`). Chemin complet à partir de `sm` ; en dessous, seulement les 2 derniers niveaux.
- Page enfant : la carte d'étape mène à `paths.stage(...)`, soit `/equipes/{t}/voyages/{v}/etapes/{stageSlug}` (StageDetailPage, hors périmètre).

### Fichier de page

`pages/trip/TripDetailPage.tsx` (288 lignes).

Garde-fous en tête de page :

| Situation | Effet | Lignes |
|---|---|---|
| Équipe introuvable | redirection vers `/equipes` | :86-88 |
| `!team.enableTrips` ou `!team.enableRoutes` | redirection vers la page de l'équipe | :90-92 |
| Chargement | `DetailPageSkeleton` | :94-115 |
| Erreur | `QueryStateBoundary` avec bouton de nouvel essai | :94-115 |
| 404 | « Voyage introuvable » / « Le voyage que vous recherchez n'existe pas. » / lien « Retour aux voyages » | :94-115 |

### Données chargées

Le hook est `useTripDetailData` (`pages/trip/tripDetailData.ts:88-100`). Il fait trois lectures :

- `useGetTeam(teamSlug)`, qui renvoie `TeamDto`. La page en lit `role` (via `teamAccess`), `enableTrips`, `enableRoutes`, `name`, `slug` et `about`.
- `useGetTrip(teamSlug, tripSlug)`, qui renvoie `TripDto` (`api/dto/tripDto.ts`). Champs utilisés par la page :
  - identité : `name`, `media` (logo, markdown, pièces jointes), `status`, `finished`, `tags`, `team` ;
  - dates : `dateTime`, `timezone`, `endDateTime`, `publishAt` ;
  - parcours et étapes : `routeSlug`, `stages[]`, `stageCount` ;
  - chiffres : `participantCount`, `totalDistance`, `totalElevationGain` ;
  - inscription : `registered`.
- `useGetTripWeather(teamSlug, tripSlug)`, qui renvoie `TripWeatherDto` : `stages[]` de `TripStageWeatherDto {stageId?, summary?, leg, departure}`, plus `attribution`, `status` et `fetchedAt`. Pas de toast d'erreur (`TRIP_WEATHER_REQUEST`).

Champs de `TripStageDto` lus par la carte d'étape :
- `id`, `slug`, `name`, `media.assets.logo` ;
- `dateTime`, `timezone`, `averageSpeed` ;
- `route` (un `RouteDto` complet : `slug`, `distance`, `elevationGain`, `media.assets.gpx/fit`) ;
- `startPlace`, `endPlace`.

`stageIndex` et `stageCount` ne sont **pas** lus : le numéro affiché est `index + 1`.

Autres lectures, faites par les enfants :
- `useTripMembership` (rejoindre / quitter, avec son message d'erreur) ;
- `usePublicationStatusActions` (menu organisateur et dialogues) ;
- `RoutesMapView` → `useRoutesBulk` (traces GPX des parcours) ;
- `ParticipantList` → `useGetTripParticipants` (paginé, `?q=` / `?p=`) ;
- `CommentSection` → commentaires du voyage ;
- `useGpsConnections` (menu « Envoyer vers l'appareil »).

Le prefetch SSR (`tripDetailData.ts:112-148`) couvre l'équipe, le voyage et la météo, puis les commentaires (membres seulement), le bulk des parcours et les participants (si `participantCount > 0` et que le lecteur est membre).

### Droits calculés dans la page (`TripDetailPage.tsx:119-132`)

| Variable | Définition |
|---|---|
| `isMember` | `!!team.role` : vraie appartenance, un admin plateforme n'est pas membre |
| `canEdit` (= `isOrganizer`) | ADMIN ou ORGANIZER de l'équipe, ou admin plateforme |
| `canReadComments` | `isMember \|\| isPlatformAdmin` ; commande aussi la liste nominative des participants |
| `hasJoined` | `!!user && trip.registered` |
| `canJoinTrip` | `isMember && status === PUBLISHED && !hasJoined && !trip.finished` |
| `stageCount` | `trip.stages.length` (et non `trip.stageCount`) |
| `onlyStage` | l'unique étape si `stageCount === 1` |
| `singleLeg` | `stageCount <= 1` **et** `weather.stages.length === 1` |

---

## 2. Disposition

Conteneur : Mantine `Container size="xl" py="xl"`, soit une largeur maximale d'environ 1320 px.

### 2.A Desktop (≥ 64em, soit 1024 px)

Ordre DOM et ordre visuel, de haut en bas :

**0. Fil d'Ariane** (Layout, hors page)
- Composant : `components/common/Breadcrumb.tsx:96-101`.
- Contenu : « Équipes › {équipe} › Agenda › {nom du voyage} ». Le dernier niveau est grisé, sans lien.

**1. Bandeau d'équipe** (`TeamContextBanner`)
- Composant : `components/team/TeamContextBanner.tsx:28-50`, appelé en `TripDetailPage.tsx:137`.
- Condition : toujours (dès que `team` existe).
- Contenu : un Paper bordé, qui forme une seule ligne cliquable vers la page de l'équipe. On y trouve :
  - l'avatar de l'équipe (`TeamAvatar` sm, avec repli sur les initiales) ;
  - le nom de l'équipe (sm, 500, une ligne) ;
  - un chevron droit grisé.
  - Le lien porte l'aria « Voir la page de l'équipe {name} ».

**2. En-tête de publication** (`PublicationHeader`)
- Composant : `components/publication/PublicationHeader.tsx:50-182`, appelé en `TripDetailPage.tsx:139-172`.
- Forme : un `Paper` avec `shadow xs`, `p lg`, bordure, `component="header"`.
- Ligne 1 (`Group justify space-between`, avec retour à la ligne) :
  - À gauche :
    - `EntityLogo` lg (le logo du voyage, rien s'il n'y en a pas : `EntityLogo` n'a pas de repli) ;
    - le titre h2 `trip.name`, sur **une ligne tronquée avec ellipse** ;
    - un badge de statut toujours présent : « Brouillon » (gris) / « Publié » (vert) / « Annulé » (rouge), selon `STATUS_COLORS` ;
    - si `trip.finished`, un badge gris « Terminé ».
  - À droite, dans l'ordre :
    1. **« Rejoindre le voyage »**, bouton plein, si `canJoinTrip` (`TripDetailPage.tsx:148-152`) ;
    2. **« Quitter le voyage »**, bouton outline, si `hasJoined` (`:153-157`), même pour un voyage terminé ou annulé ;
    3. si `canEdit`, un `Button.Group` : « Modifier » (crayon, lien vers `/modifier`) et un chevron qui ouvre le menu :
       - DRAFT : « Publier » ;
       - PUBLISHED : « Dépublier », « Annuler le voyage » ;
       - CANCELLED : « Restaurer le voyage » ;
       - si supprimé : « Restaurer » ;
       - puis un séparateur et « Supprimer » (rouge).
       - Chaque action passe par un `ConfirmDialog` (`statusActions.dialogs`, `TripDetailPage.tsx:285`).
    4. `ShareButton` : ActionIcon `IconShare`, aria « Partager ». Il copie le lien ou ouvre le partage natif (non vérifié en détail).
    5. `ContentActionsMenu` : ActionIcon `IconDots`, aria « Plus d'actions », menu « Signaler ». Il est **masqué pour un anonyme** (`ContentActionsMenu.tsx:62`).
- Si l'adhésion vient d'échouer : une `Alert` rouge sous la ligne (`PublicationHeader.tsx:157-161`), qui affiche le code d'erreur traduit ou « L'inscription n'a pas pu être enregistrée. Réessayez. ».
- Enfants (`mt md`, `Stack gap sm`) :
  - **2a. Bloc départ** (`DepartureBlock`, `components/common/DepartureBlock.tsx:33-118`, appelé en `TripDetailPage.tsx:164-169`, ton `teal`) :
    - une surface grise bordée ;
    - à gauche, la **DayBox** lg turquoise (`components/common/DayBox.tsx:30-88`) sur 3 ou 4 lignes : jour court (« sam. »), numéro (28 px, 700, « 14 »), mois court (« nov. »), puis l'année seulement hors de l'année courante ;
    - au centre :
      - « Départ 09:00 » (24 px, 700) ;
      - à côté, un badge turquoise « Aujourd'hui » ou « Demain » si le premier départ tombe ce jour-là ;
      - en dessous (sm, gris), la **plage du voyage** (`dayLine`, par exemple « ven. 13 → dim. 15 nov. »), suivie si besoin de la mention de fuseau « · heure de Tokyo (ven. 01:00 chez vous) ».
    - Le voyage ne passe ni `place` ni `group`, donc **pas de lieu de départ ni de colonne « Votre groupe »**.
  - **2b. Bande de chiffres** (`FactsStrip`, `components/publication/FactsStrip.tsx:18-72`, avec `publicationFacts.ts:41-50`). Textes sm gris, sans icône, en ligne :
    - « {n} étapes », si `trip.stageCount > 0` ;
    - « {n} personnes », toujours, **même à 0** (« 0 personne ») ;
    - « {totalDistance} km », si présent, avec une décimale (`toFixed(1)`), par exemple « 245.3 km » ;
    - « D+ : 3120 m », si présent, sans séparateur de milliers.
- Ligne de publication programmée, si `status === DRAFT && publishAt` (`PublicationHeader.tsx:165-177`) : icône calendrier jaune et « Publication programmée pour le sam. 14 nov. · 08:00 », plus la mention de fuseau.
- `TagList` : toutes les étiquettes `trip.tags` (`mt md`). Rien s'il n'y en a pas (non vérifié dans `TagList`).

**3. Zone à deux colonnes** (`Box.detail-layout`, `TripDetailPage.tsx:177-234`)
- CSS : `index.css:267-317`.
- Grille ≥ 64em : `minmax(380px, 440px) | minmax(0, 1fr)`, avec les zones `'side map'` et `gap lg`.
- Sans aucun item de carte, la classe `detail-layout--no-map` s'applique : une seule colonne pleine largeur. Cela n'arrive que pour un voyage sans `routeSlug` **et** sans étape ; voir §6.

Colonne GAUCHE, `.detail-side` (`Stack gap lg`), dans l'ordre :

- **3.1 Consignes** (`InstructionsBlock`, `components/publication/InstructionsBlock.tsx:22-36`)
  - Condition : `media.markdown` non vide **ou** au moins une pièce jointe.
  - Contenu : un Paper bordé `p lg`, **sans titre visible** (aria-label « Consignes »), qui affiche `MediaDisplay` : le markdown rendu, les images référencées et les pièces jointes.
- **3.2 Étapes** (`TripDetailPage.tsx:184-206`)
  - Toujours affiché.
  - Titre h3 (taille h4) « Étapes ».
  - S'il y a des étapes : une liste de `TripStageCard` (`Stack gap sm`). Sinon le texte gris « Aucune étape définie pour ce voyage. ».
  - Une carte d'étape (`components/trip/TripStageCard.tsx:28-95` dans `components/publication/ChildCard.tsx:47-127`) :
    - Forme : un Paper bordé `p md`. **Toute la carte est un lien** vers la page de l'étape (lien étiré, `ChildCard.module.css`).
    - Survol de la carte : la trace s'allume sur la carte. Une carte allumée (survol ou clic sur sa trace) prend une ombre md, une bordure et un fond `primary-light`.
    - Ligne 1, à gauche :
      - le marqueur : le logo de l'étape (`EntityLogo` md) s'il existe, sinon un **badge rond numéroté** « 1 », « 2 »… (light, primary) ;
      - le nom de l'étape (600, tronqué) suivi d'un chevron droit.
    - Ligne 1, à droite (`corner`) : `DepartureLine` sm `withDay` (`components/common/DepartureLine.tsx:47-97`). Horloge (`IconClock`, primary) puis, en 700, « sam. 14 nov. · 09:00 » / « Demain · 09:00 » / « Aujourd'hui · 09:00 ». S'y ajoute une icône globe (`IconWorld`, avec la mention de fuseau en tooltip) si le fuseau de l'étape n'a pas le décalage du lecteur.
    - Ligne lieux, si `startPlace` ou `endPlace` : épingle verte et nom du départ, épingle rouge et nom de l'arrivée (sm). Pas de flèche entre les deux.
    - Ligne chiffres (`ChildFacts`, `ChildCard.tsx:135-173`) :
      - `IconBolt` « 25 km/h », si `averageSpeed > 0` ;
      - `IconArrowsMaximize` « 82.4 km », si l'étape a un parcours ;
      - `IconArrowUp` « 1240 m », si l'étape a un parcours.
      - Ici, pas de préfixe « D+ ».
    - Ligne météo, si la météo du voyage donne un `summary` pour cette étape (`components/weather/RideWeatherSummaryLine.tsx:36-126`) :
      - statut NOT_YET_AVAILABLE : `IconCalendarTime` « Météo disponible à partir du 21 novembre 2026 » ;
      - statut OK ou STALE :
        - icône du ciel et « 8 → 14 °C » (ou une seule valeur) ;
        - `IconWind`, flèche de provenance et « 15 km/h » ;
        - badge bleu parapluie « Averses dès 14:00 » si une alerte pluie existe (tooltip « … % ») ;
        - `IconHistory` si STALE.
    - Actions du parcours, si `stage.route` (`components/ride/RideGroupRouteActions.tsx:29-108`, `withViewLink={false}`) : liens gris xs « GPX », « FIT » (téléchargement, si les fichiers existent) et, pour un utilisateur connecté qui a un service GPS lié, un menu « Envoyer vers l'appareil » (Garmin, Wahoo…). **Pas de lien « Voir le parcours »** : c'est la carte entière qui mène à l'étape.
    - **La description de l'étape n'apparaît jamais** sur la carte.
- **3.3 Personnes inscrites** (`ParticipantsSection`, `components/publication/ParticipantsSection.tsx:30-76`, appelé en `TripDetailPage.tsx:208-215`)
  - Condition : `trip.participantCount > 0`.
  - Contenu : un Paper bordé `p lg`.
    - Titre h3 « Personnes inscrites », et à droite, en gris, « {n} personnes ».
    - Si `canReadComments` (membre ou admin plateforme), la `ParticipantList` (`components/ride/ParticipantList.tsx:84-185`) :
      - un champ de recherche « Rechercher par nom… » ;
      - la liste des lignes : avatar md, nom (sm 600, tronqué), petit chevron décoratif ;
      - « 1–20 sur 45 » ;
      - la `Pagination`.
    - Sinon : **le titre et le compte seulement**.

Colonne DROITE, `.detail-map` (`detail-map--fill detail-map--solo`) :

- Condition : `mapItems.length > 0`, c'est-à-dire que le voyage a un `routeSlug` ou au moins une étape (même sans parcours).
- Comportement : **sticky** en dessous de l'en-tête de l'application (`index.css:256-262`). Hauteur = hauteur visible − 130 px, avec un minimum de 360 px (`index.css:312-316`). Si son contenu déborde, il défile à l'intérieur de la colonne.
- **3.4 Carte du voyage** (`TripOverviewMap`, `components/trip/TripOverviewMap.tsx:30-93`, et `components/route/RoutesMapView.tsx`) :
  - MapLibre (`components/map/PedalonsMap.tsx:76-95`), avec les contrôles suivants :
    - en haut à gauche : zoom et boussole, puis plein écran (`RoutesMapView.tsx:651`) ;
    - le contrôle « Masquer la trace (H) » ;
    - le sélecteur de fond de carte (relief et ombrage si disponibles, une case à cocher par trace s'il y a plus d'une trace) ;
    - la barre d'échelle (`MapScale`) ;
    - l'attribution.
  - Traces : une par étape qui a un parcours (couleur propre à chaque étape, opacité 0,5, épaisseur 5 ; l'étape allumée passe à 8 et 0,9), ou la trace unique du voyage si `trip.routeSlug`. Des chevrons de sens sont posés sur toutes les traces.
  - Marqueurs : départ (premier point de la première trace) et arrivée (dernier point de la dernière trace).
  - Bornes kilométriques : chacune comptée depuis le départ de son étape (`kmMarkers` hors mode Météo).
  - **Profil altimétrique en surimpression** en bas à gauche (`RoutesMapView.tsx:752-770`), sur un Paper ombré :
    - taille : largeur 40 % en md (50 % en sm, 100 % − 40 px en base) ; hauteur 150 / 140 / 120 px ;
    - Chart.js, qui suit l'étape allumée, sinon la première trace visible ;
    - axes titrés « Distance (km) » et « Elevation (m) » (**en anglais, non traduits**) ;
    - réticule synchronisé avec un marqueur sur la carte.
  - Clic sur une trace : sélectionne l'étape (la carte d'étape s'allume), **sans naviguer**.
  - Pendant le chargement : un Skeleton, puis un encart gris « Chargement » ; sans aucune trace chargée, un encart gris « Aucun parcours disponible ».
- **3.5 Sélecteur « Étapes | Météo »** (`ColorByControl`, `components/route/ColorByControl.tsx:34-58`) :
  - Il n'apparaît que si au moins une étape a une prévision de vent. Sans cela, il n'y a qu'une option et rien n'est dessiné.
  - Le mode par défaut est toujours « Étapes ».
- **3.6 Légende du vent** (`WindMapLegend`, `components/weather/WindMapLegend.tsx:37-85`, en mode Météo seulement) :
  - « Vent sur le tracé : », suivi de traits colorés « Dos 32 km · Travers 18 km · Face 40 km », sommés sur toutes les étapes ;
  - le badge « Prévision ancienne » si l'une des prévisions est périmée ;
  - la mention de la vitesse par défaut ;
  - « Prévisions {fournisseur} ».
  - En mode Météo, les traces sont colorées par vent relatif et portent des badges météo aux points de prévision (`WeatherLegsMarkers`, heures lues dans le fuseau de chaque étape). Les bornes km disparaissent alors.

**4. Météo du parcours** (`RouteWeatherSection`, `components/weather/RouteWeatherSection.tsx:50-129`, appelé en `TripDetailPage.tsx:239-261`)
- Pleine largeur, sous la grille, ancre `#meteo`.
- Condition : `singleLeg`, c'est-à-dire un voyage d'une seule étape, ou sans étape et roulé sur son propre parcours, **et** une réponse météo qui contient exactement 1 leg. Il faut en plus :
  - `offered = !trip.finished && status !== CANCELLED` ;
  - la météo chargée ;
  - un statut de leg montrable (`showsDetailBlock`) : OK, STALE, NOT_YET_AVAILABLE ou UNAVAILABLE. NO_LOCATION ne s'affiche qu'à un organisateur ; OUT_OF_RANGE n'affiche rien.
- Contenu : un Paper bordé `p md/lg`.
  - En-tête :
    - titre h3 « Météo du parcours », avec le badge « Prévision ancienne » si STALE ;
    - à droite, « Prévisions {fournisseur} » et « Mise à jour à 14:05 ».
  - Notice d'état (`WeatherStatusNotice.tsx:35-89`) :
    - « La météo sera disponible à partir du 21 novembre 2026. » ;
    - ou « La météo n'est pas disponible pour le moment. » avec un bouton « Réessayer » ;
    - ou, pour un organisateur, « Ajoutez un parcours à cette étape pour afficher sa météo. ».
  - Avec prévision, `RouteWeather` (`components/weather/RouteWeather.tsx:126-240`) :
    - 4 **verdicts** « L'essentiel du parcours » (`RouteVerdicts.tsx`) : Températures, Pluie, Vent, Jour ;
    - « Heure par heure, à votre passage » : « Passages estimés à 25 km/h · un point tous les 5 km », avec le total de vent ;
    - ≥ sm (48em) : un **tableau défilant** de points de passage. Lignes : tronçons, heure, température, pluie, vent, rafales ;
    - < sm : une **bande avec curseur** ;
    - le **détail du point sélectionné**, sous le tableau ou la bande ;
    - < sm seulement : la liste « Par tronçon ».
  - Leg sans prévision (pas de parcours, par exemple) : `DepartureWeather` (« AU DÉPART », « 09:00 · 12 °C », ciel, ressenti, pluie %, vent, lever et coucher) suivi de « Cette étape n'a pas de parcours : pas de prévision le long de la route. ».

**5. Alertes d'accès** (`AccessAlerts`, `components/publication/AccessAlerts.tsx:19-49`, appelé en `TripDetailPage.tsx:263-270`)
- Anonyme : `Alert` bleue « Connectez-vous et rejoignez cette équipe pour participer aux voyages. » et le lien « Se connecter » (qui ramène ici après connexion).
- Connecté mais non membre : `Alert` jaune « Rejoignez cette équipe pour participer aux voyages. » et le lien « Voir l'équipe ».
- Membre : rien.

**6. Commentaires** (`CommentSection`, `components/comment/CommentSection.tsx:77-131`, appelé en `TripDetailPage.tsx:273-283`)
- Condition : `canReadComments` (membre ou admin plateforme).
- Contenu : un Paper `p xl` ombré.
  - Titre h4 « Commentaires ({total}) ».
  - Le formulaire « Écrivez un commentaire... ».
  - Les commentaires (`CommentItem.tsx:79-180`) :
    - avatar, nom, date relative « il y a 2 heures » ;
    - menu ⋯ « Signaler », ou « Bloquer {nom} » ;
    - texte ;
    - « Répondre », et « Supprimer » pour l'auteur ou un organisateur ;
    - réponses indentées avec un liseré gauche, et « Voir N réponses ».
  - Commentaires vides : `EmptyState` « Aucun commentaire » / « Aucun commentaire pour le moment. Lancez la discussion ! ».
  - Plus bas : « Charger plus de commentaires ».

### 2.B Viewport étroit (< 64em)

Seuls les blocs 3.x changent de place (`index.css:267-286`).

- `.detail-layout` devient **une seule colonne**, avec les zones `'map' 'side'`. **La carte passe au-dessus** des Consignes, des Étapes et des Personnes inscrites, alors qu'elle vient après dans le DOM.
- La carte **n'est plus sticky**. Sa hauteur tombe à `clamp(300px, 52svh, 560px)`, car `--detail-map-height` n'est défini qu'à partir de 64em.
- Le profil en surimpression est plus petit (sm : 50 % × 140 ; base : 100 % − 40 px × 120).
- Dans la Météo du parcours, sous 48em, le tableau horaire laisse place à la bande avec curseur, et la liste « Par tronçon » apparaît (`RouteWeather.tsx:191-237`, bascule CSS `visibleFrom` / `hiddenFrom`).
- La ligne de l'en-tête passe à la ligne : les boutons tombent sous le titre (`wrap="wrap"`), et le titre reste tronqué sur une ligne.
- Fil d'Ariane : seulement les 2 derniers niveaux sous `sm` (« Agenda › {voyage} »).
- `DepartureBlock` porte une container query à 600 px. Elle ne change rien pour un voyage, qui n'a pas de colonne « groupe ».
- ≥ 90em : la règle `.detail-map { grid-column: span 2 }` (`index.css:331-335`) est neutralisée par `.detail-layout > .detail-map { grid-area: map }`, plus spécifique. La disposition ne change pas.
- La page n'a pas d'onglets.

---

## 3. Variantes

| Bloc | Une étape | Plusieurs étapes | Sans étape, avec `routeSlug` | Sans étape ni parcours |
|---|---|---|---|---|
| FactsStrip | « 1 étape » | « N étapes » | pas de compte d'étapes | pas de compte d'étapes, ni km, ni D+ |
| Étapes (3.2) | 1 carte | N cartes | « Aucune étape définie pour ce voyage. » | idem |
| Carte (3.4) | trace de l'étape, ou du voyage si `routeSlug` | N traces colorées, case à cocher par trace dans le panneau du fond de carte | 1 trace (le parcours du voyage) | **colonne carte absente** (`detail-layout--no-map`), colonne gauche pleine largeur |
| Mode Météo carte (3.5/3.6) | s'il existe une prévision | s'il existe une prévision ; légende sommée, sujet « trip » | s'il existe une prévision (leg sans `stageId`), sujet « stage » | — |
| Météo du parcours (4) | **oui** (leg de l'étape, fuseau de l'étape) | **non** : seules les lignes météo des cartes et le mode Météo de la carte en parlent (test `TripDetailPage.test.tsx:139`) | **oui** (leg du voyage, `trip.dateTime`, fuseau du voyage) | leg NO_LOCATION : visible **des organisateurs seulement**, avec la notice « Ajoutez un parcours à **cette étape** » |

Ce qui change selon que l'étape a un parcours ou non :

- **Avec parcours** :
  - la carte d'étape affiche km et D+ ;
  - elle porte une ligne météo si la prévision est OK, STALE ou NOT_YET ;
  - elle porte les liens GPX, FIT et « Envoyer vers l'appareil » ;
  - sa trace apparaît sur la carte et peut être colorée par le vent.
- **Sans parcours** :
  - la carte d'étape ne garde que le marqueur, le nom, la date, les lieux et la vitesse (si renseignée) ;
  - pas de ligne météo, faute de `summary` en NO_LOCATION ;
  - pas d'actions ;
  - sur la carte, l'item existe mais n'a pas de `routeSlug`, donc rien n'est dessiné. Si aucune étape n'a de parcours, la colonne carte reste présente et affiche « Aucun parcours disponible » (déduction de `TripDetailPage.tsx:79-83`, de `RoutesMapView.tsx:593-603` et de la condition `mapItems.length > 0` ; pas vérifié à l'écran).

Membre, non-membre, anonyme :

| Élément | Anonyme | Connecté non membre | Membre | Organisateur ou admin plateforme |
|---|---|---|---|---|
| « Rejoindre le voyage » | non | non | si publié, non terminé, pas inscrit | idem membre (un admin plateforme non membre : non) |
| « Quitter le voyage » | non | non | si inscrit | si inscrit |
| Modifier + menu de statut | non | non | non | oui |
| Menu ⋯ « Signaler » | **non** | oui | oui | oui (non vérifié pour `isOwn`) |
| Personnes inscrites | titre + compte | titre + compte | liste complète | liste complète |
| AccessAlerts | bleue « Connectez-vous… » | jaune « Rejoignez cette équipe… » | rien | rien (un admin plateforme non membre voit la jaune) |
| Commentaires | non | non | oui | oui (admin plateforme compris) |
| Notice météo NO_LOCATION | non | non | non | oui |

Le prefetch SSR des participants et des commentaires suit les mêmes règles.

Voyage à venir, en cours, terminé, et autres statuts :

- **À venir** (PUBLISHED, non terminé) :
  - « Rejoindre » est possible ;
  - le badge « Aujourd'hui » / « Demain » apparaît dans le bloc départ si le premier départ tombe ce jour-là ;
  - la météo est offerte (lignes, mode carte, section unique) ;
  - au-delà de 7 jours, « Météo disponible à partir du … ».
- **En cours**. Le serveur pose `finished = « sa dernière étape a commencé »` (`tripDto.ts`, champ `finished`). Le client ne calcule aucun état « en cours » ici : `isUnderWay`, qui existe dans `utils/publicationTiming.ts:31`, n'est pas utilisé par la page. Concrètement :
  - **Entre la première et la dernière étape** :
    - aucun badge spécial ;
    - « Rejoindre » reste proposé ;
    - le bloc départ montre la date passée de la première étape, sans badge ;
    - les cartes des étapes passées n'ont ni marque « passée » ni météo (leg OUT_OF_RANGE, donc pas de `summary`).
  - **Dès que la dernière étape a commencé** :
    - badge « Terminé » ;
    - plus de « Rejoindre » ;
    - plus de météo (`tripOffersWind` est faux) ;
    - et cela alors que la dernière étape est encore en train de rouler.
- **Terminé** :
  - badge gris « Terminé » à côté du badge « Publié » ;
  - pas de « Rejoindre », mais « Quitter » reste présent si inscrit ;
  - aucun bloc météo, et le mode Météo de la carte est indisponible ;
  - la carte, le profil, les étapes, les participants et les commentaires restent identiques.
- **Annulé** :
  - badge rouge « Annulé » (et éventuellement « Terminé » en plus) ;
  - pas de « Rejoindre », mais « Quitter » reste présent si inscrit ;
  - pas de météo ;
  - menu organisateur : « Restaurer le voyage ».
- **Brouillon** :
  - badge gris « Brouillon » ;
  - la ligne « Publication programmée pour le … » apparaît si `publishAt` ;
  - la météo est vide (« `stages` vide quand le voyage n'est pas publié », `tripWeatherDto.ts`), donc ni ligne météo, ni section, ni mode Météo ;
  - pas de « Rejoindre ».
  - Je n'ai pas vérifié qui peut ouvrir un brouillon côté backend.

---

## 4. Dates et heures

Repères utilisés :
- **Fuseau de l'évènement** : lu par `useRendezvousFormat(zone)` (`hooks/useRendezvousFormat.ts:32-72`). Si le navigateur ne connaît pas le fuseau ou qu'il manque, il retombe sur le fuseau du lecteur, sans mention.
- **Fuseau du lecteur** : lu par `useFormattedDate()` (`utils/dateFormat.ts:301-323`). C'est la préférence `timezone` de l'utilisateur, sinon celui du navigateur.
- Langue : FR (date-fns `fr`).
- Exemples calculés à partir d'aujourd'hui, mardi 10 novembre 2026.

| # | Emplacement | Champ source | Formatage (`fichier:ligne`) | Format produit (FR) | Fuseau | Cas particuliers |
|---|---|---|---|---|---|---|
| 1 | DayBox du bloc départ | `trip.dateTime` | `components/common/DayBox.tsx:72-85`, motifs `EEE` / `d` / `MMM` / `yyyy` | « sam. » / « 14 » / « nov. » (+ « 2027 » en 4ᵉ ligne hors année courante) | évènement (`trip.timezone`) ; repli lecteur | année affichée seulement si elle diffère de l'année courante, comparée dans le fuseau de l'évènement |
| 2 | « Départ HH:mm » | `trip.dateTime` | `DepartureBlock.tsx:56-58` → `formatTime` (`utils/dateFormat.ts:136-145`, motif `p`), clé `departure.block.time` | « Départ 09:00 » (EN « Departure 9:00 AM ») | évènement | `trip.dateTime` est le départ de la 1ʳᵉ étape selon le contrat (`timezone` = celui de la 1ʳᵉ étape) ; non vérifié côté backend |
| 3 | Badge relatif | `trip.dateTime` | `DepartureBlock.tsx:43,59-63` → `formatRelativeDay` (`dateFormat.ts:193-204`) | « Aujourd'hui » / « Demain » ; rien pour les autres jours, passés compris | évènement (aujourd'hui et demain jugés dans le fuseau du voyage) | — |
| 4 | Plage du voyage (`dayLine`) | `trip.dateTime` → `trip.endDateTime` | `utils/publicationTiming.ts:48-71` (`formatPublicationSpan`, mode `full`) ; `formatDepartureDay` `dateFormat.ts:241-258` ; motifs `dateFormats.weekdayDay` = `EEE d`, `departureDay` = `EEE d MMM`, `departureDayWithYear` = `EEE d MMM yyyy` | même jour : « sam. 14 nov. » ; même mois : « ven. 13 → dim. 15 nov. » ; mois différents : « ven. 27 nov. → mar. 1 déc. » ; fin hors année courante : « mer. 30 déc. → ven. 1 janv. 2027 » ; même mois d'une autre année : « ven. 14 → dim. 16 mai 2027 » | début dans `trip.timezone` ; fin dans le fuseau de la **dernière étape** (`tripEndZone`, `utils/rendezvous.ts:63-72`) ; repli lecteur | « → » écrit en dur, non traduit ; la fin est `endDateTime` (fin *estimée* de la dernière étape, départ + durée, ou +3 h), pas `endDate` : une étape qui finit après minuit pousse la plage au lendemain (déduction) ; même jour et même mois jugés sur les horloges de l'évènement ; année ajoutée par extrémité, hors année courante |
| 5 | Mention de fuseau après la plage | instant `trip.dateTime` | `DepartureBlock.tsx:44,70` → `ZoneMentionText` (`components/common/Rendezvous.tsx:70-78`) → `rendezvousMention` (`utils/rendezvous.ts:33-55`) | « · heure de Tokyo (ven. 01:00 chez vous) » ; jour court ajouté seulement si le jour du lecteur diffère | évènement comparé au lecteur ; rien si les décalages sont égaux à cet instant | absente au rendu SSR et à l'hydratation (fuseau du lecteur encore inconnu) ; une seule mention, calculée au départ, même si la fin est dans un autre fuseau |
| 6 | Publication programmée | `trip.publishAt` | `PublicationHeader.tsx:165-177` → `<Rendezvous format="dateTime" variant="detail">` → `formatDateTime` (`dateFormat.ts:109-115`, jamais relatif) ; clé `trips.detail.scheduledPublish` | « Publication programmée pour le sam. 14 nov. · 08:00 » (+ « · heure de … ») | évènement (`trip.timezone`) | seulement en DRAFT ; « le » + jour abrégé se lit un peu mal |
| 7 | Coin de la carte d'étape | `stage.dateTime` | `TripStageCard.tsx:52` → `DepartureLine withDay` (`DepartureLine.tsx:60-64`) → `formatDeparture` relatif (`dateFormat.ts:220-234`), clé `dateFormats.dayAndTime` « {{day}} · {{time}} » | « sam. 14 nov. · 09:00 », « Demain · 09:00 », « Aujourd'hui · 09:00 », « sam. 10 avr. 2027 · 09:00 » | **fuseau de l'étape** (`stage.timezone`, qui peut différer de celui du voyage) | icône globe et tooltip de mention (`ZoneMentionIcon`, `Rendezvous.tsx:84-110`) si le décalage diffère ; pas de date de fin ni d'heure d'arrivée par étape |
| 8 | Ligne météo de la carte, avant ouverture | `summary.availableFrom` | `RideWeatherSummaryLine.tsx:45-53` → `useFormattedDate().formatDate` (`dateFormat.ts:91-102`, motif `PPP`) | « Météo disponible à partir du 21 novembre 2026 » (année toujours affichée) | **lecteur** | — |
| 9 | Badge pluie de la carte | `summary.rainAlert.time` | `RideWeatherSummaryLine.tsx:98-114` → `useRendezvousFormat(summary.timezone ?? stage.timezone).formatTime` | « Averses dès 14:00 » | évènement (étape) | — |
| 10 | Mise à jour de la météo (section 4) | `leg.fetchedAt` | `components/weather/WeatherAttribution.tsx:24-33` (`useFormattedDate`) | « Mise à jour à 14:05 » si aujourd'hui, sinon « Mise à jour le 9 novembre 2026 à 14:05 » | lecteur (horodatage) | — |
| 11 | Notice « pas encore disponible » (section 4) | `leg.availableFrom` | `WeatherStatusNotice.tsx:46-55` (`useFormattedDate().formatDate`, `PPP`) | « La météo sera disponible à partir du 21 novembre 2026. » ; sans date : « …sept jours avant le départ de l'étape. » | lecteur | c'est pourtant une date liée au départ, d'où un fuseau incohérent avec #7 |
| 12 | Verdicts (section 4) | `checkpoints[].time`, `leg.arrivalTime`, `departure.sunrise` / `sunset`, alerte pluie | `components/weather/RouteVerdicts.tsx:43-230` (`useRendezvousFormat(timezone)`) | « Le plus chaud vers 15:00. », « Dès 14:00 (km 42), 60 %. », « Lever 07:58, coucher 17:12. », « Arrivée estimée 16:30. » | évènement (`onlyStage.timezone ?? trip.timezone`) | — |
| 13 | Tableau, bande, détail, tronçons (section 4) | `checkpoints[].time` | `RouteWeather.tsx:260,377,475,546,609,660,682,790,891` (`useRendezvousFormat(timezone).formatTime`) ; tronçons `phaseTimes` `:88-100` | « 09:00 », « 09:00–10:00 » | évènement | en EN, « 9:00 AM » coupé sur deux lignes dans l'en-tête du tableau (`:475`) |
| 14 | Météo au départ, repli sans prévision le long du parcours (section 4) | heure : `onlyStage.dateTime ?? trip.dateTime` ; lever et coucher : `departure.sunrise` / `sunset` | `DepartureWeather.tsx:53-55` (évènement) ; lever et coucher via `<FormattedTime>` `:85-96` (**lecteur**) | « 09:00 · 12 °C … », lever « 07:58 », coucher « 17:12 » | heure dans le fuseau de l'évènement, lever et coucher dans celui du lecteur | **incohérent** avec #12, qui lit lever et coucher dans le fuseau de l'évènement |
| 15 | Badges météo sur la carte (mode Météo) | `checkpoints[].time` par étape | `WeatherCheckpointMarkers.tsx:75,403,444` via `WeatherLegsMarkers` (fuseau de chaque étape, `tripWeatherOnMap.ts:55-76`) | heures « 14:00 », avec le jour du passage en contexte multi-jours (`useInContext`, non lu en détail) | évènement (chaque étape) | non vérifié visuellement |
| 16 | Commentaires | `comment.createdAt` | `CommentItem.tsx:59,95-98` → `formatRelative` (`dateFormat.ts:286-295`, `formatDistanceToNow`) | « il y a 2 heures », « il y a 3 jours » | aucun (durée relative) | jamais de date absolue, même pour un commentaire ancien |

Ce qui n'est **pas** affiché sur cette page :
- `trip.createdAt` et `trip.endDate` (la plage lit `endDateTime`) ;
- l'heure d'arrivée estimée d'une étape (sauf dans la section météo d'un voyage d'une étape) ;
- la date d'inscription des personnes ;
- `stage.stageIndex` / `stageCount` (« Jour 2 / 5 »).

---

## 5. Wireframes ASCII

### 5.1 Plusieurs étapes, desktop (≥ 1024 px), membre, à venir, avec prévision

```
 Équipes › Les Rouleurs › Agenda › Traversée des Vosges
┌────────────────────────────────────────────────────────────────────────────┐
│ (av) Les Rouleurs                                                       ›  │  1. TeamContextBanner
└────────────────────────────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────────────────────────────┐
│ [logo] Traversée des Vosges… [Publié]        [Rejoindre le voyage] [⇪] [⋯] │  2. PublicationHeader
│ ┌──────────────────────────────────────────────────────────────────────┐   │
│ │┌─────┐ Départ 09:00   (Demain)                                       │   │  2a. DepartureBlock
│ ││ ven.│ ven. 13 → dim. 15 nov.                                         │   │      (DayBox turquoise)
│ ││ 13  │                                                                │   │
│ ││ nov.│                                                                │   │
│ │└─────┘                                                                │   │
│ └──────────────────────────────────────────────────────────────────────┘   │
│ 3 étapes   12 personnes   245.3 km   D+ : 3120 m                           │  2b. FactsStrip
│ [#Bikepacking] [#Montagne]                                                 │  TagList
└────────────────────────────────────────────────────────────────────────────┘
┌──────────────── 380–440 px ───────┐ ┌──────────── carte sticky ─────────────┐
│┌─────────────────────────────────┐│ │ [+][-][⌖]                    [fond]   │
││ (texte markdown des consignes,  ││ │ [⛶][H]                               │
││  pièces jointes)                ││ │        ～～ étape 1 (bleu)            │  3.4 TripOverviewMap
│└─────────────────────────────────┘│ │   ●départ   ～～ étape 2 (vert)       │
│ 3.1 Consignes (sans titre)        │ │              ～～ étape 3 ■arrivée    │
│ Étapes                            │ │ ┌───────────────────┐   km 10  km 20 │
│┌─────────────────────────────────┐│ │ │ profil altimétr.  │                │
││(1) Colmar → Munster ›  ⏰ Demain ││ │ │ Distance/Elevation│        ─ 1 km  │
││                         · 09:00 ││ │ └───────────────────┘          ⓘ    │
││ 📍Colmar  📍Munster             ││ └───────────────────────────────────────┘
││ ⚡25 km/h ↔82.4 km ↑1240 m      ││  [ Étapes | Météo ]                        3.5 ColorByControl
││ ☁ 8 → 14 °C  💨↗ 15 km/h        ││  (en mode Météo : Vent sur le tracé :      3.6 WindMapLegend
││ ⬇GPX ⬇FIT 📱Envoyer vers l'app. ││   ▬Dos 32 km ▬Travers 18 km ▬Face 40 km)
│└─────────────────────────────────┘│
││(2) Munster → Gérardmer › ⏰ sam. ││  3.2 TripStageCard ×N
││                  14 nov. · 09:00││
││ … idem …                        ││
│└─────────────────────────────────┘│
││(3) … dim. 15 nov. · 09:00       ││
│└─────────────────────────────────┘│
│┌─────────────────────────────────┐│
││ Personnes inscrites  12 personnes││  3.3 ParticipantsSection
││ [🔍 Rechercher par nom…        ] ││
││ (av) Léa                       › ││
││ (av) Sam                       › ││
││        1–12 sur 12               ││
││        [‹ 1 ›]                   ││
│└─────────────────────────────────┘│
└───────────────────────────────────┘
   (pas de « Météo du parcours » pour un voyage de plusieurs étapes)
┌────────────────────────────────────────────────────────────────────────────┐
│ Commentaires (4)                                                           │  6. CommentSection
│ [Écrivez un commentaire...                                     ] [➤]       │
│ (av) Léa  il y a 2 heures                                         [⋯]      │
│      Texte…                                                                │
│      [Répondre] [Supprimer]                                                │
└────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Une étape (ou sans étape, avec parcours propre), desktop

```
 [fil d'Ariane]
 [1. TeamContextBanner]
┌──────────────────────────────────────────────────────────────────────────┐
│ [logo] Boucle du Ventoux [Publié]          [Quitter le voyage] [⇪] [⋯]   │ 2. PublicationHeader
│ ┌─────┐ Départ 08:30  (Aujourd'hui)                                     │ 2a. DepartureBlock
│ │mar. │ mar. 10 nov.          ← répète la DayBox (même jour)            │
│ │ 10  │                                                                 │
│ │nov. │                                                                 │
│ └─────┘                                                                 │
│ 1 étape   5 personnes   112.0 km   D+ : 2150 m                          │ 2b. FactsStrip
└──────────────────────────────────────────────────────────────────────────┘
┌──── colonne 380–440 ─────────┐ ┌──────── carte sticky ──────────────────┐
│ [3.1 Consignes]              │ │ 1 trace + profil altimétrique          │ 3.4
│ Étapes                       │ │ (+ [Étapes | Météo] si prévision)      │ 3.5/3.6
│ ┌──────────────────────────┐ │ └────────────────────────────────────────┘
│ │(1) Bédoin → … › ⏰ Aujour-│ │
│ │       d'hui · 08:30      │ │ 3.2 1 seule TripStageCard
│ │ ☀ 9 → 17 °C 💨 12 km/h   │ │ (ligne météo redondante avec la section 4)
│ │ ⬇GPX ⬇FIT                │ │
│ └──────────────────────────┘ │
│ [3.3 Personnes inscrites]    │
└──────────────────────────────┘
┌──────────────────────────────────────────────────────────────────────────┐ #meteo
│ Météo du parcours [Prévision ancienne?]   Prévisions X · Mise à jour 14:05│ 4. RouteWeatherSection
│ ┌Températures┐┌Pluie┐┌Vent┐┌Jour┐       ← 4 verdicts                     │
│ Heure par heure, à votre passage                                         │
│ Passages estimés à 25 km/h · un point tous les 5 km   Dos … Face …       │
│ ┌ tronçons │ 08:30 │ 09:00 │ 09:30 │ … (tableau défilant)                │
│ │ heure    │       │       │       │                                     │
│ │ temp/pluie/vent/rafales …                                              │
│ └──────────────────────────────────────────────────────────────          │
│ [détail du point sélectionné : Température · Pluie · Vent · Tronçon]     │
└──────────────────────────────────────────────────────────────────────────┘
 [5. AccessAlerts — rien pour un membre]
 [6. Commentaires]
```

Pour un voyage **sans étape avec `routeSlug`** : même disposition, mais la liste « Étapes » affiche « Aucune étape définie pour ce voyage. », la FactsStrip n'a pas de compte d'étapes et la section 4 est lue dans `trip.timezone`.

### 5.3 Étroit (< 1024 px), toutes variantes

```
 Agenda › Traversée des Vosges          (2 niveaux sous sm)
 [1. TeamContextBanner]
┌──────────────────────────────────────┐
│ [logo] Traversée des V… [Publié]     │ 2. PublicationHeader
│ [Rejoindre le voyage] [⇪] [⋯]        │ (boutons passés à la ligne)
│ ┌────┐ Départ 09:00 (Demain)         │ 2a.
│ │DayB│ ven. 13 → dim. 15 nov.        │
│ └────┘                               │
│ 3 étapes  12 personnes               │ 2b. (passe à la ligne)
│ 245.3 km  D+ : 3120 m                │
│ [tags]                               │
└──────────────────────────────────────┘
┌──────────────────────────────────────┐
│ CARTE (non sticky, 300–560 px)       │ 3.4 — avant la colonne
│ ┌──────────────────────────┐         │
│ │ profil (pleine largeur-40)│        │
│ └──────────────────────────┘         │
└──────────────────────────────────────┘
 [ Étapes | Météo ] + légende           3.5/3.6
 [3.1 Consignes]
 Étapes                                 3.2
 [carte étape 1] [carte étape 2] …
 [3.3 Personnes inscrites]
 [4. Météo du parcours — 1 étape seulement ;
     < 48em : bande + curseur, détail, « Par tronçon »]
 [5. AccessAlerts]
 [6. Commentaires]
```

### 5.4 Anonyme ou non-membre (n'importe quelle largeur)

```
 [Banner] [Header : badges, Partager ; (⋯ seulement si connecté) ; pas de Rejoindre]
 [Consignes] [Étapes] [Personnes inscrites : titre + « 12 personnes », sans liste] | [Carte]
 [Météo du parcours si 1 étape]
 ┌ Alert bleue (anonyme) « Connectez-vous et rejoignez cette équipe pour participer aux voyages. Se connecter »
 └ ou jaune (non-membre) « Rejoignez cette équipe pour participer aux voyages. Voir l'équipe »
 (pas de commentaires)
```

---

## 6. Étonnements

1. **« Terminé » arrive trop tôt.** `finished` = « la dernière étape a commencé ». Le jour de la dernière étape, le voyage est donc marqué « Terminé », perd « Rejoindre » et toute sa météo, alors que l'étape roule encore. La page n'a pas non plus d'état « En cours », bien que `isUnderWay` (`utils/publicationTiming.ts:31`) existe.
2. **La colonne carte est vide si aucune étape n'a de parcours.** `mapItems` reprend toutes les étapes, même sans `routeSlug` (`TripDetailPage.tsx:79-83`). Le layout réserve donc la colonne carte, qui n'affiche que « Aucun parcours disponible ». Seul un voyage sans étape ni parcours obtient `--no-map`. C'est une déduction de lecture, non vérifiée à l'écran.
3. **Voyage avec `routeSlug` et des étapes.** La carte ne dessine que le parcours du voyage, pas ceux des étapes (`TripDetailPage.tsx:76-78`). Les cartes d'étape montrent pourtant km, D+ et GPX de *leurs* parcours, et le survol d'une carte n'allume rien. Avec exactement une étape, la section 4 détaille le leg de **l'étape** (son parcours), sous une carte qui montre le parcours **du voyage**.
4. **Doublons pour un voyage d'une étape.**
   - La date est affichée trois fois : DayBox, `dayLine` (« mar. 10 nov. ») et coin de la carte d'étape (« Aujourd'hui · 08:30 »).
   - La règle « la DayBox dit déjà le jour » (commentaire `DepartureBlock.tsx:46-47`) n'est pas tenue quand la plage tient en un jour.
   - La météo apparaît deux fois : ligne résumée sur la carte d'étape et section 4 complète.
   - Le titre « Étapes » coiffe une liste d'une seule carte.
5. **Des bornes « inversées » dans les chiffres.**
   - `tripFacts` lit `trip.stageCount`, alors que le reste de la page lit `trip.stages.length`. La carte numérote avec `index + 1` au lieu de `stage.stageIndex`.
   - La FactsStrip affiche « 0 personne » sans condition, alors que la section participants n'apparaît qu'au-delà de 0.
6. **Chiffres sans mise en forme locale.**
   - `formatDistance` utilise `toFixed(1)`, d'où « 245.3 km » avec un point au lieu d'une virgule, et toujours une décimale (« 112.0 km »).
   - `formatElevation` donne « 3120 m » sans espace des milliers.
   - D+ est préfixé « D+ : » dans la FactsStrip, mais pas sur les cartes (icône flèche à la place).
7. **Axes du profil altimétrique en anglais en dur** : « Distance (km) » et « Elevation (m) » (`RoutesMapView.tsx:537,555`), ainsi que le libellé du dataset « Elevation ».
8. **Fuseaux incohérents dans la météo.**
   - Lever et coucher sont lus dans le fuseau de l'évènement dans les verdicts (`RouteVerdicts.tsx:225-228`), mais dans celui du lecteur dans `DepartureWeather` (`<FormattedTime>`, `DepartureWeather.tsx:89,94`).
   - « Météo disponible à partir du … » est lu dans le fuseau du lecteur, avec le format long « 21 novembre 2026 » (année toujours présente). C'est un format différent du format unique « sam. 14 nov. » utilisé partout ailleurs.
9. **Formulations.**
   - La plage utilise une flèche « → » écrite en dur, non traduite (`publicationTiming.ts:71`).
   - « Publication programmée pour le sam. 14 nov. · 08:00 » combine « le » avec un jour abrégé et un point médian.
   - Pour un voyage sans étape ni parcours, l'organisateur lit « Ajoutez un parcours à **cette étape** » (sujet « stage » imposé, `TripDetailPage.tsx:243`).
10. **Badge « Publié » toujours visible**, même pour un lecteur pour qui un voyage est forcément publié. Il s'ajoute à « Terminé » et forme deux badges.
11. **« Quitter le voyage » reste proposé sur un voyage terminé ou annulé** (`TripDetailPage.tsx:153`, sans condition sur `finished` ou `status`). Le commentaire en `:123-124` le présente comme voulu (« Leaving stays open »).
12. **Admin plateforme non membre.** Il peut modifier, modérer et lire les commentaires et les noms, mais il voit l'alerte jaune « Rejoignez cette équipe pour participer… » et pas de bouton « Rejoindre ». C'est voulu (API-137), mais c'est contradictoire à l'écran.
13. **Lignes de participants décorées d'un chevron** (`ParticipantList.tsx:160-165`) alors qu'elles ne sont pas cliquables (`cursor: default`).
14. **Hauteur `--solo` pour plusieurs traces.** La carte d'un voyage porte toujours la classe `detail-map--solo` (130 px réservés sous la carte), même sans prévision, alors qu'aucun sélecteur ni aucune légende ne s'y affiche dans ce cas. Il reste alors un espace vide sous la carte sticky (déduction CSS).
15. **Titre tronqué sur une ligne** (`PublicationHeader.tsx:69-74`, `nowrap` + ellipse). Un nom de voyage long est coupé sur mobile, sans tooltip.
16. **Pas de lieu dans le bloc départ.** Le départ et l'arrivée de la première étape ne sont visibles que dans la carte d'étape (épingles vertes et rouges), alors que `DepartureBlock` sait afficher un `place`, ce qu'il fait pour une sortie.
