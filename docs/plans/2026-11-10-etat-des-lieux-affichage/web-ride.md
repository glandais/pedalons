# Web — page de détail d'une sortie (RideDetailPage) : état des lieux

Lecture seule du code, worktree `feat/mobile-review` au 2026-11-10. Chemins relatifs à `frontend/src/`.
Rien n'a été exécuté : pas de build, pas de test, pas de navigateur. Tout ce qui suit vient de la lecture du code.

---

## 1. Points d'entrée

**Route**
- id `ride-detail` (`config/routes.config.ts:749-758`), `auth: 'public'`, `parentId: 'team-agenda'`, fil d'Ariane dynamique `entity: 'ride'`, `meta: rideMeta` (aperçus de lien).
- Chemins : `contracts/routes.yaml:534-540`. FR `/equipes/{teamSlug}/sorties/{rideSlug}`, EN `/teams/{teamSlug}/rides/{rideSlug}`.
- Routes voisines :
  - `rideGroup` `/…/sorties/{rideSlug}/groupes/{groupId}`, page `RideGroupPage`, hors périmètre. On y arrive par le lien étiré de chaque `RideGroupCard` (`components/ride/RideGroupCard.tsx:113`). Elle n'existe que pour une sortie à 2 groupes ou plus : `rideGroupDataRedirect` (`pages/ride/rideGroupData.ts:131-142`) renvoie vers la page de la sortie quand il y a 0 ou 1 groupe (`leavesGroupPage`, `utils/soloGroup.ts:23-25`).
  - `rideMap` `/…/sorties/{rideSlug}/carte` : carte plein écran, réservée à la sortie solo (`rideMapDataRedirect`, `pages/ride/rideDetailData.ts:221-231`).
  - `rideGroupMap` `/…/groupes/{groupId}/carte`.

**Fichier de page** : `pages/ride/RideDetailPage.tsx` (430 lignes).
- Elle n'est pas montée dans `TeamLayout`. Le `Layout` global affiche au-dessus d'elle le fil d'Ariane (`components/common/Layout.tsx:360`). Ce fil a une version compacte sous `sm` (`components/common/Breadcrumb.tsx:99-106`). Son contenu exact n'a pas été vérifié.

**Données** (`pages/ride/rideDetailData.ts`, `useRideDetailData`, l.99-135)

| Requête | Hook | DTO |
|---|---|---|
| Équipe | `useGetTeam(teamSlug)` | `TeamDto` (nom, slug, about, droits via `teamAccess`) |
| Sortie | `useGetRide(teamSlug, rideSlug)` | `RideDto` |
| Météo | `useGetRideWeather(teamSlug, rideSlug, {skipErrorToast})` | `RideWeatherDto` (`status`, `availableFrom`, `fetchedAt`, `attribution`, `departure`, `legs[]`) |
| Parcours | `useRoutesBulk(teamSlug, {slug: rideRouteSlugs(ride)})` | `RouteDetailDto[]`, regroupés en `routesBySlug`. Clé : route de la sortie + routes des groupes, sans doublon, triées |

Dérivés calculés par le même hook :
- `soloGroup` : le groupe unique quand `groups.length === 1` (`utils/soloGroup.ts:11-14`).
- `soloLeg` : `ownLeg(ride, weather)` (`utils/soloGroup.ts:33-42`). C'est le tronçon du groupe solo, ou le tronçon unique sans `groupId` d'une sortie sans groupe. Pour une sortie à plusieurs groupes, `ownLeg` renvoie `undefined`.

Lus par des enfants de la page :
- `useRideGroupMembership` (rejoindre / quitter).
- `GET …/participants` (`ParticipantList`).
- Commentaires (`CommentSection`).
- Services GPS (`useGpsConnections`, menu « Envoyer vers l'appareil »).

SSR : `prefetchRideDetail` (l.150-191) précharge équipe + sortie + météo, puis commentaires, parcours, services GPS et la 1re page des participants. Les participants sont ceux du groupe pour une sortie solo, ceux de toute la sortie sinon.

**Champs `RideDto` lus par la page** : `name`, `media` (logo, markdown, pièces jointes), `status`, `finished`, `timezone`, `dateTime`, `publishAt`, `tags`, `team`, `startPlace`, `endPlace`, `participantCount`, `distance`, `elevationGain`, `routeSlug`, `groups[]`, `registered`, `registeredGroupId`, `registeredGroup`.

**Champs `RideGroupDto` lus** : `id`, `name`, `startAt`, `routeSlug`, `averageSpeed`, `maxParticipants`, `countParticipants`, `participants` (aperçu), `registered`, `full`, `distance`, `elevationGain`, `leader`.

**Jamais affichés** : `RideDto.endDateTime`, `createdAt`, `groupSummaries`, `weather` (résumé de liste), `surfaceType`, `excerpt`. `RideGroupDto.time` est déprécié et volontairement ignoré. Un groupe n'a pas de lieu propre : le seul lieu de rendez-vous est `ride.startPlace`.

**Droits** (`RideDetailPage.tsx:145-155`)
- `isMember` et `canEdit` (= `isOrganizer`) viennent de `teamAccess(team, isPlatformAdmin)`.
- `canReadComments = isMember || isPlatformAdmin`. Cette même valeur sert de `canSeeParticipants`.
- `isPast = ride.finished`. Selon la doc du DTO, ce champ est calculé par le serveur et vaut vrai dès que l'heure de départ est passée.
- `canJoinRide = isMember && status === PUBLISHED && !ride.registered && !isPast`.

---

## 2. Disposition

### Structure générale (desktop ≥ 64em)

`Container size="xl" py="xl"` (`RideDetailPage.tsx:177`), de haut en bas :

1. Bandeau d'équipe, pleine largeur
2. En-tête (`PublicationHeader`), pleine largeur, qui contient le bloc Départ, les lieux et les faits
3. Grille `.detail-layout` (`index.css:267-317`) :
   - colonne gauche `.detail-side`, 380 à 440 px : consignes, groupes, participants, puis « Météo au départ » (sauf sortie solo) ;
   - colonne droite `.detail-map`, en `position: sticky`, sous le header de l'app + `md` (`index.css:256-262`), hauteur = hauteur visible (`--detail-map-height`, au moins 420 px). Pour la sortie solo : hauteur visible − 130 px, au moins 360 px, `max-height` = hauteur visible et `overflow-y: auto` (`index.css:312-316`).
   - Sans carte, `detail-layout--no-map` : une seule colonne pleine largeur.
4. Sortie solo seulement : « Météo du parcours », pleine largeur (`RideDetailPage.tsx:383-403`).
5. Alertes d'accès (`AccessAlerts`)
6. Commentaires (membres et admins plateforme)

**Breakpoints.** Le seuil de la grille est `64em` (1024 px), codé en dur dans `index.css`. Il ne correspond pas au `md` Mantine : aucun override de `breakpoints` n'a été trouvé, donc Mantine garde ses valeurs par défaut, sm = 48em et md = 62em. Les commentaires du code parlent pourtant de « md+ ».

**Viewport étroit (< 64em).** Une seule colonne avec `grid-template-areas: 'map' 'side'` : la carte passe au-dessus de la colonne, alors qu'elle la suit dans le DOM. Elle n'est plus sticky.
- Hauteur de la carte : `clamp(300px, 52svh, 560px)` (`hooks/useResponsive.ts:97`).
- Profil altimétrique en surimpression dans `RoutesMapView` : 120 px sous sm, 140 en sm, 150 en md (`RoutesMapView.tsx:755-762`).

Ajustements internes, sans changement d'ordre :
- Bloc Départ : container query à 600 px. La colonne « Votre groupe » passe sous le reste (`DepartureBlock.module.css:34-46`).
- `StatsCard` : container query, 4 colonnes à partir de 560 px, 2 en dessous (`StatsCard.tsx:76`).
- `RouteWeather` : tableau « Heure par heure » à partir de sm (`visibleFrom="sm"`), bande + curseur + liste « Par tronçon » en dessous (`RouteWeather.tsx:194-232`).
- Verdicts météo : 2 colonnes, 4 à partir de md (`RouteVerdicts.tsx:239`).

Aucun onglet sur cette page.

### Détail bloc par bloc (ordre réel du DOM)

**B0. Fil d'Ariane** — `components/common/Layout.tsx:360`, global, hors page. Non détaillé.

**B1. Bandeau d'équipe** — `components/team/TeamContextBanner.tsx:28-50`, appelé en `RideDetailPage.tsx:179`
- Condition : toujours.
- Contenu : `Paper withBorder` cliquable vers `paths.team()`. Avatar de l'équipe (`TeamAvatar` sm), nom (1 ligne), chevron droit `IconChevronRight`.
- aria-label « Voir la page de l'équipe {nom} ».

**B2. En-tête de publication** — `components/publication/PublicationHeader.tsx:64-180`, appelé en `RideDetailPage.tsx:181-202`. `Paper shadow="xs" p="lg" withBorder component="header"`.

- **Ligne titre (gauche)**, l.67-83 :
  - `EntityLogo` (logo de la sortie, size lg, rien sans logo) ;
  - `Title order=2`, nom sur une ligne avec ellipse ;
  - badge de statut, toujours affiché, PUBLISHED compris : « Publié » / « Brouillon » / « Annulé ». Couleur `STATUS_COLORS` ;
  - badge gris « Terminée » si `ride.finished`.
- **Ligne titre (droite)**, l.85-154 :
  - `canEdit` seulement : `Button.Group` avec « Modifier » (`IconPencil`, lien vers `rideEdit`) et un menu chevron (aria « Options de gestion »). Entrées du menu selon le statut :
    - DRAFT : « Publier » ;
    - PUBLISHED : « Dépublier », « Annuler la sortie » ;
    - CANCELLED : « Restaurer la sortie » ;
    - `deleted` : « Restaurer » ;
    - toujours, sous un séparateur : « Supprimer ».
    - Confirmations par `ConfirmDialog` (`statusActions.dialogs`, l.427).
  - `ShareButton` : ActionIcon `IconShare`, aria « Partager ».
  - `ContentActionsMenu` : menu « Plus d'actions », signaler / bloquer. Masqué pour un anonyme (`moderation/ContentActionsMenu.tsx:62`).
  - Pas de bouton Rejoindre dans l'en-tête d'une sortie : `joinActions` n'est pas passé.
- **children**, l.163, `Stack gap="sm"` (`RideDetailPage.tsx:191-201`) :
  - **B2a. Bloc Départ** — `components/common/DepartureBlock.tsx:33-118`. Section aria « Date et heure de départ ». Surface grise bordée.
    - À gauche, `DayBox` lg (`components/common/DayBox.tsx:30-88`), ton indigo, 3 lignes : « sam. » / « 12 » / « avr. ». Une 4e ligne donne l'année quand elle n'est pas l'année courante.
    - Au centre, « Départ 09:00 » (24 px, 700) et une pastille « Aujourd'hui » / « Demain » si c'est le cas.
    - Ligne dimmed avec la mention de fuseau, seulement si l'offset diffère : « heure de Tokyo (ven. 01:00 chez vous) ».
    - Lieu de départ : épingle verte `IconMapPin` (aria « Lieu de départ »), **nom** en gras et « (adresse) » en dimmed. Seulement si `ride.startPlace`.
    - À droite, seulement si le lecteur est inscrit dans un groupe dont `startAt ≠ ride.dateTime` : « Votre groupe » en dimmed, puis « Groupe B · 09:30 » en 700 (`RideDetailPage.tsx:167-171`, `departure.block.group`).
  - **B2b. Lieu d'arrivée** — `components/publication/PlacesLine.tsx:21-56`, avec `end` seulement. Épingle rouge, « Arrivée : » en rouge, nom, « (adresse) » en dimmed. Rien sans `ride.endPlace`.
  - **B2c. Bandeau de faits** — `components/publication/FactsStrip.tsx:18-72`, alimenté par `rideFacts()` (`publicationFacts.ts:28-38`). Une `Group` de textes dimmed, sans icônes :
    - « 3 groupes », seulement si au moins 1 groupe ;
    - « 12 personnes » (`participantCount`), toujours ;
    - distance : « 62 à 92 km » si les groupes diffèrent, « 85 km » si une seule valeur. À défaut de groupe porteur, `ride.distance` ;
    - dénivelé : « D+ : 700 à 1 350 m » ou « D+ : 900 m ».
- **Publication programmée**, l.165-177 : seulement si `status === DRAFT && publishAt`. `IconCalendar` jaune et « Publication programmée pour le sam. 12 avr. · 09:00 », suivi de la mention de fuseau en ligne.
- **Tags**, l.179 : `TagList`, tous les tags de la sortie.

**B3. Consignes** — `components/publication/InstructionsBlock.tsx:22-36`, appelé en `RideDetailPage.tsx:212`
- Condition : markdown non vide, ou au moins une pièce jointe. Une image seule ne suffit pas.
- Contenu : `Paper withBorder p="lg"` en section aria « Consignes », sans titre visible. `MediaDisplay` affiche le texte riche, les images référencées et les pièces jointes.

**B4. Groupes**, conteneur `data-testid="ride-groups"` (`RideDetailPage.tsx:215-311`). Le contenu dépend de la variante, voir §3. Composants possibles :
- **B4-solo. Panneau du groupe solo** — `components/ride/RideSoloGroupPanel.tsx:39-112`. `Paper withBorder p="md"`, bord et halo indigo si le lecteur est inscrit. Le panneau n'est pas un lien.
  - Petit libellé capitales « GROUPE ».
  - Barre de couleur 4×20 px, seulement si la carte est multi-tracés (`trackColor`).
  - Nom du groupe (`Title order=3 size=h4`, 1 ligne) et badge « J'y vais » si inscrit.
  - À droite, `GroupJoinActions` (`group/GroupJoinActions.tsx`) selon `groupAction` (`rideGroupData.ts:186-192`) : bouton « Rejoindre », bouton outline « Quitter », ou badge gris « Complet » (`showFull`).
  - `GroupPlaces` (`group/GroupPlaces.tsx`) :
    - sans maximum : « 8 personnes » en dimmed ;
    - avec maximum : « 11/12 personnes » et « 1 place restante » (ou « Aucune place restante »), plus une barre `Progress`, grise quand c'est plein.
  - `GroupLeader framed=false` (`group/GroupLeader.tsx`), seulement si `group.leader` : avatar sm, nom, badge « Capitaine » avec `IconShieldCheck`.
  - `RideGroupRouteActions` (`ride/RideGroupRouteActions.tsx`), si le groupe ou la sortie a une route :
    - « Voir le parcours » (`IconMap`) ;
    - « GPX » et « FIT » (`IconDownload`), si l'asset existe ;
    - « Envoyer vers l'appareil » (`IconDeviceMobile`, menu des services GPS connectés), si l'utilisateur est connecté et a un service.
  - Alerte rouge si l'inscription a échoué.
- **B4-solo-stats. Chiffres** — `group/GroupStats.tsx` → `publication/StatsCard.tsx:59-120`. `Paper p="lg"`, jusqu'à 4 tuiles (libellé capitales et icône, puis valeur en 700 lg) :
  - « DÉPART » (`IconClock`) : `group.startAt` en heure seule, globe de fuseau en infobulle. `showDeparture` vaut true par défaut ici ;
  - « ALLURE MOYENNE » (`IconBolt`) si `averageSpeed > 0`. Sous la valeur : « Arrivée estimée 12:15 » quand le tronçon a une prévision ;
  - « DISTANCE » (`IconArrowsMaximize`) ;
  - « DÉNIVELÉ POSITIF » (`IconArrowUp`).
- **B4-titre**, cas non solo : `Title order=3 size=h4` « Groupes » (l.244-246).
- **B4-cartes. Carte de groupe** — `components/ride/RideGroupCard.tsx:111-247` sur `components/publication/ChildCard.tsx:47-127`.
  - Rendu : `Paper withBorder p="md"`. Le lien étiré vers la page du groupe couvre toute la carte.
  - Survol : bord et fond indigo. Il allume aussi la trace sur la carte et les autres cartes du même parcours.
  - Carte du lecteur inscrit : bord et halo indigo.
  - Ligne 1 : barre de couleur de la trace, nom en 600 avec `IconChevronRight`, badge « J'y vais » si inscrit. Coin droit :
    - « Quitter » (outline xs) si inscrit ;
    - sinon « Rejoindre » (xs) si `canJoinRide && !full` ;
    - sinon « Complet » (badge gris) si `canJoinRide && full` ;
    - sinon rien.
  - Sous le nom :
    - encart d'heure propre (variante d uniquement) : fond indigo-0, `DepartureLine` avec horloge indigo et « Départ 09:30 » en 700, globe de fuseau en infobulle si nécessaire ;
    - capitaine, si `group.leader` : avatar sm, nom, badge « Capitaine ».
  - Ligne de méta (`ChildFacts`) : `IconBolt` allure (« 25 km/h »), `IconArrowsMaximize` distance, `IconArrowUp` D+. Le D+ n'est affiché que si la distance est connue.
  - Personnes, selon `canSeeParticipants` :
    - membre ou admin : bouton avec jusqu'à 5 avatars, `IconUsers`, « 8 personnes » ou « 8/12 personnes », et « Voir tout » si plus de 5. Il ouvre `ParticipantListModal` ;
    - sinon : `IconUsers` et le compte seul.
  - Ligne météo `GroupWeatherLine` (`components/weather/GroupWeatherLine.tsx:29-95`), seulement si le tronçon du groupe a une prévision (OK ou STALE) :
    - icône du ciel et « 14 °C · Partiellement nuageux » au premier point du tronçon ;
    - badge bleu `IconUmbrella` « Pluie 40 % vers 10:30 » si alerte pluie ;
    - badges « Face 12 km » et « Dos 30 km » si l'exposition est positive.
  - Actions de parcours : comme sur le panneau solo, sans « Voir le parcours » (`withViewLink=false`).
  - Alerte rouge si erreur.
- **B4-séparateur** : `Divider` « Autres groupes » après la 1re carte, quand le lecteur est inscrit dans un groupe. Ce groupe est remonté en tête (`groupsRegisteredFirst`, `rideGroupData.ts:195-201`).
- **B4-vide** : `EmptyState` avec `IconUsersGroup`, « Aucun groupe » / « Aucun groupe défini pour cette sortie. », seulement si `groups` est vide.

**B5. Personnes inscrites** — `components/ride/group/GroupParticipantsSection.tsx` → `components/publication/ParticipantsSection.tsx:30-76`
- Condition : sortie solo (liste du groupe) ou au moins 1 groupe (liste de toute la sortie). Absent sans groupe.
- Contenu : `Paper p="lg"`, section. Titre « Personnes inscrites » et, à droite, « 12 personnes » en dimmed.
- Membre ou admin seulement, `ParticipantList` (`components/ride/ParticipantList.tsx:46-186`) :
  - champ « Rechercher par nom… » si le compte est supérieur à 0 ;
  - lignes : avatar md (pastille bouclier si capitaine), nom en 600, « Capitaine » en dimmed, chevron décoratif ;
  - « 1–20 sur 45 » et pagination. Recherche et page passent dans l'URL `?q=` / `?p=` ;
  - liste vide : `IconUsers` et « Aucune inscription pour le moment. ».
- Non-membre : titre et compte seulement.

**B6. Météo au départ** — `components/weather/RideWeatherSection.tsx:38-97`, ancre `#meteo` (`RideDetailPage.tsx:315-328`)
- Condition : sortie non solo, ni `finished`, ni CANCELLED, chargement terminé, et `showsDetailBlock` (`weatherDisplay.ts:106-118`). Les statuts affichés sont OK, STALE, NOT_YET_AVAILABLE, UNAVAILABLE (y compris pas de données) et NO_LOCATION pour un organisateur seulement.
- En-tête du `Paper p="lg"` : titre « Météo au départ » et badge jaune « Prévision ancienne » (`IconHistory`) si STALE.
- `WeatherStatusNotice` (`weather/WeatherStatusNotice.tsx`) :
  - NOT_YET_AVAILABLE : `IconCalendarTime` et « La météo sera disponible à partir du 15 novembre 2026. ». Sans date : « … sept jours avant le départ. » ;
  - UNAVAILABLE : `IconCloudOff`, « La météo n'est pas disponible pour le moment. » et un bouton « Réessayer » ;
  - NO_LOCATION : `IconMapPinOff` et « Ajoutez un lieu de départ ou un parcours pour afficher la météo de la sortie. ».
- `DepartureWeather` (`weather/DepartureWeather.tsx:27-101`), si OK ou STALE :
  - grande icône 44 px, libellé « AU DÉPART » ;
  - en xl/700 : « 09:00 · 14 °C », puis « Partiellement nuageux » et « ressenti 12 °C » en dimmed ;
  - stats : `IconDroplet` « Pluie 30 % » ou « Pluie 30 % · 0,4 mm » ; `IconWind` avec une flèche de provenance et « 15 km/h, rafales 30 » (libellé exact de `speedWithGusts` non vérifié) ; `IconSunrise` heure ; `IconSunset` heure.
- Sans groupe seulement (variante a) : un `Divider`, puis `LegWeather` (`weather/LegWeather.tsx:15-87`) :
  - « Départ 09:00 → arrivée vers 12:15 · 85 km » ;
  - « Heures de passage estimées à 25 km/h », avec la variante « vitesse par défaut » ;
  - « Vent dominant : ↗ … » ;
  - bandeau pluie (`WeatherRainBanner`) : vert « Pas de pluie attendue sur le parcours », ou bleu « Averses probables (40 %) vers 10:30, à 32 km » ;
  - bande horizontale de points (`WeatherCheckpointStrip`) : lieu (« Départ » / « 32 km » / « Arrivée · 85 km »), heure, icône, température, pluie, vent ;
  - barre « Exposition au vent » (`WindExposureBar`).
- Pied, `WeatherAttribution` (`weather/WeatherAttribution.tsx`) : « Prévisions » suivi du lien vers le fournisseur. À droite, « Mise à jour à 08:12 » ou « Mise à jour le 9 novembre 2026 à 18:40 ».

**B7. Carte** — colonne droite (`RideDetailPage.tsx:333-377`)
- Condition : `hasMap = !!soloRouteSlug || mapItems.length > 0`, c'est-à-dire au moins une route sur la sortie ou sur un groupe.
- **Variante multi-tracés**, `RoutesMapView variant="sticky"` (`components/route/RoutesMapView.tsx`) :
  - une trace par route distincte (`rideMapRoutes`, `pages/ride/rideMapRoutes.ts:29-57`). Une trace est nommée d'après ses groupes séparés par « · », ou « Parcours principal » si aucun groupe ne la roule ;
  - couleurs numérotées par ordre d'apparition ;
  - contrôles : masquer les tracés (`HideTrackControl`), plein écran MapLibre (top-left), cases à cocher par trace dans le panneau des fonds de carte (`onTraceToggle`) ;
  - marqueurs départ / arrivée, flèches de sens ;
  - bornes km seulement s'il n'y a qu'une trace (`kmMarkers={mapItems.length === 1}`) ;
  - **profil altimétrique** en surimpression en bas à gauche (Chart.js), pour la trace allumée ;
  - clic sur une trace : sélection, sans navigation ;
  - pas de mode Météo ici (`winds` n'est pas passé).
- **Variante solo à route unique**, `RouteMapPanel heightVariant="sticky" withActions={false}` (`components/route/RouteMapPanel.tsx:45-162`) :
  - `RouteMapView` avec profil en surimpression et bouton « Carte plein écran » vers `paths.rideMap(…)?color=` ;
  - « Profil d'altitude provisoire » si l'élévation est PENDING ;
  - `ColorModeControls` : segmenté « Pente / Revêtement / Météo ». Météo n'est proposé qu'avec une prévision de vent, sur une sortie ni terminée ni annulée (`groupWindLeg`, `rideGroupData.ts:115-122`). En mode Météo s'ajoutent la légende du vent et les badges aux points de prévision, avec popups ;
  - `RouteSurfaceSummary` (affichage non vérifié en détail) ;
  - `RouteWaypointList` ;
  - le point sélectionné est partagé avec « Heure par heure » (`useWeatherFocus`).

**B8. Météo du parcours** — sortie solo seulement, pleine largeur sous la grille, ancre `#meteo` (`RideDetailPage.tsx:383-403`). Chaîne : `weather/GroupWeatherSection.tsx` → `weather/RouteWeatherSection.tsx:50-129`.
- Condition : `offered` (ni terminée ni annulée), puis les mêmes statuts que B6.
- En-tête : titre « Météo du parcours » et badge « Prévision ancienne » à gauche. L'attribution et la mise à jour sont à droite, dans l'en-tête et non en pied, contrairement à B6.
- Puis le même `WeatherStatusNotice`.
- Avec une prévision de tronçon, `RouteWeather` (`weather/RouteWeather.tsx:126-235`) :
  - 4 verdicts (`RouteVerdicts`) :
    - « Températures » : « 9 → 17 », « 9 °C au départ, ressenti 7 °C. Le plus chaud vers 14:10. » ;
    - « Pluie » : « Dès 10:30 (32 km), 40 %. », « Sec », etc. ;
    - « Vent » ;
    - « Jour » : « 2 h de marge », « Lever 07:45, coucher 17:20. Arrivée estimée 12:15. ».
  - « Heure par heure, à votre passage » : « Passages estimés à 25 km/h · un point tous les 10 km ».
  - Totaux vent (sm et plus) et tableau desktop : lignes Tronçons, Heure, Température, Pluie, Vent, Rafales.
  - Sous sm : bande avec curseur.
  - Panneau détail du point sélectionné.
  - Sous sm : liste « Par tronçon » repliable.
- Sans prévision de tronçon : `DepartureWeather` et « Les prévisions le long du parcours ne sont pas encore disponibles. ». Si le groupe n'a pas de parcours : « Ce groupe n'a pas de parcours : la météo n'est connue qu'au départ. ».

**B9. Alertes d'accès** — `components/publication/AccessAlerts.tsx:19-49` (`RideDetailPage.tsx:405-412`)
- Anonyme : alerte bleue « Connectez-vous et rejoignez cette équipe pour participer aux sorties. » avec le lien « Se connecter », qui revient sur la page après connexion.
- Connecté non membre : alerte jaune « Rejoignez cette équipe pour participer aux sorties. » avec « Voir l'équipe ».
- Membre : rien.
- Le bloc est placé après la météo et les groupes, donc loin sous le bouton Rejoindre absent.

**B10. Commentaires** — `components/comment/CommentSection.tsx:76-130` (`RideDetailPage.tsx:415-425`)
- Condition : `isMember || isPlatformAdmin`.
- Titre « Commentaires (3) », formulaire « Écrivez un commentaire... ».
- Chaque élément : avatar, nom, date relative, menu de modération, texte, « Répondre », « Supprimer » (auteur ou organisateur), « Voir N réponses ».
- Liste vide : « Aucun commentaire ». Bouton « Charger plus de commentaires ».

---

## 3. Variantes

Ce qui distingue les variantes, d'après le code :
- `solo = soloGroup(ride)`, vrai quand `groups.length === 1` ;
- `showStartTime = someGroupLeavesAtOwnTime(groups, ride.dateTime)` (`utils/groupStart.ts:24-29`), qui compare des instants et non des chaînes ;
- `ownTimeGroup` : bloc Départ.

### a) Sortie sans groupe

Le cas existe dans le code et il est géré :
- le backend accepte `groups` vide : `RideRequest.groups` est `required` sans `@Size(min=1)`, et la doc de `endDateTime` prévoit « a ride with no group » ;
- `RideEditor` affiche bien « Aucun groupe défini. Ajoutez au moins un groupe. » quand la liste est vide. Je n'ai pas vérifié si le schéma Zod bloque la soumission.

Rendu :

| Bloc | Rendu |
|---|---|
| En-tête / Départ | `ride.dateTime`, jamais de « Votre groupe » (`registeredGroupOf` → undefined) |
| Faits | pas de « N groupes » (`childCount` 0) ; « 0 personne » (pluriel `_one` pour 0 en français) ; distance et D+ de la sortie |
| B4 | titre « Groupes » + EmptyState « Aucun groupe » |
| B5 | **absent** (condition `groups.length > 0`) |
| B6 | « Météo au départ » + **le tronçon complet (`LegWeather`)** quand la météo a un unique tronçon sans `groupId` |
| Carte | si `ride.routeSlug` : `RoutesMapView` 1 trace « Parcours principal », bornes km ; sinon pas de carte, colonne pleine largeur |
| B8 | absent |
| Rejoindre | aucun moyen de s'inscrire, rien ne l'explique |

### b) Sortie à 1 groupe (« solo », WEB-79)

| Bloc | Rendu |
|---|---|
| Départ | `ride.dateTime` ; « Votre groupe · X · 09:30 » à droite seulement si inscrit et `startAt ≠ dateTime` |
| Faits | « 1 groupe », personnes, distance et D+ du groupe |
| B4 | **pas de titre « Groupes »**, à la place `RideSoloGroupPanel` + `GroupStats` (avec tuile **Départ** = `group.startAt`) + `GroupParticipantsSection` du groupe |
| B6 | **absent** |
| Carte | une seule route en jeu, ou route de sortie = route du groupe : `RouteMapPanel` (profil, Pente / Revêtement / Météo, waypoints, plein écran `/carte`), pas de barre de couleur. Deux routes différentes (sortie ≠ groupe) : `RoutesMapView` à 2 traces, barre de couleur sur le panneau. Aucune route : pas de carte |
| B8 | **présent**, pleine largeur, avant les alertes et les commentaires |
| Rejoindre | dans le panneau, à droite du nom (`groupAction`), non dans l'en-tête |
| « Complet » | badge visible même pour un non-membre (`showFull`, `groupAction` → 'none' puis `group.full`) |

### c) Plusieurs groupes, même heure

| Bloc | Rendu |
|---|---|
| Départ | `ride.dateTime` ; jamais de « Votre groupe » (aucun `startAt` ne diffère) |
| Faits | « 3 groupes », personnes, plages « 62 à 92 km », « D+ : 700 à 1 350 m » |
| B4 | titre « Groupes », cartes **sans encart d'heure**, « Autres groupes » si inscrit |
| B5 | participants de **toute la sortie** (`participantCount`) |
| B6 | « Météo au départ » seule, sans tronçon (`ownLeg` → undefined) |
| Carte | `RoutesMapView` : une trace par route distincte, bornes km seulement si tous les groupes roulent la même route |
| B8 | absent |

### d) Plusieurs groupes, heures différentes

Comme (c), sauf :

| Bloc | Rendu |
|---|---|
| Départ | si le lecteur est inscrit dans un groupe dont l'heure diffère de `ride.dateTime` : colonne droite « Votre groupe » / « Groupe B · 09:30 ». Sinon rien, y compris pour un lecteur non inscrit |
| B4 | **chaque carte, y compris celle qui part à l'heure de la sortie**, porte l'encart « Départ 09:30 » (`showStartTime` est global). `withDay` si le jour diffère : « sam. 12 avr. · 09:30 » ou « Demain · 09:30 » |
| B6 | l'heure affichée « Au départ · 09:00 » reste `ride.dateTime` |
| Ligne météo des cartes | conditions au premier point du tronçon de **chaque** groupe, donc à son propre départ |

---

## 4. Dates et heures

Rappel des fonctions :
- `useRendezvousFormat(zone)` (`hooks/useRendezvousFormat.ts:32-72`) formate dans le fuseau de l'évènement. Si la zone est absente ou inconnue d'`Intl`, il formate dans le fuseau du lecteur, sans mention.
- `useFormattedDate()` (`utils/dateFormat.ts:301-323`) formate dans le fuseau du lecteur : `user.timezone` s'il existe, sinon celui du navigateur, sinon `UTC` en SSR.
- `'p'` en français donne « 09:00 », en anglais « 9:00 AM ».
- Formats FR (`locales/fr/common.json`) :
  - `departureDay` = `EEE d MMM` → « sam. 12 avr. »
  - `WithYear` = `EEE d MMM yyyy`
  - `dayAndTime` = « {{day}} · {{time}} »
  - `PPP` → « 12 avril 2026 »
- **Mention de fuseau** (`utils/rendezvous.ts:33-55`) : « heure de Tokyo (ven. 01:00 chez vous) ». Elle n'apparaît que si l'offset diffère à cet instant. Le jour n'est préfixé que si le jour civil du lecteur diffère. Elle est supprimée tant que la zone du lecteur est le placeholder SSR.

| # | Emplacement | Champ source | Formatage (`fichier:ligne`) | Exemple FR | Fuseau | Cas particuliers |
|---|---|---|---|---|---|---|
| 1 | Bloc Départ, boîte jour | `ride.dateTime` | `DayBox` `components/common/DayBox.tsx:55-85` (`EEE` / `d` / `MMM` / `yyyy`) | « sam. » / « 12 » / « avr. » (+ « 2027 ») | évènement (`start.zone`) | année seulement hors année courante, jugée dans le fuseau de l'évènement |
| 2 | Bloc Départ, heure | `ride.dateTime` | `DepartureBlock.tsx:57` `formatTime` + `departure.block.time` | « Départ 09:00 » | évènement | toujours l'heure de la **sortie**, jamais celle du groupe |
| 3 | Bloc Départ, pastille | `ride.dateTime` | `DepartureBlock.tsx:43,59-63` `formatRelativeDay` (`dateFormat.ts:193-203`) | « Aujourd'hui » / « Demain » | évènement (le « demain » de Tokyo) | seulement ces deux jours, jamais « hier » ni « dans 2 h » ; rien pour une date passée |
| 4 | Bloc Départ, ligne 2 | `ride.dateTime` | `DepartureBlock.tsx:44,65-77` `mention().full` | « heure de Tokyo (ven. 01:00 chez vous) » | évènement → lecteur | ligne absente si offsets égaux ; pas de « samedi 12 avril » en toutes lettres (la DayBox le dit) |
| 5 | Bloc Départ, « Votre groupe » | `registeredGroup.startAt` | `DepartureBlock.tsx:107-112` `formatTime` + `departure.block.group` | « Groupe B · 09:30 » | évènement | seulement inscrit **et** `startAt ≠ dateTime` (`groupStart.ts:9-17`) ; pas de mention de fuseau pour cette heure |
| 6 | Publication programmée | `ride.publishAt` | `PublicationHeader.tsx:165-177` `<Rendezvous variant="detail">` → `formatDateTime` (`dateFormat.ts:109-115`, `relative:false`) | « Publication programmée pour le sam. 12 avr. · 09:00 · heure de Tokyo (…) » | évènement + mention en ligne | DRAFT et `publishAt` seulement ; jamais relatif |
| 7 | Carte de groupe, encart | `group.startAt` | `RideGroupCard.tsx:199-216` → `DepartureLine` (`DepartureLine.tsx:60-64`) | « Départ 09:30 » ; avec `withDay` : « sam. 12 avr. · 09:30 » ou « Demain · 09:30 » | évènement (`rideTimezone`) ; mention en infobulle sur globe (`ZoneMentionIcon`) | seulement variante d, sur **toutes** les cartes ; `withDay` = jour ≠ celui de `ride.dateTime` (`samePeriod`), en pratique jamais : la doc DTO dit que `startAt` est sur la date locale de la sortie |
| 8 | Sortie solo, tuile « DÉPART » | `group.startAt` | `StatsCard.tsx:77-84` `<Rendezvous format="time">` (variante card) | « 09:30 » + globe | évènement | sur la sortie solo, `showDeparture` vaut true par défaut : la tuile **double le bloc Départ** (heure du groupe, contre l'heure de la sortie dans l'en-tête) |
| 9 | Sortie solo, sous « ALLURE MOYENNE » | `soloLeg.arrivalTime` | `StatsCard.tsx:90-96` `formatTime` + `rides.group.stats.arrival` | « Arrivée estimée 12:15 » | évènement | seulement avec allure > 0 **et** prévision OK/STALE (`RideDetailPage.tsx:232`) ; pas d'heure d'arrivée sans météo (`endDateTime` jamais affiché) |
| 10 | Météo au départ, heure | `ride.dateTime` (pas `conditions.time`) | `DepartureWeather.tsx:53-55` `formatTime` | « 09:00 · 14 °C » | évènement | variante d : heure de la sortie, pas celle du groupe |
| 11 | Météo au départ, lever / coucher | `weather.departure.sunrise/sunset` | `DepartureWeather.tsx:85-96` `<FormattedTime>` (`FormattedDate.tsx:24-27`) | « 07:45 », « 17:20 » | **lecteur** | incohérent avec les verdicts (#15) qui donnent les mêmes valeurs dans le fuseau de l'évènement |
| 12 | Avis « pas encore disponible » | `weather.availableFrom` | `WeatherStatusNotice.tsx:51-53` `formatDate` (`PPP`) | « La météo sera disponible à partir du 15 novembre 2026. » | lecteur | jour sans heure |
| 13 | Pied / en-tête météo | `weather.fetchedAt` | `WeatherAttribution.tsx:24-32` `isToday` ? `formatTime` : `formatDate` + `formatTime` | « Mise à jour à 08:12 » / « Mise à jour le 9 novembre 2026 à 18:40 » | lecteur | « aujourd'hui » jugé dans le fuseau du lecteur |
| 14 | Tronçon (variante a) | `leg.startTime`, `leg.arrivalTime` | `LegWeather.tsx:49-55` `formatTime` | « Départ 09:00 → arrivée vers 12:15 · 85 km » | évènement | `leg.startTime` peut différer de `ride.dateTime` (non vérifié côté serveur) |
| 15 | Bandeau pluie, points (a) ; verdicts, tableau, curseur, détail, tronçons (b) | `rainAlert.time`, `checkpoint.time`, `departure.sunrise/sunset`, `leg.arrivalTime` | `WeatherRainBanner.tsx:36`, `WeatherCheckpointStrip.tsx:90`, `RouteVerdicts.tsx:72,94,99,115,121-122,225-229`, `RouteWeather.tsx:96-98,475,609,674,682,891` | « vers 10:30 », « 09:10–10:05 », « Lever 07:45, coucher 17:20. Arrivée estimée 12:15. » | évènement | tableau desktop : « 9:00 AM » coupé en deux lignes (`replace(/\s/,'\n')`, utile seulement en anglais) |
| 16 | Ligne météo de carte | `leg.rainAlert.time` | `GroupWeatherLine.tsx:67-73` `formatTime` | « Pluie 40 % vers 10:30 » | évènement | — |
| 17 | Popups des badges carte (solo, mode Météo) | `checkpoint.time`, `alert.time` | `WeatherCheckpointMarkers.tsx:234,444` `formatTime` ; préfixe jour `useInContext` l.476 `formatDepartureDay` (`rides.weather.map.inContext`, avec contexte seulement : trip) | « 10:30 » | évènement | — |
| 18 | Commentaires | `comment.createdAt` | `CommentItem.tsx:59,97` `formatRelative` (`dateFormat.ts:286-295`, `formatDistanceToNow` avec `addSuffix`) | « il y a environ 2 heures » (formulation date-fns fr, non vérifiée à l'exécution) | indépendant du fuseau | toujours relatif, même pour un commentaire vieux d'un an ; pas de date absolue en infobulle |

Ce qui n'apparaît pas :
- aucune heure de retour (`endDateTime`, le test `RideDetailPage.test.tsx:405` vérifie l'absence de « retour vers ») ;
- aucune date de création ;
- aucun relatif du type « dans 2 h » ;
- aucune plage de dates (une sortie dure un jour).

---

## 5. Wireframes ASCII

### Desktop, commun (≥ 1024 px)

```
┌ Fil d'Ariane (Layout) ───────────────────────────────────────────────────────┐
┌ [avatar] Nom de l'équipe                                                  >  ┐  B1
┌ HEADER ──────────────────────────────────────────────────────────────────────┐  B2
│ [logo] Nom de la sortie  [Publié] [Terminée?]   [Modifier|v] [Partager] [⋯]  │
│ ┌ DÉPART ───────────────────────────────────────────────┬──────────────────┐ │  B2a
│ │ ┌sam.┐ Départ 09:00 [Demain]                          │ Votre groupe     │ │
│ │ │ 12 │ heure de Tokyo (ven. 01:00 chez vous)          │ Groupe B · 09:30 │ │
│ │ └avr.┘ ● Parking de la gare (1 rue X)                 │ (cas d)          │ │
│ └───────────────────────────────────────────────────────┴──────────────────┘ │
│ ● Arrivée : Place du marché (adresse)                                        │  B2b
│ 3 groupes   12 personnes   62 à 92 km   D+ : 700 à 1 350 m                   │  B2c
│ 📅 Publication programmée pour le sam. 12 avr. · 09:00   (brouillon)        │
│ [tag] [tag]                                                                  │
└──────────────────────────────────────────────────────────────────────────────┘
┌ COLONNE 380-440 px ──────────┐ ┌ CARTE sticky (hauteur visible) ────────────┐
│ (B3, B4, B5, B6 selon        │ │                                            │  B7
│  variante)                   │ │                                            │
└──────────────────────────────┘ └────────────────────────────────────────────┘
(B8 Météo du parcours : solo seulement, pleine largeur)
┌ ⓘ Connectez-vous et rejoignez cette équipe… Se connecter ────────────────────┐  B9
┌ Commentaires (3) ────────────────────────────────────────────────────────────┐  B10
```

### a) Sans groupe — desktop

```
[B1 Équipe]
[B2 Header : Départ 09:00 · lieu | Arrivée | « 0 personne · 85 km · D+ : 900 m »]
┌ Colonne ─────────────────────┐ ┌ Carte : 1 trace « Parcours principal » ┐
│ [B3 Consignes?]              │ │ bornes km, départ/arrivée              │
│ Groupes                      │ │                                        │
│  (icône) Aucun groupe        │ │ ┌ profil altimétrique ┐                │
│  Aucun groupe défini…        │ │ └─────────────────────┘                │
│ ┌ Météo au départ  #meteo ─┐ │ └────────────────────────────────────────┘
│ │ AU DÉPART 09:00 · 14 °C  │ │
│ │ Pluie · Vent · ☀↑ · ☀↓   │ │
│ │ ──────────────────────── │ │
│ │ Départ 09:00 → arrivée…  │ │
│ │ [bandeau pluie]          │ │
│ │ [points →→→]             │ │
│ │ [Exposition au vent]     │ │
│ │ Prévisions X  Mise à jour│ │
│ └──────────────────────────┘ │
└──────────────────────────────┘
[B9 Alertes] [B10 Commentaires]
```
Sans `ride.routeSlug` : pas de carte, la colonne prend toute la largeur.

### b) Solo — desktop

```
[B1] [B2 Header : Départ 09:00 (+ Votre groupe si heure propre et inscrit) | « 1 groupe · 8 personnes · 85 km · D+ »]
┌ Colonne ─────────────────────┐ ┌ Carte (RouteMapPanel) sticky, scrollable ──┐
│ [B3 Consignes?]              │ │ carte + profil en surimpression [⛶]        │
│ ┌ GROUPE ─────────[Rejoindre]┐│ │                                            │
│ │ Nom du groupe [J'y vais]   ││ │                                            │
│ │ 11/12 personnes  1 place…  ││ ├────────────────────────────────────────────┤
│ │ ▓▓▓▓▓▓▓▓▓▓▓▓▓░             ││ │ [ Pente | Revêtement | Météo ]             │
│ │ (av) Léa [Capitaine]       ││ │ légende vent / résumé revêtement           │
│ │ Voir le parcours GPX FIT … ││ │ liste des points de passage                │
│ └────────────────────────────┘│ └────────────────────────────────────────────┘
│ ┌ DÉPART  ALLURE   DIST  D+ ┐ │
│ │ 09:30   25 km/h  85km 900m│ │
│ │         Arrivée est. 12:15│ │
│ └───────────────────────────┘ │
│ ┌ Personnes inscrites   8 p.┐ │
│ │ [Rechercher par nom…]     │ │
│ │ (av) Léa  ⛨ Capitaine     │ │
│ │ 1–8 sur 8   [pagination]  │ │
│ └───────────────────────────┘ │
└──────────────────────────────┘
┌ Météo du parcours [Prévision ancienne]        Prévisions X · Mise à jour à… ┐  B8 #meteo
│ [Températures] [Pluie] [Vent] [Jour]                                         │
│ Heure par heure, à votre passage — Passages estimés à 25 km/h · un point…    │
│ Face 12 km · Dos 30 km                                                       │
│ [tableau : Tronçons / Heure / Temp. / Pluie / Vent / Rafales  → défilant]    │
│ [détail du point sélectionné]                                                │
└──────────────────────────────────────────────────────────────────────────────┘
[B9 Alertes] [B10 Commentaires]
```

### c) Plusieurs groupes, même heure — desktop

```
[B1] [B2 Header : Départ 09:00 · lieu | « 3 groupes · 24 personnes · 62 à 92 km · D+ : 700 à 1 350 m »]
┌ Colonne ─────────────────────┐ ┌ Carte multi-tracés sticky ─────────────┐
│ [B3 Consignes?]              │ │ une trace par route, colorées          │
│ Groupes                      │ │ [⛶] [masquer tracés]                   │
│ ┌ ▌Rapide >  [J'y vais][Quitter]┐ │ ┌ profil de la trace allumée ┐      │
│ │ (av) Léa [Capitaine]       │ │ │ └────────────────────────────┘      │
│ │ ⚡28 km/h ⤢92 km ↑1 350 m  │ │ └────────────────────────────────────────┘
│ │ (av)(av)(av) 👥 8/12 p.     │ │
│ │ ☁ 14 °C · Nuageux [☂ Pluie…]│ │
│ │ GPX  FIT  Envoyer vers…    │ │
│ └────────────────────────────┘ │
│ ── Autres groupes ──────────── │
│ ┌ ▌Cool >          [Rejoindre]┐ │
│ │ ...                         │ │
│ └─────────────────────────────┘ │
│ ┌ Personnes inscrites  24 p. ┐  │   (toute la sortie)
│ └────────────────────────────┘  │
│ ┌ Météo au départ  #meteo ───┐  │
│ │ AU DÉPART 09:00 · 14 °C …  │  │
│ │ Prévisions X · Mise à jour │  │
│ └────────────────────────────┘  │
└─────────────────────────────────┘
[B9 Alertes] [B10 Commentaires]
```

### d) Plusieurs groupes, heures différentes — desktop

Identique à (c), avec en plus :
```
B2a :  ┌sam.┐ Départ 09:00            │ Votre groupe       ← seulement si inscrit dans
       │ 12 │ ● Parking …             │ Cool · 09:30         un groupe à heure propre
Carte de groupe (TOUTES les cartes) :
 ┌ ▌Rapide >                [Rejoindre]┐
 │ ┌ 🕘 Départ 09:00 ─────────────────┐ │  ← encart indigo-0 (aussi pour le groupe à l'heure de la sortie)
 │ └──────────────────────────────────┘ │
 │ (av) Léa [Capitaine]                 │
 │ ⚡ ⤢ ↑   👥 …                        │
 │ ☁ (météo à SON départ)               │
 └──────────────────────────────────────┘
Météo au départ : « AU DÉPART 09:00 » = heure de la sortie
```

### Étroit (< 1024 px), toutes variantes

Une colonne : carte d'abord, puis la colonne.
```
[Fil d'Ariane compact (< 768 px)]
[B1 Équipe]
[B2 Header — boutons qui passent à la ligne ; le bloc Départ met « Votre groupe »
 SOUS le reste quand il fait moins de 600 px]
[B7 CARTE  clamp(300px, 52svh, 560px), profil en surimpression 120–150 px]
   (solo : + Pente/Revêtement/Météo, légende, waypoints)
[B3 Consignes?]
[B4 Groupes / panneau solo + chiffres (2 colonnes < 560 px)]
[B5 Personnes inscrites]
[B6 Météo au départ]         (non solo)
[B8 Météo du parcours]       (solo ; < 768 px : bande + curseur + « Par tronçon »)
[B9 Alertes]
[B10 Commentaires]
```
L'ancre `#meteo` est atteinte avec un délai de 4 s (`WEATHER_ANCHOR_SETTLE_MS`). Ce délai laisse le temps à la carte, au profil et aux images de se charger au-dessus.

---

## 6. Étonnements

1. **« Terminée » et « finished » dès l'heure de départ passée** (doc `RideDto.finished` : « its start time has passed »). Une sortie en cours est donc marquée « Terminée » dès 09:01. À partir de là, plus de « Rejoindre » ni de météo (B6 et B8 s'effacent, `RideWeatherSection.tsx:48`, `GroupWeatherSection.tsx:43`). Le bouton « Quitter » reste disponible sur une sortie passée.
2. **Badge de statut toujours affiché**, y compris « Publié », qui est le cas normal. Il est au masculin (« Annulé », « Publié ») alors qu'on parle d'*une* sortie : `status.*` est une clé générique.
3. **Le nombre de personnes répété** :
   - variante solo : 3 fois (faits « 8 personnes », panneau « 8 personnes » ou « 11/12 personnes », en-tête de la section « 8 personnes ») ;
   - multi-groupes : faits + chaque carte + section.
4. **Heure de départ en double, voire contradictoire, sur la sortie solo.**
   - L'en-tête donne `ride.dateTime`. La tuile « DÉPART » de `StatsCard` donne `group.startAt` (`GroupStats` y appelle `showDeparture` avec sa valeur par défaut true, alors que la page du groupe la désactive « because the departure block above already gives it »).
   - Si le groupe solo a une heure propre, un lecteur non inscrit voit « Départ 09:00 » en haut et « 09:30 » dans la tuile, sans explication.
5. **L'encart d'heure apparaît sur toutes les cartes dès qu'un seul groupe diffère**, y compris sur le groupe qui part à l'heure de la sortie. C'est voulu (« so none reads as no time ») mais cela se répète.
   - `withDay` existe dans `RideGroupCard.tsx:213`, mais selon la doc DTO `startAt` est toujours sur la date locale de la sortie : la branche ne sert pratiquement jamais.
6. **« Météo au départ » est toujours calée sur l'heure de la sortie**, même quand le groupe du lecteur part plus tard. À l'inverse, la ligne météo de chaque carte prend le premier point du tronçon du groupe, donc son heure propre. Deux « départs » météo coexistent sur la page.
7. **Fuseau du lever et du coucher incohérent** :
   - `DepartureWeather` les affiche dans le fuseau du **lecteur** (`FormattedTime`) ;
   - `RouteVerdicts` les affiche dans le fuseau de l'**évènement**.
   - Sur la page solo (bloc de repli sans tronçon) ou d'une page à l'autre, les mêmes valeurs peuvent donc différer.
8. **« Complet » visible ou non selon la variante** :
   - panneau solo : toujours visible (`showFull`), même pour un anonyme ;
   - cartes multi-groupes : visible seulement si `canJoinRide`. Un non-membre, ou un membre déjà inscrit ailleurs, ne voit pas qu'un groupe est plein.
9. **`registeredElsewhere`** : la valeur est calculée par `groupAction`, mais `GroupJoinActions` ne rend rien pour elle et `RideGroupCard` ne s'en sert pas. Sur les cartes, rien n'indique « votre inscription est dans le groupe X », hormis l'ordre des cartes et le séparateur « Autres groupes ».
10. **Sortie sans groupe** :
    - aucune inscription possible et aucun message, seulement l'EmptyState « Aucun groupe » sous un titre « Groupes » ;
    - pas de section participants, alors que les faits affichent « 0 personne » ;
    - l'unique tronçon météo se déroule dans « Météo au départ » (`LegWeather`), avec un rendu plus pauvre que le `RouteWeather` de la sortie solo ;
    - son message sans route dit « **Ce groupe** n'a pas de parcours… », alors qu'il n'y a pas de groupe.
11. **Deux rendus météo de tronçon** : `LegWeather` (variante a : bande de points, exposition au vent) et `RouteWeather` (variante b : verdicts, tableau, tronçons). L'attribution est en pied dans B6 et en en-tête dans B8.
12. **Carte de la sortie solo selon les routes** : si la route de la sortie diffère de celle de son unique groupe, la page bascule sur la carte multi-tracés. On perd alors le mode Météo, le panneau Pente / Revêtement et les waypoints, et une barre de couleur apparaît sur le panneau. Le plein écran `/carte` redirige également.
13. **Carte multi-tracés sans mode Météo**, alors que le composant le permet (`winds`, utilisé par la page voyage). Sans groupe, la carte multi-tracés n'a qu'une seule trace, mais elle ne propose ni Pente / Revêtement ni waypoints, contrairement à la variante solo.
14. **Breakpoint de la grille à 64em** en CSS brut, contre 62em pour le `md` Mantine par défaut, alors que le code parle de « md+ ». Entre 992 et 1024 px, les composants Mantine sont en mode « md » mais la grille est encore empilée.
15. **Les alertes d'accès viennent après toute la météo**, loin de l'action. Il n'existe aucun bouton Rejoindre dans l'en-tête d'une sortie, contrairement au voyage (`joinActions`). Le seul point d'inscription se trouve sur les cartes ou dans le panneau solo.
16. **Commentaires toujours relatifs** (« il y a environ 2 heures »), sans date absolue au survol. Le reste de la page suit le format unique « sam. 12 avr. · 09:00 ».
17. **Champs du DTO jamais affichés** : `endDateTime` (heure de retour), `ride.distance`/`elevationGain` quand un groupe porte les siens, `surfaceType`. Le dénivelé d'une carte de groupe est masqué si sa distance est inconnue (`RideGroupCard.tsx:143`), mais il reste visible dans la `StatsCard` solo.
18. **Points non vérifiés** : le libellé exact de `speedWithGusts`, le contenu de `RouteSurfaceSummary` et de `RouteWaypointList`, le fil d'Ariane exact, le blocage ou non de l'enregistrement d'une sortie sans groupe par le formulaire, et le rendu réel dans un navigateur.
