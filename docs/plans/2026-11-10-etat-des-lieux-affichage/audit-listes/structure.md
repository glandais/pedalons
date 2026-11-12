# Audit des listes — axe « structure des pages de liste » (préfixe S)

Lu dans le code du worktree `feat/mobile-review` le 12 novembre 2026. Rien n'a été vérifié à l'écran. Chemins
abrégés : app = `mobile/lib/`, site = `frontend/src/`. Libellés français : app `mobile/assets/l10n/fr.json`,
site `frontend/src/locales/fr/common.json`.

## Synthèse

Les deux supports ont la même ossature : en-tête, barre d'outils, compteur, liste. Ils divergent surtout sur
**l'action de création**. Le site la place en bouton d'en-tête sur l'Agenda, les Publications, les Annonces, les
Équipes et l'accueil (raccourcis d'organisation). L'app ne l'offre qu'aux Parcours d'une équipe et aux Modèles :
nulle part sur l'Agenda, les Publications, les Annonces, les Équipes ni l'accueil. Ensuite vient **la bascule de vue** :
le site a un seul `ListViewSwitch` à icônes (« Vignettes · Lignes · Carte / Calendrier »), dont l'état vit dans l'URL ;
l'app a des segmentés distincts (« Liste / Carte » plus « Vignettes / Compact » pour les Parcours, « Liste /
Calendrier » à icônes pour l'Agenda), et la vue des parcours est persistée globalement. Le **calendrier global** du
site n'a aucun filtre (type, équipe), là où l'app en a deux. Les barres d'outils de l'app sont épinglées ; celles du
site ne le sont jamais.

---

## 1. Fil d'accueil

| # | Sujet | Listes concernées | App (valeur · fichier:ligne) | Site (valeur · fichier:ligne) | Verdict | Gravité |
|---|---|---|---|---|---|---|
| S1 | Titre de page | Accueil | Aucun titre de page : barre supérieure « Pédalons » (`app.name`), wordmark, cloche et avatar · `features/home/presentation/pages/home_page.dart:89-124` | Salutation « Bonjour {nom} » (`home.member.greeting`) et date au-dessus des blocs · `pages/home/MemberHome.tsx:52-71` | tient au support | faible |
| S2 | Titre de la section du fil | Accueil | En-tête de section « Dernières publications » (`home.latestPublications`), avec le compte à droite (« 1 248 publications », `home.publicationCount`), **sous** la barre d'outils · `features/feed/presentation/widgets/publication_feed_view.dart:283-299` | Titre H2 « Dernières publications » (`home.feed.title`) **au-dessus** de la barre, puis `ResultCount` sous les chips · `components/home/HomeFeedSection.tsx:93-96,145` | écart (ordre titre / barre) | faible |
| S3 | Contrôles de la barre, de gauche à droite | Accueil | Rangée 1 : recherche (« Rechercher une publication… »). Rangée 2 (chips) : chip de portée par rôle (icône réglage, « Toutes les équipes » / Membre / Organisateur / Administrateur, en feuille), puis chips de type « Tout / Sorties / Publications / Voyages » · `publication_feed_view.dart:521-546,586-608,627-632` | Rangée 1 : recherche, segmenté de période « Tout / À venir / Je participe » (`publications.scope.*`), liste déroulante de rôle « Toutes les équipes / Membre / Organisateur / Administrateur » (connecté). Rangée 2 : chips « Tous / Sorties / Publications / Voyages » · `HomeFeedSection.tsx:101-143` | écart : l'app n'a pas de contrôle de période (le détail relève de l'axe filtres) | forte |
| S4 | Libellé de la chip « tout » | Accueil | « Tout » (`home.feed.all`) · `publication_feed_view.dart:615` | « Tous » (`teams.publications.list.filter.all`) · `HomeFeedSection.tsx:139` | écart | faible |
| S5 | Barre fixe au défilement | Accueil | Barre épinglée (`PdlPinnedToolbar`) ; la barre supérieure `pinned, floating, snap` · `publication_feed_view.dart:265-282`, `home_page.dart:89-92` | Rien d'épinglé (aucun `sticky` dans `pages/` ni dans les composants de liste) | tient au support | faible |
| S6 | Densité | Accueil | Une colonne de `PublicationCard`, largeur bornée par `ContentWidthConstraint`, quelle que soit la largeur · `publication_feed_view.dart:429-444` | `PublicationCard` dans `SimpleGrid cols={{ base: 1, sm: 2, lg: 3 }}` · `HomeFeedSection.tsx:164` | tient au support | faible |
| S7 | Action de création | Accueil | Aucune | `QuickActions` pour qui organise au moins une équipe : « Créer une sortie », « Ajouter un parcours », « Rédiger une publication », avec un menu de choix d'équipe quand il y en a plusieurs ; calcul local (`canOrganize`, modules de l'équipe) · `MemberHome.tsx:69`, `components/home/QuickActions.tsx:34-62` | écart : action d'un seul côté | forte |
| S8 | Pagination et retour | Accueil | Défilement continu ; filtres en mémoire (providers Riverpod), conservés tant que l'onglet vit (`StatefulShellRoute.indexedStack`) ; un détail se pousse au-dessus, la liste reste montée · `config/router.dart:1078-1100` | Filtres dans l'URL (`?q=`, `?type=`, `?w=`, `?role=`, `?p=`) · `hooks/filters/homeFilters.ts:15-20`, `hooks/filters/common.ts:13`, `membership.ts:18` ; position restaurée au retour (`useScrollRestoration`, POP) · `components/common/Layout.tsx:83` | tient au support | — |
| S9 | Chemin | Accueil | `/` (`home`, lien profond), aucun paramètre lu | `/`, filtres dans la chaîne de requête | tient au support | faible |

## 2. Fil d'une équipe (Publications) et cadre des sections

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| S10 | Rangée des sections d'équipe | toutes les sections | Rangée de chips épinglée sous l'en-tête d'équipe, ordre « Tableau de bord, Agenda, Publications, Parcours, Annonces, Membres, À propos » (`teams.tabs.*`) · `features/teams/presentation/widgets/team_sections.dart:160-233`, `team_sections_bar.dart:20-64` | `NavButtons` (rangée défilante `ScrollArea`, non collante), même ordre et mêmes libellés · `hooks/useNavItems.ts:186-264`, `components/team/TeamLayout.tsx:140` | identique (ordre) ; collant contre défilant tient au support | — |
| S11 | Condition de la section Annonces | Annonces | `isMember && team.enableAds` : un administrateur de la plateforme qui n'est pas membre n'a pas la chip · `team_sections.dart:210` | `canReadAds = isMember \|\| isPlatformAdmin` · `useNavItems.ts:196,232` | écart | faible |
| S12 | Retour depuis une section | toutes les sections | Flèche de l'en-tête : `context.go(Paths.teams())`, toujours « Mes équipes », jamais l'écran précédent · `team_header.dart:134-138` ; le nom ouvre le sélecteur d'équipes ou le tableau de bord · `team_header.dart:302-309` | Fil d'Ariane « Équipes › {équipe} › {section} » (`parentId: 'team-detail'`) et retour du navigateur · `config/routes.config.ts` (entrées `team-directory`, `routes`, `ads`) | tient au support | faible |
| S13 | Titre de la section | Publications | Aucun titre : la chip active de la rangée en tient lieu · `team_home_page.dart:250-265` | H2 « Publications » (`teams.detail.tabs.posts`) · `pages/team/TeamPostsPage.tsx:76` | écart | faible |
| S14 | Barre d'outils | Publications | Recherche « Rechercher une publication… » (`teams.posts.searchPlaceholder`), puis chip « Tags » quand l'équipe en a ; deux barres épinglées l'une sous l'autre (sections puis recherche) · `team_home_page.dart:250-265`, `publication_feed_view.dart:265-282` | Recherche « Rechercher par titre ou description... » (`teams.posts.search.placeholder`), puis `TagFilter` sur la même ligne · `TeamPostsPage.tsx:88-104` | identique (composition) ; invite différente | faible |
| S15 | Action de création | Publications | Aucune dans la section. « Nouvelle publication » n'existe qu'au tableau de bord, et ouvre le site (`openTeamWebPage`) · `team_dashboard_page.dart:215,256-266` | Bouton d'en-tête « Nouvelle publication » (`posts.create.title`), pour un organisateur si `enablePosts` ; calcul local (`teamAccess().isOrganizer`) · `TeamPostsPage.tsx:63,77-85` | écart : action d'un seul côté dans la liste | forte |
| S16 | Densité | Publications | Une colonne de `PublicationCard` · `publication_feed_view.dart:429-444` | `SimpleGrid` 1 / 2 / 3 colonnes · `TeamPostsPage.tsx:116` | tient au support | faible |
| S17 | Chemin | Publications | `teamPosts` `/equipes/{teamSlug}/articles`, lien profond ; aucun paramètre de requête lu · `config/router.dart:714-717` | Même chemin ; `?q=`, `?tags=`, `?p=` | tient au support | faible |

## 3. Agenda d'une équipe

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| S18 | Titre | Agenda | Aucun titre (la chip « Agenda » de la rangée) · `features/teams/presentation/pages/team_agenda_page.dart:139-175` | H2 « Agenda » (`teams.detail.tabs.agenda`) · `pages/team/TeamAgendaPage.tsx:140` | écart | faible |
| S19 | Ordre de la barre | Agenda | Ligne 1 : segmenté de période « À venir / Je participe / Passées » à gauche, bascule de vue à droite. Ligne 2 : recherche « Rechercher dans l'agenda… ». Ligne 3 : chips « Tout / Sorties / Voyages », puis « Tags » une fois le type choisi. Tout est épinglé · `team_agenda_page.dart:152-160,179-247`, `publication_feed_view.dart:513-549` | Ligne 1 : segmenté de période, segmenté de type « Tout / Sorties / Voyages », bouton « Filtres » repliable. Le panneau replié contient la recherche (« Rechercher par titre ou description... ») et les tags. La bascule de vue est sur la ligne du compteur, à droite · `TeamAgendaPage.tsx:170-235`, `components/agenda/AgendaFilterBar.tsx:72-89` | écart : recherche toujours visible dans l'app, derrière « Filtres » sur le site ; le type est en chips d'un côté, en segmenté de l'autre | moyenne |
| S20 | Vues offertes | Agenda | Deux : « Liste » / « Calendrier », icônes seules (`PdlIcons.list`, `PdlIcons.calendar`), étiquette d'accessibilité « Affichage » · `team_agenda_page.dart:215-243` | Trois : « Vignettes · Lignes · Calendrier » (`listView.*`, icônes `IconLayoutGrid`, `IconList`, `IconCalendar`), précédées du libellé visible « Affichage » · `TeamAgendaPage.tsx:110,235`, `components/common/ListViewSwitch.tsx:18-23,56-80` | écart : pas de vue en lignes dans l'app | moyenne |
| S21 | Condition du calendrier | Agenda | Rôle dans l'équipe ou administration de la plateforme · `team_agenda_page.dart:91` | Pareil, **et** `enableRides \|\| enableTrips` · `TeamAgendaPage.tsx:108-110` | identique en pratique (la section Agenda exige déjà l'un des deux modules) | — |
| S22 | Persistance de la vue | Agenda | État du widget (`setState`) : non persistée, perdue en quittant la section ; ouverte en calendrier par `teamCalendar` · `team_agenda_page.dart:85-87`, `config/router.dart:719-723` | « Lignes » dans `?view=row` ; le calendrier est un autre chemin (`teamCalendar`, navigation) · `TeamAgendaPage.tsx:111-118`, `hooks/filters/agendaFilters.ts:36,45-47` | tient au support | faible |
| S23 | Filtres d'une vue à l'autre | Agenda | Le type et « Je participe » passent au calendrier ; « Passées » y redevient « Tout » · `team_agenda_page.dart:123-131,183-185` | Le type et `?w=me` passent dans les deux sens ; la période ne passe pas · `TeamAgendaPage.tsx:318-329`, `pages/calendar/TeamCalendarPage.tsx:79-87` | identique | — |
| S24 | Action de création | Agenda | Aucune. « Créer une sortie » n'est qu'au tableau de bord (organisateur, `enableRides && enableRoutes`, calcul local) · `team_dashboard_page.dart:213-254` | Bouton d'en-tête « Créer une sortie » (`rides.create.title`), avec un menu « Créer autre chose » (`aria.createOther`) qui offre « Créer un voyage » (`trips.create.title`) ; organisateur, calcul local · `TeamAgendaPage.tsx:96-104,139-165` | écart : action d'un seul côté | forte |
| S25 | Densité | Agenda | Une colonne de `PublicationCard` · `publication_feed_view.dart:429-444` | `PublicationCard` en grille 1 / 2 / 3, ou `AgendaRow` en pile en vue Lignes · `TeamAgendaPage.tsx:244-268` | écart (suit S20) | faible |
| S26 | Chemins et liens profonds | Agenda | `teamAgenda` lit `?type=ride\|trip` et `?w=me\|past` ; `teamRides`, `teamTrips`, `teamCalendar` y mènent aussi. Recherche, tags et `?view=` ne sont pas lus · `team_sections.dart:39-68`, `config/router.dart:713-733` | Les mêmes chemins ; `?q=`, `?type=`, `?w=`, `?tags=`, `?view=`, `?p=` · `agendaFilters.ts:28-47` | tient au support (seule liste de l'app qui lit des paramètres) | faible |

## 4. Calendrier (global et d'équipe)

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| S27 | Titre et retour | Calendrier global | Barre « Calendrier » (`calendar.title`), avec un bouton « Aujourd'hui » (`calendar.today`) à droite · `features/calendar/presentation/pages/calendar_page.dart:143-157` | H2 « Calendrier » ; « Aujourd'hui » est dans l'en-tête du composant `Schedule` (`calendar.schedule.today`) · `pages/calendar/CalendarPage.tsx:24-26`, `components/calendar/CalendarView.tsx:85-87` | identique (même sens, autre place) | faible |
| S28 | Barre d'outils | Calendrier global | Flèche mois précédent, « mois année », flèche mois suivant. Puis le sélecteur de portée « Toutes mes équipes » (au-delà de trois équipes), ou des chips d'équipe sur la même rangée que le type. Puis chips de type « Tout / Sorties / Voyages » · `widgets/calendar_toolbar.dart:64-151` | Seulement l'en-tête de `Schedule` (précédent / suivant / aujourd'hui / niveau de vue). **Ni filtre de type, ni choix d'équipe** · `CalendarPage.tsx:23-36` | écart : critères d'un seul côté (l'API `GET /calendar/events` prend `from`/`to` ; le type est filtré côté client des deux côtés, et le site le fait déjà sur le calendrier d'équipe) | forte |
| S29 | Vues offertes | Calendrier global et d'équipe | Une seule : grille du mois repliable (poignée chevron) au-dessus d'une liste d'agenda par jour (`AgendaCard`), séparateur « À venir » · `calendar_page.dart:170-209,231-346` | `Schedule` de Mantine en `layout="responsive"` : Jour / Semaine / Mois / Année (`calendar.schedule.*`), Mois par défaut ; sur téléphone, mois et liste du jour choisi · `CalendarView.tsx:111,429-451` | écart : pas de semaine ni de jour dans l'app ; la forme téléphone du site ressemble à l'app | moyenne |
| S30 | Persistance de la vue et du mois | Calendrier | Mois dans `calendarMonthKeyProvider(teamSlug)`, en mémoire · `calendar_page.dart:77-79,479-487` | Niveau de vue et date en `useState`, ni URL ni stockage · `CalendarView.tsx:111-120`, `hooks/useCalendarDateRange.ts:56` | identique (aucune persistance) | — |
| S31 | Abonnement au calendrier | Calendrier global et d'équipe | Carte « Abonnement calendrier » (`calendar.subscription.title`) en **dernière entrée de la liste** (« S'abonner », « Régénérer le lien ») ; flux de l'équipe dans la section · `calendar_page.dart:182-204`, `widgets/calendar_subscription_card.dart:63-97` | `IcsFeedSettings` **sous** le calendrier, sans titre (description, URL, « S'abonner », « Régénérer le lien ») ; flux d'équipe sur `TeamCalendarPage` · `CalendarPage.tsx:34`, `TeamCalendarPage.tsx:115`, `components/calendar/IcsFeedSettings.tsx:60-80` | identique (titre en plus dans l'app) | faible |
| S32 | Calendrier d'équipe | Agenda en vue Calendrier | Section d'équipe : rangée des sections, puis période (« Tout / Je participe ») et bascule, puis la barre du calendrier sans portée, avec « Aujourd'hui » · `team_agenda_page.dart:98-136`, `calendar_toolbar.dart:88-99` | H2 « Agenda », `AgendaFilterBar` en mode calendrier, `ListViewSwitch` (Vignettes, Lignes, Calendrier), `Schedule` · `TeamCalendarPage.tsx:90-113` | identique (composition) | — |
| S33 | Clic sur un événement | Calendrier | `context.push` vers la sortie ou l'étape · `widgets/agenda_card.dart:47-52` | `navigate` vers la sortie ou l'étape · `CalendarView.tsx:408-424` | identique | — |
| S34 | Chemins | Calendrier | `/calendrier` (onglet 3), `/equipes/{slug}/calendrier` (Agenda en vue Calendrier) ; liens profonds | `/calendrier` ; `teamCalendar`, réservé aux membres (sinon redirection vers l'Agenda) · `TeamCalendarPage.tsx:70-75` | identique | — |

## 5. Parcours d'une équipe, Tous les parcours, carte des parcours

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| S35 | Titre | Explorer (tous) | Barre « Explorer » (`nav.explore`) · `features/routes/presentation/pages/routes_page.dart:127-132` | **Aucun titre** sur la page ; fil d'Ariane « Explorer » (liste), « Explorer › Carte » (carte) · `pages/route/AllRoutesPage.tsx:28-71`, `config/routes.config.ts` (`all-routes`, `all-routes-map`) | écart | faible |
| S36 | Titre | Parcours d'une équipe | Aucun titre (la chip « Parcours ») · `team_home_page.dart:275-282` | H2 « Parcours » (`routes.list.title`), sur la liste comme sur la carte · `pages/route/RouteListPage.tsx:59`, `pages/route/RoutesMapPage.tsx:42` | écart | faible |
| S37 | Ordre de la barre | Parcours, Explorer | Ligne 1 : recherche « Rechercher un parcours… », bouton de filtres avec un compteur (feuille `RouteFilterSheet`), puis « Ajouter » (équipe). Ligne 2 (liste, Explorer seulement) : sélecteur de portée « Toutes mes équipes » (équipe et rôle minimum, en feuille). Ligne 3 : segmenté « Liste / Carte ». Ligne 4 (liste) : chips de filtres actifs. Le tout épinglé · `widgets/routes_toolbar.dart:61-133` | Explorer : `MembershipSelect` (rôle seul), puis le bouton « Filtres » / « Masquer les filtres » qui déplie un panneau où se trouve **la recherche** (« Rechercher par nom ou description... »). Équipe : panneau puis `TagFilter`. Ensuite la ligne « compteur ⟷ bascule » · `AllRoutesPage.tsx:29-50`, `RouteListPage.tsx:74-96`, `components/route/RouteFilterPanel.tsx:79-110` | écart : recherche toujours visible dans l'app, repliée sur le site ; l'app propose aussi le choix d'une équipe sur Explorer, le site seulement le rôle | moyenne |
| S38 | Vues et densité | Parcours, Explorer | Deux contrôles distincts : segmenté « Liste / Carte » à libellés et icônes, dans la barre · `routes_toolbar.dart:106-126` ; segmenté « Vignettes / Compact » (`routes.density.*`) sur la ligne du compteur · `routes_page.dart:432-453` | Un seul `RouteViewSwitch` à icônes : « Vignettes · Lignes · Carte » (`listView.*`), sur la ligne du compteur · `components/route/RouteViewSwitch.tsx:19,56`, `ListViewSwitch.tsx:56-80` | écart : un contrôle contre deux, « Compact » contre « Lignes » | moyenne |
| S39 | Vue par défaut, persistance | Parcours, Explorer | Vue et densité dans `SharedPreferences`, **communes** à toutes les équipes et à Explorer ; l'onglet Explorer s'ouvre sur la carte (`allRoutesMap` force la carte) ; basculer ne change pas l'adresse · `providers/route_list_provider.dart:95-150`, `pages/all_routes_map_page.dart:9-17`, `config/router.dart:1124-1144` | Carte = chemin distinct (`/parcours/carte`, `/equipes/{slug}/parcours/carte`) ; densité dans `?view=`, sans mémoire au-delà de l'URL ; l'entrée « Explorer » mène à la carte · `RouteViewSwitch.tsx:34-53`, `hooks/useNavItems.ts:75` | tient au support (URL contre préférence) ; à noter, côté app, qu'une carte choisie dans une équipe rouvre Explorer sur la carte | faible |
| S40 | Densité automatique | Parcours, Explorer | Vignettes jusqu'à 200 résultats, compact au-delà, une seule fois et annoncé par un bandeau · `domain/route_filters.dart:50`, `routes_page.dart:332-347` | Même seuil 200, `resolveRouteDensity`, sans bandeau · `hooks/filters/routeFilters.ts:33,42-48` | identique (seuil) ; bandeau dans l'app seulement | faible |
| S41 | Filtres d'une vue à l'autre | Parcours, Explorer | Un seul `routeFiltersProvider(teamSlug)` sert la liste et la carte ; en carte, la portée et les chips se cachent, le compteur du bouton reste · `routes_page.dart:88-121`, `routes_toolbar.dart:16-30` | La chaîne de requête suit la navigation (sans `p` ni `view`) ; en carte, le tri se cache (`showSort={false}`), les tags restent (équipe) · `RouteViewSwitch.tsx:37-45`, `RoutesMapPage.tsx:44-56` | identique | — |
| S42 | Action de création | Parcours d'une équipe | « Ajouter » (`routes.editor.add`, lu « Ajouter un parcours ») dans la barre, à droite des filtres, **en liste comme en carte** ; `canManageRoutesProvider` = `enableRoutes` et rôle organisateur / admin ou plateforme, calcul local · `routes_page.dart:135-158`, `features/rides/domain/ride_permissions.dart:34-41` | En-tête de la liste : `UploadGpxFiles` et « Créer un nouveau parcours » (`routes.create.title`), pour un organisateur (calcul local) ; **absents de la page carte** ; le même bouton revient dans l'état vide · `RouteListPage.tsx:53-68,117-121`, `RoutesMapPage.tsx:40-68` | écart : libellés, place, pas d'import en lot dans l'app | moyenne |
| S43 | Densité des lignes | Parcours | Une colonne de `RouteCard` ou `CompactRouteRow` · `routes_page.dart:292-305` | `RouteCard` en grille 1 / 2 / 3 ou `RouteRow` en pile · `components/route/RouteListContent.tsx:57,79-82` | tient au support | faible |
| S44 | Retour | Parcours | `PageStorageKey('routes-list-<slug>')` : décalage rendu au retour de la carte comme d'un détail · `routes_page.dart:171-174` | Restauration au retour du navigateur (POP) · `Layout.tsx:83` | identique | — |
| S45 | Chemins et liens profonds | Explorer | `/parcours` et `/parcours/carte` : `deeplink: false`, un lien partagé s'ouvre dans le navigateur · `contracts/routes.yaml:254-267` | Les mêmes, filtres dans l'URL | tient au support | faible |
| S46 | Carte d'une équipe, adresse propre | Parcours d'une équipe | Pas de chemin `/equipes/{slug}/parcours/carte` dans l'app (`routesMap` est `web` seulement), la carte n'est qu'un état ; l'AASA exclut ce chemin (`NOT /equipes/*/parcours/carte`), il s'ouvre donc dans le navigateur · `contracts/routes.yaml:711-717`, `frontend/public/.well-known/apple-app-site-association:42-43` | Chemin propre `routesMap` | tient au support | faible |

## 6. Annonces

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| S47 | Titre | Annonces | Aucun (la chip « Annonces ») · `team_home_page.dart:283-290` | H2 « Annonces » (`ads.title`) · `pages/ad/AdListPage.tsx:112` | écart | faible |
| S48 | Ordre de la barre | Annonces | Recherche « Rechercher une annonce » ; chips : tri en premier (`sortStyle`, en feuille), « Tous », un chip par type, « Tags ». Épinglée · `features/ads/presentation/widgets/ads_toolbar.dart:37-93`, `pages/ads_page.dart:72-74` | Ligne 1 : recherche « Rechercher par titre ou description... », liste « Tous les types », liste de tri. Ligne 2 : prix mini, prix maxi. Puis `TagFilter` · `AdListPage.tsx:126-207` | écart : tri en tête dans l'app, en fin de ligne sur le site ; prix sur le site seulement (axe filtres) | moyenne |
| S49 | Action de création | Annonces | **Aucune** : pas de chemin `adNew` dans l'app (`web: true` seul) · `contracts/routes.yaml:765-770` | Bouton d'en-tête « Créer une annonce » (`ads.list.createAd`), pour tout membre (`isMember`, calcul local) · `AdListPage.tsx:113-121` | écart : action d'un seul côté | forte |
| S50 | Densité | Annonces | Une colonne de `AdCard` · `ads_page.dart:170-181` | `AdCard` en grille 1 / 2 / 3 · `AdListPage.tsx:240-249` | tient au support | faible |
| S51 | Non-membre | Annonces | La chip n'existe pas pour lui (S11) | Page avec titre et état « réservé aux membres » ; la plateforme lit la liste · `AdListPage.tsx:78-89` | tient au support | faible |
| S52 | Chemin | Annonces | `ads` (`teamAds`), `mobile: true` mais `deeplink: false` ; le motif `/equipes/*` de l'AASA l'attrape quand même (commentaire du contrat) · `contracts/routes.yaml:401-404,756-764` | `?q=`, `?type=`, `?pmin=`, `?pmax=`, `?sort=`, `?dir=`, `?tags=`, `?p=` · `hooks/filters/adFilters.ts:33-37` | tient au support | faible |

## 7. Mes équipes, découvrir des équipes

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| S53 | Nombre d'écrans | Équipes | Deux : « Mes équipes » (`teams.title`, `/equipes`) et « Découvrir des équipes » (`teams.discovery.title`, `/equipes/decouvrir`) · `teams_page.dart:79-96`, `teams_discover_page.dart:67-71` | Un seul : « Équipes » (`teams.title`), sous-titre « Parcourez les équipes cyclistes ou créez la vôtre » (`teams.list.subtitle`) ; `teamsDiscover` est `web: false`, `webFallback: teams` · `pages/team/TeamListPage.tsx:61-66`, `contracts/routes.yaml:336-344` | écart de forme, sens voisin | moyenne |
| S54 | Barre | Mes équipes | Pas de barre : loupe et « Découvrir » en icônes d'app bar (Material `AppBar`, pas `PdlAppBar`) ; la loupe fait apparaître un champ local non épinglé · `teams_page.dart:79-111` | Recherche « Rechercher des équipes... » et liste de rôle (« Toutes / Membre / Organisateur / Administrateur », connecté) · `TeamListPage.tsx:70-93` | écart | moyenne |
| S55 | Barre | Découvrir | Recherche épinglée « Rechercher une équipe » ; chips « Toutes / Ouvertes à l'adhésion / Mes équipes » · `teams_discover_page.dart:78-81,260-300` | — (voir S53) | — | — |
| S56 | Action de création | Équipes | **Aucune** (pas de `teamsNew` dans l'app) · `contracts/routes.yaml:344-348` | Bouton d'en-tête « Créer une équipe » (`teams.create.title`), connecté (et hors mode équipe unique), repris dans l'état vide · `TeamListPage.tsx:46-57,62-66,141` | écart : action d'un seul côté | forte |
| S57 | Invitations en attente | Mes équipes | `PendingInvitationsCard` en tête · `teams_page.dart:99` | `PendingInvitationsBanner` en tête · `TeamListPage.tsx:59` | identique | — |
| S58 | Densité et clic | Équipes | Une colonne de `TeamDiscoveryCard` ; clic → `pushLocation(Paths.team)` · `teams_page.dart:202-216`, `widgets/team_discovery_card.dart:73` | `TeamCard` en grille 1 / 2 / 3 · `TeamListPage.tsx:108-112` | tient au support | faible |

## 8. Membres d'une équipe

Le site a deux écrans : `TeamDirectoryPage` est la liste des membres (`/equipes/{slug}/membres`) ; `TeamMembersPage`
(`/admin/membres`) est l'écran d'administration, site seulement, que l'app ouvre dans le navigateur
(`appScreen: false`). La table du brief range `TeamMembersPage` en face de la liste de l'app : c'est
`TeamDirectoryPage` qu'il faut comparer.

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| S59 | Titre et compteur | Membres | Pas de titre (chip « Membres ») ; compteur « N membres » sous la barre · `team_members_page.dart:206-219` | H2 « Membres » (`teams.detail.members.title`) avec `ResultCount` **sur la même ligne**, au-dessus de la barre · `pages/team/TeamDirectoryPage.tsx:79-82` | écart (place du compteur) | faible |
| S60 | Barre | Membres | Recherche épinglée « Rechercher un membre » ; chips « Tous » + un chip par rôle quand les rôles sont montrés · `team_members_page.dart:116-120,268-320` | Recherche « Rechercher par nom... » et liste « Rôle » / « Tous les rôles » (si rôles montrés) · `TeamDirectoryPage.tsx:97-122` | identique (même composition, autre forme) | faible |
| S61 | Densité et clic | Membres | `PdlPersonRow` en liste ; toucher la ligne ouvre le menu de modération (« ⋯ »), rien sur sa propre ligne · `team_members_page.dart:327-381` | `TeamMemberList` (un `Paper`) · `TeamDirectoryPage.tsx:156` | tient au support | faible |
| S62 | Action d'administration | Membres | Aucune dans la liste | Aucune dans la liste ; « Gérer » est dans l'en-tête d'équipe pour un organisateur · `TeamLayout.tsx:126-130` | identique dans la liste | — |

## 9. Personnes inscrites

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| S63 | Forme | Personnes inscrites | Toujours une **feuille** `ParticipantsSheet` : titre « Personnes inscrites » (`participants.title`), sous-titre (groupe ou voyage), pastille du compte ; pour un groupe, une sortie entière (tous groupes) ou un voyage · `features/participants/presentation/widgets/participants_sheet.dart:58,86,102,128-160` ; ouverte par la pile d'avatars ou « Voir toutes les personnes inscrites » · `rides/presentation/widgets/ride_group_participants_section.dart:124,144` | **Section en ligne** « Personnes inscrites » (`rides.group.participantsTitle`) sur la page de groupe, la sortie à un groupe et le voyage, recherche et page dans l'URL · `components/publication/ParticipantsSection.tsx:38-70`, `pages/ride/RideGroupPage.tsx:270`, `pages/trip/TripDetailPage.tsx:213` ; **fenêtre** titrée du nom du groupe depuis une carte de groupe, état en `useState` · `components/ride/ParticipantListModal.tsx:32-51`, `components/ride/RideGroupCard.tsx:243-250` | écart (feuille contre section) ; tient en partie au support | moyenne |
| S64 | Barre | Personnes inscrites | Recherche seule « Rechercher une personne… » · `participant_list_view.dart:106-111` | Recherche seule « Rechercher par nom… » (section) · `ParticipantsSection.tsx:69` | identique | faible |

## 10. Notifications

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| S65 | Titre et retour | Notifications | « Notifications », flèche retour (pile, sinon l'accueil) · `features/notifications/presentation/pages/notifications_page.dart:58-65` | H2 « Notifications », colonne de 672 px de large · `pages/notification/NotificationListPage.tsx:28-29` | identique | — |
| S66 | Actions secondaires | Notifications | Icônes d'app bar : réglages (étiquette « Réglages des notifications »), puis « Tout marquer lu » (icône `done`, quand une non lue existe) · `notifications_page.dart:66-83` | Boutons texte : « Tout marquer lu » (`unreadCount > 0`), puis « Réglages » · `NotificationListPage.tsx:31-48` | identique (sens), forme différente (icône contre libellé) et ordre inversé | faible |
| S67 | Filtre | Notifications | Segmenté épinglé « Toutes / Non lues » · `notifications_page.dart:93-117` | Interrupteur « Non lues uniquement » à gauche, compteur à droite · `NotificationListPage.tsx:54-61` | écart de forme | faible |
| S68 | Bandeau push | Notifications | `PushActivationBanner` sous la barre · `notifications_page.dart:118` | — (web push réglé ailleurs) | tient au support | — |

## 11. Modèles de sortie

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| S69 | Cadre | Modèles | Écran plein, « Modèles de sortie » (`rides.templates.listTitle`), flèche retour (`pop`) · `features/rides/presentation/pages/ride_template_list_page.dart:80-84` | Dans `TeamAdminLayout` (onglet d'administration « Modèles de sortie »), H2 « Modèles de sortie » · `pages/ridetemplate/RideTemplateListPage.tsx:87-90` | tient au support | faible |
| S70 | Action de création | Modèles | Icône « + » d'app bar (étiquette « Nouveau modèle ») et bouton dans l'état vide · `ride_template_list_page.dart:85-92,170-172` | Bouton d'en-tête « Créer un modèle » (`rideTemplates.create.title`), et dans l'état vide · `RideTemplateListPage.tsx:91-100` | écart de libellé et de forme (« Nouveau modèle » contre « Créer un modèle ») | faible |
| S71 | Accès | Modèles | Porte `RideTemplateAccessGate` : un membre simple est refusé (`canManageRidesProvider`, calcul local) · `widgets/templates/ride_template_gate.dart:84-100` | La page s'ouvre à tout membre, seul le bouton dépend de `canManage` (calcul local) · `RideTemplateListPage.tsx:61,91` | écart | moyenne |
| S72 | Barre et compteur | Modèles | Recherche épinglée « Rechercher un modèle… » (`PdlScreenScaffold.toolbar`), compteur « N modèles » · `ride_template_list_page.dart:94-103,195-200` | Recherche « Rechercher par nom... », **pas de compteur** · `RideTemplateListPage.tsx:103-109` | écart | faible |
| S73 | Clic sur un modèle | Modèles | Toucher la carte ouvre l'édition ; « ⋯ » ouvre le menu · `ride_template_list_page.dart:212-222` | Boutons sur la carte (utiliser, modifier, supprimer) · `components/ridetemplate/RideTemplateCard.tsx:75-101` | hors axe (contenu de carte) | — |
| S74 | Points d'entrée | Modèles | Tableau de bord (« Voir tout ») et éditeur de sortie · `dashboard/dashboard_admin.dart:44`, `ride_editor_page.dart:386` | Onglets d'administration de l'équipe | tient au support | — |

## 12. Personnes bloquées

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| S75 | Cadre | Personnes bloquées | « Personnes bloquées », retour vers « Vie privée », texte d'aide en tête, `PdlPersonRow` + « Débloquer » · `features/moderation/presentation/pages/blocked_users_page.dart:70-87,167-188` | `ProfileShell` « Personnes bloquées » (barre latérale du profil sur grand écran), description, liste, « Débloquer » · `pages/profile/BlockedUsersPage.tsx:6-12` | identique | — |

## 13. Listes du site seulement

- Mes aperçus GPX (`pages/gpxtool/…`, `/outils-gpx/mes-fichiers`) : site seulement.
- Lieux, tags, signalements et pages d'une équipe (`TeamPlacesPage`, `TeamTagsPage`, `TeamReportsPage`, `TeamPagesAdminPage`) : site seulement.
- Membres côté administration (`TeamMembersPage`, `/equipes/{slug}/admin/membres`) : site seulement, l'app ouvre le navigateur (`appScreen: false`, `contracts/routes.yaml:492-501`). **Cette liste manque à la table du brief.**

---

## Incohérences internes à l'app

| # | Sujet | Valeurs | Gravité |
|---|---|---|---|
| S76 | Action de création | Trois formes : bouton « Ajouter » dans la barre (Parcours, `routes_page.dart:150-156`), icône « + » d'app bar (Modèles, `ride_template_list_page.dart:86-91`), boutons du tableau de bord (« Créer une sortie », « Nouvelle publication » vers le site, `team_dashboard_page.dart:248-266`) ; rien sur l'Agenda, les Publications, les Annonces | moyenne |
| S77 | Bascule de vue | L'Agenda : segmenté à icônes seules, à droite de la période (`team_agenda_page.dart:215-243`). Les Parcours : segmenté pleine largeur à libellés et icônes (`routes_toolbar.dart:106-126`), plus un second segmenté de densité à libellés sur la ligne du compteur (`routes_page.dart:432-453`) | moyenne |
| S78 | Persistance de la vue | Parcours : `SharedPreferences`, commune à toutes les équipes et à Explorer (`route_list_provider.dart:95-150`). Agenda : état de widget, perdu en quittant (`team_agenda_page.dart:87`) | faible |
| S79 | Recherche | Toujours visible et épinglée partout, sauf « Mes équipes » : cachée derrière une loupe d'app bar, sans épinglage (`teams_page.dart:80-111`) ; Mes équipes est aussi le seul écran à `AppBar` Material plutôt que `PdlAppBar` | faible |
| S80 | Portée « toutes les équipes » | Accueil : chip de **rôle**, libellée « Toutes les équipes » (`home.scopeAllTeams`, `publication_feed_view.dart:627-632`). Explorer : sélecteur d'**équipe et rôle**, « Toutes mes équipes » (`routes.scope.allTeams`, `routes_toolbar.dart:146-159`). Calendrier : équipe seule, en chips au plus trois équipes, sinon sélecteur (`calendar_toolbar.dart:61-148`) | moyenne |
| S81 | Chip « tout » | « Tout » (accueil, agenda, calendrier), « Tous » (annonces `ads.list.allTypes`, membres `teams.membersList.allRoles`), « Toutes » (découverte, notifications) — accords justes, mais l'accueil dit « Tout » quand le site dit « Tous » (S4) | faible |
| S82 | « Aujourd'hui » | Dans l'app bar sur le calendrier global, dans la barre du mois sur celui d'une équipe (`calendar_page.dart:146-154`, `calendar_toolbar.dart:88-99`) | faible (assumé dans le code) |
| S83 | Paramètres d'URL | Seul l'Agenda lit `?type=` et `?w=` ; aucune autre liste ne lit les filtres d'un lien du site | faible |

## Incohérences internes au site

| # | Sujet | Valeurs | Gravité |
|---|---|---|---|
| S84 | Libellés de création | « Créer une sortie », « Créer un voyage », « Créer une annonce », « Créer une équipe », « Créer un modèle », « Créer un nouveau parcours » (seul avec « nouveau »), « Nouvelle publication » (liste) contre « Rédiger une publication » (raccourci de l'accueil) · `TeamPostsPage.tsx:83`, `QuickActions.tsx:59`, `RouteListPage.tsx:67` | faible |
| S85 | Lien de création des parcours | `component="a" href=` : rechargement complet, sans `PrefetchLink`, contre la règle du module · `RouteListPage.tsx:63-66,117` | faible |
| S86 | Place de la recherche | Toujours visible : accueil, Publications, Annonces, Équipes, Membres, Modèles. Repliée derrière « Filtres » : Agenda, Parcours, Explorer · `TeamAgendaPage.tsx:179-224`, `RouteFilterPanel.tsx:102-110` | moyenne |
| S87 | Titre de page | H2 sur toutes les listes sauf Explorer (liste et carte), qui n'a que le fil d'Ariane · `AllRoutesPage.tsx:29`, `AllRoutesMapPage.tsx:20` | faible |
| S88 | Compteur | Sous la barre presque partout ; à côté du titre sur Membres (`TeamDirectoryPage.tsx:79-82`) ; absent des Modèles et des pages carte | faible |
| S89 | Filtres du calendrier | Le calendrier d'équipe filtre le type et « Je participe » (`TeamCalendarPage.tsx:30-46,94-101`), le calendrier global rien (`CalendarPage.tsx:23-36`) | moyenne |
| S90 | Création sur la carte d'équipe | Bouton présent en liste, absent sur `RoutesMapPage` | faible |

## Non vérifié

- **Le rendu à 390 px.** Lu dans le code : les barres sont des `Group wrap="wrap"`, et les listes déroulantes passent en
  `w={{ base: '100%' }}` sous `sm`. On en déduit un empilement en pleine largeur, sans repli dans un menu ;
  rien de responsive (`hiddenFrom`, `visibleFrom`, `useMediaQuery`) dans les pages de liste. Seuls les panneaux
  « Filtres » (Agenda, Parcours) replient du contenu, à toute largeur. Ni la hauteur réelle ni l'ordre visuel n'ont été vus.
- **Le défilement de l'en-tête du site.** Aucun `sticky` dans les listes. Je n'ai pas vérifié si l'en-tête global
  (`Layout`) reste fixe.
- **La liste de toute une sortie côté site.** `ParticipantList` accepte une source `{ kind: 'ride' }` sans `groupId`
  (`components/ride/ParticipantList.tsx:20`). Je n'ai pas trouvé d'appelant qui l'emploie pour une sortie entière (le
  pendant de `ParticipantsSheet.openRide` dans l'app) ; non tranché.
- **Un lien profond vers un chemin d'équipe que l'app n'a pas** (par exemple `/equipes/x/annonces?type=SALE`). L'app
  ouvre la section sans ses filtres (déduit de `config/router.dart:696-703`, qui ignore la requête) ; non exécuté.
- **La disparition des filtres en changeant de section dans l'app.** Les providers de filtres sont `autoDispose`
  (`ad_list_provider.dart:10`, `route_list_provider.dart:20`) : on en déduit que les filtres d'une section sont perdus
  quand on la quitte pour une autre. Le site fait de même (adresse nue). Non vérifié à l'exécution.
- **Les permissions de création.** Elles sont calculées en local des deux côtés (`teamAccess` sur le site,
  `ride_permissions.dart` dans l'app) : `TeamDetailDto` ne porte aucun champ `permissions` ni `canCreate…` dans
  `contracts/openapi.yaml`, et les champs `permissions` existants sont par entité (`ContentPermissionsDto`, par exemple
  sur `AdDto`).
