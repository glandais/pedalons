# Audit des listes — axe « états d'une liste » (préfixe E)

Worktree `feat/mobile-review`, lecture du code le 12 novembre 2026. Chemins relatifs à `mobile/lib/` (app) et
`frontend/src/` (site). Les libellés sont cités tels qu'ils figurent dans `mobile/assets/l10n/fr.json` et
`frontend/src/locales/fr/common.json`. Rien n'a été vérifié à l'écran ; « déduit » signale ce qui découle du code
sans y être écrit.

## Synthèse

L'app traite ses états de façon presque uniforme : `PagedListNotifier` + `PdlEmptyState`/`PdlDeadEndEmpty`, une
erreur toujours accompagnée de « Réessayer », un pied de liste « N sur M · Vous avez tout vu », et le tirer pour
rafraîchir partout sauf au calendrier. Elle a deux défauts nets : les Parcours n'ont **aucun état vide absolu**
(« Aucun parcours pour ces filtres » s'affiche sans filtre), et le fil ne compte que la recherche comme filtre. Le site,
lui, distingue bien le vide filtré du vide absolu, mais **sept listes sur treize n'ont aucun état d'erreur** : une panne
y prend la forme d'une liste vide, toast compris seulement si l'API a renvoyé un code. Le site n'affiche jamais rien en
fin de liste, et « Cette page n'existe pas » manque sur cinq listes paginées.

---

## 1. Briques communes

| # | Sujet | Listes concernées | App (valeur · fichier:ligne) | Site (valeur · fichier:ligne) | Verdict | Gravité |
|---|---|---|---|---|---|---|
| E1 | Composant d'état vide | toutes | `PdlEmptyState`, quatre variantes `empty / filtered / error / notFound`, icône 48, titre nominal, 0 à 2 actions · `core/pdl/pdl_empty_state.dart:9-24` ; « cul-de-sac » `PdlDeadEndEmpty` (filtre nommé à retirer, « Tout réinitialiser », aperçu) · `core/pdl/pdl_dead_end_empty.dart:11-26` | `EmptyState`, deux variantes `absolute / filtered`, aucune variante d'erreur · `components/common/EmptyState.tsx:15` ; cul-de-sac pour les seuls parcours, `RouteDeadEnd` · `components/route/RouteDeadEnd.tsx:136-168` | écart : le site n'a pas de variante d'erreur partagée | moyenne |
| E2 | Composant d'erreur | toutes | les erreurs de liste passent par `PdlEmptyState(variant: error)` avec « Réessayer » (`common.retry`) et « Signaler un problème » (`ReportProblemButton`) — sauf le fil, voir E9 | `QueryStateBoundary` → `ErrorMessage` : « Chargement impossible » / « Les données n'ont pas pu être chargées. Vérifiez votre connexion puis réessayez. » (`query.error.*`) + « Réessayer » (`generic.retry`) · `components/common/QueryStateBoundary.tsx:62-69`, `ErrorBoundary.tsx:136-150` — utilisé par **deux** listes seulement (notifications, trombinoscope) | écart | forte (détail par liste plus bas) |
| E3 | Message hors connexion | toutes | erreur de connexion ou délai dépassé → message « Vérifiez votre connexion internet, puis réessayez. » (`errors.offline.message`) sous le titre de l'écran (le titre « Pas de connexion », `errors.offline.title`, n'est pas repris par les listes) · `core/utils/api_error_handler.dart:47-68` | aucun traitement propre : erreur réseau = pas de `code` → **pas de toast** (`lib/axiosInstance.ts:210-236`), la liste affiche son état d'erreur s'il existe, sinon son état vide | écart | moyenne |
| E4 | Cache hors connexion, bandeau | toutes | aucun cache persistant des listes, aucun bandeau ; pas de `connectivity_plus` dans `pubspec.yaml` | aucun cache persistant, aucun bandeau (`navigator.onLine` absent du code) | identique | — |
| E5 | Nouvelles tentatives | toutes | une seule requête ; l'échec s'affiche tout de suite (`core/pagination/paged_list_notifier.dart:76-87`) | 3 tentatives pour 5xx et réseau, aucune pour un autre 4xx (délai 1 s, 2 s, 4 s) · `lib/queryClient.ts:21-42` → l'erreur n'apparaît qu'après environ 7 s (déduit) | tient au support | faible |
| E6 | Fraîcheur du cache | toutes | providers `autoDispose` : liste rechargée à chaque réouverture de l'écran, gardée tant que l'onglet du shell la garde montée (déduit de `StatefulShellRoute.indexedStack`) ; `myTeamsProvider` sans `autoDispose`, gardé jusqu'à invalidation · `features/teams/providers/team_providers.dart:30` | `staleTime` 3 min, `gcTime` 10 min, pas de rechargement au retour sur l'onglet (`refetchOnWindowFocus: false`) · `lib/queryClient.ts:11,20,44` ; calendrier 5 min · `pages/calendar/CalendarPage.tsx:19`, `teamCalendarData.ts:41` ; notifications non lues interrogées toutes les 60 s · `hooks/useNotifications.ts:17,39-41` | tient au support | — |
| E7 | Tirer pour rafraîchir, bouton Rafraîchir | toutes | `PdlRefresh` (vibration au déclenchement) sur fil, agenda, publications, parcours, annonces, équipes, découverte, membres, notifications, modèles, personnes bloquées ; **absent du calendrier** (aucun `PdlRefresh` dans `features/calendar/presentation/pages/calendar_page.dart`) et des personnes inscrites (feuille) | aucun bouton Rafraîchir sur aucune liste ; rechargement manuel du navigateur | tient au support (sauf calendrier app, voir E31) | — |
| E8 | Fin de liste | listes paginées | `PdlPagedListFooter` : « {loaded} sur {total} » puis « Vous avez tout vu » (`pagination.progress`, `pagination.endOfList`) ; en cours « … · chargement de la suite… » ; erreur de page suivante « Impossible de charger la suite.\nVérifiez votre connexion. » + « Réessayer » (`pagination.nextPageError`) · `core/pdl/pdl_paged_list_footer.dart:72-139` ; la page en échec n'est pas rechargée au défilement · `paged_list_notifier.dart:91-101` | rien : la liste s'arrête sur le composant `Pagination` (« Page {current} sur {total} », `pagination.page`), sans message de fin ni compteur de position — sauf les personnes inscrites (E66) | tient au support (défilement infini contre pages) | faible |
| E9 | Page au-delà de la dernière | listes paginées du site | sans objet (défilement infini) | `OutOfRangeState` : « Cette page n'existe pas » / « La liste s'arrête avant cette page. » + « Revenir à la première page » · `components/common/OutOfRangeState.tsx:11-25`. Présent : fil d'accueil, publications, agenda, annonces, équipes. **Absent** : parcours (équipe et tous), membres (admin et trombinoscope), notifications, modèles — elles montrent leur état vide (« Aucun parcours », « Aucune notification »…) | écart interne au site | moyenne |

---

## 2. Fil d'accueil

| # | Sujet | Listes concernées | App (valeur · fichier:ligne) | Site (valeur · fichier:ligne) | Verdict | Gravité |
|---|---|---|---|---|---|---|
| E10 | Vide sans filtre | fil d'accueil | « Aucune publication » / « Les sorties, publications et voyages de vos équipes s'afficheront ici. » (`home.feed.empty`, `home.feed.emptyHint`), aucune action · `features/home/presentation/pages/home_page.dart:44`, `features/feed/presentation/widgets/publication_feed_view.dart:415-422` | « Aucune publication pour le moment » / « Les publications et les sorties des équipes apparaîtront ici dès leur parution. » (`home.feed.empty`, `home.feed.emptyDescription`), aucune action · `components/home/HomeFeedSection.tsx:186-200` | écart de libellé (même clé, deux textes) | faible |
| E11 | Ce qui compte comme filtre | fil d'accueil | seule la **recherche** (et, sur un fil d'équipe, les tags) ; une chip de type (« Sorties ») ou la portée qui ne trouvent rien affichent le vide **absolu** · `publication_feed_view.dart:376` | recherche, type, portée **et** appartenance · `HomeFeedSection.tsx:70-74` | écart : l'app dit « rien ici » là où le site dit « rien pour ces filtres » | forte |
| E12 | Vide filtré | fil d'accueil | « Aucun résultat » / « Aucune publication ne correspond à « {search} ». » + « Effacer la recherche » (`home.feed.emptyFiltered.*`, `common.clearSearch`) · `publication_feed_view.dart:397-414` | « Aucune publication trouvée » / « Aucune publication ne correspond à votre recherche. » + « Effacer les filtres » (`home.feed.noResultsTitle`, `home.feed.noResults`, `common.clearFilters`) — le terme n'est pas cité, les filtres actifs non plus · `HomeFeedSection.tsx:186-199` | écart (titre, action, terme cité seulement dans l'app) | moyenne |
| E13 | Chargement initial | fil d'accueil | 5 squelettes de carte (`PdlSkeletonCardList`) · `publication_feed_view.dart:333-345` | 6 `PublicationCardSkeleton` · `HomeFeedSection.tsx:147-152` | identique (au nombre près) | faible |
| E14 | Changement de filtre | fil d'accueil | nouveau notifier par jeu de filtres → squelettes, retour en haut · `paged_list_notifier.dart:21-25`, `publication_feed_view.dart:183-195` | pas de `placeholderData` → nouvelle clé de requête sans données → squelettes (déduit) · `pages/home/homeFeedData.ts:112` | identique | — |
| E15 | Erreur | fil d'accueil | bandeau `PdlBanner` rouge « Fil indisponible. » + message + « Réessayer » · `publication_feed_view.dart:348-370` | icône rouge + « Erreur lors du chargement » (`error.loading`), **aucun bouton Réessayer** · `HomeFeedSection.tsx:153-161` | écart : sans issue sur le site | forte |
| E16 | Personne non connectée | fil d'accueil | impossible : tout l'app exige une session, redirection vers la connexion · `config/router.dart:1018-1019` | `VisitorHome` : même section, titre « Dernières publications publiques », mêmes états · `pages/home/VisitorHome.tsx:33-37` | tient au support | — |
| E17 | Rafraîchissement | fil d'accueil | tirer pour rafraîchir recharge le fil, le compteur, « Ma prochaine sortie », « Cette semaine », « Mes équipes » · `publication_feed_view.dart:243-251`, `home_page.dart:48-60` | aucun ; cache 3 min (E6) | tient au support | — |
| E18 | Invalidation après création d'une sortie ou d'une publication | fil d'accueil, calendrier | `publicationFeedProvider`, `calendarMonthProvider`, tableau de bord et modèles invalidés · `features/rides/providers/ride_changes.dart:32-37` | `invalidateTeamPublications` invalide la liste **de l'équipe** et son tableau de bord, pas le fil d'accueil (`listAllPublications`) ni le calendrier (`getEvents`) · `lib/teamDashboardCache.ts:19-22`, `pages/ride/CreateRidePage.tsx:150`, `pages/post/CreatePostPage.tsx:72` → nouvelle sortie absente de l'accueil jusqu'à 3 min, du calendrier jusqu'à 5 min (déduit) | écart | moyenne |

## 3. Publications d'une équipe

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| E19 | Vide sans filtre | publications d'équipe | « Aucune publication pour le moment » / « Les publications de l'équipe apparaîtront ici une fois publiées. » (`teams.posts.empty`, `teams.posts.emptyHint`), aucune action · `features/teams/presentation/pages/team_home_page.dart:252-264` | même titre / « Les publications de l'équipe apparaîtront ici une fois publiées » (`teams.posts.emptyDescription`, sans point final), aucune action dans l'état vide (« Créer une publication » dans l'en-tête, pour un organisateur) · `pages/team/TeamPostsPage.tsx:76-85,141-158` | identique | faible |
| E20 | Vide filtré | publications d'équipe | recherche : « Aucun résultat » / « Aucune publication ne correspond à « {search} ». » + « Effacer la recherche » ; tags seuls : « Aucun résultat » / « Aucun contenu ne porte ces tags. » + « Retirer le filtre par tag » (`tags.emptyFiltered`, `tags.clearFilter`) — avec les deux à la fois, seule la recherche est proposée · `publication_feed_view.dart:381-414` | « Aucun résultat ne correspond à votre recherche. » en **titre** (`noResults`) / « Aucune publication ne correspond à votre recherche. Essayez d'autres mots-clés ou effacez la recherche. » + « Effacer les filtres » si un tag est posé, sinon « Effacer la recherche » ; le bouton efface les deux · `TeamPostsPage.tsx:141-158` | écart de forme ; l'app peut laisser un tag actif après « Effacer la recherche » | moyenne |
| E21 | Erreur | publications d'équipe | bandeau « Fil indisponible. » + « Réessayer » (E15) | **aucun état d'erreur** : seul `isLoading` est lu · `TeamPostsPage.tsx:45,108` → une panne affiche « Aucune publication pour le moment » (déduit) | écart : le site affirme un vide qui n'existe pas | forte |
| E22 | Équipe indisponible | toutes les sections d'équipe | 3 squelettes pendant le chargement ; erreur « Équipe indisponible » + message + « Réessayer » + « Équipes » + « Signaler » · `team_home_page.dart:101-133` | `LoadingPage` (spinner + « Publications ») ; 404 ou 403 → redirection silencieuse vers la liste des équipes ; 5xx ou réseau → « Chargement impossible » + « Réessayer » · `components/team/TeamUnavailable.tsx:19-29`. Parcours, annonces, membres, modèles et calendrier redirigent vers la liste des équipes **même sur une 5xx** (`<Navigate>` sans `TeamUnavailable`) · `pages/route/RouteListPage.tsx:49-51`, `pages/ad/AdListPage.tsx:64-66`, `pages/team/TeamMembersPage.tsx:91-93`, `pages/ridetemplate/RideTemplateListPage.tsx:57-58`, `pages/calendar/TeamCalendarPage.tsx:67-69` | écart (et incohérence interne au site) | moyenne |

## 4. Agenda d'une équipe

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| E23 | Vide sans filtre | agenda | « Rien à l'agenda pour le moment » / « Les sorties et les voyages de l'équipe apparaîtront ici. » + « Voir les passées », masqué quand la période est déjà « Passées » (`teams.agenda.empty.*`) · `features/teams/presentation/pages/team_agenda_page.dart:162-173` | mêmes libellés (`agenda.empty.*`) + « Voir les passées » · `pages/team/TeamAgendaPage.tsx:296-305` | identique | — |
| E24 | Ce qui compte comme filtre | agenda | recherche et tags seulement ; type (« Sorties »), « Je participe » et « Passées » donnent le vide **absolu** · `publication_feed_view.dart:376` | recherche, tags, type **et** période différente de « À venir » (« Passées » comprise) · `TeamAgendaPage.tsx:121-122` | écart : « Je participe » vide = « Rien à l'agenda » dans l'app, « Aucun résultat » dans le site | forte |
| E25 | Vide filtré | agenda | comme E20 | « Aucun résultat ne correspond à votre recherche. » / « Aucune sortie ni aucun voyage ne correspond à ces filtres. » + « Effacer la recherche » (recherche seule) ou « Effacer les filtres » (remet type, période et tags) · `TeamAgendaPage.tsx:281-295` | écart | moyenne |
| E26 | « Passées » vide | agenda | vide absolu sans action · `team_agenda_page.dart:165` | vide filtré + « Effacer les filtres », qui ramène à « À venir » · `TeamAgendaPage.tsx:122-131` | écart de sens | faible |
| E27 | Erreur | agenda | bandeau « Fil indisponible. » + « Réessayer » (E15) | **aucun état d'erreur** (`isError` non lu) · `TeamAgendaPage.tsx:78,238` → vide affiché (déduit) | écart | forte |
| E28 | Non membre | agenda | liste publique, bascule Calendrier masquée · `team_agenda_page.dart:89-94` | liste publique ; l'adresse du calendrier redirige vers la liste · `pages/calendar/TeamCalendarPage.tsx:72-76` | identique | — |

## 5. Calendrier

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| E29 | Mois sans rien | calendrier, calendrier d'équipe | sous la grille : « Aucun événement ce mois-ci » / « Vos équipes n'ont publié aucune sortie ni étape de voyage en {month}. » + « Aller au prochain mois avec une sortie », quand un mois suivant en a (`calendar.noEvents*`, `calendar.goToNextMonthWithEvents`) · `features/calendar/presentation/pages/calendar_page.dart:384-412` | grille vide, aucun message ni raccourci ; seule la vue liste de `@mantine/schedule` reçoit le libellé « Aucun événement » (`calendar.schedule.noEvents`) · `components/calendar/CalendarView.tsx:104` | écart | moyenne |
| E30 | Vide filtré | calendrier d'équipe (type, « Je participe ») ; calendrier global (type) | « Rien avec ces filtres » / « Ce mois contient des événements, mais aucun ne correspond au filtre choisi. » + « Effacer les filtres » (`calendar.noEventsFiltered.*`, `calendar.clearFilters`) — affiché dès qu'un filtre est posé, **même si le mois est vide** : la phrase est alors fausse · `calendar_page.dart:359-382` | filtrage côté client (`keepEvent`), grille vide sans message · `TeamCalendarPage.tsx:35-43,56-59` | écart | moyenne |
| E31 | Chargement, changement de mois | calendrier | squelettes (5 compacts) **à la place de la grille et de la liste** : la grille est dans la branche `data` d'un provider par mois · `calendar_page.dart:109-118,348-353` | les événements du mois précédent restent affichés sous un `LoadingOverlay` (`keepPreviousData` + `isFetching`) · `pages/calendar/CalendarPage.tsx:13-31`, `CalendarView.tsx:428` | écart | faible |
| E32 | Erreur | calendrier | « Erreur de chargement » + message + « Réessayer » + « Signaler » (`common.loadError`) · `calendar_page.dart:119-135` | **aucun état d'erreur** : `useGetEvents` / `useGetTeamEvents` ne lisent que `data` et `isFetching` → grille vide (déduit) · `CalendarPage.tsx:17-20`, `TeamCalendarPage.tsx:54` | écart | forte |
| E33 | Rafraîchissement | calendrier | **ni tirer pour rafraîchir ni bouton** ; seul le changement de mois recharge | aucun ; cache 5 min | écart interne à l'app (seule liste de l'app sans rafraîchissement) | faible |
| E34 | Message dans une équipe | calendrier d'équipe | le message du mois vide dit « Vos équipes n'ont publié… » aussi dans le calendrier d'**une** équipe · `calendar_page.dart:395` | — | écart interne à l'app | faible |

## 6. Parcours d'une équipe, tous les parcours, carte

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| E35 | Vide sans filtre | parcours d'équipe, tous les parcours | **pas d'état vide absolu** : tout vide passe par le cul-de-sac « Aucun parcours pour ces filtres » / « Aucun parcours ne correspond à cette combinaison de filtres. » + « Tout réinitialiser », même sans filtre ; le bouton ne change alors rien · `features/routes/presentation/pages/routes_page.dart:240-246,469-510` | « Aucun parcours » / « Aucun parcours n'est disponible pour le moment. » (`routes.list.empty.*`) + « Créer un nouveau parcours » pour un organisateur · `components/route/RouteListContent.tsx:115-133`, `pages/route/RouteListPage.tsx:117-123` | écart : l'app décrit faussement une équipe sans parcours | forte |
| E36 | Vide filtré | parcours | titre « Aucun parcours pour ces filtres » ; message sans les filtres (« cette combinaison de filtres »), seule la recherche est citée ; « Retirer le filtre {filter} » (le filtre qui libère le plus de résultats côté serveur), « Tout réinitialiser », aperçu « Sans le filtre {filter} » · `routes_page.dart:486-509` | « Aucun parcours ne correspond » / « Aucun parcours ne correspond aux filtres {filters}. » (**filtres cités**), « Retirer le filtre {filter} », « Tout réinitialiser », « Sans le filtre {filter}, {count} parcours reviennent » · `components/route/RouteDeadEnd.tsx:112-168` | même structure ; le site nomme les filtres, l'app non | moyenne |
| E37 | Chargement initial | parcours | 5 squelettes avec média · `routes_page.dart:200-214` | 6 `RouteCardSkeleton` · `RouteListContent.tsx:55-61` | identique | faible |
| E38 | Changement de filtre | parcours | squelettes (nouveau notifier) | la liste précédente reste affichée **sans estompage** (`keepPreviousData`, `isFetching` non lu) · `pages/route/routeListData.ts:54`, `allRouteListData.ts:71` | écart : sur le site, rien ne signale que la liste va changer | moyenne |
| E39 | Erreur | parcours d'équipe | « Erreur de chargement » + message + « Réessayer » + « Signaler » · `routes_page.dart:216-238` | `isError` **non transmis** à `RouteListContent` → état vide (déduit) · `RouteListPage.tsx:37,96-123` | écart | forte |
| E40 | Erreur | tous les parcours | idem E39 (même écran) | icône carte rouge + « Erreur lors du chargement » (`error.loading`), **pas de Réessayer** · `RouteListContent.tsx:63-74`, `pages/route/AllRoutesPage.tsx:16,51` | écart | forte |
| E41 | Zone de carte sans parcours | carte des parcours | aucun message : la seule pastille dit que le jeton de tuiles manque (« Chargement... ») ou a échoué (message d'erreur, toucher pour réessayer) · `widgets/routes_map_view.dart:255-270` | aucun message ; squelette tant que l'emprise n'est pas connue · `components/route/RoutesTileMap.tsx:117-120` | identique | — |
| E42 | Carte : erreur de configuration | carte des parcours | style indisponible → « Erreur de chargement » + « Réessayer » · `routes_map_view.dart:388-405` | pas d'état d'erreur pour l'emprise (`bounds.isLoading` seulement) · `pages/route/AllRoutesMapPage.tsx:33-37` | écart | faible |
| E43 | Fin de liste | parcours | « {loaded} sur {total} » sans nom ni séparateur de milliers (`'${state.items.length}'`, pas `formatNumber`) · `routes_page.dart:316-321` | rien (E8) | — | faible (voir E78) |
| E44 | Invalidation | parcours | `routeListProvider` et tableau de bord invalidés · `features/routes/providers/route_changes.dart:39-43` | `invalidateRouteQueries` : liste d'équipe, liste globale, compteurs, emprises, bulk · `lib/routeCacheInvalidation.ts` | identique | — |

## 7. Annonces

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| E45 | Vide sans filtre | annonces | « Aucune annonce » / « Les annonces de vente, de location et de recherche de votre équipe apparaîtront ici. » (`ads.empty`, `ads.emptyHint`), aucune action · `features/ads/presentation/pages/ads_page.dart:139-149` | « Aucune annonce » / « Aucune annonce n'est disponible pour le moment. » (`ads.list.empty.title`, `ads.list.empty.member`), aucune action dans l'état vide (« Créer une annonce » dans l'en-tête, pour un membre) · `pages/ad/AdListPage.tsx:224-236,113-121` | écart de texte ; l'app ne propose de créer nulle part | faible |
| E46 | Vide filtré | annonces | `PdlDeadEndEmpty` sans filtre nommé : « Aucune annonce pour ces filtres » / « Aucune annonce ne correspond à cette combinaison de filtres. » (ou « … à « {search} » avec ces filtres. ») + « Tout réinitialiser » · `ads_page.dart:214-240` | « Aucune annonce trouvée » / « Aucune annonce ne correspond à votre recherche. » + « Effacer les filtres » · `AdListPage.tsx:224-234` | écart de libellés | moyenne |
| E47 | Changement de filtre | annonces | squelettes (5, média) · `ads_page.dart:94-106` | liste précédente **estompée à 50 %** (`isFetching`) · `AdListPage.tsx:244` | écart ; et seule liste du site à estomper (E80) | faible |
| E48 | Erreur | annonces | « Erreur de chargement » / « La rubrique Annonces n'est pas activée sur cette équipe, ou le réseau est indisponible. » (`ads.list.loadError`) + « Réessayer » + « Signaler » · `ads_page.dart:108-134` | **aucun état d'erreur** (`isError` non lu) → « Aucune annonce » (déduit) · `AdListPage.tsx:49,214-236` | écart | forte |
| E49 | Non membre, non connecté | annonces | chip de section masquée pour un non-membre · `features/teams/presentation/widgets/team_sections.dart:209-216` ; un lien direct ouvre la liste, l'API refuse → l'erreur E48, qui avance une rubrique désactivée (déduit : aucun contrôle d'appartenance dans `ads_page.dart`) | non connecté : redirection vers la connexion (`auth: 'authenticated'`, `config/routes.config.ts`) ; connecté non membre : « Réservées aux membres » / « Les annonces de l'équipe ne sont visibles que par ses membres. », sans action · `AdListPage.tsx:75-90` ; rubrique désactivée : redirection vers l'équipe · `AdListPage.tsx:68-71` | écart | moyenne |

## 8. Mes équipes, découvrir des équipes

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| E50 | Vide sans filtre | mes équipes | « Aucune équipe » / « Rejoignez une équipe pour commencer » + « Découvrir des équipes » (`teams.empty`, `teams.joinPrompt`, `teams.discover`) · `features/teams/presentation/pages/teams_page.dart:163-176` | pas de liste « Mes équipes » à part : l'annuaire s'ouvre sur l'appartenance « membre » si la personne a une équipe, sur « toutes » sinon (`hooks/useMembershipDefault.ts:14-24`), donc le vide absolu n'arrive que sur un site sans équipe : « Aucune équipe » / « Aucune équipe n'a encore été créée sur ce site. » + « Créer une équipe » · `pages/team/TeamListPage.tsx:128-148` | tient au support (une seule liste côté site) | — |
| E51 | Vide filtré | mes équipes | « Aucune équipe pour cette recherche » / « Aucune de vos équipes ne contient « {search} ». » + « Effacer la recherche » · `teams_page.dart:177-189` | « Aucune équipe trouvée » / « Aucune équipe ne correspond à votre recherche. » + « Effacer les filtres » (remet aussi l'appartenance) + « Créer une équipe » · `TeamListPage.tsx:128-148` | écart de libellés | faible |
| E52 | Vide | découvrir | sans filtre : « Aucune équipe à découvrir » / « Les équipes publiques de ce domaine apparaîtront ici. » ; filtré : cul-de-sac « Aucune équipe pour ces filtres » / « Aucune équipe ne correspond à cette recherche ni à cette portée. » + « Tout réinitialiser » · `teams_discover_page.dart:167-188` | même page que E50-E51 | écart de libellés | faible |
| E53 | Chargement | mes équipes, découvrir | mes équipes : 3 `ShimmerTeamCard` · `teams_page.dart:117-128` ; découvrir : 5 squelettes média · `teams_discover_page.dart:129-141` | 6 `TeamCardSkeleton` · `TeamListPage.tsx:102-105` | écart interne à l'app (voir E77) | faible |
| E54 | Erreur | mes équipes, découvrir | mes équipes : « Équipe indisponible » (singulier, clé `teams.loadError.title` de la page d'**une** équipe) + « Réessayer » · `teams_page.dart:129-143` ; découvrir : « Erreur de chargement » + « Réessayer » · `teams_discover_page.dart:143-163` | `Alert` rouge avec le **message brut** de l'erreur (`error.message`, à défaut « Échec du chargement des données », `errors.api.failedToLoad`), sans Réessayer — et l'état vide s'affiche **en dessous**, `teams` étant indéfini (déduit) · `TeamListPage.tsx:96-100,125-148` | écart : deux états contradictoires à l'écran | forte |
| E55 | Personne non connectée | équipes | impossible (session obligatoire) | annuaire public, sans le sélecteur d'appartenance ni « Créer une équipe » · `TeamListPage.tsx:42,79` | tient au support | — |

## 9. Membres d'une équipe

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| E56 | Deux listes côté site | membres | une seule liste, rôles montrés selon le rôle du lecteur · `team_home_page.dart:291-305` | administration (`TeamMembersPage`, admin seulement, sinon redirection vers l'équipe · `TeamMembersPage.tsx:96-98`) et trombinoscope (`TeamDirectoryPage`), aux états différents (E57-E59) | écart interne au site | — |
| E57 | Vide sans filtre | membres | « Aucun membre » / « Les membres de cette équipe apparaîtront ici. » (`teams.membersList.none*`) · `team_members_page.dart:181-199` | administration : texte gris « Aucun membre trouvé. » sans icône ni action · `TeamMembersPage.tsx:250-254` ; trombinoscope : `EmptyState` « Aucun membre trouvé. » sans description · `TeamDirectoryPage.tsx:117-121` | écart | faible |
| E58 | Vide filtré | membres | cul-de-sac « Aucun membre pour ces filtres » / « Aucun membre ne correspond à cette recherche ni à ce rôle. » + « Tout réinitialiser » · `team_members_page.dart:185-190` | administration : même texte gris « Aucun membre trouvé », **sans action** · `TeamMembersPage.tsx:250-254` ; trombinoscope : « Aucun membre trouvé » + « Effacer les filtres » · `TeamDirectoryPage.tsx:103-116` | écart ; l'administration du site ne propose pas d'effacer | moyenne |
| E59 | Erreur | membres | « Erreur de chargement » + message + « Réessayer » + « Signaler » · `team_members_page.dart:157-179` | administration : **aucun état d'erreur** → « Aucun membre trouvé. » (déduit) · `TeamMembersPage.tsx:69,221-254` ; trombinoscope : « Chargement impossible » + « Réessayer » · `TeamDirectoryPage.tsx:124-130` | écart | forte |
| E60 | Liste non partagée | membres | chip de section masquée quand le serveur refuserait · `team_sections.dart:163-173` ; lien direct → 403 → « Erreur de chargement » (déduit) | « Liste des membres non partagée » / « Cette équipe ne partage pas la liste de ses membres avec vous. » + « À propos » · `TeamDirectoryPage.tsx:71,84-92` | écart | moyenne |
| E61 | Fin de liste | membres | « {loaded} membres sur {total} · Vous avez tout vu » (nom accordé, milliers formatés) · `team_members_page.dart:242-258` | pagination | tient au support | — |

## 10. Personnes inscrites

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| E62 | Vide sans filtre | inscrites (sortie, groupe, voyage) | « Aucune inscription » / « Aucune inscription dans ce groupe pour le moment. » (`participants.emptyTitle`, `participants.emptyMessage`) · `features/participants/presentation/widgets/participant_list_view.dart:133-138` | icône + « Aucune inscription pour le moment. » (`participants.empty`), sans titre · `components/ride/ParticipantList.tsx:111-117` | écart de forme | faible |
| E63 | Vide filtré (recherche) | inscrites | « Personne ne correspond » / « Aucun nom ne correspond à « {search} ». » + « Effacer la recherche » · `participant_list_view.dart:139-153` | « Personne ne correspond à votre recherche. » (`participants.noMatchGeneric`, passé par `ParticipantsSection`), **sans bouton** · `ParticipantList.tsx:111-117`, `components/publication/ParticipantsSection.tsx:70` | écart | moyenne |
| E64 | Chargement | inscrites | indicateur circulaire · `participant_list_view.dart:114-118` | `Loader` centré · `ParticipantList.tsx:103-106` ; changement de page ou de recherche : liste précédente gardée, sans estompage (`keepPreviousData`) · `ParticipantList.tsx:78,84` | identique au chargement initial ; écart au changement (l'app recharge via un nouveau provider) | faible |
| E65 | Erreur | inscrites | « Erreur de chargement » + message + « Réessayer » · `participant_list_view.dart:119-132` | texte rouge « La liste des inscriptions n'a pas pu être chargée. Réessayez. », **sans bouton** · `ParticipantList.tsx:107-110` | écart : le texte demande de réessayer sans en donner le moyen | forte |
| E66 | Fin de liste | inscrites | bouton « Afficher plus » précédé de « {loaded} personnes sur {total} », puis pied commun « Vous avez tout vu » · `participant_list_view.dart:186-219` | « {from}–{to} sur {total} » (`participants.shownOf`) + pagination · `ParticipantList.tsx:188-195` | tient au support | — |
| E67 | Non membre | inscrites | aucun nom, le compte seul (`permissions.canSeeParticipants`) · `features/rides/presentation/widgets/ride_group_participants_section.dart:56` | titre et compte seuls, liste non rendue (`canSeeParticipants`) · `ParticipantsSection.tsx:57-73` | identique (règle produit) | — |

## 11. Notifications

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| E68 | Vide sans filtre | notifications | « Aucune notification » / « Les sorties, voyages et publications de vos équipes apparaîtront ici. » · `features/notifications/presentation/pages/notifications_page.dart:233-262` | mêmes textes (`notifications.empty.title`, `.description`) · `pages/notification/NotificationListPage.tsx:91-96` | identique | — |
| E69 | Vide filtré (non lues) | notifications | « Aucune notification non lue » / « Tout est lu. Revenez à « Toutes » pour revoir les précédentes. » + « Toutes » (`notifications.empty.unread*`, `notifications.filter.all`) · `notifications_page.dart:240-258` | « Aucune notification non lue » / « Tout est lu. Enlevez le filtre pour revoir les notifications précédentes. » + « Voir toutes les notifications » · `NotificationListPage.tsx:79-90` | écart de libellé du bouton | faible |
| E70 | Chargement, erreur | notifications | 6 squelettes « personne » ; « Erreur de chargement » + « Réessayer » + « Signaler » · `notifications_page.dart:195-231` | 5 rectangles `Skeleton` de 64 px ; « Chargement impossible » + « Réessayer » (`QueryStateBoundary`) · `NotificationListPage.tsx:65-77` | identique | — |
| E71 | Rafraîchissement | notifications | tirer pour rafraîchir ; liste invalidée à l'arrivée d'un push · `features/notifications/providers/push_provider.dart:153,177` | liste et compteur invalidés après « lu » / « tout lire » · `hooks/useNotifications.ts:20-26,53-55` ; le compteur interroge le serveur toutes les 60 s, la liste non (déduit) | tient au support | — |

## 12. Modèles de sortie

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| E72 | Vide sans filtre | modèles | « Aucun modèle » / « Créez des modèles pour accélérer la création de sorties. » + « Nouveau modèle » · `features/rides/presentation/pages/ride_template_list_page.dart:159-176` | « Aucun modèle » + « Créez des modèles pour accélérer la création de sorties. » et « Créer un modèle » (organisateur), sinon « Aucun modèle n'a encore été créé. » ; bloc fait main, pas `EmptyState` · `pages/ridetemplate/RideTemplateListPage.tsx:139-161` | écart de libellé du bouton (« Nouveau modèle » / « Créer un modèle ») | faible |
| E73 | Vide filtré | modèles | « Aucun modèle ne correspond à cette recherche », **sans bouton** · `ride_template_list_page.dart:177-181` | « Aucun modèle trouvé », sans description ni bouton · `RideTemplateListPage.tsx:145-147` | identique (sans issue des deux côtés) | moyenne |
| E74 | Chargement, erreur | modèles | 5 squelettes compacts ; « Erreur de chargement » + « Réessayer » · `ride_template_list_page.dart:116-157` | `Loader` centré ; **aucun état d'erreur** → « Aucun modèle » (déduit) · `RideTemplateListPage.tsx:38,112-114` | écart | forte |

## 13. Personnes bloquées

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| E75 | Vide | personnes bloquées | « Aucune personne bloquée » / « Pour bloquer quelqu'un, touchez ⋯ sur l'un de ses commentaires ou de ses annonces, ou son nom dans la liste des membres. » · `features/moderation/presentation/pages/blocked_users_page.dart:143-150` | texte gris italique « Vous n'avez bloqué personne. » · `components/profile/BlockedUsers.tsx:53-57` | écart de forme | faible |
| E76 | Chargement, erreur | personnes bloquées | 3 squelettes « personne » ; « Erreur de chargement » + « Réessayer » + « Signaler » · `blocked_users_page.dart:98-130` | un `Skeleton` de 40 px ; **aucun état d'erreur** → « Vous n'avez bloqué personne. » (déduit) · `BlockedUsers.tsx:22,53-57` | écart | moyenne |

Site seulement (non détaillé) : `pages/gpxtool/MyGpxPreviewsPage.tsx`, `pages/team/TeamPlacesPage.tsx`, `TeamTagsPage.tsx`,
`TeamReportsPage.tsx`, `TeamPagesAdminPage.tsx`.

---

## Incohérences internes à l'app

| # | Sujet | Constat · fichier:ligne | Gravité |
|---|---|---|---|
| E77 | Nombre et forme des squelettes | 5 sur le fil, les parcours, les annonces, la découverte, les membres et les modèles (« cinq, pas deux », §1.0.4, `publication_feed_view.dart:339-341`) ; 3 sur Mes équipes (`ShimmerTeamCard`, `teams_page.dart:117-128`), l'équipe en chargement (`team_home_page.dart:106`) et les personnes bloquées (`blocked_users_page.dart:104-106`) ; 6 sur les notifications ; indicateur circulaire pour les inscrites | faible |
| E78 | Compteur du pied de liste | nommé et formaté (`pagedProgressNamed` : membres, découverte, modèles, inscrites) contre nu et non formaté (`'pagination.progress'` + `'${state.items.length}'` : parcours `routes_page.dart:316-321`, annonces `ads_page.dart:195-200`, notifications `notifications_page.dart:309`) ; le fil passe par `PagedListFooter` sans nom (« 8 sur 40 », mais formaté) · `publication_feed_view.dart:450-454` | faible |
| E79 | Forme de l'erreur | le fil (accueil, agenda, publications) montre un `PdlBanner` « Fil indisponible. » avec un bouton texte, sans « Signaler » (`publication_feed_view.dart:356-366`) ; les autres listes un `PdlEmptyState` d'erreur avec « Réessayer » et « Signaler » ; Mes équipes titre « Équipe indisponible » (`teams_page.dart:133`) | faible |
| E80 | Vide filtré : trois traitements | cul-de-sac riche avec filtre nommé et aperçu (parcours) ; cul-de-sac sans filtre nommé (annonces, découverte, membres : « Tout réinitialiser ») ; `PdlEmptyState` filtré à une action (fil, Mes équipes, inscrites, notifications : « Effacer la recherche », « Retirer le filtre par tag », « Toutes ») ; sans action (modèles, E73) | moyenne |
| E81 | Ce qui compte comme filtre | le calendrier compte type et « Je participe » (`calendar_page.dart:359`), le fil et l'agenda ne comptent que la recherche et les tags (`publication_feed_view.dart:376`) : la même chip « Je participe » donne « Rien avec ces filtres » en vue Calendrier et « Rien à l'agenda pour le moment » en vue Liste | moyenne |
| E82 | Parcours sans vide absolu | seule liste de l'app dont l'état vide ignore s'il y a un filtre (E35), alors que les annonces, la découverte et les membres testent `isFiltered` avant de choisir | forte (déjà comptée en E35) |
| E83 | Calendrier sans rafraîchissement | seul écran de liste sans `PdlRefresh` (E33) | faible (déjà comptée) |

## Incohérences internes au site

| # | Sujet | Constat · fichier:ligne | Gravité |
|---|---|---|---|
| E84 | Erreur absente | sans état d'erreur : publications d'équipe, agenda, calendriers, parcours d'équipe, annonces, administration des membres, modèles, personnes bloquées (E21, E27, E32, E39, E48, E59, E74, E76) ; erreur sans « Réessayer » : fil d'accueil, tous les parcours, équipes, inscrites (E15, E40, E54, E65) ; erreur avec « Réessayer » : notifications, trombinoscope seulement. Une erreur réseau, sans `code`, ne déclenche même pas de toast (`lib/axiosInstance.ts:210-236`) | forte |
| E85 | Liste pendant un changement de filtre | squelettes (accueil, publications, agenda, équipes, membres, modèles) ; liste précédente gardée telle quelle (parcours, notifications, inscrites) ; gardée et estompée à 50 % (annonces, `AdListPage.tsx:244`) ; gardée sous un voile de chargement (calendrier) | moyenne |
| E86 | Hors plage | `OutOfRangeState` sur cinq listes, absent de cinq autres (E9) | moyenne |
| E87 | Composant d'état vide | `EmptyState` partout, sauf modèles (bloc fait main, `RideTemplateListPage.tsx:141`), administration des membres et personnes bloquées (simple `Text` gris, `TeamMembersPage.tsx:250`, `BlockedUsers.tsx:56`), inscrites (pile icône + texte, `ParticipantList.tsx:112`) | faible |
| E88 | Libellé du bouton de sortie d'un filtre | « Effacer les filtres » (accueil, annonces, équipes, parcours simples, trombinoscope), « Effacer la recherche » ou « Effacer les filtres » selon le cas (publications, agenda), « Tout réinitialiser » (cul-de-sac des parcours), « Voir toutes les notifications », aucun (modèles, inscrites, administration des membres) | faible |
| E89 | Équipe introuvable contre panne | `TeamUnavailable` (redirection sur 404/403, « Réessayer » sur 5xx) pour l'accueil d'équipe et les publications ; redirection vers la liste des équipes **sur toute absence**, panne comprise, pour parcours, annonces, membres, modèles, calendrier d'équipe (E22) | moyenne |

---

## Non vérifié

- **Rien n'a été vu à l'écran.** Tout « déduit » repose sur la sémantique de React Query (`isLoading` vrai sans données
  pour une clé neuve, `keepPreviousData` qui garde la page précédente) et de Riverpod (`autoDispose`, nouveau provider
  par clé de famille).
- **Toast sur une erreur 5xx du site** : un toast « errors.api.{code} » s'affiche si la réponse porte un `code`. Je n'ai
  pas vérifié si le backend renvoie un `code` sur une 500 ; s'il le fait, les listes sans état d'erreur (E84) affichent
  au moins un toast par-dessus leur vide.
- **Annonces et membres d'une équipe ouverts par lien direct par un non-membre dans l'app** (E49, E60) : je n'ai pas
  trouvé de garde dans le routeur ou la page ; la réponse 403 et le message affiché sont déduits.
- **Fil d'accueil de l'app pour une personne sans équipe** : la portée par défaut vient de `homeFeedDefaultScopeProvider`,
  non lu ; je ne sais pas si le fil y montre des publications publiques (comme le site, qui ouvre alors l'appartenance
  sur « toutes ») ou un vide sans action — dans ce cas l'app n'offre pas « Découvrir des équipes » depuis l'accueil.
- **Vue liste du calendrier du site** : `calendar.schedule.noEvents` est passé à `@mantine/schedule`, mais je n'ai pas lu
  dans quelle vue la bibliothèque l'affiche.
- **Persistance de l'onglet du shell** : que les listes de l'app restent montées quand on change d'onglet (et ne se
  rechargent donc pas au retour) se déduit de `StatefulShellRoute.indexedStack` ; les écrans poussés au-dessus du shell
  se rechargent à chaque ouverture.
- **Brief** : `pages/team/TeamDirectoryPage.tsx` n'est pas « découvrir des équipes » mais le **trombinoscope** d'une
  équipe (lu au membre, `TeamDirectoryPage.tsx:1-5`). Le site n'a pas de page de découverte à part : c'est
  `TeamListPage` avec l'appartenance « toutes ». Ce tableau traite le trombinoscope dans la section Membres. Aucune autre
  liste manquante n'a été trouvée sur cet axe.
