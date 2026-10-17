# Générer une boucle vélo depuis un départ et une distance : méthodes et pistes pour Pédalons

*Recherche du 17 octobre 2026 (workflow deep-research : 5 angles, 20 sources lues, 91 affirmations
extraites, 25 contre-vérifiées par trois votes, 21 confirmées, 4 réfutées). Le niveau de
confiance de chaque point est donné en [§8](#8-sources-et-fiabilité). L'état de Pédalons est celui du
code à cette date : `backend/src/main/java/fr/pedalons/service/router/RouterService.java`.*

## Sommaire

1. [En une page](#1-en-une-page)
2. [Le problème et ses défauts typiques](#2-le-problème-et-ses-défauts-typiques)
3. [Ce que font les moteurs](#3-ce-que-font-les-moteurs)
4. [Ce que propose la littérature](#4-ce-que-propose-la-littérature)
5. [Pondération vélo et accroche des points](#5-pondération-vélo-et-accroche-des-points)
6. [Mesurer la qualité d'une boucle](#6-mesurer-la-qualité-dune-boucle)
7. [Application à Pédalons](#7-application-à-pédalons)
8. [Sources et fiabilité](#8-sources-et-fiabilité)
9. [Questions ouvertes](#9-questions-ouvertes)

---

## 1. En une page

- **Aucune méthode connue ne livre seule une boucle de longueur exacte, sans chevauchement et sans
  impasse.** Trouver une marche fermée de longueur exactement *k* est NP-difficile (Basagni et
  al. 1997, cité par Lewis & Corcoran 2024). Tout générateur est donc une heuristique avec une
  tolérance ε (≈ 10 % chez Gemsa et al.). Le mainteneur de GraphHopper le dit lui-même : « there is
  no optimal solution like for A-B routing ».
- **La méthode de production** (GraphHopper `round_trip`, reprise par OpenRouteService) projette des
  points sur un polygone autour du départ, selon un cap et une graine, les accroche au réseau, puis
  route au travers en pénalisant les arêtes déjà parcourues. La longueur obtenue n'est
  qu'approximative et tend à **dépasser la cible**, parce que l'espacement des points est calculé à
  vol d'oiseau. Un exemple sur le forum ORS : 38 km obtenus pour 21 km demandés.
- **Le point de passage généré est le maillon faible.** Une route faite de plus courts chemins
  bout à bout ne peut contenir de détour local *qu'autour des points de passage* (Abraham et al.
  2010). La « grande route prise parce qu'un point y a été posé » et l'épi aller-retour vers un
  point tombé dans une impasse sont précisément ce défaut. On le détecte par un test d'optimalité
  locale autour de chaque point, et on le prévient en contrôlant l'accroche.
- **La littérature place les points à partir du graphe plutôt que de la géométrie** :
  - anneaux de distance par Dijkstra pondéré par une « pénalité » (PSP, Gemsa et al. 2013) ;
  - polygone inscrit dans une isochrone *k/2* (Lewis & Corcoran 2024, la méthode la plus précise en
    distance parmi celles comparées) ;
  - deux chemins à arêtes disjointes vers un point de retournement (Bhandari/Suurballe, Lewis &
    Corcoran 2022).
- **Contre les impasses, deux leviers vérifiés** : retirer le 1-shell du graphe en amont (on ne
  garde que le 2-cœur) et élaguer les sommets de degré 1 de la boucle obtenue en aval.
- **Quand on vise l'agrément** (routes plaisantes, POI) sous un budget de distance, le problème
  devient un *Arc Orienteering Problem*, qui se résout par heuristiques (ILS, GRASP). L'exact (MILP)
  plafonne vers 60 km à la campagne et 13 km en ville.
- **Pour Pédalons, qui ne possède pas de graphe** (Stadia Maps, Valhalla hébergé, facturé à
  l'appel, OPS-48), la piste réaliste est un générateur en trois temps :
  1. *générer* quelques candidats : polygone et graine, accroche filtrée par classe de route ;
  2. *router* chaque candidat en un appel ;
  3. *nettoyer et noter* localement : élagage des épis, mesure du chevauchement et des détours, écart
     de distance et de D+ ;

  puis garder le meilleur. Les méthodes qui exigent le graphe (PSP, Bhandari, 2-cœur) supposeraient
  de réintroduire un graphe routier local, ce qui revient sur une décision d'infrastructure ([§7.4](#74-si-un-graphe-local-redevenait-envisageable)).

## 2. Le problème et ses défauts typiques

On demande, à partir d'un départ *s* et d'une distance *k* :

- **obligatoirement**, une marche fermée de longueur ≈ *k* ;
- **en option** : un D+ cible, un cap préféré, des POI à inclure, des points de passage imposés.

Les défauts à éviter, et leur cause habituelle :

| Défaut | Cause habituelle |
|---|---|
| Même route à l'aller et au retour | Le plus court chemin de retour reprend celui de l'aller (deux points seulement, ou corridor unique : vallée, pont, côte) |
| Épi aller-retour en cul-de-sac | Point de passage accroché dans une impasse, ou arc « attrayant » relié par plus courts chemins (Pieper 2018) |
| Tronçon de grande route absurde | Point de passage accroché sur la route la plus proche, qui se trouve être une départementale à fort trafic |
| Demi-tour sur place | Point de passage traversé « en cul-de-sac » : on arrive et on repart par la même arête |
| Distance très au-dessus de la cible | Espacement des points calculé à vol d'oiseau ; obstacles (rivière, côte) qui imposent un détour |
| Tracé tourmenté | Croissance face par face, ou trop de points de passage |

Les trois défauts du milieu (épi, grande route, demi-tour) ont la même origine : **un point de
passage que l'algorithme a posé lui-même, sans regarder le graphe**.

## 3. Ce que font les moteurs

### GraphHopper `round_trip` (et OpenRouteService)

*Confiance haute : documentation officielle, code (`RoundTripRouting.java`), papier évalué.*

- **Paramètres** : `algorithm=round_trip`, `round_trip.distance` (« approximative length »),
  `round_trip.seed` (0 par défaut, donc déterministe : on change de boucle en changeant la graine),
  `heading` du point de départ.
- **Placement** : `new Random(seed)`, cap initial égal au `heading` s'il est fourni et sinon tiré au
  hasard, puis caps successifs `initialHeading + 360·i/points`. Les points sont espacés d'environ
  `distance/points` à vol d'oiseau.
- **Anti-chevauchement** : `AvoidEdgesWeighting` pénalise les arêtes des tronçons précédents. C'est
  l'approche « penalty » héritée de la recherche d'itinéraires alternatifs. La première version
  (PR 420, 2015) n'utilisait que deux points, A et un point B généré, et comptait sur la recherche
  d'alternative pour que le retour diffère de l'aller.
- **Limites rapportées** :
  - longueur qui dépasse la cible, surtout pour les petites boucles ;
  - mauvais comportement près des côtes ;
  - ajouter des points ne corrige pas un dépassement dû au terrain, puisqu'il faut toujours passer le
    même pont.
- **Contournement relevé sur le forum ORS** (juillet 2025) : générer jusqu'à cinq candidats en
  incrémentant la graine et garder le premier qui tombe à 15-20 % de la cible, sinon le plus proche.
  ORS n'avait alors pas de paramètre de cap.
- **Évitement des demi-tours** : `pass_through=true` avec `heading_penalty`, en pénalité souple et
  seulement en mode flexible (`ch.disable=true`).

### Trailrouter

Construit sur GraphHopper. Son auteur jugeait `round_trip` insuffisant pour des boucles guidées par
les préférences. Il proposait de router jusqu'à un point de retournement, de mettre les arêtes de
l'aller en liste de pénalité, puis de router le retour (forum GraphHopper). *Source : forum, une
seule voix.*

### Valhalla (le moteur que Pédalons utilise via Stadia Maps)

**Il n'a pas de mode boucle** dans ce que la recherche a couvert. Côté pondération, voir
[§5](#5-pondération-vélo-et-accroche-des-points).

### Non couverts

**Komoot, Ride with GPS, Strava, plotaroute, BRouter (côté boucle), OSRM** : la recherche n'a trouvé
aucune description vérifiable de leur algorithme de boucle. Ce sont des produits fermés ou sans mode
boucle documenté. Ne rien en déduire.

## 4. Ce que propose la littérature

### 4.1 Placement par anneaux de distance — PSP (Gemsa, Pajor, Wagner & Zündorf, SEA 2013)

*Confiance haute, sur un réseau piéton.*

- Un Dijkstra est lancé depuis *s* sous la métrique ω(a) = bad(a) · ℓ(a), où **bad(a) pénalise les
  arêtes indésirables** (dérivée des tags OSM `highway` et `landuse`).
- Les sommets dont la longueur de chemin tombe dans I(L/3, ε) forment un « anneau » :
  - **PSP2** choisit *u* et *v* sur cet anneau pour former un triangle s→u→v→s ;
  - **PSP3** forme un quadrilatère à L/4, avec un lissage autour des points.
- Chaque tronçon étant un plus court chemin, la longueur est **garantie** dans (1 ± ε)L.
- Performances : succès d'environ 98 % pour 10 km à ε = 10 %, en 155 à 179 ms sur un cœur
  (Karlsruhe, environ 105 000 sommets).
- Pourquoi c'est la bonne réponse au problème de la « grande route par hasard » : **les points sont
  choisis parmi les sommets que la métrique pénalisée atteint**, pas projetés en géométrie. Une
  grande route pénalisée n'attire ni les points ni les tronçons.
- Anti-chevauchement : le Dijkstra du tronçon suivant n'a pas le droit de relaxer les arêtes du
  tronçon précédent. *Les pourcentages de chevauchement avancés pour PSP2/PSP3 ont été réfutés au
  vote (1-2) : ne pas les citer.*

### 4.2 Placement dans une isochrone k/2 (Lewis & Corcoran, SN Computer Science 2024)

*Confiance haute, sur un réseau piéton.*

1. Poser les sommets du polygone **dans l'isochrone de rayon k/2** autour du départ, pour que chaque
   point soit atteignable par le réseau.
2. Les accrocher au réseau et les relier par plus courts chemins.
3. **Supprimer les allers-retours** (élagage des sommets de degré 1, [§4.4](#44-retirer-les-impasses)).

Résultats sur 250 adresses réelles, *k* de 1 à 50 km et *n* de 3 à 8 points : c'est la méthode la
plus précise en écart à la cible, devant le `round_trip` d'ORS. Sur le chevauchement, en revanche,
pas de différence significative.

Une recherche locale Pareto (longueur × chevauchement), qui recombine les trajets déjà obtenus sans
appel supplémentaire, améliore encore le compromis : 96 % des exécutions en moins de 6 s, latence de
l'API comprise. **Le papier travaille au-dessus d'une API de routage, comme Pédalons.**

Réserves :
- profil ORS `foot-walking`, pas vélo ;
- comparaison face à deux références seulement ;
- moyennes sans test de significativité.

### 4.3 Deux chemins à arêtes disjointes (Lewis & Corcoran, Journal of Heuristics 2022)

*Confiance moyenne, votes 2-1.*

- On choisit un sommet de retournement *t*, on calcule **deux chemins s→t à arêtes disjointes** de
  poids total minimal (méthode de Bhandari, variante de Suurballe) et on les unit.
- **Aucune arête n'est réempruntée**, sauf les ponts (arêtes de coupure), qui peuvent l'être deux
  fois.
- Une variante « cycle » interdit aussi de repasser par un sommet, sauf aux points d'articulation.
  Elle coûte de 20 à 100 % de calcul en plus.
- Une recherche locale ajuste ensuite la longueur vers *k*.
- Résultats : boucles à quelques mètres de la cible, souvent en moins d'une seconde, sur des réseaux
  OSMnx de 12 × 12 km de cinq villes. L'approche k-plus-courts-chemins de Yen ne trouvait rien en
  30 min au-delà de 700 m.

C'est **la seule construction qui garantit l'absence de réemprunt**, mais elle exige le graphe.

### 4.4 Retirer les impasses

*Confiance haute (a) et moyenne (b).*

- **(a) En amont, sur le graphe** : retirer itérativement les sommets de degré 1 (le « 1-shell »).
  Il reste le 2-cœur, sans impasse, et ni les points ni les tronçons ne peuvent plus y entrer
  (Gemsa et al.).
- **(b) En aval, sur la boucle** : construire le graphe non orienté des arêtes de la boucle, puis
  supprimer les sommets de degré 1 (sauf *s*) jusqu'à ce qu'il n'en reste plus (Lewis & Corcoran
  2024). Les épis disparaissent. **La boucle raccourcit** et peut passer sous la cible.

Ce qu'aucune des deux ne fait :
- (b) ne retire pas une rue empruntée deux fois *à l'intérieur* de la boucle, puisqu'aucun de ses
  sommets n'est de degré 1 ;
- la validité en sens orienté (sens uniques) n'est traitée par aucune des deux sources.

### 4.5 Croissance par faces (Greedy Faces, Gemsa et al.)

On fait croître la boucle face par face sur le graphe dual, après retrait des impasses
(1 000 requêtes, L = 10 km, ε = 10 %) :

| Variante | Chevauchement | Virages | Échecs | Longueur |
|---|---|---|---|---|
| Croissance pure | 0,2 % | 51 | 7 % | stable |
| Avec lissage par plus courts chemins | 6 à 7 % | 28 à 30 | — | écart-type d'environ 0,6 km → 2 km |

C'est l'**arbitrage explicite chevauchement / sinuosité / précision**. En ville dense, on ne peut pas
gagner sur les trois tableaux.

### 4.6 Optimalité locale : détecter le point mal placé (Abraham, Delling, Goldberg & Werneck, SEA 2010)

*Confiance haute sur le théorème. Son application aux boucles est une analogie raisonnée, pas un
résultat publié.*

- Un chemin est **T-localement optimal** si tout sous-chemin de longueur ≤ T est un plus court
  chemin. Un chemin qui ne l'est pas contient un détour local.
- Une concaténation s→v→t de plus courts chemins **ne peut perdre cette propriété qu'autour de v**.
- Le test pratique : pour chaque point de passage *v*, prendre une fenêtre de longueur T centrée sur
  *v*, router entre ses deux extrémités, et comparer. Si le chemin direct est nettement plus court,
  *v* a induit un détour : épi, crochet par une grande route, demi-tour.
- C'est le contrôle qui manque à `round_trip`.

### 4.7 Orientation par arcs : quand on vise l'agrément

*Confiance haute sur le cadre, moyenne sur les détails.*

**Le cadre.** Boucle de loisir à vélo = **Arc Orienteering Problem** : chaque arc a un score
(agrément) et un coût (longueur), et l'on maximise le score sous un budget de distance. On parle
d'**OP** quand le score porte sur des sommets, par exemple des POI. Les deux sont NP-difficiles. Les
références à comité de lecture sont Souffriau et al. (Omega 2011, Flandre orientale) et Verbeeck et
al. (TR-E 2014).

**Klocker (TU Wien/AIT, 2015)** traite une variante sur multigraphe orienté où **réemprunter une rue
est permis mais pénalisé** dans le score. Ses MILP exacts (formulation *flow*, CPLEX) passent jusqu'à
environ 60 km à la campagne et environ 13 km en ville. Au-delà, il faut des heuristiques.

**Pieper (Union College, 2018)** a implémenté les heuristiques ILS de Lu & Shahabi sur GraphHopper.
Ces heuristiques collent des « arcs attractifs » par plus courts chemins et **produisent des épis
aller-retour**, jusqu'à des routes faites uniquement d'épis. Le remède testé :
- liste noire des arcs déjà dans la solution ;
- coût infini sur les arcs en impasse.

Cette liste noire par requête est incompatible avec les contraction hierarchies, ce qui force le
repli sur un Dijkstra bidirectionnel. *Source unique, mémoire de licence.*

**Limite de ces modèles** : ils plafonnent la distance (budget) au lieu de viser une cible, et ne
disent rien des impasses. Il faut leur ajouter une contrainte de longueur minimale et une pénalité
d'impasse.

## 5. Pondération vélo et accroche des points

*Affirmations extraites de sources primaires ou de blogs d'éditeurs. Celles marquées † n'ont pas
été contre-vérifiées faute de budget.*

### GraphHopper

`custom_model` multiplie la priorité des arêtes selon leurs attributs. Exemples officiels †, dans le
format JSON du `custom_model` :

```json
{ "if": "road_class == PRIMARY", "multiply_by": "0.1" }
{ "if": "max_speed >= 50", "multiply_by": "0.1" }
{ "if": "bike_network == MISSING", "multiply_by": "0.9" }
```

- **Un multiplicateur 0 exclut la classe et empêche aussi d'y accrocher un point** †.
- **Un petit multiplicateur positif** laisse l'accroche possible mais éloigne l'itinéraire de cette
  classe †.
- `snap_prevention` ne fait que changer **où un point s'accroche** : l'itinéraire peut toujours
  emprunter la classe exclue (réponse du mainteneur) †.
- `distance_influence` règle combien de détour on accepte pour une meilleure route †.

### BRouter

- **Coût par mètre** `costfactor ≥ 1`, ce qui est requis par la coupure de recherche. Un
  `costfactor ≥ 10000` rend la voie interdite †.
- **Virages** : `turncost · (1 − cos angle)`, donc un demi-tour coûte deux fois le `turncost` †.
- **Dénivelé** : `uphillcost` et `downhillcost`, avec un seuil de pente (*cutoff*) sous lequel la
  voie compte comme plate, et un tampon d'hystérésis (`elevationmaxbuffer`, 10 m par défaut) qui
  filtre le bruit †.

### Valhalla (Mapzen, puis Stadia Maps)

- **Poids d'une arête** : `1 + stress_factor + slope_factor` †.
  - `stress_factor = accommodation × road_stress` : vitesse, nombre de voies, présence d'un
    aménagement cyclable.
  - `use_roads` et `use_hills`, entre 0 et 1, modulent ces facteurs †.
- **`bicycle_type`** (Road, Hybrid, Cross, Mountain) fixe les surfaces admises et la vitesse par
  défaut †.
- La pente est évaluée **le long des arêtes** †. *Le billet de 2015 disait que l'élévation n'était
  pas encore prise en compte ; `use_hills` est arrivé ensuite.*

### Ce que cela implique pour l'accroche

Il y a deux leviers distincts, à ne pas confondre :

1. **Où le point s'accroche** : filtre de classe de route sur le point.
2. **Par où passe l'itinéraire** : pondération des arêtes.

Un générateur de boucle a besoin des deux. Le point doit s'accrocher sur une voie que la
pondération *aime*, sinon l'itinéraire est forcé d'aller le chercher.

## 6. Mesurer la qualité d'une boucle

Indicateurs réutilisables pour un banc de test et pour classer des candidats :

| Indicateur | Définition | Source |
|---|---|---|
| f1, écart de distance | \|k − L(S)\|, en m ou en % de k | Lewis & Corcoran 2024 |
| f2, chevauchement | 100 × Σ(x−1)·w(u,v) / L(S), sur arêtes non orientées, x = multiplicité | Lewis & Corcoran 2024 |
| Virages | angles hors de 180° ± α | Gemsa et al. |
| « Badness » pondérée | moyenne de bad(a) pondérée par la longueur (tags `highway` et `landuse`) | Gemsa et al. |
| Taux d'échec, stabilité de longueur | sur un lot de requêtes | Gemsa et al. |
| *Détour local aux points* | rapport longueur réelle / plus court chemin sur une fenêtre T autour de chaque point | dérivé d'Abraham et al. (analogie) |
| *Écart de D+* | \|D+ cible − D+ obtenu\| | proposé ici, non sourcé |

## 7. Application à Pédalons

### 7.1 Les contraintes

- **Pas de graphe local.** Le planificateur appelle `POST /route/v1` de Stadia Maps (protocole
  Valhalla) avec deux `locations` et un `costing` dérivé de `RouterProfile` (`bicycle_type`,
  `use_roads`, `avoid_bad_surfaces`). Pédalons n'héberge plus de routeur (OPS-48).
- **Chaque appel est décompté d'un quota mensuel** : une erreur 429 signale le quota épuisé. Un
  générateur qui ferait des dizaines d'appels par boucle est exclu.
- **Le dénivelé est déjà calculé localement** : `GpxPipeline` recale l'altitude sur le MNT. Noter un
  candidat en D+ ne coûte aucun appel.

### 7.2 Le générateur proposé : candidats, nettoyage, notation

Les options Valhalla citées ci-dessous (`search_filter`, `radius`, `type: through`, `heading`,
`isochrone`) **viennent de la documentation Valhalla et n'ont pas été vérifiées par cette
recherche** : à confirmer sur la référence API et chez Stadia Maps avant d'écrire du code.

1. **Candidats (sans appel).** On génère N polygones (N ≈ 4 à 6) autour de *s*.
   - **Forme** : triangle ou quadrilatère. Trois ou quatre points suffisent, et plus de points rend
     le tracé plus tourmenté sans corriger le terrain ([§3](#3-ce-que-font-les-moteurs)).
   - **Cap** : celui de l'utilisateur, sinon une graine. Le cap fixe l'axe départ → centre du
     polygone.
   - **Rayon** : déduit de *k*, divisé par un **facteur de détour** pour compenser le dépassement
     systématique. Le facteur se calibre par zone ou s'ajuste entre deux essais (sécante) ; aucune
     valeur n'est sourcée ici.
   - **Points imposés et POI** : ce sont des sommets du polygone. On ne génère que les points
     manquants, répartis sur l'arc restant.
2. **Accroche maîtrisée.** Chaque point généré est envoyé avec :
   - un **filtre de classe de route** qui exclut primaire et au-dessus, voire secondaire selon le
     profil ;
   - un **rayon de recherche** ;
   - un **cap tangent au polygone**, pour qu'il soit traversé dans le sens de la boucle et non en
     cul-de-sac ;
   - le type `through` (pas d'arrêt).

   Les points imposés par l'utilisateur gardent une accroche libre : c'est lui qui les a posés.
3. **Routage (un appel par candidat).** On envoie toute la boucle en une requête (s, p1…pn, s).
   Valhalla n'offre pas de liste noire d'arêtes par requête. L'anti-chevauchement repose donc sur la
   forme du polygone, sur l'étape 4 et sur la notation.
4. **Nettoyage local**, sur la géométrie rééchantillonnée :
   - **élagage des épis** : repérer un tronçon suivi de son inverse et le couper au point de
     rebroussement. C'est l'équivalent géométrique de l'élagage des sommets de degré 1
     ([§4.4](#44-retirer-les-impasses)) ;
   - **mesure de f2** : longueur parcourue à moins de quelques mètres d'une portion déjà parcourue.
5. **Notation et choix.** Le score combine :
   - f1, l'écart de distance après élagage ;
   - f2, le chevauchement ;
   - l'écart de D+ quand une cible est donnée ;
   - la **sinuosité autour de chaque point généré** : un rapport élevé entre la longueur dans une
     fenêtre autour du point et la distance entre ses extrémités signale l'épi ou le crochet de
     [§4.6](#46-optimalité-locale--détecter-le-point-mal-placé-abraham-delling-goldberg--werneck-sea-2010)
     sans appel supplémentaire.

   On garde le meilleur candidat et l'on propose les suivants en « autre boucle », comme le fait
   « changer la graine » chez GraphHopper.
6. **Optionnel, un second tour.** On repart du meilleur candidat, on corrige le rayon par le rapport
   *k*/L obtenu, on déplace ou retire le point le plus mal noté, puis on reroute. Le budget total
   reste d'environ N + 1 appels.

### 7.3 Le dénivelé

Aucune source vérifiée ne traite le D+ cible. Trois options, de la moins chère à la plus chère :

1. **Reclasser les candidats** sur l'écart de D+. C'est gratuit, mais l'effet est limité : les
   candidats sont tirés sans regarder le relief.
2. **Orienter le polygone** vers le relief ou loin de lui. Le MNT est déjà disponible localement :
   on évalue, par cap, l'amplitude d'altitude sur un rayon donné, puis on tire les caps en
   conséquence.
3. **Jouer sur `use_hills`** du costing Valhalla (bas pour un parcours plat, haut pour accepter les
   pentes). C'est la seule option qui agit sur le routage lui-même.

### 7.4 Si un graphe local redevenait envisageable

Un graphe vélo local permettrait les méthodes qui donnent des garanties :
- PSP, pour une longueur garantie et des points posés là où la métrique pénalisée le permet ;
- Bhandari/Suurballe, pour l'absence de réemprunt ;
- le 2-cœur, pour l'absence d'impasse ;
- la liste noire d'arêtes par requête.

Ce graphe pourrait être pgRouting sur le PostGIS existant, à partir d'un extrait OSM, ou un
GraphHopper auto-hébergé (`round_trip`, `custom_model` et `snap_prevention` natifs). Il reviendrait
sur la décision de ne plus héberger de routeur (OPS-48) : import OSM, mémoire, mises à jour. Cela
mérite un arbitrage explicite et pas un glissement.

## 8. Sources et fiabilité

| Source | Type | Ce qu'on en retient | Confiance |
|---|---|---|---|
| [Docs GraphHopper routing](https://docs.graphhopper.com/openapi/routing) | primaire | `round_trip`, seed, heading, `pass_through`, `custom_model` | haute (3-0) |
| [Lewis & Corcoran 2024, SN Comput. Sci. 5:868](https://link.springer.com/article/10.1007/s42979-024-03223-3) | évalué | dépassement du polygone, isochrone k/2, élagage, f1/f2 | haute (3-0, 2-1 sur l'élagage) |
| [Gemsa et al. 2013, SEA, « Efficient Computation of Jogging Routes »](https://i11www.iti.kit.edu/extra/publications/gpwz-ecjr-13.pdf) (404, lue via Wayback) | évalué | PSP, 1-shell, Greedy Faces, indicateurs | haute (3-0) |
| [Abraham et al. 2010, SEA, alternative routes](https://microsoft.com/en-us/research/wp-content/uploads/2010/01/alternativeSea2010.pdf) | évalué | optimalité locale autour du point de passage | haute (théorème) ; analogie pour les boucles |
| [Lewis & Corcoran 2022, J. Heuristics 28](https://link.springer.com/article/10.1007/s10732-022-09493-5) | évalué | double chemin à arêtes disjointes | moyenne (2-1) |
| [Klocker 2015, AIT/TU Wien](https://publications.ait.ac.at/en/publications/optimization-approaches-for-recreational-bicycle-tour-planning-4/) | mémoire de master (abstract) | AOP vélo, réemprunt pénalisé, limites MILP | haute sur le cadre |
| [Pieper 2018, Union College](https://cs.union.edu/Archives/SeniorProjects/2018/CS.2018/files/piepera/piepera-499-report.pdf) | mémoire de licence | ILS → épis, liste noire, incompatibilité CH | moyenne (source unique) |
| [Préprint arXiv 2512.16865](https://arxiv.org/pdf/2512.16865) | secondaire | définition de l'OP | moyenne |
| Forums [ORS 4170](https://ask.openrouteservice.org/t/description-of-round-trip-feature/4170), [ORS 7475](https://ask.openrouteservice.org/t/directions-api-accurate-target-distance-response/7475), [ORS 1223](https://ask.openrouteservice.org/t/dynamic-weights-to-avoid-repetition-in-routes/1223), [GH 311](https://discuss.graphhopper.com/t/prevent-double-usage-of-edges/311), [GH 5266](https://discuss.graphhopper.com/t/can-graphhopper-be-used-to-suggest-a-walking-route-based-on-a-start-point-and-a-distance/5266), [GH 7933](https://discuss.graphhopper.com/t/difference-between-snap-prevention-and-custom-model/7933) | forum | comportement réel, contournements, propos des mainteneurs | moyenne |
| [GraphHopper, customizable routing](https://www.graphhopper.com/blog/2020/05/31/examples-for-customizable-routing/), [BRouter profile guide](https://brouter.de/brouter/profile_developers_guide.txt), [Poutnik glossary](https://github.com/poutnikl/Brouter-profiles/wiki/Glossary), [Mapzen bike options](https://mapzen.com/blog/valhalla-bicycle-routing-options), [Mapzen low-stress](https://www.mapzen.com/blog/low-stress-bike-routing) | primaire ou blog d'éditeur | pondération vélo ([§5](#5-pondération-vélo-et-accroche-des-points)) | non contre-vérifiée († ) |

**Réfutées au vote, à ne pas reprendre :**
- le « Simple Jogging Problem » faiblement NP-difficile avec un DP en O(L|E|) (0-3) ;
- les chiffres de chevauchement 52,5 / 23,6 / 13,9 % de PSP2/PSP3/PSP3-Bi (1-2) ;
- la transposition directe des trois conditions d'admissibilité des alternatives (sharing, T-LO,
  stretch) à la notation des boucles (0-3) ;
- la formulation exacte de l'AOP par set-partitioning et column generation (0-3).

**Portée.** Les chiffres de Gemsa et de Lewis & Corcoran portent sur des réseaux **piétons**
(Karlsruhe, ORS `foot-walking`, villes OSMnx). Un réseau cyclable est moins dense, contraint par les
sens uniques et filtré par classe de route. Les ordres de grandeur ne se transposent pas tels quels.

## 9. Questions ouvertes

1. **D+ cible** : pondérer par la pente, viser des sommets locaux, ou reclasser ? Rien de vérifié.
   À trancher par l'expérience sur un banc de départs réels.
2. **Points imposés et POI dans une méthode à anneaux ou à isochrone** : comment les intégrer sans
   réintroduire l'accroche sur grande route ? Piste : accroche restreinte aux classes que la
   pondération favorise, plus un test de détour local autour de chaque point.
3. **Valhalla et Stadia Maps** : vérifier `search_filter` (classes min et max), `radius`, `heading`,
   `type: through`, la disponibilité de l'isochrone chez Stadia et son coût en quota. La faisabilité
   de [§7.2](#72-le-générateur-proposé--candidats-nettoyage-notation) en dépend.
4. **Transfert au vélo** : l'élagage des degrés 1, l'isochrone k/2 et les chemins disjoints tiennent-
   ils sur un réseau routier avec sens uniques ? Et la trace élaguée reste-t-elle une marche fermée
   valide en orienté ?
5. **Calibration** : quel facteur de détour (rayon ↔ distance réelle) par type de zone (ville,
   bocage, montagne) ? Il se mesure sur un échantillon, sans source.
6. **Moteurs fermés** (Komoot, Ride with GPS, Strava) : aucune information vérifiable sur leurs
   méthodes de boucle.
