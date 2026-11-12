# Tri de l'audit des listes — trois tas (2026-11-12)

Étape 1 de la [méthode](../audit-cartes/METHODE.md). Matière : les 300 lignes de [filtres.md](filtres.md) (F),
[tri-recherche.md](tri-recherche.md) (T), [structure.md](structure.md) (S) et [etats.md](etats.md) (E). Proposition à
relire : rien n'est décidé ici.

**Synthèse.** 22 défauts, dont la moitié tient en une ligne. Le plus grave est côté site : neuf listes n'ont pas d'état
d'erreur, et une panne y passe pour une liste vide. Côté app, les parcours n'ont pas d'état vide simple, le fil ne
compte que la recherche comme filtre, et « Mes équipes » s'arrête à 20 sans le dire. Côté serveur, quatre listes n'ont
pas d'ordre total, et celle des membres n'a pas d'ordre du tout. Le reste se règle en 14 règles : 9 se voient et
auront une planche, une seule touche l'API (l'ordre des membres). 15 écarts tiennent au support. Deux d'entre eux sont
à confirmer, car ce sont des choix de produit : l'app ne crée ni annonce ni équipe.

**Lire une référence** : « F20 » = `filtres.md`, ligne F20 ; « T§12 » = `tri-recherche.md`, section 12 (non numérotée).
Chemins : `app/` = `mobile/lib/`, `site/` = `frontend/src/`, `back/` = `backend/src/main/java/fr/pedalons/`.

**Comment j'ai tranché** :

- Un état qui ment est un défaut : une panne affichée comme un vide, un vide affiché comme « filtré », une liste coupée
  sans le dire, un libellé qui promet autre chose que ce que la liste montre.
- Quand les deux supports ont chacun une forme qui se défend, c'est une décision. Dans le doute, j'ai classé en décision.
- Les défauts forts ont été relus dans le code. Ce qui n'a pas pu être lu est marqué « écran d'abord ».

**Corrections et compléments à l'audit** (vérifiés dans le code) :

- **F20, F46, confirmés.** Sans `minRole`, `GET /api/routes` rend aussi le contenu public des équipes publiques. La
  clause de rôle est seule à retirer cette branche (`back/repository/common/TeamEntityRepository.java:350-355`,
  `getPublicEntity` :426-440). Le calendrier global s'en tient bien aux équipes de la personne
  (`back/service/calendar/CalendarService.java:226-241`).
- **T10, incomplet.** « Seules les équipes départagent par id » est faux. Les notifications (`createdAt desc, id
  desc`), les personnes inscrites (`registeredAt, id`), les commentaires (TSID) et les membres triés par `JOINED_AT`
  le font aussi. L'audit oublie en revanche deux listes sans départage : les modèles (`name ASC`,
  `back/repository/…/RideTemplateRepository.java:28`) et l'agenda « À venir » (`dateTime asc`,
  `back/repository/common/AllPublicationRepository.java:161-163`).
- **T62, T42, T12, confirmés.** Les commentaires sont rendus du plus ancien au plus récent par défaut
  (`back/dto/comments/request/CommentListParams.java:41-43, 66`). La liste des équipes prend `size=20` par défaut
  (`back/api/…/TeamResource.java:76`). La période « À venir » de l'accueil du site n'envoie que `from`
  (`site/hooks/filters/publicationFilters.ts:20-21`).
- **Pas de contradiction de fait** entre les quatre audits. Ils s'accordent tous sur `TeamDirectoryPage` (l'annuaire
  des membres), `TeamListPage` (la découverte) et `TeamMembersPage` (l'administration, propre au site). Ce tri compare
  donc les membres de l'app à `TeamDirectoryPage`. `TeamMembersPage` n'apparaît que pour les incohérences internes au
  site.

---

## Décisions prises

### Décisions du 12 novembre 2026, sans planche

| Règle | Décision |
|---|---|
| **RL1** | Une liste inter-équipes s'ouvre sur **mes équipes** (« Membre »), ou sur toutes les équipes pour qui n'en a aucune. Explorer › Parcours de l'app s'aligne. |
| **RL5** — membres | **Par nom**, départagé par id. Nouvelle valeur `NAME` de `MemberSortBy`, ordre par défaut de l'API (DL22). |
| **RL5** — commentaires | **Le plus ancien d'abord**, des deux côtés. Le site change. |
| **RL5** — équipes | **Selon la portée** : mes équipes par nom, toutes les équipes par nombre de membres. L'ordre est dit à côté du compteur. |
| **RL7** | Invite de recherche : **« Rechercher {un objet}… »** partout, avec « … » (U+2026), même texte des deux côtés. Exception : « Rechercher par nom ou e-mail… » pour qui administre les membres. |
| **RL12** | Retenu sans question (option recommandée, sans enjeu) : dans l'app, un seul pied « {N} {objets} sur {M} · Vous avez tout vu », formaté ; « Afficher plus de commentaires » des deux côtés ; la taille de page reste propre à chaque support. |
| **RL14** | **Ce n'était pas une décision.** Le serveur refuse la liste des modèles à qui n'organise pas (`back/service/ridetemplate/RideTemplateAccessChecker.java:40`, vérifié). L'app a raison. Devient deux défauts : **DL23** (site : la page des modèles s'ouvre à une personne simplement membre, qui reçoit un refus) et **DL24** (app : la section Annonces manque à une personne qui administre la plateforme sans être membre, alors que le site la lui montre). |
| **VL11** | **Voulu** : l'app ne crée ni annonce ni équipe. À écrire dans « Délibérément dehors ». |

### RL15 — Événements datés quand on affiche « Tout » (demande du 12 novembre 2026)

Demande de la personne qui décide, hors audit : pour les événements datés (sorties, voyages), quand la liste affiche
tout, il faut **deux listes** : « À venir », du plus proche au plus lointain, puis « Passées », du plus récent au plus
ancien. Aujourd'hui « Tout » est une seule liste en `dateTime desc` : la sortie la plus lointaine d'abord, la prochaine
noyée au milieu (T12, DL16 pour le cas « À venir » de l'accueil du site).

- **Listes** : agenda d'une équipe, fil d'accueil et publications quand ils montrent des sorties ou des voyages, « Mes
  sorties » du tableau de bord.
- **À trancher sur planche** : la place des publications (non datées par un départ) dans un fil mixte ; deux sections
  dans une seule liste paginée, ou deux listes côte à côte ; le libellé des en-têtes.
- **Coût** : **API** — un ordre « à venir d'abord (croissant), puis passées (décroissant) » servi par page, pour que les
  numéros de page du site et le défilement de l'app restent une seule liste ; ou deux requêtes par client. App S, site S.
- **Se voit** : oui, planche.

### Décisions du 12 novembre 2026, sur les planches « Listes — cibles »

Toutes les options recommandées ont été retenues. La forme vérifiable de chaque règle est dans
[`maquettes/KIT.md` §10](../maquettes/KIT.md).

| Règle | Décision |
|---|---|
| **RL2** | Un contrôle de portée par support ; le choix d'une équipe au calendrier global seulement. Explorer de l'app perd son choix d'équipe. |
| **RL3** | L'app gagne la période du fil d'accueil et le prix des annonces ; le site gagne « Ouvertes à l'adhésion » et l'équipe au calendrier global. « Autour de moi » reste à l'app seule. |
| **RL4** | La pastille compte ce que « Effacer les filtres » lève : tout sauf le tri. La portée revient à son défaut (le code de l'app la gardait : `route_filters.dart`, `cleared`). |
| **RL6** | Recherche et tri toujours visibles, des deux côtés ; le panneau de l'agenda du site disparaît. |
| **RL8** | Total filtré seul, masqué à zéro. |
| **RL9** | Un seul contrôle de vue, comme le site ; l'app gagne la vue en lignes de l'agenda. **Revient sur l'écart voulu `MOB-140`.** |
| **RL10** | Deux états de vide, filtres nommés dans le vide filtré. |
| **RL11** | Une forme d'erreur par support ; plus de notification par-dessus le bloc ; liste estompée sur le site pendant un changement de filtre. |
| **RL13** | Bouton court « Créer » dans la barre de l'app (agenda, parcours, modèles) ; libellés « Créer {un objet} » sur le site. |
| **RL15** | Une liste, deux sections « À venir » · « Plus tôt » ; les publications dans la seconde ; agenda « Toutes les dates / Je participe » ; fil d'accueil « Tout / Je participe ». Ajout à l'API (`API-185`). |

Conséquence : les planches RL4, RL6, RL9, RL10 et RL13 dessinent encore l'agenda avec ses trois périodes ; la barre
décidée par RL15 prévaut.

---

## 1. Défauts

Un seul côté a raison. Corrigés sans maquette, au lot 0.

### App

| # | Ce qui est faux | Correction | Réfs | Taille | Écran d'abord |
|---|---|---|---|---|---|
| DL1 | Parcours : aucun état vide simple. Une équipe sans parcours affiche « Aucun parcours pour ces filtres » et un « Tout réinitialiser » sans effet (`app/features/routes/presentation/pages/routes_page.dart:240-246, 469-510`, vérifié) | Tester les filtres avant de choisir. Sans filtre : « Aucun parcours », plus « Ajouter » pour qui gère les parcours | E35, E82 | S | |
| DL2 | Fil et agenda : seuls la recherche et les tags comptent comme filtre. « Sorties » ou « Je participe » sans résultat affichent « Rien à l'agenda pour le moment » (`app/features/feed/presentation/widgets/publication_feed_view.dart:376`, vérifié). Le calendrier, lui, les compte | Tout critère qui s'écarte de son défaut compte comme filtre. Pour la période, voir RL10 | E11, E24, E81 | S | |
| DL3 | Calendrier : « Ce mois contient des événements, mais aucun ne correspond… » s'affiche dès qu'un filtre est posé, même sur un mois vide (`app/features/calendar/presentation/pages/calendar_page.dart:359-382`) | Afficher cette phrase seulement si le mois a des événements. Sinon, afficher le message du mois vide | E30 | XS | |
| DL4 | Calendrier d'une équipe : « Vos équipes n'ont publié… » (`calendar_page.dart:395`) | « L'équipe n'a publié… ». Ligne faible, remontée parce que la phrase est fausse | E34 | XS | |
| DL5 | « Mes équipes » : `listTeams` est appelé sans `page` ni `size`. La liste s'arrête à 20 sans le dire, et la recherche locale ne voit que ces 20, sans tenir compte des accents (`app/features/teams/data/team_repository.dart:23-26`, vérifié) | Paginer comme Découvrir, avec une recherche côté serveur | T42, T43 | S | |
| DL6 | Explorer › Parcours : « Toutes mes équipes » (`routes.scope.allTeams`) nomme une portée qui inclut les équipes publiques (vérifié côté serveur) | « Toutes les équipes », comme l'accueil. « Toutes mes équipes » reste au calendrier, où c'est vrai. Ce qui s'affiche à l'ouverture relève de RL1 | F20, F46 | XS | |
| DL7 | Agenda et calendrier d'une équipe : « Sorties » et « Voyages » sont toujours proposés, même sans le module (`app/features/teams/presentation/pages/team_agenda_page.dart:27-31, 148`, `calendar_toolbar.dart:119-125`) | N'afficher un type que si l'équipe a le module, comme le site | F10 | XS | |
| DL8 | Nombres non formatés : en-têtes « 2585 annonces » (`.plural(total)` sans `format`), pieds « 8 sur 40 » sans nom (`'${state.items.length}'`) sur les annonces, les parcours et les notifications (`app/features/ads/presentation/pages/ads_page.dart:166, 195-200`, `routes_page.dart:316-321, 427-430`, `notifications_page.dart:303-309`) | `formatNumber` partout, pied nommé (`pagedProgressNamed`) | T38, T56, T§12, E43, E78 | XS | oui (déduit) |
| DL9 | Un refus est affiché comme une panne. Une personne non membre qui ouvre les annonces par un lien lit « rubrique non activée, ou réseau indisponible ». Une liste de membres non partagée donne « Erreur de chargement » | Sur un 403, afficher « Réservées aux membres » ou « Liste non partagée », comme le site | E49, E60 | S | oui (déduit) |
| DL10 | Erreur de « Mes équipes » titrée « Équipe indisponible », clé de la page d'une seule équipe (`app/features/teams/presentation/pages/teams_page.dart:133`) | Utiliser le titre d'erreur des listes | E54 (app), E79 | XS | |

### Site

| # | Ce qui est faux | Correction | Réfs | Taille | Écran d'abord |
|---|---|---|---|---|---|
| DL11 | Neuf listes n'ont pas d'état d'erreur : une panne affiche leur état vide (« Aucune publication pour le moment », « Aucune annonce »…). Sont touchés : publications d'équipe, agenda, calendrier global et d'équipe, parcours d'équipe, annonces, modèles, personnes bloquées, administration des membres. `isError` de la liste n'y est jamais lu (vérifié : `site/pages/team/TeamPostsPage.tsx:45`, `TeamAgendaPage.tsx:78`, `site/pages/route/RouteListPage.tsx:37`…) | Un état d'erreur avec « Réessayer » sur chaque liste, sur le composant de RL11 | E21, E27, E32, E39, E48, E59, E74, E76, E84 | M | toast sur 5xx (E, Non vérifié) |
| DL12 | Erreur sans « Réessayer » : fil d'accueil, tous les parcours (`error.loading`) et personnes inscrites, dont le texte dit « Réessayez » sans donner de bouton (`site/components/home/HomeFeedSection.tsx:153-161`, `site/components/route/RouteListContent.tsx:63-74`, `site/components/ride/ParticipantList.tsx:107-110`, vérifié) | Ajouter « Réessayer » | E15, E40, E65 | XS | |
| DL13 | Équipes : en cas d'erreur, une alerte rouge affiche le message brut. En dessous s'affiche « Aucune équipe n'a encore été créée sur ce site » avec « Créer une équipe » (`site/pages/team/TeamListPage.tsx:96-148`, vérifié) | Afficher seulement l'état d'erreur, sans le vide | E54 | XS | |
| DL14 | Parcours, annonces, administration des membres, modèles, calendrier d'équipe : sur une panne (5xx), l'équipe manque et la page redirige vers la liste des équipes (`RouteListPage.tsx:49-51`, vérifié, et les quatre autres) | Utiliser `TeamUnavailable`, comme l'accueil d'équipe et les publications | E22, E89 | S | |
| DL15 | Page au-delà de la fin : parcours, membres, notifications et modèles affichent leur état vide (« Aucun parcours »…) | `OutOfRangeState`, comme les cinq autres listes | E9, E86 | XS | |
| DL16 | Accueil, « À venir » : seul `from=now` est envoyé. La sortie la plus lointaine passe en premier, et une sortie en cours disparaît (vérifié) | Envoyer `when=UPCOMING`, comme l'agenda. L'API le permet déjà | T12, T§13 | XS | |
| DL17 | Après la création d'une sortie ou d'une publication, seules la liste de l'équipe et son tableau de bord sont invalidés. Le fil d'accueil peut rester ancien jusqu'à 3 min, le calendrier jusqu'à 5 min (`site/lib/teamDashboardCache.ts:19-22`, vérifié) | Invalider aussi `listAllPublications` et `getEvents`, comme `site/lib/registration.ts:18-21` | E18 | XS | |
| DL18 | Le calendrier global n'a aucun filtre de type, alors que le calendrier d'équipe en a un sur les mêmes `CalendarEventDto` (`site/pages/calendar/CalendarPage.tsx:17-32`) | Filtre de type côté client, comme `TeamCalendarPage`. Le choix d'une équipe relève de RL3 | F16 (type), F54, S28, S89 | S | |
| DL19 | La croix d'effacement de la recherche n'a pas de nom accessible (`site/components/common/SearchInput.tsx:41`) | `aria-label` « Effacer la recherche ». Ligne faible, remontée pour l'accessibilité | T8 | XS | |

### Les deux

| # | Ce qui est faux | Correction | Réfs | Taille | Écran d'abord |
|---|---|---|---|---|---|
| DL20 | Vide filtré sans issue : modèles, des deux côtés (`app/features/rides/presentation/pages/ride_template_list_page.dart:177-181`, `site/pages/ridetemplate/RideTemplateListPage.tsx:145-147`). Sur le site seulement, les personnes inscrites et l'administration des membres | « Effacer la recherche » ou « Effacer les filtres » | E73, E63, E58 | XS | |

### Backend

| # | Ce qui est faux | Correction | Réfs | Taille | Écran d'abord |
|---|---|---|---|---|---|
| DL21 | L'ordre n'est pas total. Sans départage par id, l'offset peut répéter ou sauter un élément entre deux pages. Sont touchés : `dateTime desc` / `asc` (fil, agenda, publications : `TeamEntityRepository.java:395`, `AllPublicationRepository.java:161-163`), `champ sens` (parcours, annonces : `RouteRepository.java:214-217`, `AdRepository.java:125-128`) et `name ASC` (modèles : `RideTemplateRepository.java:28`). Tout est vérifié | Terminer chaque clé par `id` dans le même sens, comme `TeamRepository.java:150-158`. Ne remplace pas `API-21`, qui le demande aussi. API : le comportement change, pas le contrat | T10 | S | |
| DL22 | Membres sans `sortBy` : aucun `ORDER BY` (`UserTeamRepository.java:96-100`, vérifié). Le contrat dit « unspecified » | Un ordre par défaut (le choix relève de RL5), départagé par id. API : la description du contrat change, la version aussi | T10, T46 | S | |

---

## 2. Décisions

Quatorze règles. Chacune se lit seule.

### RL1 — Ce qu'une liste inter-équipes montre à l'ouverture

- **Question** : à l'ouverture, une liste inter-équipes montre-t-elle mes équipes, ou aussi les équipes publiques ?
- **App** : le fil d'accueil s'ouvre sur « Membre », ou sur toutes les équipes pour qui n'en a aucune (F2). Explorer ›
  Parcours s'ouvre sans rôle : mes équipes plus le contenu public des équipes publiques (F20, vérifié). Les équipes ont
  deux écrans, « Mes équipes » et « Découvrir », ce dernier sur « Toutes » (F37).
- **Site** : une seule règle partout (`useMembershipDefault`) : « Membre », ou toutes pour qui n'a aucune équipe. Elle
  vaut pour le fil, les parcours et les équipes (F20, F37, E50).
- **Listes** : fil d'accueil, Explorer (liste et carte), équipes.
- **Options** :
  1. *(recommandée)* La règle du site partout. Elle est déjà celle de l'accueil des deux côtés. L'app n'a qu'une valeur
     par défaut à changer, dans Explorer.
  2. Explorer s'ouvre sur toutes les équipes, sur les deux supports : c'est un écran de découverte de parcours.
- **Se voit** : non. Le contenu change, pas la forme.
- **Coût** : app XS (`route_filters.dart`). Site : rien avec l'option 1. API : non.
- **Réfs** : F20, F37, F45, E50.

### RL2 — Contrôle de portée : forme, valeurs, choix d'une équipe

- **Question** : sous quelle forme choisit-on la portée d'une liste, et peut-on y choisir une équipe ?
- **App** : trois formes (F47, S80). À l'accueil, une puce et une feuille de quatre rôles. Dans Explorer, une feuille
  « équipe, puis rôle minimum » (F21). Au calendrier, des puces d'équipe jusqu'à trois équipes, puis un sélecteur. Les
  équipes ont deux écrans ; Découvrir propose « Toutes / Ouvertes à l'adhésion / Mes équipes » (S53, S55).
- **Site** : un `Select` de rôle, sans choix d'une équipe (F21). Il existe en trois copies : 180, 200 et 160 px,
  « Toutes les équipes » ou « Toutes », aria « Équipes » ou « Filtre » (F52). Les équipes tiennent sur une page (S53,
  S54).
- **Listes** : fil d'accueil, Explorer, calendrier global, équipes.
- **Options** :
  1. *(recommandée)* Un seul contrôle « Portée » par support : la feuille dans l'app, un composant `MembershipSelect`
     sur le site. Valeurs : « Toutes les équipes / Membre / Organisateur / Administrateur ». Le choix d'une équipe ne
     vaut qu'au calendrier global, sur les deux supports, car il n'a pas de page par équipe. Ailleurs, la page de
     l'équipe existe déjà. Les équipes gardent deux écrans dans l'app et une page sur le site ; seuls les mots
     s'alignent (« Mes équipes » = « Membre »).
  2. Le site ajoute le choix d'une équipe partout où l'app l'a (Explorer, calendrier).
- **Se voit** : oui. Planche : barres de l'accueil, d'Explorer et du calendrier.
- **Coût** : app S (trois formes à fondre). Site XS (un composant au lieu de trois) plus S (équipe au calendrier
  global : appeler l'endpoint de l'équipe, comme l'app). API : non.
- **Réfs** : F2, F3, F21, F47, F52, S53, S54, S55, S80, E50.

### RL3 — Quels critères une liste propose

- **Question** : pour chaque critère présent d'un seul côté, l'ajoute-t-on à l'autre ?
- **État et recommandation** (l'API permet chacun de ces critères) :

  | Critère | App | Site | Recommandé | Réfs |
  |---|---|---|---|---|
  | Période « Tout / À venir / Je participe » au fil d'accueil | non | oui | l'app l'ajoute : c'est le contrôle principal de l'accueil du site | F1, S3 |
  | Choix d'une équipe au calendrier global | oui | non | le site l'ajoute (RL2) | F16, S28 |
  | Prix min. / max. des annonces | non | oui | l'app l'ajoute dans sa feuille | F32 |
  | « Ouvertes à l'adhésion » | oui | non | le site l'ajoute, à côté du rôle | F38 |
  | Proximité « Autour de moi » | oui | non | garder l'app seule : au bureau, on déplace la carte ; au téléphone, on est sur place | F22 |
  | Rôle Organisateur / Administrateur sur les équipes | non | oui | ne pas l'ajouter à l'app : « Mes équipes » est courte | F39 |
  | « Je participe » au calendrier global | non | non | ne pas l'ajouter | F17 |
  | Proximité, période sur les annonces | non | non | ne pas l'ajouter | F36 |

- **Autre option** : tout critère permis par l'API, des deux côtés (proximité sur le site, rôle dans l'app).
- **Se voit** : oui. Planche : barre de l'accueil de l'app, feuille des annonces, page équipes du site.
- **Coût** : app S (période de l'accueil) et S (prix). Site XS (adhésion) et S (équipe au calendrier). API : non.
- **Réfs** : F1, F16, F17, F22, F32, F36, F38, F39, S3, S28.

### RL4 — Signaler un filtre actif, et le lever

- **Question** : comment voit-on qu'une liste est filtrée, et que lève « Effacer les filtres » ?
- **App** : une pastille de compte sur le bouton de filtres, aux parcours seulement (F29, F48). Ailleurs, seules les
  puces sélectionnées le disent. Chaque liste lève autre chose. L'accueil n'efface que la recherche (F5) et l'agenda
  rien (F14). La feuille des parcours garde la recherche, le tri et la portée (F30), mais son « Tout réinitialiser »
  remet le tri (F51). Les annonces gardent le tri (F35). Dans les publications, « Effacer la recherche » laisse le tag
  (E20). Retoucher une puce exclusive la lève sur certaines listes, pas sur d'autres (F49).
- **Site** : l'agenda teinte son bouton « Filtres » (F13). Aux parcours, le bouton ne change jamais : seul « Effacer »
  apparaît (F29). Ailleurs, rien ne le signale (F55). L'étendue de la réinitialisation change d'une liste à l'autre
  (F56). Aux parcours, un tri choisi compte comme un filtre (T29).
- **Listes** : toutes celles qui filtrent.
- **Options** :
  1. *(recommandée)* Un compteur sur le bouton « Filtres » partout où une feuille ou un panneau existe. Replié, le
     panneau du site ne dit rien sinon. Un seul geste, « Effacer les filtres » : il lève la recherche, les critères et
     les tags, et remet la période et la portée à leur défaut. Il garde le tri, car le tri n'est pas un filtre (c'est
     déjà la règle de l'app). Retoucher une puce exclusive ne la lève pas : c'est le rôle de « Tout ».
  2. Même chose, mais la recherche reste hors de la réinitialisation : elle a sa propre croix.
- **Se voit** : oui. Planche : bouton « Filtres » au repos et actif, panneau replié du site.
- **Coût** : app S. Site S. API : non.
- **Réfs** : F5, F8, F13, F14, F29, F30, F35, F48, F49, F51, F55, F56, T29, E20, E88.

### RL5 — Ordre par défaut

- **Question** : dans quel ordre s'ouvrent les listes où les deux supports diffèrent, ou dont l'ordre n'est pas défini ?
- **État** :
  - Découvrir des équipes : l'app trie par nombre de membres, du plus grand au plus petit, et le dit (« triées par
    nombre de membres »). Le site trie par nom (T40, T41).
  - Commentaires : l'app montre le plus ancien d'abord (le défaut de l'API), le site le plus récent d'abord (T62). Avec
    la pagination, la première page diffère.
  - Membres : pas d'ordre, sur les deux supports (T46, DL22). L'API ne connaît que `JOINED_AT` (`MemberSortBy`).
- **Options** :
  1. *(recommandée)*
     - Équipes : par nom quand la portée est « Membre », par nombre de membres quand elle est « Toutes ». Le premier
       est un carnet d'adresses, le second une découverte. L'ordre est dit à côté du compteur, comme dans l'app.
     - Commentaires : le plus ancien d'abord. Une conversation se lit dans l'ordre, les réponses suivent déjà cet
       ordre, et c'est le défaut de l'API.
     - Membres : par nom.
  2. Équipes par nom partout ; commentaires du plus récent au plus ancien ; membres par date d'arrivée (sans
     changement d'API).
- **Se voit** : non. Une liste de décisions suffit.
- **Coût** : app XS. Site XS (`sortBy` selon la portée, `sort` des commentaires). **API : oui** pour les membres, avec
  une nouvelle valeur `NAME` de `MemberSortBy` et un ordre par défaut (entrée `API-…`).
- **Réfs** : T40, T41, T46, T62.

### RL6 — Barre d'outils : place de la recherche et du tri, forme des contrôles

- **Question** : où se trouvent la recherche et le tri, et un même contrôle a-t-il une seule forme ?
- **App** : la recherche est toujours visible et épinglée, sauf dans « Mes équipes », où elle est cachée derrière une
  loupe (S54, S79). Le tri des parcours est une puce visible (T28). Le tri des annonces passe en tête des puces (S48).
  Les types sont des puces. Les notifications ont un segmenté « Toutes / Non lues » (F42, S67).
- **Site** : la recherche est repliée derrière « Filtres » dans l'agenda, les parcours et Explorer (S19, S37, S86,
  F58). Le tri des parcours est dans ce panneau replié (T28). Le tri des annonces est en fin de ligne (S48). Le type
  est un `Chip.Group` à l'accueil et un `SegmentedControl` dans l'agenda (F53). Les notifications ont un interrupteur
  « Non lues uniquement » (F42).
- **Options** :
  1. *(recommandée)* La recherche est toujours visible, en tête de liste, sur les deux supports (« Mes équipes »
     comprise). Le tri est visible hors du panneau. Le panneau ou la feuille ne garde que les critères. Un critère a
     une forme par support : des puces dans l'app, un segmenté sur le site. « Non lues » a le même libellé partout.
  2. Le site garde son panneau replié, qui prend moins de hauteur ; seuls les libellés s'alignent.
- **Se voit** : oui. Planche : agenda et parcours du site, « Mes équipes » de l'app.
- **Coût** : site S (agenda, parcours). App XS. API : non.
- **Réfs** : F11, F33, F42, F53, F58, S14, S19, S37, S48, S54, S67, S79, S86, T28.

### RL7 — Invite de recherche

- **Question** : que dit l'invite d'un champ de recherche ?
- **App** : « Rechercher {un objet}… » (« une publication… », « un parcours… », « un modèle… », « une personne… »).
  Les points de suspension manquent sur « Rechercher une annonce », « un membre » et « une équipe » de Découvrir (T§12).
  L'invite ne dit pas à qui administre que l'e-mail est cherché aussi (T48).
- **Site** : « Rechercher par titre ou description... » (accueil, publications, agenda, annonces), « par nom ou
  description... » (parcours), « par nom... » (modèles, annuaire), « par nom ou e-mail... » (administration),
  « Rechercher des équipes... ». Trois points partout, sauf aux personnes inscrites (T§13).
- **Options** :
  1. *(recommandée)* « Rechercher {un objet}… » partout, avec « … » (U+2026), et le même texte des deux côtés. Une
     exception : « Rechercher par nom ou e-mail… » pour qui administre, app comprise.
  2. La forme du site, qui nomme les champs cherchés.
- **Se voit** : non. Une liste de textes suffit.
- **Coût** : clés des deux fichiers de traduction, XS. API : non.
- **Réfs** : T14, T18, T21, T32, T37, T43, T44, T48, T53, T59, T§12, T§13.

### RL8 — Compteur de résultats

- **Question** : quelles listes ont un compteur, où est-il, et que dit-il à zéro ou sous un filtre ?
- **App** : un compteur dans l'en-tête de section du fil. Aucun dans les publications d'équipe ni dans « Mes équipes »
  (T19). Les parcours disent « N parcours sur M » sous un filtre (T33). À zéro, rien (T22).
- **Site** : `ResultCount` sous les filtres. À zéro, « 0 publication » s'affiche au-dessus de l'état vide (T15, T22).
  Aucun compteur sur les équipes, les modèles ni l'administration des membres (T45, T60, T49), alors que les clés
  `list.count.teams`… existent. Sur la page Membres, le compteur est à côté du titre (S59, S88). Les personnes
  inscrites ont « 1–50 sur 120 » (T54).
- **Options** :
  1. *(recommandée)* Un compteur sur chaque liste paginée, à la même place : sous la barre, à gauche de la bascule de
     vue. Nombre formaté, nom accordé. Masqué à zéro, car l'état vide parle. Sous un filtre, le total filtré seul.
  2. Même chose, avec « N sur M » sous un filtre, partout (deux appels `count` sur le site aussi).
- **Se voit** : oui. Il partage la planche de RL6.
- **Coût** : app XS. Site XS. API : non, `count` existe partout (T39).
- **Réfs** : S2, S59, S72, S88, T15, T19, T22, T33, T45, T49, T54, T60.

### RL9 — Bascule de vue et densité

- **Question** : combien de contrôles de vue une liste a-t-elle, et sous quels noms ?
- **App** : l'agenda a « Liste / Calendrier », en icônes seules, et pas de vue en lignes (S20). Les parcours ont deux
  contrôles : « Liste / Carte » et « Vignettes / Compact » (S38, S77). La vue des parcours est commune à toutes les
  équipes et à Explorer (S39, S78). Un bandeau annonce le passage automatique en compact (S40).
- **Site** : un seul contrôle à icônes, « Vignettes · Lignes · Carte » ou « Calendrier », précédé de « Affichage ».
- **Options** :
  1. *(recommandée)* Un seul contrôle par liste, à icônes, avec les mêmes trois valeurs et les mêmes noms. L'app
     renomme « Compact » en « Lignes » et ajoute la vue en lignes à l'agenda. La vue choisie dans une équipe ne
     rouvre plus Explorer sur la carte.
  2. L'app garde deux contrôles ; seul le nom « Lignes » s'aligne.
- **Se voit** : oui. Planche : agenda, parcours.
- **Coût** : app S à M (vue en lignes de l'agenda). Site : rien. API : non.
- **Réfs** : S20, S25, S38, S39, S40, S77, S78.

### RL10 — État vide et état vide filtré

- **Question** : que disent un vide « rien ici » et un vide « rien pour ces filtres », et qu'est-ce qu'un filtre ?
- **App** : trois traitements du vide filtré (E80) : un cul-de-sac riche aux parcours ; un cul-de-sac sans filtre
  nommé (annonces, Découvrir, membres) ; un état à une action ailleurs. Le terme cherché est cité (E12). « Passées »
  vide donne le vide absolu (E26). Au calendrier, un mois vide a son message et « Aller au prochain mois avec une
  sortie » (E29).
- **Site** : deux variantes. Le vide filtré ne cite ni le terme ni les filtres, sauf aux parcours (E12, E36). « Passées »
  vide est un vide filtré qui ramène à « À venir » (E26). Au calendrier, la grille vide n'a aucun message (E29, E30).
- **Options** :
  1. *(recommandée)* Vide absolu : ce qui apparaîtra ici, plus l'action de création si la personne a le droit (RL13).
     Vide filtré : « Aucun {objet} pour ces filtres », un message qui nomme le terme ou les filtres, et « Effacer les
     filtres ». « Retirer le filtre {x} » s'ajoute quand le serveur sait lequel libère le plus de résultats. Une période
     (« Passées », « Je participe ») est un filtre. Le calendrier du site reprend le message de l'app sous la grille.
  2. Garder le cul-de-sac riche aux seuls parcours ; un vide filtré simple partout ailleurs.
- **Se voit** : oui. Planche : agenda vide et filtré, calendrier vide.
- **Coût** : app S. Site S. API : non.
- **Réfs** : E10, E12, E19, E20, E25, E26, E29, E30, E36, E45, E46, E51, E52, E57, E58, E62, E63, E69, E72, E75, E80,
  E87, E88.

### RL11 — Erreur, hors connexion, chargement

- **Question** : quelle forme a une erreur, et que voit-on pendant un changement de filtre ?
- **App** : une erreur de liste montre « Erreur de chargement », « Réessayer » et « Signaler un problème ». Le fil
  montre à la place un bandeau « Fil indisponible. », sans « Signaler » (E79). Une coupure réseau a son message (E3).
  Les squelettes reviennent à chaque filtre et à chaque mois (E14, E31) ; il y en a 3, 5 ou 6 selon la liste (E77).
- **Site** : « Chargement impossible » sur deux listes seulement, `error.loading` sans bouton ailleurs (E2). Pas de
  message hors connexion, pas même un toast (E3). Trois nouvelles tentatives font attendre l'erreur environ 7 s (E5).
  Pendant un changement de filtre, selon la liste : squelettes, liste gardée telle quelle, liste estompée, ou voile
  (E38, E85).
- **Options** :
  1. *(recommandée)* Une forme d'erreur par support : « Chargement impossible », un message qui distingue réseau et
     serveur, « Réessayer », et « Signaler un problème » dans l'app. Le fil de l'app la prend aussi. Pendant un
     changement de filtre, l'app garde ses squelettes et le site garde la liste précédente estompée, partout, comme
     les annonces.
  2. Squelettes partout sur le site aussi.
- **Se voit** : oui. Planche : état d'erreur des deux supports.
- **Coût** : app XS. Site S (le composant commun, qui sert ensuite à DL11). API : non.
- **Réfs** : E1, E2, E3, E5, E13, E14, E31, E37, E38, E47, E53, E64, E70, E77, E79, E85.

### RL12 — Pied de liste et taille de page

- **Question** : que dit le pied d'une liste, et la taille de page doit-elle être la même ?
- **App** : le pied a trois formes : nommé et formaté, nu et formaté, nu et non formaté (T§12, E78). Les personnes
  inscrites ont « Afficher plus », les commentaires « Voir plus de commentaires » (T51, T63). Les pages font 20, ou 50
  pour les personnes inscrites (T47).
- **Site** : des numéros de page, sans message de fin. Les personnes inscrites ont « 1–50 sur 120 ». Les commentaires
  ont « Charger plus de commentaires ». Les pages font 12, 20 ou 50.
- **Options** :
  1. *(recommandée)* Dans l'app, un seul pied : « {N} {objets} sur {M} · Vous avez tout vu », formaté. Un seul
     libellé pour « plus » sur les deux supports (« Afficher plus de commentaires »). La taille de page reste libre par
     support : elle tient au mode de pagination.
  2. Les membres passent à 50 dans l'app, comme sur le site.
- **Se voit** : non.
- **Coût** : XS. API : non.
- **Réfs** : E8, E43, E66, E78, T2, T47, T51, T54, T63, T§12.

### RL13 — Créer depuis une liste

- **Question** : quelles listes portent l'action de création, sous quelle forme et avec quel libellé ?
- **App** : « Ajouter » dans la barre des parcours. Un « + » d'app bar pour les modèles (« Nouveau modèle »). Rien sur
  l'agenda, les publications, les annonces, les équipes ni l'accueil (S7, S15, S24, S76). « Créer une sortie » n'existe
  qu'au tableau de bord, alors que l'éditeur de sortie existe (`MOB-80`).
- **Site** : un bouton d'en-tête sur chaque liste et des raccourcis à l'accueil (S7). Les libellés varient : « Créer
  un nouveau parcours », « Nouvelle publication » contre « Rédiger une publication » (S84). Pas de bouton sur la carte
  des parcours (S90).
- **Options** :
  1. *(recommandée)* Un bouton de création en tête de chaque liste dont le support sait créer l'objet, pour qui en a
     le droit, repris dans le vide absolu. Dans l'app : agenda (« Créer une sortie »), parcours, modèles. Une forme par
     support : bouton de barre dans l'app, bouton d'en-tête sur le site. « Créer {un objet} » partout (« Créer un
     parcours », « Créer une publication »). Ce que l'app ne crée pas n'a pas de bouton dans ses listes (VL11).
  2. Les listes de l'app ouvrent aussi le site pour ce qu'elle ne crée pas, comme le tableau de bord.
- **Se voit** : oui. Planche : agenda de l'app, en-têtes du site.
- **Coût** : app S. Site XS. API : non. Les droits restent calculés en local des deux côtés (S, Non vérifié).
- **Réfs** : E45, E72, S7, S15, S24, S42, S70, S76, S84, S90.

### RL14 — Qui ouvre une liste

- **Question** : une liste s'ouvre-t-elle à toute personne que le serveur sert, ou seulement à qui peut agir dessus ?
- **App** : les modèles sont refusés à une personne simplement membre (S71). Une administratrice de la plateforme non
  membre n'a pas la section Annonces (S11).
- **Site** : les modèles s'ouvrent à tout membre ; seul le bouton dépend du rôle. La plateforme lit les annonces.
- **Options** :
  1. *(recommandée)* Masquer les modèles aux personnes simplement membres, des deux côtés : un modèle ne sert qu'à qui
     crée des sorties. Les annonces suivent le site, car la plateforme modère.
  2. Suivre le serveur partout : l'app ouvre les modèles à tout membre.
- **Se voit** : non.
- **Coût** : XS des deux côtés. API : non. À vérifier : le serveur sert-il les modèles à une personne simplement membre ?
- **Réfs** : S11, S71.

---

## 3. Écarts voulus

À écrire dans « Délibérément dehors » de `LEDGER_NEXT.md` quand la source manque.

| # | Écart | Raison | Source | Réfs |
|---|---|---|---|---|
| VL1 | Défilement infini dans l'app, numéros de page sur le site ; fin de liste et tailles de page différentes | Toute vue du site est partageable par son adresse | `WEB-8`, `frontend/CLAUDE.md` | T1, T3, E8, E61, E66 |
| VL2 | Filtres, tri, vue et page dans l'URL sur le site, en mémoire dans l'app | Même raison ; l'app n'a pas d'adresse visible | `WEB-8`. **Pas au ledger côté app** | F6, F15, F19, F31, F41, T5, T30, T57, S8, S9, S17, S22, S26, S30, S52, S83 |
| VL3 | Feuille dans l'app, panneau ou `Select` sur le site ; application sur brouillon (« Voir N parcours ») contre application immédiate | Écran étroit | **Pas au ledger** | F7, F28, T36 |
| VL4 | Tirer pour rafraîchir et rechargement à la réouverture dans l'app ; cache de 3 min et nouvelles tentatives sur le site | Geste propre au téléphone | **Pas au ledger** | E6, E7, E17, E71 |
| VL5 | Barres épinglées dans l'app, défilantes sur le site | Écran étroit | **Pas au ledger** | S5, S10 |
| VL6 | Une colonne dans l'app, grille de 1 à 3 colonnes sur le site | Largeur d'écran | **Pas au ledger** | S6, S16, S43, S50, S58, S61 |
| VL7 | Pas de titre de section dans l'app (la puce active en tient lieu) ; retour vers « Mes équipes » contre fil d'Ariane | La rangée de sections épinglée nomme déjà la section | **Pas au ledger** | S1, S12, S13, S18, S36, S47 |
| VL8 | Aucune liste sans session dans l'app ; listes publiques pour une personne non connectée sur le site | L'app exige une session | `config/router.dart:1018` | E16, E55 |
| VL9 | Personnes inscrites en feuille dans l'app, en section sur le site | Écran étroit | `MOB-134` (V4 des cartes) | S63 |
| VL10 | Vues jour, semaine et année du calendrier sur le site seulement ; grille et agenda par jour dans l'app | Largeur d'écran ; la vue téléphone du site ressemble déjà à l'app | **Pas au ledger** | S29, T25 |
| VL11 | **À confirmer.** Pas de création d'annonce (S49) ni d'équipe (S56) dans l'app ; « Nouvelle publication » ouvre le site (S15) | Périmètre de produit, pas règle de liste. `MOB-24` nomme les publications, les voyages et l'administration d'équipe, **mais ni les annonces ni la création d'une équipe** : à trancher avant de l'écrire | `MOB-24` (en partie) | S15, S49, S56 |
| VL12 | Listes de gestion propres au site : administration des membres, lieux, tags, signalements, pages, aperçus GPX | Administration d'équipe hors app | `MOB-24` | F44, E56 |
| VL13 | Bandeau d'activation des notifications poussées dans l'app | Les notifications du navigateur se règlent ailleurs | **Pas au ledger** | S68 |
| VL14 | Carte des parcours d'une équipe sans adresse propre dans l'app ; `/parcours` sans lien profond | Choix du contrat des routes | `contracts/routes.yaml:254-267, 711-717` | S45, S46 |
| VL15 | Modèles en écran plein dans l'app, en onglet d'administration sur le site | Navigation propre à chaque support | **Pas au ledger** | S69, S74 |

---

## 4. Lignes identiques des deux côtés

Rien à faire. F2, F9, F17, F18, F23, F34, F35, F36, F43 ; T9, T11, T13, T16, T17, T20, T24, T26, T27, T31, T34, T35,
T38 (en-tête), T50, T55, T56 (en-tête), T58, T61 ; S21, S23, S30, S32, S33, S34, S41, S44, S57, S62, S65, S75, et S73
(hors axe : contenu de carte) ; E4, E14, E23, E28, E41, E44, E67, E68, E70.

---

## 5. Écarts faibles, par liste

Ils ne sont pas triés un par un : un lot qui touche la liste les ramasse. Compte par fichier d'audit. Beaucoup sont déjà
cités par une règle (libellés « Tout / Tous », invites, squelettes) et se règlent avec elle.

| Liste | filtres | tri | structure | états | Total |
|---|---|---|---|---|---|
| Fil d'accueil | 2 | 1 | 6 | 2 | 11 |
| Publications d'équipe | 1 | 0 | 4 | 1 | 6 |
| Agenda | 3 | 2 | 4 | 1 | 10 |
| Calendrier | 0 | 1 | 3 | 4 | 8 |
| Parcours, Explorer, carte | 4 | 1 | 10 | 3 | 18 |
| Annonces | 1 | 1 | 5 | 2 | 9 |
| Équipes | 0 | 2 | 2 | 3 | 7 |
| Membres | 1 | 3 | 3 | 1 | 8 |
| Personnes inscrites | 0 | 4 | 1 | 2 | 7 |
| Notifications | 0 | 0 | 2 | 1 | 3 |
| Modèles de sortie | 0 | 1 | 3 | 1 | 5 |
| Personnes bloquées | 0 | 0 | 0 | 1 | 1 |
| Commentaires | 0 | 1 | 0 | 0 | 1 |
| Toutes listes (débounce, rognage, « Tout / Tous », squelettes, libellés de sortie…) | 8 | 5 | 6 | 7 | 26 |
| **Total** | **20** | **22** | **49** | **29** | **120** |

Quatre faibles sont remontés en défaut : E34 (DL4), E43 et E78 (DL8), T8 (DL19). À noter aussi : le commentaire de
`app/…/ads_page.dart:20-23` affirme que `classifieds/count` n'existe pas, alors qu'il existe (T39,
`contracts/openapi.yaml:14149`). La clé `home.searchPlaceholder` de l'app est probablement morte (T§12).

---

## 6. À vérifier à l'écran avant toute correction

| Constat déduit | Réfs | Ce qu'il faut voir |
|---|---|---|
| « 2585 annonces » sans espace des milliers dans l'app | T§12, DL8 | une liste de plus de 1 000 éléments |
| Doublons ou trous entre deux pages | T10, DL21 | deux pages d'un fil où plusieurs sorties partagent une date (import biketeam) |
| Un toast s'affiche-t-il par-dessus le vide sur une 5xx du site ? | E84, DL11 | une liste du site, serveur coupé |
| 403 lu comme panne dans l'app | E49, E60, DL9 | annonces et membres ouverts par lien, par une personne non membre |
| Alerte et état vide à la fois sur la page équipes du site | E54, DL13 | une panne de `listTeams` |
| Compteur de l'agenda du site plus grand que les cartes (éléments non datés retirés) | T23 | un agenda avec un élément sans date |
| Défilement non remis en haut quand on change un filtre sur le site | T4 | un filtre changé en bas de page |
| Pas de la distance en impérial dans l'app (5 km ≈ 3,1 mi) | F24, F25 | l'app en unités impériales |
| Proximité armable depuis la vue liste de l'app | F, Non vérifié | Explorer en vue liste |
| Filtres de l'agenda de l'app gardés au changement d'onglet | F, Non vérifié | aller-retour entre onglets |
| Ordre de « Je participe » à l'accueil du site (passées comprises ?) | T, Non vérifié | la portée « Je participe » |
| Fil d'accueil de l'app pour une personne sans équipe | E, Non vérifié | un compte sans équipe |
| Vue liste du calendrier du site : « Aucun événement » | E, Non vérifié | un mois vide en vue liste |
| Le serveur sert-il les modèles à une personne simplement membre ? | S71, RL14 | appel de la liste des modèles |
| Rendu des barres du site à 390 px | S, Non vérifié | agenda, parcours, annonces sur téléphone (RL6) |
| Lien profond vers une liste filtrée : l'app ignore les filtres | S, Non vérifié | `/equipes/x/annonces?type=SALE` ouvert dans l'app |

---

## 7. Récapitulatif

| | XS | S | M | Total |
|---|---|---|---|---|
| Défauts app | 6 | 4 | 0 | 10 |
| Défauts site | 6 | 2 | 1 | 9 |
| Défauts des deux | 1 | 0 | 0 | 1 |
| Défauts backend | 0 | 2 | 0 | 2 |
| **Défauts** | **13** | **8** | **1** | **22** |

| | Nombre |
|---|---|
| Règles à décider | 14 (9 se voient : RL2, RL3, RL4, RL6, RL8, RL9, RL10, RL11, RL13 ; une touche l'API : RL5, ordre des membres) |
| Écarts voulus | 15 (VL11 à confirmer ; 10 sans entrée au ledger) |
| Lignes identiques | 49 |
| Écarts faibles | 120 (4 remontés en défaut) |

**Découpage proposé du lot 0** :

| Sous-lot | Défauts | Nature |
|---|---|---|
| 0a — États qui mentent | DL1, DL2, DL3, DL9, DL11, DL12, DL13, DL14, DL15, DL20 | Vide, erreur, refus, hors plage. DL11 (M) attend le composant d'erreur de RL11, ou part avec l'existant (`QueryStateBoundary`) |
| 0b — Contenu et ordre | DL5, DL7, DL16, DL17, DL18, DL21, DL22 | Pagination de « Mes équipes », types selon les modules, « À venir », cache, filtre du calendrier, ordre total côté serveur. DL22 attend RL5 pour le choix de l'ordre |
| 0c — Mots et nombres | DL4, DL6, DL8, DL10, DL19 | Clés de traduction, `formatNumber`, `aria-label` ; XS, sans risque |
