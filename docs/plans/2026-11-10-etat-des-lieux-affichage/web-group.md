# Web — page d'un GROUPE de sortie (état des lieux)

Périmètre : `frontend/src/pages/ride/RideGroupPage.tsx` et `RideGroupFullscreenMapPage.tsx`, avec les
composants qu'elles montent. Lecture seule du code au commit `ef1fc9a99` (branche `feat/mobile-review`) ;
rien n'a été exécuté. Chemins relatifs à `frontend/src/`.

**Composant commun avec l'étape** (commit `85792a9b1`, ledger `WEB-155`) : **`ChildDetailShell`**
(`components/publication/ChildDetailShell.tsx`). C'est la mise en page commune de « la page d'un enfant
d'une publication » (groupe d'une sortie, étape d'un voyage). Les deux pages s'appuient aussi sur les mêmes
briques, toutes dans `components/publication/` : `SiblingNav`, `RouteCard`, `PlacesLine`,
`useWeatherFocus` / `CHILD_WEATHER_ANCHOR`, `StatsCard` (via `GroupStats` côté groupe) et
`ParticipantsSection` (via `GroupParticipantsSection`). Elles partagent encore `components/common/DepartureBlock`,
`components/route/RouteMapPanel` et `components/weather/RouteWeatherSection` (via `GroupWeatherSection`
côté groupe). L'étape ajoute `InstructionsBlock`, `AccessAlerts` et des commentaires (prop `children` du
shell) ; le groupe n'utilise aucun des trois.

---

## 1. Points d'entrée

| | Page groupe | Carte plein écran du groupe |
|---|---|---|
| Route id | `ride-group` (`config/routes.config.ts:761`) | `ride-group-map` (`config/routes.config.ts:776`, `layout: 'bare'`) |
| URL FR | `/equipes/{teamSlug}/sorties/{rideSlug}/groupes/{groupId}` | `/equipes/{teamSlug}/sorties/{rideSlug}/groupes/{groupId}/carte` (`?color=grade\|surface\|wind`) |
| URL EN | `/teams/{teamSlug}/rides/{rideSlug}/groups/{groupId}` | `/teams/…/groups/{groupId}/map` |
| contracts/routes.yaml | `rideGroup` (l. 544) : `web`, `mobile`, `deeplink` à true | `rideGroupMap` (l. 556) : web seulement |
| Fichier | `pages/ride/RideGroupPage.tsx` | `pages/ride/RideGroupFullscreenMapPage.tsx` |
| Accès | `auth: 'public'` | `auth: 'public'` |
| Fil d'Ariane (Layout) | Équipes › {équipe} › Agenda › {sortie} › « Groupe {nom} » (`hooks/useBreadcrumbData.ts:86`, parents `ride-detail` → `team-agenda` → `team-detail` → `teams`). Sous `sm`, seulement les deux derniers niveaux (`components/common/Breadcrumb.tsx:104`) | sans objet (layout bare) |

**Données** : tout passe par `useRideGroupData(teamSlug, rideSlug, groupId)` (`pages/ride/rideGroupData.ts:50`),
c'est-à-dire les lectures de la page sortie (`useRideDetailData`, `pages/ride/rideDetailData.ts:99`) sous les
mêmes clés de cache :
- `useGetTeam` → `TeamDto` (droits via `teamAccess(team, isPlatformAdmin)` : `isMember`, `isOrganizer`) ;
- `useGetRide` → `RideDto` (groupes, `dateTime`, `timezone`, `startPlace`, `endPlace`, `status`, `finished`,
  `registered`, `registeredGroupId`, `routeSlug`, `name`) ;
- `useGetRideWeather` → `RideWeatherDto` (`status`, `legs[]`, `departure`, `attribution`, `fetchedAt`,
  `availableFrom`) ;
- `useRoutesBulk` → `RouteDetailDto[]` (`routesBySlug`).
- Dérivés : `group` = `ride.groups.find(id)` (`RideGroupDto`), `leg` = `weather.legs.find(groupId)` (`WeatherLegDto`).
- À part : `useRideGroupMembership` (rejoindre / quitter) ; `useGetRideParticipants`, appelé par
  `ParticipantList` avec `groupParticipantsParams(groupId, {search, page})` (`?q=` et `?p=` dans l'URL,
  50 par page) ; `useGpsConnections` (envoi vers un appareil).
- SSR : `prefetchRideGroup` (`rideGroupData.ts:62`) charge équipe, sortie et météo, puis les parcours, les
  participants (seulement si `readsMemberContent`) et les services GPS (seulement connecté).
  `rideGroupDataRedirect` (l. 131) renvoie vers la page de la sortie quand la sortie a **≤ 1 groupe**
  (`leavesGroupPage`, `utils/soloGroup.ts:23`).

---

## 2. Disposition

### 2.1 Desktop (≥ 64em = 1024 px)

Conteneur `Container size="xl" py="xl"` (`ChildDetailShell.tsx:63`). Sous le Layout : fil d'Ariane, puis :

**B0. Lien retour** — `ChildDetailShell.tsx:64-71`. Toujours affiché. `IconArrowLeft` + « Retour à la sortie »
(lien gris, souligné au survol), vers `paths.ride`.

**B1. En-tête (Paper `component="header"`, bordure, shadow xs)** — `ChildDetailShell.tsx:73-106`, empilé (gap md) :

- **B1a. Navigation entre groupes `SiblingNav`** — `components/publication/SiblingNav.tsx:29`. Visible dès
  qu'il y a ≥ 2 groupes, donc toujours sur cette page. Une flèche ‹ (`IconChevronLeft`), un contrôle
  segmenté pleine largeur (**≤ 4 groupes**) ou un `Select` (max 420 px, **> 4 groupes**), une flèche ›.
  Libellé de chaque option : « {nom} · {inscrits}/{max} » (`rides.group.option`) ou « {nom} · {inscrits} »
  sans max. aria-label « Groupes de la sortie ». Une flèche est désactivée au premier et au dernier groupe ;
  aria « Précédent : … » / « Suivant : … ».
- **B1b. Ligne titre** — `ChildDetailShell.tsx:77-94` (Group space-between) :
  - à gauche, le nom de la sortie en petit gris (`parentName`), puis le H1 (taille h2)
    « Groupe {nom} » (`rides.group.title`) ;
  - à côté du titre, les **badges** (`RideGroupPage.tsx:169-186`) : « J'y vais » (primary light) si
    `group.registered`, sinon « Complet » (gris light) si `group.full`. Toujours ensuite un
    **bouton Partager** (`ShareButton`, `IconShare`, ActionIcon default, aria/title « Partager ») qui ouvre
    la feuille de partage du système, ou copie le lien ;
  - à droite, les **actions** (`RideGroupPage.tsx:187-201`) : `GroupJoinActions`
    (`components/ride/group/GroupJoinActions.tsx:10`) affiche « Rejoindre » (bouton plein) ou « Quitter »
    (outline), désactivé pendant la requête, ou rien. Puis « Modifier » (`IconPencil`, outline, vers
    `paths.rideEdit`) si l'utilisateur est organisateur ou admin plateforme.
- **B1c. Bloc départ** — `RideGroupPage.tsx:202-213`, Stack gap sm :
  - `DepartureBlock` (`components/common/DepartureBlock.tsx:33`), une surface grise bordée. À gauche la
    **DayBox** `lg` (`components/common/DayBox.tsx:30`) : « sam. / 12 / avr. », plus l'année sur une
    4e ligne hors année courante. Au milieu : « Départ 09:00 » (24 px, gras) et une pastille
    « Aujourd'hui » / « Demain » si c'est le cas. En dessous, en gris, la mention de fuseau seule
    (« heure de Tokyo (ven. 01:00 chez vous) »), seulement si le décalage diffère. Enfin le lieu de départ
    de la **sortie** (`ride.startPlace`) : `IconMapPin` vert, nom en gras, adresse entre parenthèses en gris.
    La colonne de droite « Votre groupe » n'est **pas** utilisée ici (prop `group` non passée).
  - `PlacesLine end={ride.endPlace}` (`components/publication/PlacesLine.tsx:21`) : `IconMapPin` rouge,
    « Arrivée : » en rouge gras, nom, adresse grise. Rien sans `endPlace`.
  - `GroupPlaces` (`components/ride/group/GroupPlaces.tsx:6`). Avec un max : « 11/12 personnes » (gras) à
    gauche, « 1 place restante » / « Aucune place restante » (gris) à droite, puis une barre `Progress`
    (primary, grise quand c'est plein). Sans max : « 11 personnes » en gris, sans barre.
- **B1d. Notices** — `RideGroupPage.tsx:214-254` :
  - inscrit dans un autre groupe : « Votre inscription est dans le groupe {X}. **Voir le groupe** » (texte sm) ;
  - anonyme : Alert bleue « Connectez-vous pour rejoindre ce groupe. **Se connecter** » ;
  - connecté mais non membre : Alert jaune « Rejoignez cette équipe pour participer aux sorties.
    **Voir l'équipe** ».
- **B1e. Erreur d'inscription** — `ChildDetailShell.tsx:100-104`. Alert rouge avec le message de
  `membership.error`, seulement pour ce groupe.

**B2. Grille `.detail-layout`** — `ChildDetailShell.tsx:108-113`, CSS `index.css:267-317`. Colonnes
`minmax(380px, 440px)` puis `minmax(0, 1fr)`, zones `'side map'`, gap lg.

- **Colonne gauche `.detail-side`** (Stack gap lg), `RideGroupPage.tsx:256-286` :
  - **B2a. Stats `GroupStats` → `StatsCard`** (`components/ride/group/GroupStats.tsx:8`,
    `components/publication/StatsCard.tsx:59`). Paper bordé, grille 2 colonnes (requête de conteneur : 4 à
    partir de 560 px de conteneur, jamais atteint dans une colonne de 440 px). Tuiles, chacune seulement si
    la donnée existe : `IconBolt` « ALLURE MOYENNE » « 28 km/h », avec en dessous en petit gris
    « Arrivée estimée 12:30 » si la météo donne une arrivée ; `IconArrowsMaximize` « DISTANCE » « 92 km » ;
    `IconArrowUp` « DÉNIVELÉ POSITIF » « 1 150 m ». La tuile « Départ » est **désactivée**
    (`showDeparture={false}`) parce que le bloc départ l'affiche déjà.
  - **B2b. Capitaine `GroupLeader`** (`components/ride/group/GroupLeader.tsx:12`). Seulement si
    `group.leader`. Paper bordé : avatar md, nom en gras (tronqué), badge « Capitaine » avec `IconShieldCheck`.
  - **B2c. Personnes inscrites `GroupParticipantsSection` → `ParticipantsSection`**
    (`components/ride/group/GroupParticipantsSection.tsx:10`, `components/publication/ParticipantsSection.tsx:30`).
    Paper bordé `section` : H3 « Personnes inscrites », et à droite « {n} personnes » en gris. Si
    `canSeeParticipants` (membre ou admin plateforme), `ParticipantList` (`components/ride/ParticipantList.tsx:46`)
    affiche :
    - un champ de recherche « Rechercher par nom… » (si n > 0) ;
    - la liste : avatar md, nom en gras, et pour le capitaine une pastille `IconShieldCheck` sur l'avatar plus
      « Capitaine » en sous-ligne. Un chevron › décoratif termine chaque ligne ;
    - « 1–11 sur 11 », puis la pagination (50 par page) ;
    - les états vides : « Aucune inscription pour le moment. » (`IconUsers` 48), « Personne ne correspond à
      votre recherche. », ou l'erreur « La liste des inscriptions n'a pas pu être chargée. Réessayez. ».
  - **B2d. Carte parcours `RouteCard`** (`components/publication/RouteCard.tsx:8`). Seulement si
    `routeSlug` (celui du groupe, sinon celui de la sortie). Paper : H3 (h5) au nom du parcours, ou
    « Parcours du groupe » pendant le chargement. Dessous, `RideGroupRouteActions` (`components/ride/RideGroupRouteActions.tsx:29`) :
    - `IconMap` « Voir le parcours », vers `paths.route` ;
    - `IconDownload` « GPX » et « FIT », si le fichier existe ;
    - `IconDeviceMobile` « Envoyer vers l'appareil » (menu des services GPS connectés), si l'utilisateur est
      connecté et a au moins un service.
- **Colonne droite `.detail-map.detail-map--fill.detail-map--solo`** : sticky (`top` = hauteur du header
  + md, `index.css:257`), `max-height` = hauteur visible, avec `overflow-y: auto`. Seulement si `routeSlug`.
  Contenu : **B2e. `RouteMapPanel`** (`components/route/RouteMapPanel.tsx:45`) avec `withActions={false}` et
  `heightVariant="sticky"` :
  - **Carte et profil** (`RouteMapView`, `components/route/RouteMapView.tsx:69`) : Paper bordé. Carte MapLibre
    de hauteur `max(360px, visible − 130px)`, avec bornes km (sauf en mode Météo). Bouton de colonne
    « Carte plein écran » (`IconArrowsMaximize`) vers `rideGroupMap?color=…`. **Profil altimétrique posé
    sur le bas de la carte** (`profilePlacement="overlay"`, hauteur `clamp(110px, 38%, 200px)`), coloré
    par pente ou revêtement, avec une bande de vent en mode Météo. Zoom synchronisé entre carte et profil.
  - « Profil d'altitude provisoire » en petit gris si `route.elevationState === PENDING`.
  - **`ColorModeControls`** (`components/route/ColorModeControls.tsx:14`) :
    - un contrôle segmenté xs « Pente | Revêtement | Météo », dessiné seulement s'il y a au moins 2 modes.
      Revêtement apparaît si le parcours a des surfaces, Météo si `groupWindLeg` existe. Le mode est dans
      `?color=` ;
    - en mode Météo, `WindMapLegend` : « Vent sur le tracé : ▬ Dos 32 km ▬ Travers 18 km ▬ Face 40 km »,
      un badge « Prévision ancienne » si la prévision est ancienne, la ligne de vitesse par défaut, et
      « Prévisions {source} » ;
    - `RouteSurfaceSummary` : la répartition des revêtements.
  - **Badges météo sur la carte** (mode Météo, `WeatherCheckpointMarkers`) : un badge par point de
    prévision, avec une popup « {lieu} · {heure} », et une goutte là où la pluie devient probable
    (« Pluie probable (60 %) vers 11:20, à km 45 »). Le badge ouvert est synchronisé avec la ligne
    sélectionnée du tableau (`useWeatherFocus`).
  - **`RouteWaypointList`** (`components/route/RouteWaypointList.tsx:24`) : H4 « Points du parcours (n) »,
    puis une ligne par point : « 12,4 km » ou « Hors tracé », une icône colorée du type, le nom et le type
    en gris, et la description sur 2 lignes. Repli après 10 avec « Voir les N autres points ». Cliquer
    sélectionne le point sur la carte. Rien sans waypoint.

**B3. Météo du parcours** — `ChildDetailShell.tsx:115-121`, ancre `id="meteo"`, pleine largeur sous la grille.
`GroupWeatherSection` (`components/weather/GroupWeatherSection.tsx:29`) appelle `RouteWeatherSection`
(`components/weather/RouteWeatherSection.tsx:50`), le tout dans un `ErrorBoundary` inline. Rien n'est affiché
si la sortie est terminée ou annulée, pendant le chargement, ou si le statut est OUT_OF_RANGE ou inconnu.
NO_LOCATION n'est montré qu'aux éditeurs. Sinon, un Paper `section` contient :
- **B3a. En-tête** : H3 « Météo du parcours », un badge jaune « Prévision ancienne » (`IconHistory`) si
  STALE, et à droite `WeatherAttribution` : « Prévisions {Open-Meteo…} » et « Mise à jour à 14:05 » ou
  « Mise à jour le 9 novembre 2026 à 14:05 ».
- **B3b. Notice d'état** (`WeatherStatusNotice`) :
  - NOT_YET_AVAILABLE : `IconCalendarTime` « La météo sera disponible à partir du {date}. » ou « … sept jours
    avant le départ. » ;
  - UNAVAILABLE : `IconCloudOff` « La météo n'est pas disponible pour le moment. » et un bouton
    « Réessayer » ;
  - NO_LOCATION : `IconMapPinOff` « Ajoutez un lieu de départ ou un parcours… ».
- **B3c. Si la prévision existe (OK ou STALE) et que le leg a des points** : `RouteWeather`
  (`components/weather/RouteWeather.tsx:126`) affiche dans l'ordre :
  1. `RouteVerdicts` : 4 tuiles (2 colonnes, 4 à partir de md) :
     - « Températures » : « 8° → 15° », « 9° au départ, ressenti 7°. Le plus chaud vers 12:00. » ;
     - « Pluie » : « Sec » ou « 60 % au plus, de 10:40 à 11:20 (km 30 à km 45). » ;
     - « Vent » : « Surtout de face », « Dans le dos après le km 50. » ;
     - « Jour » : « 3 h 10 de marge », « Lever 07:45, coucher 17:20. Arrivée estimée 12:30. ».
  2. « Heure par heure, à votre passage » (H4/h5), puis « Passages estimés à 28 km/h · un point tous les
     10 km » (ou la variante « vitesse par défaut (le groupe n'en indique pas) »). Ensuite les totaux
     « Dos 32 km · … » (à partir de sm seulement).
  3. À partir de sm, **tableau défilant** (`DesktopTimeline`), avec les lignes Tronçons (blocs « Face »,
     « Dos »…, heures « 09:00–10:00 »), Heure, Temp., Pluie %, Vent km/h, Rafales, km. Une colonne est
     sélectionnable.
  4. **Détail du point** (`CheckpointDetail`) : « {Départ | km 40 | Arrivée · km 92} » et l'heure, puis
     4 cellules Température / Pluie / Vent / Tronçon.
- **B3d. Leg sans prévision** (pas de parcours, ou pas encore) : `DepartureWeather`
  (`components/weather/DepartureWeather.tsx:27`) affiche une icône météo, « AU DÉPART », « 09:00 · 12° »,
  la condition, le ressenti, puis la pluie, le vent, le lever et le coucher. En dessous :
  « Ce groupe n'a pas de parcours : la météo n'est connue qu'au départ. » (leg NO_LOCATION) ou « Les
  prévisions le long du parcours ne sont pas encore disponibles. ».

Pas de bloc description ou consignes de la sortie, pas de commentaires (« No comments here: the thread is the
ride's », `RideGroupPage.tsx:43-44`), pas de badge de statut de sortie.

### 2.2 Viewport étroit

- **< 64em** (`index.css:267-286`) : la grille passe à **une colonne**, avec les zones `'map' 'side'`. La
  **carte vient avant** les stats, le capitaine, les participants et la carte parcours, alors qu'elle les
  suit dans le DOM. Elle n'est plus sticky. Sa hauteur est `clamp(300px, 52svh, 560px)` (repli de la
  variante `sticky`, `hooks/useResponsive.ts:97`). Le profil reste posé sur la carte, et les contrôles de
  couleur et la liste des points restent sous la carte, avant la colonne.
- Sans parcours (`detail-layout--no-map`) : une seule colonne pleine largeur à toutes les tailles.
- `StatsCard` : 2 colonnes sous 560 px de conteneur, **4 colonnes entre 560 px et 1023 px** de viewport
  (la colonne y prend toute la largeur).
- `DepartureBlock` : la requête de conteneur ≤ 600 px fait passer la colonne groupe à la ligne. Elle ne sert
  pas ici.
- Météo, **< sm (48em)** : le tableau est remplacé par `PhoneStrip`, une bande avec la courbe de température,
  des barres de pluie, une bande de vent colorée et quelques heures en graduation, plus un curseur
  « Glisser pour choisir un passage ». Les totaux de vent ne sont plus dans l'en-tête. Après le détail
  apparaît **« Par tronçon »** (`PhaseList`), une liste des phases avec leurs heures et leurs points. Les
  tuiles de verdict restent sur 2 colonnes jusqu'à md (62em). Le padding du Paper passe de lg à md.
- Le fil d'Ariane ne garde que les 2 derniers niveaux sous sm. Les boutons ont une hauteur minimale de 44 px
  sous 48em (`index.css:229`).
- Il n'y a pas d'onglets sur la page groupe. (La page de la sortie et l'app ont un onglet « Météo »
  qui pointe sur `#meteo`, `useScrollToAnchor`.)

### 2.3 Carte plein écran (`RideGroupFullscreenMapPage`)

`MapColorFullscreenView` → `RouteFullscreenView` (`components/route/RouteFullscreenView.tsx`), sans le chrome
du site :
- barre du haut : ← retour (vers la page groupe avec `?color=`), titre « {sortie} · Groupe {nom} », et sous
  le titre `DepartureLine withDay` : `IconClock` « Demain · 09:00 » ou « sam. 12 avr. · 09:00 », avec
  l'icône 🌐 de mention de fuseau (infobulle) ;
- stats du **parcours** (distance, D+, D−) ;
- le même contrôle de mode de couleur ;
- la carte, avec les badges météo en mode Météo ;
- en bas : `WindMapLegend` (en mode Météo), puis le profil sur un bandeau fixe de 160 px **sous** la carte.

Le `document.title` vaut « {sortie} · Groupe {nom} — {app} ». La page redirige vers `rideMap` pour une sortie
solo, vers la page sortie quand il n'y a aucun groupe, et vers la page groupe s'il n'y a pas de groupe ou
pas de parcours.

---

## 3. Variantes (bloc par bloc)

| Variante | Effet |
|---|---|
| **Sortie solo (1 groupe)** ou **sans groupe** | **Il n'y a pas de page groupe.** Redirection serveur (`rideGroupDataRedirect`) ou client (`RideGroupPage.tsx:78-82`, avec squelette pendant ce temps) vers la page de la sortie, qui joue le rôle de page du groupe (`RideSoloGroupPanel`, couvert ailleurs). |
| **Multi-groupes, id inconnu** | `EmptyState` avec `IconUsersGroup` : « Ce groupe n'existe plus », « Il a peut-être été retiré de la sortie… », bouton « Retour à la sortie » (`RideGroupPage.tsx:115-130`). |
| **≤ 4 / > 4 groupes** | B1a : contrôle segmenté jusqu'à 4, Select au-delà. |
| **Avec parcours** | B2d (RouteCard) et B2e (carte sticky) présents, grille à 2 colonnes. La météo B3c est possible. |
| **Sans parcours** (`group.routeSlug` et `ride.routeSlug` absents) | Pas de B2d ni de B2e, colonne unique pleine largeur. Météo : le leg est probablement NO_LOCATION (statut non vérifié côté serveur), d'où B3d « Ce groupe n'a pas de parcours… ». Si le statut global est NO_LOCATION, seuls les éditeurs voient le bloc. |
| **Avec capitaine** | B2b affiché. Dans B2c, le capitaine porte la pastille bouclier et le mot « Capitaine ». |
| **Sans capitaine** (cas courant) | B2b absent, aucun repli sur `createdBy`. |
| **Membre** | B2c avec recherche et liste. « Rejoindre » si sortie PUBLISHED, non finie, groupe non plein et pas d'inscription dans la sortie. |
| **Connecté non membre** | B1d : Alert jaune. B2c : **titre et compte seulement**. B2b : rien, l'API ne renvoie pas de capitaine à un non-membre (invariant `API-144`, non revérifié dans le DTO de cette page). Pas de bouton « Rejoindre » (`groupAction` renvoie `none`). |
| **Anonyme** | B1d : Alert bleue « Connectez-vous… Se connecter ». B2c : compte seulement. B2d : pas d'« Envoyer vers l'appareil ». Partager reste disponible. SSR sans participants. |
| **Admin plateforme non membre** | Voit les noms (`canSeeParticipants = isMember \|\| isPlatformAdmin`) et « Modifier ». Ne peut pas rejoindre (`isMember` réel). |
| **Organisateur** | Bouton « Modifier ». En plus, la notice NO_LOCATION en météo. |
| **Inscrit dans ce groupe** | Badge « J'y vais » (pas de badge « Complet » même si le groupe est plein). Bouton « Quitter ». |
| **Inscrit dans un autre groupe** | Pas d'action. Notice « Votre inscription est dans le groupe X. Voir le groupe ». |
| **Groupe complet** | Badge gris « Complet », pas d'action, barre grise, « Aucune place restante ». |
| **Sans max** | B1c : « 11 personnes » sans barre. Option du sélecteur « Rapide · 11 ». |
| **Sortie passée** (`finished`) | Pas de « Rejoindre », mais **« Quitter » reste** pour l'inscrit (choix délibéré, `rideGroupData.ts:182`). B3 entier masqué (`offered=false`). Pas de mode Météo sur la carte. B2a : « Arrivée estimée » seulement si le leg a encore une prévision (non vérifié côté serveur, sans doute OUT_OF_RANGE, donc absente). |
| **Sortie annulée** | Mêmes effets que pour une sortie passée (B3 masqué, pas de mode Météo, pas de « Rejoindre », « Quitter » visible). **Aucun badge « Annulée »** sur la page groupe. |
| **Brouillon** (status ≠ PUBLISHED) | Pas de « Rejoindre ». Aucun indicateur. |
| **Météo : STALE / NOT_YET / UNAVAILABLE** | Voir B3a et B3b. En STALE, le badge apparaît dans l'en-tête de la section et dans la légende du vent. |
| **Pas d'allure** (`averageSpeed` absent ou 0) | Tuile Allure absente, et avec elle **l'arrivée estimée** (elle est l'indice de cette tuile). |
| **Zone de la sortie ≠ zone du lecteur** | Ligne de mention sous « Départ 09:00 ». Ailleurs, aucune mention. |

---

## 4. Dates et heures

Fonctions de base : `formatTime` = date-fns `p`, ce qui donne « 09:00 » en français (`utils/dateFormat.ts:136`).
`useRendezvousFormat(zone)` (`hooks/useRendezvousFormat.ts:32`) formate dans la zone de l'**évènement**
(`ride.timezone`), avec repli sur celle du lecteur si la zone est absente ou inconnue d'Intl. `useFormattedDate()`
(`utils/dateFormat.ts:301`) formate dans la zone du **lecteur** : sa préférence `timezone`, sinon le navigateur,
et UTC au rendu SSR anonyme. La mention de fuseau vient de `rendezvousMention` (`utils/rendezvous.ts:33`).

| # | Emplacement | Champ source | Formatage (`fichier:ligne`) | Exemple FR | Fuseau | Cas particuliers |
|---|---|---|---|---|---|---|
| 1 | B1c DayBox | `startFor(ride, group)` = `group.startAt` (sinon `ride.dateTime` si illisible) (`utils/groupStart.ts:56`) | `DayBox` → `formatPattern` `EEE` / `d` / `MMM` / `yyyy` (`components/common/DayBox.tsx:73-84`) | « sam. » / « 14 » / « nov. » (+ « 2027 ») | évènement | L'année n'apparaît que hors année courante (année jugée dans la zone de l'évènement). |
| 2 | B1c heure | idem | `t('departure.block.time')` + `formatTime` (`DepartureBlock.tsx:57`) | « Départ 09:30 » | évènement | C'est l'heure **du groupe**. L'heure de la sortie (`ride.dateTime`) n'apparaît pas dans l'en-tête. Pas d'heure de RDV distincte de l'heure de départ : la seule notion est `startAt`. |
| 3 | B1c pastille | idem | `formatRelativeDay` (`utils/dateFormat.ts:193`, `DepartureBlock.tsx:43,59`) | « Demain » / « Aujourd'hui » | évènement | Rien les autres jours. Pas de « samedi 14 novembre » en toutes lettres (choix BRANDING §7.8, `DepartureBlock.tsx:46`). |
| 4 | B1c mention | idem | `rendezvous.mention` → `t('timezone.rendezvousMention')` (`utils/rendezvous.ts:33`, `DepartureBlock.tsx:65-76`) | « heure de Tokyo (ven. 01:30 chez vous) » | lecteur, pour l'équivalent | Seulement si les décalages diffèrent à cet instant. Le jour est ajouté si le jour calendaire diffère. Absente au rendu SSR et à l'hydratation sans préférence. |
| 5 | B2a indice sous Allure | `leg.arrivalTime` (si `hasForecast(leg.status)`) | `StatsCard` → `rendezvous.formatTime` (`StatsCard.tsx:93`) | « Arrivée estimée 12:40 » | évènement | Affiché **uniquement si `averageSpeed`** est renseigné. Pas de mention de fuseau. |
| 6 | B3a pied | `weather.fetchedAt` | `WeatherAttribution` → `useFormattedDate` `formatTime` / `formatDate` PPP (`WeatherAttribution.tsx:26-31`) | « Mise à jour à 14:05 » / « Mise à jour le 9 novembre 2026 à 14:05 » | **lecteur** | « aujourd'hui » est jugé dans la zone du lecteur. |
| 7 | B3b NOT_YET | `weather.availableFrom` | `useFormattedDate().formatDate` PPP (`WeatherStatusNotice.tsx:52`) | « La météo sera disponible à partir du 7 novembre 2026. » | **lecteur** | Sans date : « … sept jours avant le départ. » |
| 8 | B3c verdict Températures | `checkpoint.time` du plus chaud | `RouteVerdicts` `formatTime` (`RouteVerdicts.tsx:72`) | « Le plus chaud vers 12:00. » | évènement | |
| 9 | B3c verdict Pluie | `checkpoint.time` (alerte, première et dernière fenêtre) | `RouteVerdicts.tsx:94-122` | « Dès 10:40 (km 30), 70 %. » / « 60 % au plus, de 10:40 à 11:20 (km 30 à km 45). » | évènement | Plage « de … à … ». |
| 10 | B3c verdict Jour | `departure.sunrise`, `departure.sunset`, `leg.arrivalTime`, `leg.startTime` | `RouteVerdicts.tsx:202-230` | « Lever 07:45, coucher 17:20. Arrivée estimée 12:40. » ; réponse « 4 h 40 de marge » / « Arrivée 20 min après le coucher » / « Arrivée de nuit » ; « Départ avant le lever du soleil. » | évènement | **Deuxième** affichage de l'arrivée estimée (après #5). |
| 11 | B3c bloc des tronçons du tableau | `checkpoints[first/last].time` | `phaseTimes` (`RouteWeather.tsx:88-100`) | « 09:30–10:40 » (une seule heure si le tronçon tient en un point) | évènement | Plage. |
| 12 | B3c ligne « Heure » du tableau | `checkpoint.time` | `DesktopTimeline` `formatTime(...).replace(espaces, '\n')` (`RouteWeather.tsx:~475`) | « 09:30 » (en anglais « 9:30⏎AM » sur 2 lignes) | évènement | À partir de sm seulement. |
| 13 | B3c graduations de la bande (téléphone) | `checkpoints[tick].time` | `PhoneStrip` (`RouteWeather.tsx:~606`) | « 09:30 … 11:00 … 12:40 » | évènement | Sous sm seulement. Quelques graduations, pas une par point. |
| 14 | B3c détail du point | `checkpoint.time` | `CheckpointDetail` (`RouteWeather.tsx:~682`) ; annonce aria « {lieu}, {heure} » | « km 40  10:50 » | évènement | |
| 15 | B3c « Par tronçon » (téléphone) | heures des tronçons et des points | `PhaseList` (`RouteWeather.tsx:~808, ~891`) | « Face · km 0–30 », « 09:30–10:40 », et une ligne « 10:10 » par point | évènement | Sous sm seulement. |
| 16 | B3d « Au départ » (repli sans leg) | **`ride.dateTime`** (pas `group.startAt`) | `DepartureWeather` `useRendezvousFormat.formatTime` (`DepartureWeather.tsx:54`, prop `departureTime={ride.dateTime}` dans `GroupWeatherSection.tsx:49`) | « AU DÉPART 09:00 · 12° » | évènement | Choix délibéré (le serveur prévoit le point de RDV à l'heure de la sortie), mais l'heure diffère de « Départ 09:30 » de l'en-tête quand le groupe part plus tard. |
| 17 | B3d lever et coucher | `departure.sunrise`, `departure.sunset` | `<FormattedTime>` = `useFormattedDate` (`DepartureWeather.tsx:89,94`) | « 07:45 » / « 17:20 » | **lecteur** | Incohérent avec #10, qui les formate dans la zone de l'évènement. |
| 18 | Carte, popup d'un badge | `checkpoint.time` | `WeatherCheckpointMarkers.tsx:444` `rides.weather.map.checkpointTitle` | « km 40 · 10:50 » | évènement | Pas de préfixe de contexte sur la page groupe (`context` non passé, non vérifié en détail). |
| 19 | Carte, goutte de pluie | `alert.time` | `WeatherCheckpointMarkers.tsx:234` | « Pluie probable (70 %) vers 10:40, à km 30 » | évènement | |
| 20 | Plein écran, sous-titre | `startFor(ride, group)` | `DepartureLine withDay` → `formatDeparture` (`DepartureLine.tsx:63`, `utils/dateFormat.ts:220`) | « Demain · 09:30 » / « sam. 14 nov. · 09:30 » / « sam. 10 avr. 2027 · 09:30 » | évènement | Relatif (Aujourd'hui / Demain). Mention de fuseau en icône 🌐 avec infobulle, pas en ligne. |

Rien d'autre n'est daté sur la page : pas de date de création, pas de « il y a 2 h », pas de date
d'inscription, pas de date de retour estimé de la sortie, pas d'heure brute `group.time`.

---

## 5. Wireframes ASCII

### Desktop (≥ 1024 px, avec parcours)

```
 Équipes › Les Rouleurs › Agenda › Sortie du samedi › Groupe Rapide          (fil d'Ariane du Layout)
 ← Retour à la sortie                                                         [B0]
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│ [‹] [ Rapide · 11/12 | Moyen · 8/15 | Cool · 5 ]  [›]                    [B1a SiblingNav] │
│ Sortie du samedi                                              [Rejoindre] [✎ Modifier]     │
│ Groupe Rapide  (J'y vais|Complet) [⇪]                                    [B1b titre/actions]│
│ ┌──────┬───────────────────────────────────────────────────────────────────────────────┐ │
│ │ sam. │ Départ 09:30  (Demain)                                                        │ │
│ │  14  │ heure de Tokyo (ven. 01:30 chez vous)          ← seulement si fuseau ≠         │ │
│ │ nov. │ 📍 Place de la Mairie (1 rue X, Ville)                         [B1c DepartureBlock]│
│ └──────┴───────────────────────────────────────────────────────────────────────────────┘ │
│ 📍 Arrivée : Parking du lac (route Y)                                     [PlacesLine end] │
│ 11/12 personnes                                              1 place restante [GroupPlaces]│
│ ███████████████████████████████████████████████████████░░░░                               │
│ Votre inscription est dans le groupe Moyen. Voir le groupe    | Alert connexion/non-membre│
│ [Alert rouge erreur d'inscription]                                        [B1d/B1e]       │
└──────────────────────────────────────────────────────────────────────────────────────────┘
┌──────── colonne 380–440 px ─────────┐ ┌──────────── carte sticky (hauteur visible) ────────┐
│ [B2a Stats]                          │ │ [B2e RouteMapPanel]                    [⤢][+][−][▦]│
│ ⚡ ALLURE MOYENNE  ↔ DISTANCE        │ │                                                     │
│ 28 km/h            92 km             │ │        ~~~~ tracé (pente/revêt./vent) ~~~~          │
│ Arrivée estimée 12:40                │ │        (badges météo si mode Météo)                 │
│ ↑ DÉNIVELÉ POSITIF                   │ │ ┌─────────────────────────────────────────────────┐ │
│ 1 150 m                              │ │ │ profil altimétrique (overlay, 110–200 px)       │ │
├──────────────────────────────────────┤ │ └─────────────────────────────────────────────────┘ │
│ [B2b Capitaine] (si leader)          │ └─────────────────────────────────────────────────────┘
│ (◉) Léa Martin  [🛡 Capitaine]       │  Profil d'altitude provisoire (si PENDING)
├──────────────────────────────────────┤  [ Pente | Revêtement | Météo ]       [ColorByControl]
│ [B2c] Personnes inscrites  11 pers.  │  Vent sur le tracé : ▬Dos 32 km ▬Travers 18 ▬Face 40
│ [🔍 Rechercher par nom…           ]  │  Prévisions Open-Meteo               [WindMapLegend]
│ (◉🛡) Léa Martin / Capitaine      ›  │  ▬ Asphalte 82 % ▬ Gravier 18 %   [RouteSurfaceSummary]
│ (◉)   Paul Durand                 ›  │  Points du parcours (4)            [RouteWaypointList]
│ …            1–11 sur 11             │  12,4 km (☕) Café du port · Café
│        ‹ 1 ›                         │  …                     (défile dans la colonne sticky)
├──────────────────────────────────────┤
│ [B2d RouteCard] Boucle des lacs      │
│ 🗺 Voir le parcours ⬇ GPX ⬇ FIT      │
│ 📱 Envoyer vers l'appareil           │
└──────────────────────────────────────┘
┌──────────────────────────────── #meteo (pleine largeur) ─────────────────────────────────┐
│ Météo du parcours (Prévision ancienne)       Prévisions Open-Meteo · Mise à jour à 14:05 │
│ [notice d'état si NOT_YET / UNAVAILABLE / NO_LOCATION]                                    │
│ ┌Températures──┐┌Pluie─────────┐┌Vent──────────┐┌Jour──────────────┐   [RouteVerdicts]   │
│ │8° → 15°      ││Sec           ││Surtout de    ││4 h 40 de marge   │                      │
│ │9° au départ… ││              ││face          ││Lever… Arrivée…   │                      │
│ └──────────────┘└──────────────┘└──────────────┘└──────────────────┘                      │
│ Heure par heure, à votre passage                                                          │
│ Passages estimés à 28 km/h · un point tous les 10 km                                      │
│ Dos 32 km · Travers 18 km · Face 40 km                                                    │
│ Tronçons │  Face 09:30–10:40   │ Dos 10:40–12:40 …          [DesktopTimeline, défilant]   │
│ Heure    │ 09:30 │ 09:51 │ 10:13 │ …                                                      │
│ Temp.    │  9°   │ 10°   │ 11°   │                                                        │
│ Pluie    │  0 %  │ 10 %  │ 60 %  │                                                        │
│ Vent km/h│  15   │ 18    │ 20    │   Rafales │ … │   km │ 0 │ 10 │ 20 │                     │
│ ┌ km 40   10:50 ───────────────────────────────────────────────────── [CheckpointDetail] ┐ │
│ │ Température 12° …   Pluie 60 %   Vent ↗ 20 km/h rafales 35   Tronçon Face du km…       │ │
│ └────────────────────────────────────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────────────────────────────────┘
```

Sans parcours : pas de colonne carte. B2a, B2b et B2c prennent toute la largeur, il n'y a pas de B2d, et B3
affiche « AU DÉPART 09:00 · 12° … » suivi de « Ce groupe n'a pas de parcours… ».

### Étroit (< 1024 px ; détails téléphone < 768 px)

```
 Agenda? › Sortie du samedi › Groupe Rapide        (2 derniers niveaux sous sm)
 ← Retour à la sortie
┌───────────────────────────────┐
│ [‹][Rapide·11/12|Moyen|Cool][›]│ [B1a]
│ Sortie du samedi               │
│ Groupe Rapide (J'y vais) [⇪]   │
│ [Rejoindre] [✎ Modifier]       │ (actions passent à la ligne)
│ ┌────┬──────────────────────┐  │
│ │sam.│ Départ 09:30 (Demain)│  │ [B1c]
│ │ 14 │ 📍 Place de la Mairie │  │
│ │nov.│                      │  │
│ └────┴──────────────────────┘  │
│ 📍 Arrivée : Parking du lac    │
│ 11/12 personnes  1 place rest. │
│ ██████████████████████░░       │
│ [Alerts]                       │
└───────────────────────────────┘
┌───────────────────────────────┐
│ [B2e CARTE, avant la colonne] │  clamp(300px, 52svh, 560px), non sticky
│   … tracé …                    │
│ ┌ profil overlay ───────────┐ │
│ └───────────────────────────┘ │
└───────────────────────────────┘
 [Pente|Revêtement|Météo]  légende vent · revêtements
 Points du parcours (4) …
┌───────────────────────────────┐
│ [B2a Stats] 2 col. (<560 px)  │  (4 col. entre 560 et 1023 px)
├───────────────────────────────┤
│ [B2b Capitaine]               │
├───────────────────────────────┤
│ [B2c Personnes inscrites]     │
├───────────────────────────────┤
│ [B2d RouteCard]               │
└───────────────────────────────┘
┌──── #meteo ───────────────────┐
│ Météo du parcours             │
│ Prévisions … · Mise à jour …  │
│ [Temp.][Pluie]                │  verdicts 2×2 jusqu'à md
│ [Vent ][Jour ]                │
│ Heure par heure, à votre pass.│
│ Passages estimés à 28 km/h …  │
│ ╭ courbe temp. ─────────────╮ │  [PhoneStrip] < sm
│ │▁▃▅ barres pluie           │ │
│ │███ bande vent colorée     │ │
│ ╰ 09:30   10:40   12:40 ────╯ │
│ Glisser pour choisir un passage│
│ ●────────○──────────          │  (input range)
│ ┌ km 40  10:50 ─────────────┐ │  [CheckpointDetail] 2 col.
│ └───────────────────────────┘ │
│ Par tronçon                   │  [PhaseList] < sm uniquement
│ Dos 32 km · Travers 18 · Face │
│ Face · km 0–30   09:30–10:40  │
│   10:10 … 10:31 …             │
└───────────────────────────────┘
```

---

## 6. Étonnements

1. **L'arrivée estimée apparaît deux fois** : dans la tuile Allure (B2a, « Arrivée estimée 12:40 ») et dans
   le verdict Jour (B3c, « Arrivée estimée 12:40. »). Elle **disparaît de B2a quand le groupe n'a pas
   d'allure**, puisque c'est un `hint` de la tuile Allure (`StatsCard.tsx:86-99`), alors que le leg peut
   avoir une arrivée calculée à vitesse par défaut.
2. **Deux heures de départ différentes sur la page** : l'en-tête dit « Départ 09:30 » (`group.startAt`) et le
   repli météo sans parcours dit « AU DÉPART 09:00 » (`ride.dateTime`, `GroupWeatherSection.tsx:49`).
   C'est documenté (le serveur prévoit le point de RDV à l'heure de la sortie), mais rien ne l'explique à
   l'écran.
3. **Lever et coucher du soleil dans deux fuseaux** : la zone du lecteur dans `DepartureWeather`
   (`<FormattedTime>`, l. 89 et 94), la zone de l'évènement dans `RouteVerdicts` (l. 225-228). C'est
   contraire à la règle du CLAUDE.md frontend (« un rendezvous se lit dans la zone de son entité »).
4. **« J'y vais »** est le badge d'inscription (`rides.detail.groups.joined`). Le lexique racine cite
   « Vous participez » comme formulation de référence. À vérifier contre BRANDING §8.4 (non lu).
5. **Aucun indicateur d'annulation, de brouillon ou de sortie passée** sur la page groupe. Seuls effets :
   la section météo disparaît, le mode Météo aussi, et « Rejoindre » n'est plus proposé. « Quitter » reste
   offert sur une sortie annulée ou passée.
6. **Pas de description ni de consignes de la sortie** sur la page groupe, alors que l'étape a un
   `InstructionsBlock` et que la doc de `ChildDetailShell` cite « instructions » dans la colonne
   (`ChildDetailShell.tsx:27`). Pas de commentaires non plus (choix assumé).
7. **Le compte de personnes est affiché trois fois** : l'option du sélecteur (« Rapide · 11/12 »),
   `GroupPlaces` (« 11/12 personnes ») et l'en-tête de `ParticipantsSection` (« 11 personnes »).
   Pour un non-membre, ce bloc ne contient que ce compte : un Paper titré presque vide.
8. **Le lieu de départ est celui de la sortie** (`ride.startPlace`), au vert dans le DepartureBlock, et
   l'arrivée suit sur une ligne `PlacesLine` séparée, hors de la surface du bloc. Le DTO ne porte aucun
   lieu de RDV par groupe.
9. **Un chevron › sur chaque participant** (`ParticipantList.tsx:163-168`) alors que la ligne n'est pas
   cliquable (`cursor: default`) : une affordance trompeuse.
10. **Stats du plein écran ≠ stats de la page** : le plein écran montre distance, D+ et D− du **parcours**
    (`route.*`), la page montre `group.distance` et `group.elevationGain`. Je n'ai pas vérifié si elles
    peuvent différer.
11. **La carte est au-dessus de l'en-tête de contenu en étroit** : sous 1024 px, la carte (DOM après la
    colonne) remonte avant les stats et les participants. Sur tablette (768 à 1023 px), la carte fait au plus
    560 px, puis viennent les stats sur 4 colonnes.
12. **Mention de fuseau inégale** : en ligne dans le DepartureBlock, en icône dans le plein écran, et
    **absente** pour toutes les autres heures (arrivée, passages, verdicts) pourtant dans la même zone.
13. **Le profil altimétrique est posé sur la carte** sur la page, et en bandeau sous la carte en plein écran.
14. **Deux fils de retour en haut de page** : le fil d'Ariane du Layout et le lien « ← Retour à la sortie »
    du shell se suivent et mènent au même endroit.
15. La page **n'est jamais vue pour une sortie solo** : sur le web, l'équivalent « page groupe » d'une
    sortie à un groupe est la page de la sortie (`RideSoloGroupPanel`). Pour aligner le mobile, il faut
    donc comparer ces deux pages, pas celle-ci seule.
