# Audit des listes — axe T : tri, recherche, pagination, compteur, sections

Lecture du code au 12 novembre 2026 (branche `feat/mobile-review`). Rien n'a été vérifié à l'écran. « Lu » = lu dans le code ; « déduit » = conséquence tirée du code, non observée.

## Synthèse

Les deux supports ont deux modèles de pagination opposés, ce qui est voulu : l'app fait du défilement infini par 20 avec un pied « N sur M · Vous avez tout vu », le site des numéros de page par 12 sans fin de liste. Les tris proposés sont les mêmes là où ils existent (annonces : six options identiques ; parcours : quatre champs + sens). Les écarts forts sont ailleurs. L'annuaire des équipes est trié par nombre de membres dans l'app et par nom sur le site. Les commentaires s'affichent du plus ancien au plus récent dans l'app et dans l'ordre inverse sur le site. « Mes équipes » dans l'app coupe sans rien dire à 20 équipes. « À venir » sur l'accueil du site est trié du plus lointain au plus proche, à l'inverse de l'Agenda. Sur les deux supports, le compteur de résultats et l'invite de recherche manquent ou divergent selon la liste. Tous les textes d'invite de recherche diffèrent entre l'app et le site, sauf celui des personnes inscrites.

## 1. Mécanique commune (toutes les listes paginées)

| # | Sujet | Listes concernées | App (valeur · fichier:ligne) | Site (valeur · fichier:ligne) | Verdict | Gravité |
|---|---|---|---|---|---|---|
| T1 | Mode de pagination | toutes | Défilement infini, chargement de la page suivante à 3 éléments de la fin · `core/pagination/paged_list_notifier.dart:14`, `:142-151` | Numéros de page Mantine (`withEdges`, 1 voisin, 1 bord) ; sur écran étroit « Page {{current}} sur {{total}} » avec flèches (`pagination.page`) · `components/common/Pagination.tsx:39-77` ; règle « jamais de scroll infini » dans `frontend/CLAUDE.md` | tient au support | — |
| T2 | Taille de page par défaut | fil, agenda, publications, parcours, annonces, équipes | 20 (`kDefaultPageSize`) · `paged_list_notifier.dart:8` | 12 · `publicationFilters.ts:5`, `agendaFilters.ts:5`, `teamPostFilters.ts:5`, `routeFilters.ts:30`, `adFilters.ts:13`, `teamFilters.ts:11` | écart (lié au mode de pagination ; aucun effet sur ce qui est montré en premier) | faible |
| T3 | Indicateur de fin de liste | toutes | Pied « {loaded} sur {total} » puis « Vous avez tout vu » (`pagination.progress`, `pagination.endOfList`) · `core/pdl/pdl_paged_list_footer.dart:128-137` | Pas d'indicateur de fin : la pagination disparaît dès qu'il n'y a qu'une page (`Pagination.tsx:29`). Une page au-delà de la fin affiche `OutOfRangeState` (« La liste s'arrête avant cette page. ») · `HomeFeedSection.tsx:183-184` | tient au support | — |
| T4 | Changement de filtre ou de recherche | toutes | Nouveau notifier par jeu de filtres (clé de famille), donc page 0. Retour en haut par `jumpTo(0)` · `paged_list_notifier.dart:22-24`, `publication_feed_view.dart:184-195`, `ads_page.dart:46-59`, `routes_page.dart:81-100` | `setFilters` remet `page` à 0 sauf si le patch la fixe · `hooks/useUrlFilters.ts:22`, `:156-157`. Le défilement n'est **pas** remis en haut sur changement de filtre (navigation REPLACE, « leaves the scroll alone ») · `hooks/useScrollRestoration.ts:28-31`. Il l'est seulement au changement de page (`scrollToListTop`) · `HomeFeedSection.tsx:177-180` | écart : sur le site, un filtre changé en bas de page laisse la personne au milieu de la nouvelle liste (déduit) | faible |
| T5 | Position au retour d'un détail | toutes | Le détail s'empile au-dessus du shell et la liste reste montée. `PageStorageKey` sur annonces et parcours · `ads_page.dart:69`, `routes_page.dart:174`. Position gardée : déduit, non lu de bout en bout | Restauration manuelle sur navigation POP, avec page et filtres dans l'URL · `useScrollRestoration.ts:32-80`, monté dans `components/common/Layout.tsx:85` | tient au support | — |
| T6 | Débounce de la recherche | toutes celles qui cherchent | 350 ms · `core/pdl/pdl_search_field.dart:14` | 300 ms · `hooks/useDebouncedSearch.ts:20` (et 300 ms codés à la main dans la modale des personnes inscrites · `components/ride/ParticipantListModal.tsx:36-41`) | écart | faible |
| T7 | Longueur minimale, nettoyage | toutes | Pas de minimum. Saisie rognée, et vide traité comme `null` · `pdl_search_field.dart:110-113` | Pas de minimum. **Pas de rognage** : `value \|\| undefined`, donc « ␣␣ » part à l'API · `HomeFeedSection.tsx:63-66` (même motif dans chaque page) | écart | faible |
| T8 | Bouton d'effacement | toutes | Croix en suffixe, cible de 44 px, info-bulle `common.clearSearch` « Effacer la recherche » quand l'appelant la passe · `pdl_search_field.dart:182-193` | `CloseButton` en `rightSection`, **sans `aria-label`** · `components/common/SearchInput.tsx:41` | écart (accessibilité côté site) | faible |
| T9 | Recherche combinée aux filtres | toutes | Oui. La recherche fait partie de la clé de filtres (`PublicationFeedKey.search`, `AdFilters.search`, `RouteFilters.search`) | Oui. La recherche est un champ du schéma de filtres d'URL (`searchField`) · `hooks/filters/common.ts:4` | identique | — |
| T10 | Ordre stable entre deux pages (backend) | parcours, annonces, fil, agenda, membres | Ne dépend pas du client. L'app supprime les doublons par `itemKey` · `paged_list_notifier.dart:42-48` | Ne dépend pas du client. Le site ne supprime pas les doublons | Backend : `te.dateTime desc` par défaut sans départage par id · `TeamEntityRepository.java:395`. Tri explicite `champ sens` sans id · `RouteRepository.java:214-217`, `AdRepository.java:125-128`. **Membres sans `sortBy` : aucun ORDER BY** · `UserTeamRepository.java:97-100` (contrat : « Omitted, the order is unspecified »). Seules les équipes départagent par id · `TeamRepository.java:150-158` | identique des deux côtés (risque de doublons ou de trous entre deux pages, déduit) | moyenne |

## 2. Fil d'accueil

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| T11 | Ordre par défaut | fil d'accueil | Aucun `sortDir` ni `when` envoyé, donc `dateTime desc` côté backend · `features/feed/providers/publication_feed_provider.dart:149-159`, `TeamEntityRepository.java:395` | Idem pour la portée « Tout » · `hooks/filters/publicationFilters.ts:63-75` | identique | — |
| T12 | Ordre de la portée « À venir » | fil d'accueil (site) | — (l'app n'a pas de portée temporelle sur l'accueil) | `scope=upcoming` envoie `from=now` **sans `when` ni `sortDir`** · `publicationFilters.ts:16-28`. Le backend reste donc en `dateTime desc` : la sortie la plus lointaine d'abord · `PublicationService.java:247-248`. L'API accepte `when=UPCOMING` sur `/api/publications` (`contracts/openapi.yaml`, paramètre `when`) | écart interne au site (voir §12) ; l'API le permet | moyenne |
| T13 | Tri proposé | fil d'accueil | Aucun | Aucun | identique. L'API accepte `sortDir` ; aucun client ne l'expose | — |
| T14 | Invite de recherche | fil d'accueil | « Rechercher une publication… » · `home.feed.searchPlaceholder`, `publication_feed_view.dart:526` | « Rechercher par titre ou description... » · `home.feed.search.placeholder`, `HomeFeedSection.tsx:106` | écart. API : `te.name`, `te.markdown` · `TeamEntityRepository.java:411` | moyenne |
| T15 | Compteur | fil d'accueil | Dans l'en-tête de section « Dernières publications » : « {} publication(s) », zéro « Aucune publication » (`home.publicationCount`), par l'endpoint `count` filtré · `publication_feed_view.dart:283-298`, `publication_feed_provider.dart:112-131` | Titre « Dernières publications » (`home.feed.title`). Ligne séparée sous les filtres « {{formatted}} publication(s) » (`list.count.publications`) · `HomeFeedSection.tsx:145`. À zéro : « 0 publication » (forme `_one` du français), affiché au-dessus de l'état vide | écart (place et forme à zéro) | faible |
| T16 | Sections | fil d'accueil | Aucune ; l'en-tête « Dernières publications » est unique | Aucune | identique | — |

## 3. Fil d'une équipe (Publications)

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| T17 | Ordre | publications d'équipe | `type=POST`, sans `when`, donc `dateTime desc` · `team_home_page.dart:252-263` | Idem · `teamPostFilters.ts:27-35` | identique | — |
| T18 | Invite de recherche | publications d'équipe | « Rechercher une publication… » · `teams.posts.searchPlaceholder`, `team_home_page.dart:261` | « Rechercher par titre ou description... » · `teams.posts.search.placeholder`, `TeamPostsPage.tsx:93` | écart | moyenne |
| T19 | Compteur | publications d'équipe | **Aucun** : `countLabel` n'est pas passé · `team_home_page.dart:252-263` | « {{formatted}} publications » · `TeamPostsPage.tsx:106` | écart. Le client app a `countPublications` (déjà appelé par l'Agenda) | moyenne |

## 4. Agenda d'une équipe

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| T20 | Ordre par défaut | agenda | `when=UPCOMING` (ou `PAST`), et `participating` pour « Je participe ». Ordre fixé par le serveur : départ le plus proche d'abord, passées les plus récentes d'abord · `team_agenda_page.dart:156-159`, `PublicationService.java:237-249` | Idem · `agendaFilters.ts:60-71` | identique | — |
| T21 | Invite de recherche | agenda | « Rechercher dans l'agenda… » · `teams.agenda.searchPlaceholder`, `team_agenda_page.dart:160` | « Rechercher par titre ou description... » (`agenda.search.placeholder`), libellé « Rechercher dans l'agenda » ; le champ est dans un panneau repliable « Filtres » · `TeamAgendaPage.tsx:197-204` | écart | moyenne |
| T22 | Compteur | agenda | Mêmes formulations par période et par type (« {} sortie(s) et voyage(s) à venir »…, `teams.agenda.count.*`). Rien quand le total vaut 0 · `publication_feed_view.dart:233-241`, `:300-310` | Mêmes formulations (`list.count.agenda*`) · `TeamAgendaPage.tsx:231-234`, `:313-317`. À 0 : « 0 sortie ou voyage à venir » | écart à zéro seulement | faible |
| T23 | Total et éléments montrés | agenda (site) | — | Les éléments non datés sont retirés côté client (`.filter(isDated)`) alors que le compteur affiche le `total` serveur · `TeamAgendaPage.tsx:134` | écart possible entre compteur et cartes (déduit) | faible |
| T24 | Sections | agenda | Aucune (liste plate) | Aucune (vignettes ou lignes) | identique | — |

## 5. Calendrier

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| T25 | Regroupement | calendrier | Grille du mois plus agenda groupé par jour : en-têtes « Aujourd'hui · <date> », « Demain · <date> », sinon la date complète. Un séparateur « À venir » (`calendar.upcoming`) apparaît une fois entre passé et à venir · `calendar_page.dart:417-434`, `agenda_card.dart:65-78` | Vues jour, semaine, mois et année de `@mantine/schedule`, mois par défaut · `components/calendar/CalendarView.tsx:111`. Pas de séparateur passé / à venir | tient au support (en partie) ; pas de pagination ni de tri, des deux côtés | faible |

## 6. Parcours d'une équipe et tous les parcours

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| T26 | Tri par défaut | parcours | `DATE_TIME` `DESC`, toujours envoyé · `routes/domain/route_filters.dart:19-20` | `DATE_TIME` `DESC`, toujours envoyé · `components/route/routeFilterDefaults.ts:3-4`, `routeFilters.ts:60-61` | identique | — |
| T27 | Options et ordre | parcours | Distance, Dénivelé, Relief, Date (ordre de l'énumération), puis « Croissant » ou « Décroissant » en segmenté · `route_filter_sheet.dart:513-531`, `routes.sort.*` | Même ordre, `Object.values(RouteSortBy)`, mêmes libellés · `RouteFilterPanel.tsx:218-223`, `routes.list.filters.sort.*` | identique | — |
| T28 | Forme du contrôle de tri | parcours | Chip toujours visible au-dessus de la liste, libellé = champ seul (« Date ») avec un chevron pour le sens · `route_filter_chips_bar.dart:59-66`. Également dans la feuille de filtres « Trier par : Date ↓ » · `route_filter_sheet.dart:124-126`, `:209-211` | `Select` étiqueté « Trier par » plus un bouton-chevron pour le sens, **dans le panneau replié** « Filtres » · `RouteFilterPanel.tsx:206-249` | écart (sur le site, le tri n'est visible qu'une fois le panneau ouvert) | moyenne |
| T29 | Le tri compte-t-il comme filtre ? | parcours | Non : « Sorting is not a filter » ; hors du compte de filtres actifs · `route_filters.dart:157-186` | Oui : un tri autre que le défaut fait apparaître « Effacer les filtres », qui remet aussi le tri à zéro · `RouteFilterPanel.tsx:58-76` | écart | faible |
| T30 | Persistance du tri | parcours, annonces | En mémoire (`StateProvider.autoDispose.family`), perdu dès que la section n'est plus affichée · `route_list_provider.dart:20`, `ad_list_provider.dart:10` | Dans l'URL (`?sort=`, `?dir=`) · `routeFilters.ts:79-80`, `adFilters.ts:36-37` | tient au support | — |
| T31 | Tri sur la carte | carte des parcours | Chip de tri masquée en vue carte · `routes_toolbar.dart:128-131` | `showSort={false}` · `RoutesMapPage.tsx:49`, `AllRoutesMapPage.tsx:31` | identique | — |
| T32 | Invite de recherche | parcours | « Rechercher un parcours… » · `routes.filters.searchPlaceholder`, `routes_toolbar.dart:73` | « Rechercher par nom ou description... » · `routes.list.search.placeholder`, `RouteFilterPanel.tsx:108` | écart. API : `te.name`, `te.markdown` | moyenne |
| T33 | Compteur | parcours | « {} parcours », ou « {shown} parcours sur {total} » quand un filtre est actif (deux appels `count`). Nombres non formatés (`'$shown'`) · `routes_page.dart:409-434`, `routes.list.countOf` | « {{formatted}} parcours » seulement, total filtré, nombre formaté · `RouteListPage.tsx:89`, `AllRoutesPage.tsx:43` | écart (l'app dit aussi combien de parcours le filtre cache) | moyenne |

## 7. Annonces

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| T34 | Tri par défaut | annonces | `DATE_TIME` `DESC`, envoyé · `ads/domain/ad_filters.dart:22-23` | `DATE_TIME` `DESC`, envoyé · `components/ad/adSortOptions.ts:4-5` | identique | — |
| T35 | Options, libellés, ordre | annonces | « Plus récentes d'abord », « Plus anciennes d'abord », « Prix croissant », « Prix décroissant », « Nom A → Z », « Nom Z → A » · `ad_sort_sheet.dart:16-22`, `ads.sort.*` | Mêmes six options, mêmes clés et textes, même ordre · `adSortOptions.ts:14-21` | identique | — |
| T36 | Forme du contrôle | annonces | Bouton de tri dont le libellé est l'option courante (« Plus récentes d'abord »), qui ouvre une feuille « Trier par » · `ads_toolbar.dart:57-62`, `ad_sort_sheet.dart:67` | `Select` étiqueté « Trier par » dans la barre de filtres · `AdListPage.tsx:149-161` | tient au support | — |
| T37 | Invite de recherche | annonces | « Rechercher une annonce » (sans points de suspension) · `ads.list.searchPlaceholder`, `ads_toolbar.dart:46` | « Rechercher par titre ou description... », libellé « Rechercher des annonces » · `AdListPage.tsx:131-132` | écart. API : `te.name`, `te.markdown` | moyenne |
| T38 | Compteur | annonces | « {} annonce(s) » au-dessus de la liste · `ads_page.dart:166`. Pied « N sur M » non formaté et sans nom · `ads_page.dart:195-200` | « {{formatted}} annonce(s) » · `AdListPage.tsx:211` | identique pour l'en-tête | — |
| T39 | Endpoint `count` | annonces (app) | Le commentaire affirme que « `GET …/classifieds/count` **n'existe pas** », d'où l'impasse sans filtre suggéré · `ads_page.dart:20-23`, `:215-221` | — | l'API le permet : `/api/teams/{teamSlug}/classifieds/count` existe (`contracts/openapi.yaml`, § classifieds/count) ; l'app ne l'utilise pas | faible |

## 8. Mes équipes, découvrir des équipes

Remarque sur le périmètre : `pages/team/TeamDirectoryPage.tsx`, cité dans le brief sur cette ligne, est l'**annuaire des membres** d'une équipe, pas la découverte d'équipes (voir §9). Sur le site, « Mes équipes » et « Découvrir » forment une seule page, `TeamListPage.tsx`, avec un sélecteur d'appartenance.

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| T40 | Ordre de l'annuaire | découvrir des équipes | `sortBy=MEMBER_COUNT`, `sortDir=DESC` : les plus peuplées d'abord · `team_discovery_filters.dart:28`, `team_repository.dart:110-111` | Aucun `sortBy`, donc nom croissant côté backend · `teamFilters.ts:31-37`, `TeamRepository.java:151-153` | écart. Avec la pagination, la première page ne montre pas les mêmes équipes (déduit) ; l'API permet `MEMBER_COUNT`, le site ne l'envoie pas | forte |
| T41 | Tri proposé | équipes | Aucun choix, mais l'ordre est annoncé : « {count} · triées par nombre de membres » (`teams.discovery.countSortedByMembers`) · `teams_discover_page.dart:202-208` | Aucun choix, aucune mention | écart (l'API accepte `NAME` et `MEMBER_COUNT` ; aucun client ne laisse choisir) | faible |
| T42 | Pagination de « Mes équipes » | mes équipes (app) | `listTeams(minRole: MEMBER)` **sans `page` ni `size`**, donc 20 au plus (défaut du contrat), sans pagination ni pied · `team_repository.dart:23-26`, `teams_page.dart:76` | Paginé par 12 · `TeamListPage.tsx:115-122` | écart : au-delà de 20 équipes, l'app coupe sans rien dire (le défaut que `ad_repository.dart:22-24` dit avoir corrigé pour les annonces). La portée « mine » de Découvrir, elle, est paginée | forte |
| T43 | Recherche de « Mes équipes » | mes équipes | Cachée derrière une icône-loupe. **Locale**, sur le nom seulement, `toLowerCase().contains` sans ignorer les accents · `teams_page.dart:42-61`. Invite « Rechercher une équipe… » (`teams.search.hint`) | Côté serveur, sur `t.name` et `t.aboutPage.markdown` · `TeamRepository.java:117`. Invite « Rechercher des équipes... » · `TeamListPage.tsx:75` | écart (les champs cherchés diffèrent ; la recherche de l'app ne voit que les 20 équipes chargées, cf. T42) | moyenne |
| T44 | Invite de recherche Découvrir | découvrir | « Rechercher une équipe » (sans points de suspension) · `teams.discovery.searchPlaceholder`, `teams_discover_page.dart:277` | « Rechercher des équipes... » | écart | faible |
| T45 | Compteur | équipes | Découvrir : « {} équipe(s) · triées par nombre de membres ». Mes équipes : aucun | **Aucun** compteur sur `TeamListPage`, alors que `list.count.teams` existe et n'est utilisé nulle part · `components/common/ResultCount.tsx:24` | écart | moyenne |

## 9. Membres d'une équipe

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| T46 | Ordre | membres | Aucun `sortBy`, donc ordre non spécifié (cf. T10) · `team_repository.dart:69-86` | Aucun `sortBy` · `teamMemberFilters.ts:7-12` | identique ; l'API permet `JOINED_AT` (selon les droits), aucun client ne l'expose | moyenne (cf. T10) |
| T47 | Taille de page | membres | 20 · `team_repository.dart:78` | 50 · `teamMemberFilters.ts:5` | écart | faible |
| T48 | Invite de recherche | membres | « Rechercher un membre », la même pour tout le monde · `teams.membersList.searchPlaceholder`, `team_members_page.dart:290` | Annuaire : « Rechercher par nom... » ; administration : « Rechercher par nom ou e-mail... » · `TeamDirectoryPage.tsx:67-69`, `TeamMembersPage.tsx:203` | écart : l'app ne dit pas à un administrateur que l'e-mail est cherché aussi (API : `displayName` + `email` pour les admins · `UserTeamRepository.java:79-92`) | faible |
| T49 | Compteur | membres | « {} membre(s) » · `team_members_page.dart:216` ; pied « N membres sur M » | Annuaire : « {{formatted}} membre(s) » · `TeamDirectoryPage.tsx:81`. Page d'administration : pas de total filtré, seulement le compteur de limite sur `team.memberCount` · `TeamMembersPage.tsx:174-175` | écart côté administration du site | faible |

## 10. Personnes inscrites

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| T50 | Ordre | personnes inscrites | Ordre du serveur : `registeredAt, id` · `ParticipantPages.java:41` | Idem | identique | — |
| T51 | Pagination | personnes inscrites | 50 par page, bouton « Afficher plus » (pas de défilement infini) · `participant_list_provider.dart:24`, `participant_list_view.dart:205-212` | 50 par page, numéros de page · `groupParticipantFilters.ts:6`, `ParticipantList.tsx:195` | écart de forme | faible |
| T52 | Condition d'affichage de la recherche | personnes inscrites | Au-delà de 8 personnes · `participant_list_view.dart:103` | Dès 1 personne · `ParticipantList.tsx:95` | écart | faible |
| T53 | Invite de recherche | personnes inscrites | « Rechercher une personne… » · `participants.search` | « Rechercher une personne… » (modale) ; « Rechercher par nom… » sur la page d'un groupe · `ParticipantList.tsx:99`, `ParticipantsSection.tsx:69` | identique pour la modale, écart interne au site | faible |
| T54 | Compteur, progression | personnes inscrites | « {loaded} personnes sur {total} » (`pagination.progressNamed`, nombres formatés) · `paged_list_footer.dart:78-88` | Plage « {{from}}–{{to}} sur {{total}} » (`participants.shownOf`), sans nom ni formatage · `ParticipantList.tsx:188-194` | écart | faible |

## 11. Notifications, modèles de sortie, personnes bloquées, commentaires

| # | Sujet | Listes concernées | App | Site | Verdict | Gravité |
|---|---|---|---|---|---|---|
| T55 | Ordre, taille, recherche | notifications | `createdAt desc, id desc` côté serveur · `NotificationRepository.java:29`. 20 par page, pas de recherche | 20 par page, pas de recherche · `notificationFilters.ts:4` | identique (l'API n'a pas de `search`) | — |
| T56 | Compteur | notifications | « {} notification(s) » · `notifications_page.dart:279` ; pied « N sur M » non formaté · `:303-307` | « {{formatted}} notification(s) » · `NotificationListPage.tsx:60` | identique | — |
| T57 | Persistance de « Non lues » | notifications | `setState` local · `notifications_page.dart:37` | Dans l'URL (`?unread=`) · `notificationFilters.ts:8-21` | tient au support | — |
| T58 | Ordre, taille | modèles de sortie | `name ASC` côté serveur · `RideTemplateRepository.java:28` ; 20 | 20 · `rideTemplateFilters.ts:4` | identique | — |
| T59 | Invite de recherche | modèles de sortie | « Rechercher un modèle… » · `rides.templates.search`, `ride_template_list_page.dart:99` | « Rechercher par nom... » · `rideTemplates.list.search.placeholder`, `RideTemplateListPage.tsx:107` | écart. API : `name` | faible |
| T60 | Compteur | modèles de sortie | « {} modèle(s) » · `ride_template_list_page.dart:197` | **Aucun** (ni `ResultCount` ni clé `list.count.*` pour les modèles) | écart | moyenne |
| T61 | Personnes bloquées | personnes bloquées | Liste non paginée, sans recherche ni tri · `blocked_users_page.dart:64` | Idem, `useListMyBlockedUsers()` · `components/profile/BlockedUsers.tsx:22` | identique (l'API n'a pas de pagination pour cette liste) | — |
| T62 | Ordre des commentaires (liste absente du brief) | commentaires d'un détail | Aucun `sort` envoyé, donc ASC par défaut du contrat : **le plus ancien d'abord** · `comment_thread_provider.dart:39-44` | `sort: DESC` : **le plus récent d'abord** · `hooks/useComments.ts:55-57` | écart : avec la pagination, la première page ne montre pas les mêmes commentaires (déduit) | forte |
| T63 | Pagination des commentaires | commentaires | 20 par page (réponses chargées par 100), bouton « Voir plus de commentaires » (`comments.loadMore`) | 20 par page, « Charger plus de commentaires » · `useComments.ts:44` | écart de libellé | faible |

Site seulement, non détaillé : lieux d'équipe (`PlaceList`, recherche « Rechercher par nom ou adresse... », 20 par page), tags, signalements, pages, « Mes aperçus GPX » (12 par page).

## 12. Incohérences internes à l'app

- **Pied de liste en trois formes.** « N {nom} sur M » avec nombres formatés pour les modèles, membres, Découvrir et personnes inscrites (`pagedProgressNamed`). « N sur M » formaté, sans nom, pour le fil et l'Agenda (`PagedListFooter` sans `itemNounKey`). « N sur M » **non formaté** (`'${state.items.length}'`) pour les annonces, parcours et notifications · `ads_page.dart:195-200`, `routes_page.dart:310-316`, `notifications_page.dart:303-307`.
- **Compteurs d'en-tête non formatés** (déduit). `'….count'.plural(total)` d'easy_localization sans `format` donne « 2585 annonces », alors que les cartes ont reçu l'espace des milliers (MOB-139) · `ads_page.dart:166`, `routes_page.dart:427-430`.
- **Compteur présent ou absent selon la liste.** Absent des Publications d'équipe (T19) et de « Mes équipes ». Présent partout ailleurs.
- **Pagination.** Défilement infini partout, sauf les personnes inscrites et les commentaires, qui ont un bouton « Afficher plus » ou « Voir plus de commentaires ». « Mes équipes » n'est pas paginée du tout (T42).
- **Taille de page.** 20 partout, 50 pour les personnes inscrites. 20 pour les membres, alors que le pied de maquette cité dans `mobile/CLAUDE.md` parle de « 60 membres sur 1 999 ».
- **Points de suspension.** Absents de « Rechercher une annonce », « Rechercher un membre », « Rechercher une équipe » (Découvrir). Présents (« … ») ailleurs, y compris « Rechercher une équipe… » de « Mes équipes » : même chose, deux textes.
- **Recherche locale contre serveur.** « Mes équipes » filtre en mémoire sur le nom ; toutes les autres listes interrogent l'API.
- **Clé morte probable.** `home.searchPlaceholder` « Rechercher par titre ou description... » (le seul texte de l'app à « ... ») ne figure dans aucun des appels lus ; non vérifié par grep exhaustif.
- **Commentaire de code périmé.** L'endpoint `count` des annonces existe (T39).

## 13. Incohérences internes au site

- **« À venir » en deux ordres opposés.** L'Agenda envoie `when=UPCOMING` : la sortie la plus proche d'abord, et une sortie en cours reste visible. L'accueil envoie `from=now` : la plus lointaine d'abord, filtrée sur le départ et non sur la fin · `publicationFilters.ts:16-28` contre `agendaFilters.ts:60-71` (T12).
- **Compteur présent ou absent selon la liste.** Absent de la liste des équipes, des modèles de sortie et de la page d'administration des membres. Les personnes inscrites ont leur propre forme « 1–50 sur 120 ». `list.count.teams`, `rides`, `trips` et `participations` sont déclarés dans `ResultCount.tsx:9-27`, mais aucun écran lu ne les utilise.
- **Taille de page.** 12 pour les grilles de cartes, 20 pour les notifications, modèles et lieux, 50 pour les membres et personnes inscrites.
- **Invites de recherche.** « ... » (trois points) partout, sauf « Rechercher une personne… » et « Rechercher par nom… » des personnes inscrites (« … »). La formulation varie aussi entre « Rechercher par titre ou description... » (accueil, publications, agenda, annonces), « par nom ou description... » (parcours) et « par nom... » (modèles, annuaire).
- **Placement de la recherche.** Visible en tête de page sur l'accueil, les publications, les annonces et les équipes ; repliée dans « Filtres » dans l'Agenda et, avec le tri, dans les parcours.
- **Débounce de la modale des personnes inscrites.** Réécrit à la main au lieu de `useDebouncedSearch` (même délai de 300 ms) · `ParticipantListModal.tsx:36-41`. L'état en mémoire tient au support (une modale n'a pas d'URL).

## Non vérifié

- **Restauration de la position dans l'app au retour d'un détail.** Déduite de l'architecture (détail au-dessus du shell, `PageStorageKey`), non suivie dans le routeur.
- **Formatage des nombres par `.plural()` d'easy_localization.** Déduit de l'absence d'argument `format` ; le rendu réel « 2585 » contre « 2 585 » n'a pas été observé.
- **Doublons ou trous entre deux pages** (T10, T46). Le risque découle des ORDER BY lus ; aucune requête n'a été jouée. Je n'ai pas vérifié si Hibernate ajoute un départage implicite (je ne le crois pas).
- **Portée « Je participe » (`me`) de l'accueil du site.** Envoie `participating=true` sans `when` : l'ordre est donc `dateTime desc`, passées comprises (déduit du même `withWhen`) ; non tracé jusqu'au bout.
- **Ordre des événements dans la vue mois du site.** Celui de `@mantine/schedule`, non lu.
- **`home.searchPlaceholder` dans l'app.** Seuls les appels de `PdlSearchField` ont été lus ; une utilisation ailleurs n'est pas exclue.
