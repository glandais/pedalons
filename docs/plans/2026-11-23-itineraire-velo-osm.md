# Calcul d'itinéraire vélo par le moteur du générateur

Écrit le 23 novembre 2026. **État : décidé le 23 novembre 2026 (§11) ; lots 1 à 5 et 1 bis livrés (§10 bis),
moteur `1.17.1` en service et recette faite le 24 novembre 2026 (`OPS-68`) ; restent la suite e2e
(`WEB-198`) et les lots 6, 7 et 8.** Ledger `API-217`.
Suite de [`2026-11-15-generateur-parcours-osm.md`](2026-11-15-generateur-parcours-osm.md) (`API-207`) :
même moteur (osm-route-details, crate `ord-loops`), même passerelle côté Pédalons. Recoupe
[`2026-11-22-retouche-parcours.md`](2026-11-22-retouche-parcours.md) (`API-212`), §8 ici.

Ce qui est marqué **(lu)** a été relu dans le code le 23 novembre 2026 (osm-route-details `1.15.1`,
contrat Pédalons `16.3.0`, Valhalla `src/sif/bicyclecost.cc`) ; **(mesuré)** renvoie à un relevé
existant ; **(proposé)** est à confirmer par le lot 0 ou par le propriétaire. Ni secret, ni coordonnée
d'équipe réelle ici.

---

## 1. En une page

Le planificateur calcule chaque tronçon entre deux points de passage par **Stadia Maps** (protocole
Valhalla) **(lu)**. Ce routeur ne sait rien des routes que l'équipe roule. Le moteur du générateur, lui,
connaît la surcouche de chaque équipe, son goût appris, la roulabilité gravel et VTT, et sert la planète
depuis `1.14.0` ; il a déjà une recherche point à point (`astar_p2p`), mais seulement comme jambe d'un
triangle.

Ce plan ajoute au moteur un **calcul d'itinéraire de A à B**, et le propose **en option** dans le
planificateur du site et de l'app :

| | Stadia (« Standard ») | Moteur Pédalons (défaut là où il est offert, D1) |
|---|---|---|
| Profils | vélo, route, gravel, VTT, marche, moto | **route, gravel, VTT** seulement |
| Montées | curseur « éviter les montées » | **ignorées** (le moteur n'a pas l'altitude) |
| Équipe | aucune | **affinité avec les routes de l'équipe**, goût appris de l'équipe |
| Couverture | monde | celle du graphe servi (planète), tronçon de 100 km au plus à vol d'oiseau ; au-delà, ou si le moteur ne répond pas, **le tronçon est calculé par Stadia** (D4) |
| Coût | un appel facturé par tronçon | aucun appel externe |

Objectifs secondaires, chacun dans un lot à part :

- **prolonger ou raccourcir un parcours existant** : le calcul d'itinéraire donne à la retouche
  (`API-212`) la brique qui lui manquait pour raccourcir (§8) ;
- **compléter les données du graphe** pour le routage (nœuds : barrières, feux ; restrictions de
  virage ; bacs), puis **se passer des tuiles VersaTiles** dans route-details (§9).

---

## 2. Ce qui existe et ce qui manque

| Brique | État | Où |
|---|---|---|
| Graphe vélo de la planète, vues `road` et `gravel`, fenêtre par requête (0,1 à 0,5 s à froid pour 100 km **(mesuré, lot 6)**) | existe | `ord-graph`, `ord-loops/src/window.rs` |
| Coût d'une arête : classe, revêtement, accès, goût (72 classes), équipe (familiarité, λ), roulabilité | existe **(lu)** | `cost.rs`, `search.rs` (`Weighter`) |
| Règle de virage (gratuit sous 45°, coût jusqu'à 150°, refus au-delà et demi-tour) | existe **(lu)** | `search.rs` (`turn_cost`) |
| Accroche d'un point, morceaux partiels de départ et d'arrivée | existe **(lu)** | `window.rs` (`snap`), `search.rs` (`make_anchor`) |
| A* jusqu'à l'arrivée | existe, mais d'heuristique « arbre retour » (il faut l'arbre) et à l'intérieur d'une génération | `search.rs` (`astar`, `astar_p2p`) |
| **Itinéraire A → B seul** (fonction publique, zone de recherche, repli) | **manque** | lot 1 |
| Endpoint du service, `capabilities.router` | **manque** | lot 2 |
| Second moteur dans `RouterService` (qui injecte `StadiaMapsClient` en dur) | **manque** | lot 3 |
| Option « moteur » dans le planificateur | **manque** ; l'app embarque le planificateur du site en WebView, elle suit sans code Dart **(lu)** | lots 4 et 5 |
| Dans le graphe : nœuds (barrières, feux), restrictions de virage, bacs, `maxspeed`, `lanes` | **manque** ; 24 bits d'arête réservés, aucune donnée de nœud **(lu)** | lot 6 |

---

## 3. Ce qu'on prend à Valhalla, et ce qu'on n'en prend pas

Lu dans `bicyclecost.cc` et `graph.lua` :

- Valhalla calcule un **temps** (`longueur / vitesse du type de vélo × facteur de revêtement`), multiplié
  par un **facteur de confort** (classe de route, vitesse autorisée, nombre de voies, aménagement
  cyclable, réseau balisé), plus des **pénalités de transition** en secondes (virage selon le côté de
  conduite, montée de classe à un carrefour, portail, accès « destination »).
- Le moteur a déjà l'équivalent du facteur de confort, **réglé sur le réel** : `K(classe, revêtement,
  accès)` par type, multiplié par le goût commun ou celui de l'équipe (appris sur ses traces), et un coût
  de virage. On **garde ce coût** : c'est lui qui porte l'affinité d'équipe, et un parcours dessiné par
  tronçons doit ressembler à ce que le générateur propose.

Repris de Valhalla, par ordre d'utilité **(proposé)** :

| Idée | Lot | Donnée nécessaire |
|---|---|---|
| Refus par le type de vélo du revêtement impraticable (route : rien sous « compacté » ; VTT : tout sauf `impassable`) | 1 | déjà là : vue `road`, roulabilité du lot 5 |
| Demi-tour permis seulement en impasse ; virage serré **pénalisé** plutôt que refusé quand il n'y a pas d'autre chemin | 1 | déjà là |
| Pénalité d'entrée sur une voie « destination », de montée de classe (petite rue → grande route) | 1 bis | déjà là (accès, classe) |
| Aménagement cyclable (`cycleway=lane|track`) : facteur 0,4 à 0,9 de Valhalla | 1 bis | déjà là (`infra`, 2 bits), absent du coût aujourd'hui |
| Barrière infranchissable au vélo, portail (30 s + pénalité), feu | 6 | nœuds |
| Restrictions de virage (`type=restriction`, sauf `except=bicycle`) | 6 | relations |
| Stress selon `maxspeed` et `lanes` | 6 | bits réservés 40–63 |
| Bacs (`route=ferry`) | 6 | ways sans `highway` |

Écarté : le temps de parcours et la vitesse par type (on n'affiche pas de durée), la pente
(demande du propriétaire), les profils marche et moto, les instructions de guidage.

Le lot 1 ne change **aucun poids** : il route avec le coût du générateur tel quel. Le « 1 bis » règle le
coût sur un banc (§10) ; sans banc, pas de nouveau facteur.

---

## 4. Moteur (`ord-loops`) — lot 1

Une fonction publique, à côté de `generate_in`, sans rien changer à la génération (**invariant : une
génération rend les mêmes parcours qu'avant, au bit près**) :

```
route_in(engine, window, team, &RouteRequest { start, end, ride_type, mode, familiarity,
         off_team_cost_q8 }, workspace, stop) -> Result<Routed, RouteFailure>
Routed { route: Route, cost, settled, sharp_relaxed }
```

- **Vue** : `road` pour la route, `gravel` pour le gravel et le VTT, comme le générateur.
- **Poids** : `Weighter` inchangé (goût commun ou de l'équipe, familiarité, λ, roulabilité). Sans
  équipe : mode découverte. Le mode strict n'est pas offert (un tronçon doit pouvoir sortir du réseau).
- **Recherche** : A* sur les états « chaîne orientée », du morceau partiel de départ au morceau partiel
  d'arrivée ; heuristique = vol d'oiseau × plus petit coût par décimètre de la fenêtre (admissible,
  faible quand l'équipe ou le goût baissent beaucoup un poids : la recherche tend alors vers Dijkstra,
  ce qui reste borné par la zone).
- **Zone** : ellipse de foyers départ et arrivée, de somme `max(1,5 × d, d + 4 km)` où `d` est le vol
  d'oiseau **(proposé)** ; sans chemin, une seconde recherche à `max(2,5 × d, d + 15 km)` (vallée,
  estuaire, pont lointain), puis `no_route`.
- **Virages** : la règle du générateur d'abord (refus à 150° et plus aux carrefours). Sans chemin, une
  seconde passe où le virage serré coûte le maximum au lieu d'être refusé ; le demi-tour sur la même
  chaîne reste interdit hors impasse. La réponse dit laquelle a servi.
- **Départ et arrivée sur la même chaîne** : le morceau direct quand le sens est ouvert.
- **Accroche** : la plus proche chaîne roulable par le type, à 500 m au plus **(proposé ; le générateur
  accepte 2 km)**, sans condition de taille de composante ; échecs `start_too_far`, `end_too_far`.
- **Rendu** : un `Route` (suite d'arêtes de base orientées, positions de départ et d'arrivée) : la
  géométrie (`route_geometry`), les mesures d'équipe et de revêtement et le contrôleur indépendant
  servent tels quels.
- **Borne** : vol d'oiseau de 100 km au plus **(proposé)** : la fenêtre d'un tronçon de 100 km pèse
  comme celle d'une génération de 150 km.

Tests : chemin optimal contre un Dijkstra de référence sur le graphe d'essai, symétrie des morceaux
partiels, même chaîne, sens uniques, repli des virages, échappement de fenêtre, équipe préférée, et le
test de non-régression des générations.

## 5. Service (`ord-server`) — lot 2

```
POST /v1/router/route          (api 1.15, ajout pur)
{ "start": {lat, lon}, "end": {lat, lon}, "ride_type": "road|gravel|mtb", "cursor": 0.25 }
→ { "graph_id", "mode", "polyline" (précision 6), "distance_m", "team_m", "team_share",
    "offroad_m", "unpaved": [[i, j], …]   // plages d'indices de la polyligne, non revêtues
    "start_snap_m", "end_snap_m", "sharp_relaxed" }
```

- En-têtes `Ord-Namespace-Key` et `Ord-Team` **facultatifs** : sans eux (planificateur personnel),
  découverte au goût commun. Avec eux, le curseur du générateur donne mode, familiarité et λ ; une
  surcouche absente ou périmée ne bloque pas (découverte, la réponse le dit), à la différence d'une
  génération.
- Même cache de fenêtres que la génération ; **file à part**, plus courte, budget de 5 s **(proposé)** :
  un tronçon ne doit pas attendre derrière une génération de 30 s.
- Problèmes RFC 9457 existants : `out_of_coverage`, `generation_failed` (raisons `start_too_far`,
  `end_too_far`, `no_route`), `overloaded`, `timeout`, plus `too_long` (limite dans `details`).
- `capabilities.router` : `enabled`, `ride_types`, `crow_m_max`. Rien de la requête n'est journalisé.

## 6. Backend Pédalons — lot 3

- `RouterRequest` gagne `engine` (facultatif) : `STADIA` (défaut, comportement inchangé) ou `PEDALONS`.
  Contrat mineur `16.4.0`. Avec `PEDALONS` : profils `FASTBIKE` → `road`, `GRAVEL` → `gravel`, `MTB` →
  `mtb`, `BIKE` → `road` (D2) ; `RUN_HIKE` et `MOTORCYCLE` passent par Stadia, comme sans le champ ;
  `useHills` et `useRoads` ne servent qu'au repli. `teamSlug` présent : en-têtes d'équipe, curseur 0,25 (celui du générateur).
- `RouterService` passe par une interface à deux implémentations. La réponse du moteur prend le même
  chemin que celle de Stadia : `GpxPipeline` (altitude FAST), `UnpavedSpans` sur les plages `unpaved`,
  `shape`.
- Droits et quotas inchangés : `PlannerAccess.checkRouting`, compteur journalier partagé (D6), un point
  par tronçon quel que soit le moteur, repli compris.
- **Repli silencieux sur Stadia** (D4) : tout échec du moteur (tronçon trop long, hors couverture,
  point trop loin d'une voie, aucun chemin, file pleine, délai, moteur éteint ou non configuré) fait
  calculer le tronçon par Stadia, avec les curseurs de la requête ; la réponse ne le dit pas. Les erreurs
  rendues sont donc celles de Stadia, inchangées. Un compteur Micrometer par cause de repli, sans
  coordonnée, pour savoir ce que le moteur ne sert pas. Délai d'appel du moteur court (6 s), pour que le
  repli tienne dans l'attente d'un tronçon.
- `GET /api/router/engines?teamSlug=` : les moteurs offerts (lu dans `capabilities.router`, cache d'une
  heure existant) et les profils de chacun ; l'écran n'affiche l'option que si elle répond. Avec ou sans
  équipe (D3).
- Pile e2e : pas de graphe, `engines` ne rend que `STADIA` ; les specs bouchonnent. Aucune migration.
- `PlannerState` n'enregistre pas le moteur, comme il n'enregistre pas les curseurs.

## 7. Écrans — lots 4 et 5

- **Site** : dans le panneau des profils (`RouterProfileSelector`), au-dessus des curseurs, un choix
  « Calcul d'itinéraire » : *Routes de l'équipe* (défaut, D1 ; *Pédalons* sans équipe) / *Standard*,
  visible pour les quatre profils vélo (D2) quand le moteur répond, avec ou sans équipe (D3). Les
  curseurs « montées » et « routes » restent : ils servent au repli (D4), une ligne d'aide dit que le
  moteur Pédalons ne tient pas compte des montées. Choix gardé par appareil (`localStorage`), comme les curseurs ;
  changer de moteur ne recalcule rien, comme changer de profil.
- **App** : le planificateur est celui du site dans une WebView ; `pnpm build:mobile-planner` embarque
  l'option. Seul ajout Dart : `GET /api/router/engines` dans la liste fermée du pont
  (`plannerRequestAllowed`).

## 8. Prolonger, raccourcir (`API-212`)

Le lot 0 de la retouche a mesuré que **raccourcir échoue** (53 à 67 %) parce que la lentille ne sait
pas faire plus court que 1,05 × le plus court chemin, et que 44 % des échecs sont des demandes sans
fenêtre de couture **(mesuré)**. Avec un itinéraire A → B qui garde le goût de l'équipe :

- **raccourcir** = remplacer un tronçon `[i, j]` par l'itinéraire de `i` à `j` ; l'économie
  `ℓ − route(i, j)` se lit pour tous les `j` dans un seul arbre depuis `i` ; on choisit la paire dont
  l'économie approche `|Δ|`. Plus de lentille, plus de borne à 1,05 ;
- **déplacer l'arrivée** = itinéraire du point de sortie au nouveau point, avec le cap d'arrivée de la
  jambe gardée donné à la recherche (la cause de 89 % des refus mesurés) ;
- **prolonger** reste la lentille (97 % **(mesuré)**).

Et sans rien attendre : dans le planificateur, un tronçon recalculé par le moteur Pédalons suit les
routes de l'équipe ; tirer un point de passage devient la retouche manuelle. Le lot 7 reprend le plan de
la retouche avec ces briques ; il a besoin de l'option « arêtes interdites » (`KeepOut`, aujourd'hui
sous la feature `probe`) et du cap imposé au départ.

## 9. Données, et la fin des tuiles VersaTiles

**Pour le routage** (lot 6, format de graphe mineur, reconstruction de la planète sur la machine de
construction) : attributs de nœud (barrière et son accès vélo, feu, passage), restrictions de virage,
`maxspeed` et `lanes` dans les bits réservés, bacs. À faire **après** le banc du lot 1 bis, qui dira ce
qui manque vraiment.

**Pour route-details** : la typologie (classe, revêtement, ouvrages) vient aujourd'hui de tuiles
vectorielles VersaTiles, recalées par un HMM **(lu)**, avec 12,6 % des tronçons gravel sans classe de
revêtement (`API-214`). Le graphe a déjà la classe, `surface` brute, `tracktype`, `smoothness`, pont,
tunnel, sens et l'identifiant de way, et `ord-graph-match` sait poser une trace dessus (99,22 % des km
**(mesuré)**). Il lui manque, pour rendre ce que rend T03 : `foot`, `layer`, `covered`, passage sous
bâtiment, gué, et la valeur brute d'un `surface` hors table (code 31). Lot 8 : une chaîne de typologie
« graphe » derrière le même port que la chaîne « tuiles », jugée sur le banc de route-details (R1, R2,
M1, S1, S2) avant toute bascule ; les tuiles restent le repli hors du graphe servi tant que la bascule
n'est pas décidée.

---

## 10. Lots

| Lot | Dépôt | Contenu | Sortie |
|---|---|---|---|
| **1. Moteur** | osm-route-details | `route_in` (§4), tests | génération inchangée au bit près |
| **1 bis. Banc et coût** | osm-route-details (`tools/ord-loops-bench`), export hors dépôt | Tronçons réels : entre deux points d'une trace d'équipe distants de 2 à 40 km, part de la trace retrouvée, détour, temps ; mêmes tronçons par Stadia pour comparer ; réglage des facteurs du §3 | relevé `…-mesures.md`, seuils **(proposé)** confirmés ou changés |
| **2. Service** | osm-route-details | endpoint, contrat api 1.15, `capabilities`, file à part ; image publiée, pile partagée (entrée `OPS`) | version `1.16.0` |
| **3. Backend** | Pédalons | `engine`, passerelle, `engines`, erreurs, tests | contrat `16.4.0`, clients régénérés |
| **4. Site** | Pédalons | l'option, e2e bouchonné | entrée `WEB` |
| **5. App** | Pédalons | bundle du planificateur, liste du pont, Patrol | entrée `MOB` |
| **6. Données de routage** | osm-route-details | §9, première partie | planète reconstruite |
| **7. Retouche** | les deux | §8, dans le plan `API-212` | — |
| **8. Typologie par le graphe** | osm-route-details | §9, seconde partie | jugement sur le banc |

Les lots 1 à 5 livrent l'option. 1 bis peut suivre le lot 2 : l'option reste facultative et le défaut
reste Stadia tant que le banc n'a pas parlé.

## 10 bis. Lot 1 : ce qui est codé et mesuré (23 novembre 2026)

Dans osm-route-details, non commité : `crates/ord-loops/src/route.rs` (`route_in`, `route`,
`Engine::plan_route`, `route_geometry_spans`), huit tests (`tests_route.rs`, dont l'optimalité contre un
Dijkstra de référence), l'exemple `route_region`, la note `docs/design/technique/ord-route-lot1.md`. Les
123 tests existants du moteur, références figées des générations comprises, passent inchangés.

Sur les Pays de la Loire, un fil **(mesuré)** : Nantes → Carquefou (9,9 km) 16 ms à chaud, détour
× 1,12 ; Nantes → Ancenis (32,8 km) 33 ms, × 1,21 ; Nantes → Angers (80 km) 77 ms, × 1,18 ; fenêtre à
froid 40 à 140 ms ; la Loire à Saint-Nazaire franchie par le pont à la seconde zone. En équipe d'abord,
Nantes → Ancenis passe à **95 à 99 % sur les routes de l'équipe** pour les deux équipes qui roulent là,
pour 1 à 1,6 km de plus. L'heuristique coupe peu (la recherche fixe presque toute la zone) : sans
conséquence à ces temps.

**Lots 2 à 5, codés le même jour, non commités.**

- **Service** (osm-route-details `1.16.0`, api 1.15) : `POST /v1/router/route`, file à part (2 calculs,
  6 en attente, budget de 5 s), bloc `capabilities.router`. Écarts au §5 : un tronçon trop long rend un
  400 `invalid_input` (pointeur `/end`) ; la réponse porte aussi `bridged_m` ; un seul en-tête d'équipe
  sur deux rend un 400. 1 109 tests du workspace verts, clippy et `cargo deny` propres. Non couverts par
  HTTP : l'absence de chemin, la file pleine, le dépassement de budget.
- **Backend** (contrat `16.4.0`) : `RouterRequest.engine`, `GET /api/router/engines`, passerelle
  `RouterEngineGateway` (délai de 6 s, curseur 0,25), repli silencieux sur Stadia compté par cause
  (`pedalons_router_engine_total`), tronçon au-delà de la borne du moteur donné à Stadia sans appel.
  79 tests verts le 23 novembre 2026 (`RouterEngineResourceTest`, `RouterResourceTest`,
  `RouteDetailsCapabilitiesTest`, `ArchitectureTest`).
- **Site et app** : choix « Calcul d'itinéraire » (Standard / Routes de l'équipe, ou Pédalons sans
  équipe) sous les curseurs, gardé par appareil ; pont de l'app ouvert à `GET /api/router/engines`,
  bundle reconstruit. 2 548 tests vitest et `mobile/check.sh` verts ; **rien vu dans un navigateur ni
  sur un téléphone**, e2e écrits et non lancés (`WEB-198`).

**Curseur « Trafic » et « Éviter les grandes routes » (D8), codés le 23 novembre 2026, non commités.**
Moteur `1.17.0` (api 1.16) : `use_roads` / `use_roads_neutral` et `avoid_main_roads` sur
`POST /v1/router/route`, annoncés dans `capabilities.router` ; `secondary` a sa case à part, le goût
commun la mettant au prix d'une rue. Backend (contrat `16.5.0`) : `RouterRequest.avoidMainRoads`,
`RouterEngineOffer.options` ; les champs ne partent au moteur que s'il les annonce (un `1.16.0`
refuserait le champ inconnu et le tronçon retomberait sur Stadia). Écran : « Côtes » masqué (D7),
interrupteur sous le choix du calcul, gardé par appareil. Les facteurs viennent de la session
`highway-weight` et du `road_factor` de Valhalla : **une estimation, calée sur aucune mesure**. Relevé
**(mesuré)**, Nantes → Ancenis, découverte : en gravel, de 64 % de non-revêtu à « Pistes » à 0 % à
« Routes » ; en vélo de route, 43,6 km à « Pistes » contre 39,7 km à « Routes » ; éviter les grandes
routes : 39,7 → 41,4 km en route (Nantes → Angers : 94,2 → 96,2 km). La longueur roulée sur `secondary`
avant et après n'est pas mesurée. Tests : 11 du moteur, 1 117 du workspace, 89 du backend, 2 554 du
site ; aucun test du service ne montre un changement de tracé (sa grille n'a qu'une classe de voie).

**Lot 1 bis, le banc sur tronçons réels (24 novembre 2026).** Sous-commande `route-play` du banc du
moteur, relevé `ord-route-lot1bis-mesures.md` d'osm-route-details, non commités. 3 186 traces réelles,
8 334 tronçons de 2 à 40 km, itinéraire sans équipe comparé à ce qui a été roulé (indice de Jaccard en
longueur), facteurs choisis sur une moitié des traces et jugés sur l'autre **(mesuré)** :

- **le neutre est déjà à un cran de l'optimum sur chaque case** : la meilleure table trouvée gagne
  +0,8 point [+0,2 ; +1,3] en route sur la moitié de contrôle (39,1 de base), rien en gravel, et retire
  des voies cyclables ; elle n'est pas adoptée ;
- **`secondary` est juste au neutre** : 23,6 % des kilomètres réels en route, 23,0 % de l'itinéraire ;
  l'itinéraire prend trop de `tertiary` (48,0 % contre 42,7 %) et pas assez de petites routes (13,6 %
  contre 17,3 %) ; en gravel, trop de voies cyclables (19,2 % contre 12,7 %), pas assez de chemins ;
- **« Éviter les grandes routes » est bien dimensionné** : `secondary` passe de 23 à 4,8 % des
  kilomètres, pour un détour P90 de 1,05 à 1,15 ; le curseur « Trafic » déplace les kilomètres dans le
  sens attendu sur toutes les cases (`secondary` de 13 à 49 % entre « Pistes » et « Routes ») ;
- le recouvrement tombe avec la distance (61 à 63 en 2–5 km, 17 en 15–40 km) et l'itinéraire est plus
  court que le réel : au-delà de 15 km, une personne ne va pas « de A à B ».

Limites : deux équipes font presque toutes les traces, 29 tronçons VTT seulement (inexploitable), pas de
comparaison avec Stadia, goût d'équipe et aménagements cyclables (`infra`) non mesurés. Les facteurs du
moteur restent ceux de `1.17.0`.

## 11. Décisions du propriétaire (23 novembre 2026)

| # | Question | Décision | Écarté |
|---|---|---|---|
| D1 | Défaut du planificateur | **Le moteur Pédalons par défaut** (« Routes de l'équipe », « Pédalons » sans équipe) partout où il est offert pour le profil ; le choix, placé **au-dessus des curseurs** et en première position, reste gardé par appareil | Stadia par défaut et le moteur en choix explicite (la première version, changée le jour même) |
| D2 | Profil `BIKE` (vélo polyvalent) avec le moteur Pédalons | **Rangé avec la route** : l'option vaut pour les quatre profils vélo | Masquer l'option pour `BIKE` ; le ranger avec le gravel |
| D3 | Sans équipe (planificateur personnel) | **L'option est offerte**, au goût commun | Équipes seulement |
| D4 | Le moteur ne peut pas répondre (trop long, hors couverture, indisponible) | **Repli silencieux sur Stadia** | Erreur explicite ; repli signalé à l'écran |
| D6 | Compteur journalier de routage | **Partagé** avec Stadia (300 par personne) | Compteur à part ; pas de plafond |
| D7 | Curseur « Côtes » avec le moteur Pédalons | **Masqué** : le moteur n'a pas l'altitude ; le texte d'aide ne parle plus des côtes | Le laisser affiché pour le seul repli sur Stadia |
| D8 | Curseur « Trafic » et grandes routes avec le moteur Pédalons | **Le curseur agit sur le moteur** (multiplicateur par type de voie, neutre au cran du profil) et un interrupteur **« Éviter les grandes routes »** pénalise `secondary` (×2) et `primary` / `trunk` (×1,5) sans les interdire | Curseur sans effet ; interdire les `secondary` |

Reste proposé, sans décision demandée : D5, pas de curseur d'affinité dans le
planificateur, 0,25 fixe comme le générateur, à rouvrir après usage.

## 12. Risques

- **Coût réglé pour des boucles, pas pour aller au plus court** : le goût peut préférer un grand détour
  à 500 m de départementale. C'est ce que mesure le lot 1 bis ; depuis D1 le moteur est le défaut, donc
  ce banc est fait (§10 bis) : le neutre est à un cran de l'optimum, `secondary` y est juste.
- **Heuristique faible** quand l'équipe baisse beaucoup les poids : temps borné par la zone, à mesurer
  au P90 (cible : 300 ms à chaud pour 20 km **(proposé)**).
- **Mémoire** : les fenêtres du routage partagent le budget de 800 Mo avec la génération ; la borne de
  100 km en découle.
- **Vue `road`** : un point posé sur un chemin non revêtu s'accroche à la route la plus proche. C'est le
  comportement de Stadia avec `avoid_bad_surfaces = 1`, mais l'accroche peut surprendre à 500 m.
- **Pas de bac ni de barrière** avant le lot 6 : une île ou un estuaire sans pont n'a pas d'itinéraire
  dans le moteur ; le repli (D4) le donne à Stadia.
- **Le repli masque les manques du moteur** : sans le compteur par cause (§6), personne ne saurait que
  l'option ne sert pas un secteur.
