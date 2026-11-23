# Générateur de parcours au-delà du réseau de l'équipe : graphe OSM préparé, parcours organiques, off-road

Écrit le 15 novembre 2026. **État au 16 novembre 2026 : lots 0 à 3 codés (ledger `API-206`, contrat `15.0.0`, §12 quinquies), tests backend et
mise en service à faire ; lots 4 à 7 ouverts.** Ledger `API-207`.
Suite de [`2026-11-13-generateur-boucles-equipe.md`](archive/2026-11-13-generateur-boucles-equipe.md)
(`API-198`, « le plan d'équipe » ci-dessous) et de la recherche
[`2026-10-17-generateur-boucles.md`](../research/2026-10-17-generateur-boucles.md).

Cette proposition **revient sur trois points que le plan d'équipe avait mis dehors** (son §12) :
importer OSM, proposer des routes que l'équipe n'a pas roulées, faire profiter une équipe de ce que
d'autres ont roulé. La recherche demandait pour cela « un arbitrage explicite et pas un
glissement » : c'est l'objet du §11.

Les chiffres marqués **(mesuré)** viennent du banc d'`API-198` ou d'une mesure faite ce jour sur
l'export de production ; ceux marqués **(estimé)** sont des ordres de grandeur à confirmer au lot 0.

---

## 1. En une page

Le générateur d'équipe tient ses garanties, mais il ne sert presque personne : 41 % de réussite
pour la plus grande équipe, 14 % pour une équipe moyenne, 1 à 2 % pour les équipes de grands
tours, 0 % pour les petites **(mesuré, conception du lot 2 §13.3)**. La cause n'est pas
l'algorithme : un réseau fait de lignes qui ne se recoupent pas ne contient pas de boucle.

Cinq briques, dans l'ordre où elles se construisent :

| # | Brique | Ce qu'elle apporte |
|---|---|---|
| 1 | **Graphe vélo préparé à partir d'OSM**, hors ligne, écrit dans un fichier découpé en cellules et lu par `mmap` | Des routes partout, avec les attributs que les tuiles n'ont pas (contresens cyclables, accès, `smoothness`, `mtb:scale`, relations d'itinéraires). Pas de graphe dans le tas d'une JVM |
| 2 | **Moteur de génération en Rust**, à côté d'osm-route-details | Recherche en dizaines de millisecondes sur des tableaux plats ; le même cœur peut tourner plus tard dans le navigateur (WASM) |
| 3 | **Génération « squelette puis chair »** | Des parcours qui ressemblent à ceux qu'une personne trace : boucle étirée vers un point lointain, triangle vers deux points. La forme est tirée de la distribution mesurée sur les vrais parcours, pas d'un polygone régulier |
| 4 | **Données recalculées chaque nuit depuis les parcours en base** | Fréquentation par arête, **goût appris** par classe de route, formes, destinations, chemins confirmés roulables. C'est ce qui garde une couleur d'équipe là où l'équipe n'est jamais passée |
| 5 | **Coût off-road à part de cible** | « 40 % de chemins » devient une consigne tenue, pas une préférence vague |

Le curseur de fréquentation devient un curseur **« routes de l'équipe ↔ découverte »** : à un bout,
la promesse d'aujourd'hui (que des routes de l'équipe) ; à l'autre, OSM seul. Le générateur
d'`API-198` n'est pas jeté : il reste le mode strict, et son contrôleur `RouteGuarantees` reste
l'arbitre des propositions (§8).

**Les hiérarchies de contraction ne sont pas le premier levier** (§4.4) : une boucle de 100 km ne
cherche que dans un disque de 50 km, soit environ 180 000 arêtes **(estimé)**, qu'un Dijkstra sur
tableaux plats parcourt en quelques dizaines de millisecondes. Elles paient pour l'aller simple
long et pour les tables de distances entre destinations ; la variante à retenir alors est
**personnalisable** (CCH), parce que le poids change avec le type, le curseur et l'équipe.

---

## 2. Ce que les vrais parcours disent (mesuré le 15 novembre 2026)

Mesure sur l'export de production (9 équipes, 3 370 traces de plus de 5 km, dont 2 967 boucles :
arrivée à moins de 5 % de la distance du départ). Géométrie recalée des `network_edges`.

**Forme des boucles.** D = longueur, r = distance à vol d'oiseau du départ au point le plus éloigné.

| Mesure | P10 | P25 | Médiane | P75 | P90 | Repère |
|---|---|---|---|---|---|---|
| r / D | 0,25 | 0,29 | **0,32** | 0,36 | 0,38 | cercle parfait 0,32 ; aller-retour 0,50 |
| Position du point le plus éloigné le long du parcours | 0,42 | 0,46 | **0,50** | 0,55 | 0,59 | 0,50 = à mi-parcours |
| Compacité 4πA / D² | 0,16 | 0,22 | **0,30** | 0,39 | 0,48 | cercle parfait 1,00 |

Lecture : une route réelle serpente, donc un cercle « sur routes » aurait r / D vers 0,25 et une
compacité vers 0,6. Les vrais parcours vont **aussi loin qu'un cercle parfait le permettrait malgré
les détours, pour une surface enclose deux fois moindre** : ce sont des boucles étirées. Le point le
plus éloigné est à mi-parcours, à ±10 % près. Ces rapports ne dépendent pas de la distance
(r / D médian de 0,32 de 0 à 100 km, 0,34 de 100 à 150 km).

**Nombre de sommets** (simplification de Douglas-Peucker à 5 % de D, départ non compté) :

| Sommets hors départ | 1 | 2 | 3 | 4 | 5 et plus |
|---|---|---|---|---|---|
| Part des boucles | 2 % | 28 % | **40 %** | 25 % | 6 % |
| Figure | aller-retour | boucle étirée (lentille) | triangle | quadrilatère | — |

La mesure est grossière (le seuil de 5 % décide du compte), mais elle confirme l'intuition : deux
ou trois points lointains couvrent deux tiers des cas.

**Part de non-revêtu, par type déclaré du parcours** (longueur parcourue) :

| Type | Parcours | Non-revêtu P10 / médiane / P90 | Pistes et sentiers (`track` + `path`) P10 / médiane / P90 |
|---|---|---|---|
| Route | 2 445 | 0 % / 0 % / 5 % | 0 % / 0 % / 10 % |
| Gravel | 912 | 20 % / **38 %** / 49 % | 19 % / **43 %** / 54 % |
| VTT | 13 | 31 % / 41 % / 62 % | 27 % / 54 % / 68 % |

Un parcours gravel réel est aux deux tiers sur du revêtu : la demande « plus de pistes » se chiffre
contre cette base (38 % par défaut, 50 % et plus pour qui le demande), et non contre 100 %.

Script jetable, hors dépôt (`shapes.py`, dossier du banc) ; le §7 en fait un calcul régulier.

---

## 3. Données OSM préparées en amont

Aujourd'hui le graphe des rues est lu dans les tuiles VersaTiles shortbread z14 par
osm-route-details : pas d'identifiant OSM, ways fusionnées, ni `oneway:bicycle`, ni `access`, ni
`smoothness`, ni `mtb:scale` (plan d'équipe §3.1 et §4). C'est assez pour dire le revêtement sous
une trace, pas pour router.

**Pipeline hors ligne** (un binaire, lancé à la main ou par un cron mensuel, jamais dans le
chemin d'une requête) :

1. **Extrait** Geofabrik : une région pour commencer (Pays de la Loire, environ 350 Mo, déjà
   l'emprise de `cyclingtiles`), puis la France (environ 4,7 Go de `.osm.pbf`).
2. **Filtre vélo** : ways `highway=*` ouvertes au vélo, avec ce que les tuiles perdent :
   `oneway:bicycle`, `cycleway:*=opposite*`, `access` / `bicycle` / `vehicle` (et `private`,
   `destination`), `surface`, `tracktype`, `smoothness`, `mtb:scale`, `sac_scale`, `width`,
   `maxspeed`, `lanes`, barrières sur les nœuds, restrictions de tourner, et l'appartenance à une
   **relation d'itinéraire** (`route=bicycle|mtb`, réseaux `lcn` / `rcn` / `ncn`).
3. **Graphe de jonctions** : nœuds de degré ≠ 2, arêtes entre eux, géométrie gardée à part.
   Identifiant d'arête = (way OSM, nœud OSM de départ, nœud OSM d'arrivée) : **stable d'un extrait
   à l'autre**, ce que l'identifiant géométrique z14 n'était qu'à peu près.
4. **Dénivelé par arête** (gain et perte dans chaque sens) depuis Mapterhorn, que
   osm-route-details sait déjà lire. Précision de coût, pas d'affichage : le D+ exact reste celui
   du pipeline habituel à l'enregistrement.
5. **Classes dérivées**, calculées une fois : classe de roulabilité (0 = route lisse … 5 = sentier
   technique), indice de trafic présumé (classe, voies, vitesse, traversée d'agglomération),
   « chaîne off-road » (§6), cul-de-sac (hors 2-cœur), composante.
6. **Attracteurs** (§5.2) : cols, sommets desservis, points de vue, plans d'eau, bourgs, cafés et
   boulangeries, points d'eau.
7. **Écriture** du fichier de cellules (§4.1), versionné par date d'extrait ; l'ancien reste en
   place jusqu'à ce que le moteur ait rechargé (déploiement roulant).

Taille **(estimée)** : le réseau de la plus grande équipe fait 14 979 km pour 69 458 arêtes, soit
216 m par arête **(mesuré)**. Pour 2,5 à 3 millions de km de voies cyclables en France, cela donne
12 à 14 millions d'arêtes : de l'ordre de 0,5 Go de topologie et d'attributs, autant de géométrie.
Une région tient en quelques dizaines de Mo. À mesurer au lot 0 avant tout autre choix.

Outils : `osmium` pour l'extrait (déjà utilisé par `cyclingtiles`), lecture du PBF en Rust
(crate `osmpbf` ou équivalent). Pas de PostGIS, pas d'osm2pgsql : rien de tout cela ne doit
toucher la base de l'application.

---

## 4. Le graphe et le moteur

### 4.1 Sur disque, pas en mémoire

Le banc a montré le coût d'un graphe dans le tas : 1,66 Go de tas vivant pour construire le réseau
de l'équipe A, ramené à 440 Mo, plus un cache Caffeine par équipe (plan d'équipe §13.2, §13.8).
Avec un graphe OSM commun, ce modèle ne passe pas à l'échelle.

**Fichier unique découpé en cellules, lu par `mmap`.** Cellule = une case de grille (ou, mieux,
une cellule d'une partition par coupes, ce qui prépare le §4.4). Par cellule : nœuds, arêtes au
format CSR, attributs compacts, table des arêtes de bord. La géométrie est dans une section
séparée, lue seulement pour les parcours rendus. Une requête ne touche que les cellules du disque
de recherche ; la mémoire résidente est celle du cache de pages du noyau, **bornée par la limite du
conteneur**, et rendue sans GC. C'est le principe des tuiles de Valhalla et des fichiers `rd5` de
BRouter, sans leur format.

**Surcouches par équipe**, petites et séparées du graphe : un tableau « identifiant d'arête →
fréquentation par type » par équipe (quelques centaines de Ko pour 69 458 arêtes), plus les
préférences apprises (§7). Le graphe est commun à tous les domaines ; **rien de privé n'y entre**.

### 4.2 Le moteur : Rust, à côté d'osm-route-details

Trois raisons de ne pas rester en Java pour cette partie :

- **le dépôt osm-route-details a déjà les morceaux** : appariement HMM, lecture des tuiles
  d'élévation, caches, contrat, image, banc. Un crate `ord-graph` (format et lecture) et un crate
  `ord-loops` (génération) s'ajoutent au même workspace ;
- **`mmap` et tableaux plats** : pas de tas à dimensionner, pas d'`OutOfMemoryError` qui emporte
  le backend entier (plan d'équipe §13.2) ;
- **une seule base de code pour le serveur et, plus tard, le navigateur** (§10.1).

Le backend Java garde ce qui est de son ressort : droits (`PlannerAccess`), quota, limite de débit,
contrat, surcouches d'équipe, vérification finale par `RouteGuarantees`. Il appelle le moteur
comme il appelle déjà osm-route-details. **Aucune coordonnée ne quitte le serveur**, à la
différence du planificateur (Stadia).

**Convergence possible** : si osm-route-details apparie les traces sur ce même graphe plutôt que
sur les tuiles, `edges[]` porte de vrais identifiants OSM, les contresens cyclables et les accès.
Les « ce que le réseau ne sait pas » du plan d'équipe (§4) tombent, et la fréquentation se rattache
aux arêtes sans jointure géométrique. C'est un changement de source pour la typologie, donc un
passage par le banc d'osm-route-details : à faire après, pas avant.

### 4.3 Coût d'une recherche

Disque de rayon D/2 autour du départ. Pour D = 100 km : 7 850 km², environ 39 000 km de voies à
5 km de voie par km², soit 180 000 arêtes **(estimé)**. Un Dijkstra par arêtes orientées sur
tableaux plats y prend quelques dizaines de millisecondes. La génération du §5 en demande une
dizaine : un arbre depuis le départ, un arbre vers l'arrivée, puis une recherche par destination
candidate. Cible : **moins de 500 ms** là où le générateur d'équipe met 2,5 s au médian sur
69 458 arêtes **(mesuré)**.

### 4.4 Hiérarchies de contraction : où elles paient

| Technique | Ce qu'elle suppose | Verdict |
|---|---|---|
| **CH classique** | Un poids fixé au prétraitement | **Écarté.** Le poids dépend du type, du curseur, de l'équipe, et la génération interdit des arêtes en cours de requête (liste noire, couloir) : tout ce que la recherche d'octobre notait comme incompatible |
| **CCH** (hiérarchies personnalisables) | Un ordre de contraction calculé une fois par extrait, indépendant du poids ; puis une « personnalisation » par poids, en secondes | **À retenir pour le lot 5** : aller simple long (jusqu'à 300 km), tables de distances entre destinations candidates. Un poids par type et par réglage standard ; pas un par équipe |
| **Partition à plusieurs niveaux** (CRP, le MLD d'OSRM) | Cellules, et par cellule une table bord à bord par poids | **L'option la plus cohérente avec le fichier en cellules** : la table d'une cellule se calcule à la demande et se garde en cache, **y compris pour le poids d'une équipe**, uniquement là où elle roule |
| **Repères (ALT)** | Quelques arbres complets précalculés | Bon marché, gain modeste ; utile si le lot 5 tarde |

Deux réserves. La contrainte de demi-tour vit sur des arêtes orientées, ce qui grossit le graphe à
contracter. Et aucune de ces techniques n'accélère la partie qui compte ici, la recherche locale
avec pénalités changeantes : elles accélèrent les **distances** dont le squelette a besoin.
Bibliothèques existantes à évaluer plutôt que réécrire : RoutingKit (C++), le crate Rust `cch`
(réimplémentation de RoutingKit), InertialFlowCutter pour l'ordre. Non essayées.

---

## 5. Des parcours organiques : squelette, puis chair

### 5.1 Pourquoi les générateurs connus ne le sont pas

GraphHopper `round_trip` tire des points sur un cercle autour du départ et les relie : la forme est
ronde et arbitraire, les points tombent n'importe où (recherche §3). Le générateur d'équipe choisit
un point de retournement ou un polygone régulier dans un cap. Une personne fait l'inverse : elle
choisit **où aller** (un col, un bourg, un café, la mer), y va par une route qu'elle aime, et
revient par une autre.

### 5.2 Le squelette

1. **Tirer une figure** dans la distribution du §2 : lentille (un point lointain), triangle (deux),
   quadrilatère (trois), avec les proportions mesurées ; r / D tiré entre 0,25 et 0,38. Quand
   l'équipe a assez de parcours, **sa** distribution remplace la distribution générale.
2. **Choisir les points lointains parmi des attracteurs**, pas au hasard :
   - d'OSM (§3 point 6) ;
   - de la base (§7) : points les plus éloignés des parcours existants, regroupés ; lieux de
     l'équipe (`Place`) ; arrivées des sorties ;
   - du terrain : têtes de montées repérées par la pente des arêtes ;
   - pour le gravel et le VTT : les grandes **chaînes off-road** (§6).
   Un attracteur n'est retenu que s'il est à la bonne distance **par la route** (arbre depuis le
   départ, déjà calculé) et dans le cap demandé.
3. **Sans attracteur à portée** (plaine, zone peu cartographiée) : repli sur le nœud du graphe à
   la bonne distance qui maximise l'agrément du chemin pour y aller.

### 5.3 La chair

Chaque jambe du squelette est un plus court chemin pour le poids d'agrément (§5.4, §7.2).

- **Le retour s'écarte de l'aller par une pénalité de couloir**, pas par une interdiction d'arêtes :
  toute arête à moins de *w* mètres de l'aller coûte plus cher. *w* se déduit de la compacité visée
  (0,30 au médian) : c'est lui qui donne sa largeur à la lentille. Près du départ, la pénalité
  s'efface : c'est la « queue » du plan d'équipe, le tronçon commun pour sortir de chez soi.
- **Test du point mal placé** (optimalité locale, recherche §4.6) : si retirer un sommet raccourcit
  le parcours de plus qu'un seuil sans dégrader l'agrément, le sommet était un épi ; on le déplace
  le long de la jambe ou on le retire.
- **Distance** : l'échelle du squelette est corrigée par la sécante, comme aujourd'hui. Le facteur
  de détour (distance par la route / vol d'oiseau) est lu dans les données du §7 au lieu d'être
  deviné.
- **Garanties** : demi-tour, impasse, réemprunt, croisements, ±10 % restent vérifiés par le
  contrôleur indépendant. La garantie « que des routes de l'équipe » devient un mode (§8).

### 5.4 Le poids d'agrément

  longueur × classe(type) × revêtement(type) × pente × trafic présumé × itinéraire balisé × goût de l'équipe × familiarité

Les quatre premiers facteurs viennent du prétraitement ; le goût et la familiarité, des surcouches
du §7. Deux consignes chiffrées se règlent par un **multiplicateur ajusté par dichotomie** plutôt
que par un poids fixe : la part de non-revêtu (§6) et, plus tard, le D+ visé (décision 10.7 du plan
d'équipe, laissée ouverte).

---

## 6. Off-road : plus de pistes et de chemins

1. **Les bons attributs** (§3) : sans `tracktype`, `smoothness`, `mtb:scale` et les accès, un
   `track` « non revêtu » ne dit ni s'il roule ni s'il est ouvert.
2. **Combler les trous de cartographie par ce que les équipes ont roulé** (§7.4) : un chemin sans
   `surface` ni `tracktype` emprunté par des parcours gravel est **confirmé roulable** ; un chemin
   voisin du même way hérite de la confirmation. À l'inverse, un chemin que tout parcours gravel
   contourne est suspect.
3. **Une part cible, tenue.** La personne demande « environ 50 % de chemins » ; le coût des arêtes
   non revêtues reçoit un multiplicateur λ, cherché par dichotomie jusqu'à ce que la part obtenue
   soit dans la cible. Défaut : la médiane des parcours gravel (38 %) ; « plus de pistes » : le P90
   (49 %) et au-delà **(mesuré, §2)**.
4. **Des tronçons longs plutôt qu'un saupoudrage.** Le prétraitement repère les **chaînes
   off-road** : suites continues d'arêtes non revêtues roulables de plus d'un kilomètre (une allée
   forestière, un chemin de halage, une voie verte en stabilisé). Elles servent d'attracteurs au
   squelette, et chaque passage revêtu ↔ non revêtu coûte un peu : le parcours enchaîne les
   chemins au lieu d'alterner tous les 200 m.
5. **Bornes dures par type** : gravel, jamais au-delà d'une classe de roulabilité ni d'une pente
   non revêtue données ; VTT, `mtb:scale` plafonné ; jamais `access=private|no` ni `bicycle=no`.
   Les règles du plan d'équipe (§5.5) restent, étendues aux nouveaux attributs.

---

## 7. Données recalculées régulièrement depuis les parcours en base

Un travail planifié (nuit ou semaine), **idempotent** et qui réclame son travail en base (règle des
déploiements roulants), lit les `network_edges` déjà stockés et écrit des surcouches versionnées.
Il n'ajoute aucune requête au chemin d'une génération.

| # | Donnée | Calcul | Sert à |
|---|---|---|---|
| 7.1 | **Fréquentation par arête et par type** | Nombre de parcours distincts par arête ; existe déjà dans `NetworkGraphBuilder`, à sortir en surcouche | Curseur équipe ↔ découverte |
| 7.2 | **Goût appris par classe** | Pour chaque classe (catégorie de voie × revêtement × pente × balisage × trafic présumé) : part des kilomètres **roulés** / part des kilomètres **disponibles** dans un couloir autour des parcours. Au-dessus de 1, l'équipe cherche cette classe ; en dessous, elle l'évite | **Garder le goût de l'équipe sur des routes qu'elle n'a jamais prises** |
| 7.3 | **Formes** | Les mesures du §2, par équipe et par type | Tirage du squelette |
| 7.4 | **Roulabilité confirmée ou suspecte** | Chemins mal tagués empruntés (ou systématiquement contournés) par des parcours gravel et VTT | Off-road |
| 7.5 | **Destinations** | Points lointains des parcours, regroupés ; lieux et arrivées des sorties | Attracteurs |
| 7.6 | **Facteur de détour par zone** | Longueur / vol d'oiseau, par maille | Mise à l'échelle du squelette (question ouverte 5 de la recherche) |
| 7.7 | **Évitement** | Arêtes jamais prises alors que leurs deux voisines le sont souvent | Pénalité : la route que tout le monde contourne |

Le 7.2 est la pièce maîtresse. C'est une version simple de l'apprentissage de coût par les choix
observés ; une version plus fine (ajuster les poids pour que les parcours réels soient presque
optimaux) est possible ensuite, sur le même banc.

**Rattacher les `network_edges` au nouveau graphe.** Leurs nœuds sont des coordonnées z14, pas des
identifiants OSM. Deux voies : une jointure géométrique (nœud le plus proche à 2–3 m, la tolérance
que le constructeur applique déjà), ou réapparier les traces sur le nouveau graphe (§4.2,
convergence). La première suffit pour commencer.

**Cloisonnement.** Trois niveaux, du plus privé au plus général :

1. **l'équipe** : ses parcours, quelle que soit leur visibilité, pour ses seules propositions
   (règle actuelle) ;
2. **le domaine, agrégé** : uniquement des parcours publics, et une arête ou une classe n'est
   publiée que si au moins *k* équipes distinctes y contribuent. Sans ce seuil, une proposition
   révélerait où roule une équipe privée ;
3. **OSM seul**.

Le niveau 2 est une décision du propriétaire (§11.3) ; le niveau 1 et le 7.2 suffisent à tenir la
promesse sans lui.

---

## 8. Continuité avec le générateur d'équipe

| Aujourd'hui (`API-198`) | Proposé |
|---|---|
| Garantie dure « que des routes de l'équipe » | **Mode strict** du curseur. Les autres positions coûtent les arêtes hors réseau d'équipe, de plus en plus faiblement |
| Graphe d'équipe construit en mémoire, en cache Caffeine | Surcouche de fréquentation sur le graphe commun |
| Équipes de grands tours et petites équipes : 0 à 2 % de réussite | Les **raccords** entre leurs lignes viennent d'OSM : c'est le premier gain visible, avant même la découverte |
| Familles « deux chemins disjoints » et « polygone » | Squelette et chair (§5) ; les deux familles restent utilisables en mode strict |
| `RouteGuarantees`, oracle, banc sur données réelles | Inchangés, **arbitres** du nouveau moteur |
| Contrat `POST /api/teams/{teamSlug}/route-generator` | Même endpoint ; champs ajoutés (curseur de découverte, part de chemins, figure). Version mineure |

Un pont est possible sans attendre le moteur Rust : le service de graphe rend le **sous-graphe**
du disque de recherche, élagué (2-cœur, classes admises), et le générateur Java actuel tourne
dessus. C'est le chemin le plus court vers « des parcours hors du réseau de l'équipe », mais à
180 000 arêtes il dépasse le budget de temps actuel (2,5 s au médian pour 69 458) : valable pour
les boucles courtes, pas comme cible.

---

## 9. Alternatives regardées

| Option | Pour | Contre | Verdict |
|---|---|---|---|
| **GraphHopper** embarqué dans un service JVM | `round_trip`, `custom_model`, stockage `mmap`, repères ; mûr | L'import d'un pays demande beaucoup de mémoire (ordres de grandeur trouvés : 8 à 14 Go, non vérifiés pour la France en vélo) ; `round_trip` donne justement les formes rondes ; il faudrait écrire le squelette contre ses API internes | Bon **étalon** pour le banc (comparer aux mêmes départs), pas le socle |
| **BRouter** | Fichiers par dalle, mémoire minuscule, profils vélo, gravel et VTT très travaillés | Pas de boucle ; profils dans un langage à part ; service Java de plus | Source d'inspiration pour les coûts (recherche §5) |
| **Valhalla** auto-hébergé | Déjà connu | Retiré par `OPS-48` (17 Go, heures de reconstruction) ; pas de boucle | Non |
| **pgRouting** sur le PostGIS existant | Aucun service de plus | Charge la base de l'application (limite à 1 Go), recherche par requêtes SQL, pas d'état « arête orientée » ni de pénalité en cours de recherche | Non |
| **Sous-graphe rendu à la JVM** (§8) | Réutilise 8 000 lignes validées | Temps et tas | Pont, pas cible |
| **Moteur Rust sur fichier en cellules** | Mémoire bornée, vitesse, réutilise osm-route-details, portable en WASM | À écrire | **Recommandé** |

---

## 10. Plus loin

1. **Génération dans le navigateur.** Le cœur Rust compilé en WASM, les cellules servies comme des
   fichiers statiques (des « tuiles de routage », derrière Varnish), la surcouche d'équipe par une
   route authentifiée. Zéro CPU serveur, et surtout une génération **interactive** : on tire un
   point lointain sur la carte et la boucle suit. Limite : le poids des cellules pour 150 km sur un
   téléphone ; une résolution grossière pour le squelette et fine dans le couloir y répond. Même
   cœur dans l'app par FFI (`MOB-154`).
2. **Catalogue calculé la nuit.** Le cas visé est « départ toujours au même endroit » : pour
   chaque lieu d'équipe × type × tranche de distance × cap, quelques centaines de générations par
   nuit donnent des réponses immédiates, laissent le temps à des optimisations lentes, et
   permettent de proposer des parcours **différents de ceux que l'équipe a déjà**.
3. **Banc de vraisemblance.** Deux mesures que le banc actuel n'a pas : la distance entre la
   distribution des parcours générés et celle des vrais (r / D, compacité, sommets, classes de
   voies, virages au kilomètre) ; et la **reconstruction** — à partir du départ, de la distance et
   du cap d'un vrai parcours tenu à l'écart, quelle part de ses arêtes le générateur retrouve.
   C'est ce qui rend « organique » mesurable.
4. **D+ visé**, par le même multiplicateur que la part de chemins (§5.4).

---

## 11. Décisions du propriétaire (15 novembre 2026)

1. **OSM est réimporté**, sous la forme d'un extrait préparé hors ligne et d'un fichier lu par
   `mmap`, pas d'un routeur généraliste. Revient sur `OPS-48` et sur le §12 du plan d'équipe.
2. **Emprise : une région d'abord** (Pays de la Loire), pour mesurer avant d'engager la France.
   Les équipes hors région restent sur le générateur actuel en attendant.
3. **Promesse par défaut : l'équipe d'abord, OSM en raccord.** Les routes de l'équipe sont
   fortement préférées ; OSM sert à relier ses lignes pour fermer une boucle. Le mode strict et la
   découverte restent accessibles au curseur.
4. **Le moteur vit dans le dépôt osm-route-details** : nouveaux crates dans le même workspace.
5. **Pas d'agrégat entre équipes pour l'instant** (§7, niveau 2). Chaque équipe n'utilise que ses
   parcours, son goût appris par classe de route et OSM. À rouvrir avec des mesures.
6. **Le site (`WEB-179`) attend les raccords OSM** : il n'est pas mis en service sur le générateur
   strict seul.
7. **Ordre de livraison : des boucles pour tout le monde d'abord** (raccords OSM), puis les
   parcours organiques, puis l'off-road.
8. **Part de chemins : trois crans** (« Peu », « Comme d'habitude », « Beaucoup »), calés sur les
   déciles mesurés (environ 20 %, 38 %, 50 % et plus) ; le moteur vise une part précise derrière.
9. **Lot 0 engagé** le 15 novembre 2026.
10. **La recherche Java est retirée à parité.** Le générateur d'`API-198` est à considérer comme
    une preuve de concept : il n'est utilisé que par le propriétaire, pour essayer la génération.
    Sa recherche (`LoopFamily`, `PolygonFamily`, `EdgeDisjointPaths`, `NetworkGraphBuilder`,
    `TeamNetworkCache`) est retirée **quand le moteur Rust fait au moins aussi bien sur le même
    banc en mode strict**, pas avant ; le mode strict devient un filtre sur la surcouche de
    fréquentation. Restent en Java : droits, quota, limite de débit, contrat, travail planifié des
    surcouches, et `RouteGuarantees`, adapté pour vérifier la suite d'arêtes rendue par le moteur
    (identifiants, longueurs, caps, degré des nœuds) plutôt qu'un graphe Java. Un contrôleur dans
    un autre langage que le moteur reste un arbitre indépendant.

## 12. Lots

Ordre fixé par la décision 7.

| Lot | Contenu | Sortie mesurable |
|---|---|---|
| **0** | Extrait des Pays de la Loire → graphe de jonctions → fichier en cellules. Outil de mesure. Dépôt osm-route-details | Tailles réelles, temps de préparation, temps d'un Dijkstra sur un disque de 50 km. **Décide du reste** |
| **1** | Surcouche de fréquentation par équipe (§7.1), rattachée au graphe par jointure géométrique, depuis l'export du banc | Part des arêtes d'équipe retrouvées dans le graphe |
| **2** | Moteur, **raccords** : mode strict et « équipe d'abord », formes d'aujourd'hui ; contrôleur Java en arbitre | Banc du plan d'équipe rejoué : taux de réussite par équipe, temps ; parité en mode strict |
| **3** | Backend : appel du moteur, curseur, contrat, travail planifié des surcouches ; puis le site (`WEB-179`) | Tests de ressource, de requêtes, de cloisonnement ; e2e |
| **4** | **Organique** : goût appris (§7.2), squelette et chair, attracteurs | Vraisemblance (§10.3) : distributions, reconstruction |
| **5** | **Off-road** : attributs, chaînes, trois crans | Part obtenue contre part visée ; relecture de parcours gravel sur carte |
| **6** | France entière ; accélération (§4.4) si les mesures la demandent | Aller simple de 300 km dans le budget |
| **7** | Catalogue nocturne, WASM (§10) | — |

## 12 bis. Lot 0 : ce que les mesures ont donné (15 novembre 2026)

Fait dans osm-route-details, branche `feat/ord-graph` (crate `ord-graph`, outil `ord-graph-build`),
non commité. Rapport complet : `docs/design/technique/ord-graph-lot0-mesures.md` de ce dépôt.
Région : Pays de la Loire (PBF de 374 Mo). **Tout ce qui concerne la France est extrapolé.**

| Estimation de ce plan | Mesuré | Verdict |
|---|---|---|
| 216 m par arête (§3) | 100 m (91 m dans un disque de 50 km) | **Faux, d'un facteur 2,2.** Le réseau d'une équipe ne coupe une route que là où deux routes roulées se croisent ; le graphe complet la coupe à chaque allée, trottoir ou chemin. `service`, `residential` et `footway` font 54 % des arêtes |
| 180 000 arêtes dans un disque de 50 km (§4.3) | 378 000 (540 000 pour les disques entièrement dans la région) | **Faux, × 2 à 3.** La longueur de voies, elle, est juste : 36 000 km contre 39 000 |
| Un Dijkstra en quelques dizaines de ms (§4.3) | 111 ms au médian, 168 ms au P90, à chaud (96 ms sur tableaux plats) | **Faux, × 2 à 5**, à cause du nombre d'arêtes : le coût par état (0,13 µs) est celui attendu |
| 12 à 14 millions d'arêtes pour la France (§3) | environ 24 millions (22,6 à 28) | **Faux, × 1,7 à 2** |
| Environ 1 Go de fichier pour la France (§3) | environ 1,8 Go (topologie 0,97, géométrie 0,29, identifiants OSM 0,53) | Sous-estimé |
| 2,5 à 3 millions de km de voies en France | environ 2,4 à 2,5 millions | Confirmé |

Autres mesures : préparation de la région en 4,9 s, pic de 439 Mo (France : environ 4,8 Go
calculés, donc à faire sur un poste, pas sur le serveur) ; fichier de 125 Mo ; 75 Mo résidents
pendant une requête à 50 km.

**Ce que ça change.** L'architecture tient (fichier en cellules, `mmap`, mémoire résidente faible),
mais la cible de 500 ms par génération ne se tient pas sur le graphe complet : une dizaine d'arbres
à 111 ms fait plus d'une seconde. Deux corrections au plan, à concevoir au lot 2 :

- **Une vue par type, contractée hors ligne.** Le type « route » n'a besoin ni des trottoirs
  (16 % des arêtes), ni des allées et parkings (10,5 %), ni des chemins ; une fois ces arêtes
  retirées, les nœuds redevenus de degré 2 se fusionnent. Routes et pistes cyclables seules font
  145 m par arête. Le gain réel n'est pas mesuré.
- **Un état de recherche borné au disque.** L'état dense actuel est dimensionné sur tout le
  graphe : 40 Mo pour la région, environ 0,57 Go **par recherche** pour la France. La table de
  hachage bornée au disque tient en 24 Mo mais coûte 68 à 84 % de temps en plus ; un tableau dense
  local au disque (environ 9 Mo) n'a pas été essayé.

Réserves sur les mesures : un banc Java d'une autre session tournait pendant la plupart des
passes (0 à 19 % d'écart selon les passes) ; le poids de recherche est synthétique, sans coût de
virage ; huit disques seulement sont entièrement dans la région à 50 km, aucun à 75 km.

## 12 ter. Lots 0 bis et 1 : ce que les mesures ont donné (15 novembre 2026)

Dépôt osm-route-details, branche `feat/ord-graph`, commités, non poussés. Rapports :
`docs/design/technique/ord-graph-lot0bis-mesures.md` et `ord-graph-lot1-mesures.md` de ce dépôt.
Région : Pays de la Loire. Les équipes sont lettrées par kilomètres dans la région, lettrage propre
à ces rapports.

**Lot 0 bis : la cible de temps se tient sur une vue par type, pas sur le graphe complet.**

| Graphe | Arêtes | m par arête | Arêtes dans un disque de 50 km (médiane) | Un arbre à 50 km, médiane / P90 | Dix arbres à 50 km, médiane / P90 |
|---|---|---|---|---|---|
| Complet | 1 653 822 | 100 | 377 866 | 117 / 174 ms | 1 167 / 1 738 ms |
| Vue « route » | 589 715 | 162 | 128 413 | 26 / 39 ms | **257 / 393 ms** |
| Vue « route », impasses élaguées | 337 934 | 220 | 72 210 | 14 / 22 ms | 140 / 218 ms |
| Vue « gravel » | 893 341 | 161 | 190 191 | 42 / 68 ms | 418 / 677 ms |

- Une vue est le graphe filtré pour un type, dont les chaînes de nœuds de degré 2 sont fondues ;
  chaque arête de vue garde la liste des arêtes de base. Le contrôle compare chaque vue à une
  recherche sur le graphe filtré : aucun écart (4,8 millions de distances pour « route »).
- **L'état de recherche local au disque remplace les deux autres** : 4,5 Mo à 50 km sur la vue
  « route », 1,6 % plus lent que l'état dense, qui coûterait 0,2 à 0,57 Go par recherche pour la
  France.
- À 75 km de rayon, la vue « route » dépasse la cible (550 ms) ; la vue élaguée la tient
  (297 ms). L'élagage retire 22 % des kilomètres, dont de vraies routes en impasse, et déplace des
  départs jusqu'à 931 m : à réserver au cœur de la boucle, pas au départ. Non mesuré ainsi.
- **La marge est mince** : la vue lit un poids stocké, moins cher que le calcul du graphe complet.
  Au coût du graphe complet, la vue « route » ferait 379 ms au médian mais 562 ms au P90. Le vrai
  modèle de coût et le coût de virage peuvent la faire basculer.
- **La vue « route » perd des voies vertes** : 1 235 km de chemins `bicycle=designated`, dont
  603 km au revêtement connu ; elle ne garde que 62 % des kilomètres d'itinéraires cyclables
  nationaux. Et 70 % de ses kilomètres n'ont pas de tag `surface` : le revêtement y est présumé.
  À corriger au lot 2.
- France, extrapolé : vue « route » 8,2 millions d'arêtes et 0,84 Go ; « gravel » 13,3 millions
  et 1,32 Go.

**Lot 1 : la fréquentation des équipes se rattache au graphe OSM à 99 %.**

- 193 069 des 219 367 km-passages de l'export sont dans la région, pour 7 équipes sur 9. **Une
  équipe en fait 85,5 %**, deux 95,8 % : les conclusions valent pour elles.
- 99,22 % des kilomètres dans la région sont appariés à une chaîne d'arêtes OSM ; la surcouche
  compte 174 910 arêtes et 16 976 km, pour 1 Mo en tout. Calcul en 9 s.
- Précision : écart de Hausdorff de 0,64 m au P99 ; 0,75 km-passage seulement posé sur la mauvaise
  voie parallèle ; aucune arête comptée dans un sens fermé au vélo.
- Les 1 512 km non appariés : pour un tiers environ, l'appariement d'origine (sur les tuiles) a
  vraisemblablement pris la chaussée opposée d'une 2×2 — c'est une inférence ; 11 % au moins
  viennent de l'écart entre les tuiles et l'extrait OSM (route nouvelle, travaux) ; 20 % de la
  méthode, dont une partie récupérable.
- Verdict : **utilisable comme bonus sur le coût d'une arête, pas comme filtre dur sans
  précaution** — en mode strict, un trou de quelques dizaines de mètres à un carrefour coupe une
  route que l'équipe a bien roulée. Le lot 2 doit boucher ces trous courts.

## 12 quater. Lot 2 : le moteur en mode raccords (15 novembre 2026)

Dépôt osm-route-details, branche `feat/ord-graph`, commité, non poussé : crates `ord-loops`
(moteur) et `ord-loops-check` (contrôleur des garanties, écrit sans lire le moteur), outil
`ord-loops-bench`. Rapport : `docs/design/technique/ord-loops-lot2-mesures.md` de ce dépôt.
Campagne : les 323 requêtes du banc Java des équipes de la région (197 dont le disque est
entièrement dans la région), dans les trois modes. Équipes lettrées comme au §12 ter.

| Équipe | Requêtes | Java | Strict | Équipe d'abord | Découverte |
|---|---|---|---|---|---|
| A | 120 | 53 | 62 | 114 | 113 |
| B | 60 | 22 | 27 | 47 | 49 |
| C | 31 | 0 | 0 | 30 | 31 |
| D | 31 | 4 | 2 | 31 | 31 |
| E | 77 | 6 | 0 | 73 | 77 |
| F, G | 2 chacune | 0 | 0 | 2 | 2 |
| **Total** | **323** | **85** | **91** | **299** | **305** |

- **Garanties** : aucune violation relevée par le contrôleur indépendant sur 1 811 parcours.
- **« Équipe d'abord » fait ce qu'on en attendait** : 299 réussites sur 323, dont 215 des 238
  requêtes où Java ne rendait rien, et 50 sur 51 aux cinq départs où Java ne rendait jamais rien.
  La première proposition roule à 81 % sur les routes de l'équipe (médiane) et emprunte 11 km de
  route jamais roulée (42 km au P90).
- **Temps**, requêtes réussies jusqu'à 100 km : strict 67 ms au médian, équipe d'abord 163 ms
  (442 ms au P90), découverte 118 ms. Au-delà : équipe d'abord à 503 ms au médian pour 110 km,
  782 ms pour 150 km. La cible médiane tient jusqu'à 100 km ; le P90 n'a pas de marge.
- **Parité en mode strict : atteinte au total (91 contre 85), pas équipe par équipe.**
  - E (0 contre 6) : les six parcours Java sont signalés par l'oracle du banc Java lui-même pour
    un virage de 150° ou plus. En ne comptant que les réussites Java sans signalement, Java en a
    66 au total.
  - D (2 contre 4) : **question de règle, pas d'échec de recherche.** Java exempte un virage
    serré à un nœud qu'une trace de l'équipe traverse (`riddenThrough`) ; la surcouche ne garde
    pas l'identité des traces, donc l'exemption ne se recopie pas telle quelle. Décision du
    propriétaire (ci-dessous).
- **Écarts à la conception** : la famille « polygone », la pénalité de couloir sur le retour et la
  queue côté arrivée ne sont pas faites ; seuls le point de retournement et l'ordre inverse le
  sont. Une règle de pontage des jonctions courtes (30 m au plus entre deux nœuds d'équipe) a été
  ajoutée, dans le moteur et dans le contrôleur.
- **Non prouvé** : une seule région, une équipe qui fait 61 % des kilomètres ; aucun retour
  d'usage (une réussite = un parcours qui passe le contrôleur, pas un parcours qu'une équipe
  roulerait) ; les parcours Java ne sont comparés que sur leur issue, leur géométrie n'étant pas
  dans les résultats du banc.

**Décisions du propriétaire après le lot 2 (16 novembre 2026)** :

1. **La parité est atteinte.** Total, garanties et temps suffisent ; les pertes de l'équipe E
   étaient des parcours fautifs, celles de D (2 requêtes) sont acceptées en mode strict et
   réussissent en « équipe d'abord ». L'exemption `riddenThrough` de Java n'est pas recopiée. La
   recherche Java est donc retirée quand le backend appelle le moteur (§11.10).
2. **La surcouche d'une équipe est gardée en cache dans le moteur**, pas envoyée à chaque
   requête. Le service partagé détient alors des données privées de plusieurs environnements :
   l'isolement entre environnements, la purge et la suppression sont à concevoir au lot 3 et à
   relire côté sécurité.
3. **La surcouche est recalculée la nuit**, par un travail planifié du backend : un parcours
   enregistré aujourd'hui compte dans les propositions de demain.
4. **Contrat : un seul curseur**, de « routes de l'équipe » à « découverte », à la place de
   `familiarity`. Changement cassant, accepté : le générateur n'est utilisé que par le
   propriétaire. Le réglage « rarement ↔ souvent » disparaît.

**Lot 3, découpé en deux** : 3a dans osm-route-details (routes HTTP du moteur, cache des
surcouches cloisonné par environnement, appariement des `network_edges` dans le service), puis 3b
dans tribly (client, travail planifié, contrat, panneau web, retrait de la recherche Java).

**Choix de conception du lot 3a, à contredire si besoin** : le contrôleur indépendant
`ord-loops-check` tourne **dans le service**, sur chaque parcours avant la réponse ; le backend
Java ne refait qu'un contrôle géométrique simple (distance, continuité, départ et arrivée).
Cela s'écarte du §11.10, qui gardait `RouteGuarantees` en Java comme arbitre : depuis, un
contrôleur écrit sans lire le moteur existe côté Rust, et le refaire en Java demanderait de
renvoyer au backend de quoi reconstruire le graphe autour de chaque parcours. Conséquence :
`RouteGuarantees`, l'oracle et le banc Java partent avec la recherche Java au lot 3b, sauf avis
contraire. **Autre conséquence du retrait** : tant que le graphe ne couvre que les Pays de la
Loire, une équipe hors région n'a plus de générateur du tout.

## 12 quinquies. Lot 3b : le backend appelle le moteur (16 novembre 2026)

Note de conception et écarts : [`2026-11-16-generateur-parcours-osm-lot3b.md`](2026-11-16-generateur-parcours-osm-lot3b.md) ;
registre `API-206` et `OPS-60` (livrés), `WEB-179`, `SEC-52` (ouverts).

- **Fait** : `POST /api/teams/{teamSlug}/route-generator` appelle le moteur d'osm-route-details
  api 1.9 (`RouteGeneratorGateway`), droits, limite de débit et interrupteur du planificateur
  inchangés ; contrôle géométrique de chaque parcours rendu (§4 de la note) ; surcouche d'équipe
  déposée la nuit par `RouteGeneratorOverlayJob`, avec un déclencheur d'administration ; clé de
  cloisonnement `ROUTE_GENERATOR_NAMESPACE_KEY` par environnement ; la recherche Java,
  `RouteGuarantees`, l'oracle, le banc Java et le cache d'équipe sont retirés ; panneau du site
  adapté. `network_edges`, son rattrapage et la case « exclu du générateur » restent.
- **Défauts pris** (questions de la note, §12) : contrat `15.0.0` ; curseur `discovery` à
  0,25 par défaut, cinq crans au quart, 10 à 200 km ; D+ **calculé** avant la réponse (trois
  appels `fast` en parallèle, 2,5 s au plus, absent au-delà), sur les chiffres déjà relevés
  (génération 255 ms au médian, `fast` 76 ms à chaud) et non sur une mesure nouvelle ; passe à
  02:10 UTC, redépôt à 7 jours de l'expiration ; `GENERATOR_NETWORK_NOT_READY` affiche un message
  sans nouvel essai ; bouton gardé pour une équipe hors région ; planificateur coupé → surcouche
  effacée ; ni `allowed_namespaces` ni réseau chiffré pour l'instant (`SEC-52`) ; pas de bouton du
  déclencheur sur le site.
- **Fait le 16 novembre 2026**, dans l'ordre décidé ce jour-là (osm-route-details n'est fusionné
  et tagué qu'une fois tout validé) : tests backend verts (5 042) et essai de bout en bout sur un
  poste, fusion et tag `v1.9.0` d'osm-route-details, `route-generator.e2e.ts`, fusion de la
  branche dans `develop`, mise en service de la pile partagée avec le graphe (`OPS-60`). Détail :
  §18 de la note.
- **À ne pas refaire** : les migrations `V91` et `V93`, déjà livrées, ne se retouchent pas, même
  pour corriger un lien dans un commentaire : leur somme de contrôle Flyway changerait.

## 12 sexies. Lot 6 : la France entière (17 novembre 2026)

Conception et relevés dans osm-route-details : `docs/design/technique/ord-loops-lot6.md` et
`ord-loops-lot6-mesures.md` ; registre `API-207`, mise en service `OPS-61`.

- **Mesuré d'abord** : graphe de la France (extrait du 15 novembre 2026) de 18,4 millions de nœuds
  et 23,5 millions d'arêtes, 1,85 Go, construit en 80 s (pic 4,4 Go) ; vues « route » 8,0 millions
  d'arêtes (0,87 Go) et « gravel » 13,2 millions (1,43 Go). Les extrapolations du lot 0 bis
  tenaient. Le moteur 1.9.0, qui recopiait graphe et vues à plat, demandait 8 Go pour une requête
  et 15 Go en service : hors d'atteinte du conteneur de 2G.
- **Fait** (osm-route-details `1.9.1`, api 1.9 et formats de fichiers inchangés) : le graphe de
  base est lu dans le fichier projeté ; le moteur ne monte que la fenêtre de tuiles autour de la
  requête, renumérotée, dans un cache borné par un budget unique (800 Mo par défaut) ; les données
  d'une équipe se construisent autour de son seul réseau (65 Mo au pic pour la plus grosse, au lieu
  de 748) ; le contrôleur ne reconstruit plus ses tables à chaque requête.
- **Prouvé** : mêmes parcours que le moteur à plat sur les 969 requêtes du banc de la région (0
  différence, 0 violation) et sur 69 générations de la France par HTTP contre le service 1.9.0 ;
  service France en conteneur Docker de 2 Gio puis 1,5 Gio, 18 équipes sous deux clés : 1,10 Go
  d'anonyme au plus, aucun arrêt pour mémoire, aucun 503 ni 504 en série et à 4 clients ;
  démarrage en 8,5 s, fenêtre à froid sous 0,75 s, à chaud 2 à 4 % plus lent que le moteur à plat.
- **Pas prouvé** : l'altitude sollicitée dans le même conteneur ; un disque lent ; les distances
  au-delà de 200 km (le moteur est conçu jusqu'à 400, le contrat reste à 200) ; les derniers
  relevés en conteneur sont ceux de l'agent qui a codé, relus mais pas rejoués.
- **Décidé le 17 novembre 2026** : la limite du conteneur passe de 2G à 3G.
- **En service le 17 novembre 2026** (`OPS-61`) : graphe `fr-2026-11-15` sur le serveur, 13 équipes
  redéposées. Les deux déclencheurs lancés ensemble ont révélé un blocage du dépôt en file (le
  « 100 Continue » tardif, mal lu par le client HTTP du JDK), corrigé dans le moteur `1.9.2` ;
  reste `API-210` (connexion du verrou).
- **Reste au propriétaire** : le budget du générateur, et
  relever ou non la distance maximale.

## 12 septies. Lot 4 : goût appris et formes organiques (17 au 19 novembre 2026)

Conception et relevés dans osm-route-details : `docs/design/technique/ord-loops-lot4.md` (décisions §9.1 à §9.9) et
`ord-loops-lot4-mesures.md`, `-sonde.md`, `-sonde2.md`, `-3b-mesures.md`, `ord-loops-lot4c-sonde.md`,
`ord-loops-lot4c-mesures.md` ; registre `API-207`, mise en service `OPS-64`.

- **Mesuré d'abord (4a)** : un banc compare les formes et les classes de route des vraies boucles des équipes à
  celles du moteur 1.9.2. Les boucles générées étaient trop étirées et trop peu en triangle.
- **Goût (3b, 1.10)** : la première idée (« roulé contre disponible ») doublait les biais et a été abandonnée ; le
  goût retenu est **recalé** : par équipe, la part de chaque classe de route dans ses vraies boucles contre celle des
  boucles générées, en trois pas, appris au dépôt de la surcouche (au plus 500 boucles), dans un fichier chiffré à
  côté d'elle, plus une table commune à toutes les équipes (apprise sur 100 % des boucles). L'écart de classes au réel
  tombe à 0,24 au plus en route et 0,33 en gravel (1 = moteur 1.9.2). Réserve acceptée : la plus grande équipe en
  route faisait un peu moins bien que la table commune seule (+0,044), levée par les formes organiques.
- **Formes (4c, 1.11 puis 1.12)** : triangle (deux points lointains) en plus de la lentille, couloir qui écarte
  l'aller du retour, recherche des virages et des allers-retours alignée sur le contrôleur indépendant. L'écart au
  réel de l'écartement des boucles est divisé par 2,7 en route et 1,7 en gravel, la part de triangles passe de
  presque rien à 0,43–0,55 (réel 0,53 en route), 0 refus du contrôleur sur 20 280 parcours, goût inchangé.
- **Décidé le 19 novembre 2026** : le temps est accepté, médiane ×1,23 à ×1,38 du moteur 1.10 au banc (le temps à
  90 % est meilleur, ×0,95 à ×0,98) ; en conteneur de 3 Gio, 0,60 s à 4 clients et 0,30 s en série ; les formes
  organiques deviennent le défaut (osm-route-details `1.12.0`). Mémoire au pic : 1,50 Gio, profil le plus long 442 s.
- **Côté Pédalons** : rien à changer. Le backend n'envoie pas la forme, ignore les champs ajoutés et redépose toute
  surcouche `stale`. Au premier démarrage de 1.12, toutes les surcouches le deviennent (raison `profile`) et la table
  commune les sert jusqu'à la passe de la nuit.
- **En service le 20 novembre 2026** : la première passe de nuit redépose toutes les surcouches sans échec (`OPS-64`).
- **4d, attracteurs OSM (19 et 20 novembre 2026)** : cafés, boulangeries, points de vue, cols et sommets, lus dans un
  fichier par vue construit hors ligne (~10 Mo chacun), servent de points lointains organiques. L'effet est net mais
  dépasse le réel : en route, la part des points lointains près d'un commerce passe de 0,15 à 0,27–0,29, contre 0,20
  pour les vrais parcours. Sans la lentille, l'étape qui place le point lointain près de l'attracteur, l'effet devient
  trop faible. Aucun réglage ne tient tous les critères (commerce en gravel, formes, goût en route, temps au P90).
  **Décidé le 20 novembre 2026** : osm-route-details `1.13.0` est publiée avec les attracteurs `off`, fichiers posés
  (`OPS-65`), parcours identiques à la 1.12 ; les critères ne sont pas relâchés et le 4d s'arrête là.
- **Reste** : les lieux de l'équipe comme attracteurs, après le lot 4.

## 12 octies. Lot 5 : off-road (20 au 23 novembre 2026)

Conception et relevés dans osm-route-details : `docs/design/technique/ord-loops-lot5.md` (décisions du propriétaire
après le 5a et après le 5d, révision après le C4) et `ord-loops-lot5-mesures.md` ; registre `API-207`, contrat
`API-215`, site `WEB-197`, mise en service `OPS-67`.

- **Mesuré d'abord (5a)** : la part hors revêtement des vraies boucles gravel va de 0,26 (P10) à 0,61 (P90), médiane
  0,47. La page d'un parcours en montre environ 8 points de moins que le graphe du moteur : 12,6 % de la longueur n'a
  pas de classe de revêtement dans les tuiles (`API-214`, chantier à part). Le coût de passage entre chemins et routes
  (5e) est abandonné : les boucles générées enchaînent déjà plus que les vraies.
- **Une définition** : le moteur mesure le non-revêtu comme `/v1/route-details` (tag `surface`, puis `tracktype`, puis
  classe) ; chaque parcours rend `offroad_share`, mesuré par le contrôleur indépendant.
- **Consigne** : trois crans, « Peu » 0,25, « Comme d'habitude » 0,47, « Beaucoup » 0,60 (ramené de 0,65 : hors de
  portée pour la plupart des départs). Le moteur essaie au plus 4 multiplicateurs du coût du non-revêtu sur une grille
  de 0,25 à 2, mélange les candidats et rend les plus proches de la cible. Le premier essai est toujours la génération
  sans consigne : une consigne ne coûte ni 504 ni 422 que la requête sans elle n'aurait pas eu.
- **Bornes de roulabilité** (actives par défaut) : en gravel, ni revêtement très mauvais ou impraticable, ni piste de grade 5, ni boue, ni
  sentier VTT difficile ; en VTT, seulement les sentiers les plus durs exclus ; une arête que l'équipe a roulée reste
  permise, sauf impraticable. Au banc, plus aucune arête bornée n'est empruntée hors de cette exemption, pour un refus de plus sur 780
  requêtes.
- **Décidé le 23 novembre 2026** (après le 5d) : temps accepté jusqu'à × 5 au P90 par requête (médiane ≤ × 3) ;
  « Beaucoup » se juge sans les équipes dont les vraies boucles n'atteignent jamais 0,60 ; « Peu » au curseur de goût 1
  (63 à 68 % au lieu de 70) accepté ; la forme se juge au seul cran 0,47. Rejoué en conteneur de 3 Gio après la
  révision : aucun 504, 503 ni 422 de plus qu'en 1.14.0, P90 par requête × 2,4 à × 3,0 en série, mémoire au niveau de
  1.14.0.
- **Côté Pédalons** : contrat `16.3.0`, réglage « Chemins » du site, la consigne envoyée seulement si le moteur
  annonce le type, et redemandée sans elle si un moteur revenu en arrière la refuse. L'app ne l'envoie pas : sans
  réglage, gravel et VTT ont « Comme d'habitude ».
- **Reste** : un cran par équipe (R4, changement du format de profil), la couverture des tuiles (`API-214`).

## 13. Risques

- **La qualité d'OSM hors des routes roulées** : accès privés mal tagués, chemins disparus. Le
  générateur d'équipe n'avait pas ce risque, c'était sa force. Réponses : le curseur (défaut du côté
  équipe), les confirmations du §7.4, l'avertissement de l'éditeur, et l'exclusion manuelle déjà
  prévue.
- **Les estimations de taille** du §3 et du §4.3 portent toute l'architecture : le lot 0 les
  vérifie avant d'écrire le moteur.
- **Deux langages pour une fonction** : le contrôleur reste en Java, le moteur passe en Rust. Le
  contrat entre les deux doit porter les identifiants d'arêtes pour que le contrôleur vérifie sur
  le même graphe. *(Levé au lot 3a : le contrôleur indépendant tourne en Rust dans le service, le
  backend ne refait qu'un contrôle géométrique, §12 quater.)*
- **Le goût appris hérite des biais des données** : 2 445 parcours route, 912 gravel, 13 VTT.
  Le VTT n'a pas de quoi apprendre ; il part des réglages généraux.
- **Licence** : les données dérivées d'OSM restent sous ODbL ; l'attribution existe déjà pour les
  tuiles.
