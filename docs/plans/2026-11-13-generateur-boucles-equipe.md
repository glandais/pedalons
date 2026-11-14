# Générateur de parcours sur le réseau d'une équipe

Écrit le 13 novembre 2026. **État : en cours. Décisions prises le 13 novembre 2026
(§10) ; lot 0 livré le même jour (osm-route-details api `1.7`, image `sha-9f0f16f`, puis api `1.8`, `sha-ce4ec11`) ;
lot 1 (`network_edges`, `V91`) et lot 2 (générateur pur, tests verts, relu) livrés le 14 novembre 2026 ;
restent les lots 3 et 4, et le banc sur données réelles.**
Ledger `API-198` (réseau et générateur, backend), `WEB-179` (site), `MOB-154` (app, plus tard).
Numéros renumérotés le 14 novembre 2026 après rebase (`API-196`, `MOB-153` et le contrat `14.12.0` pris entre-temps) ; contrat à `14.12.0`, dernière migration `V90`.

Chemins relatifs à `backend/src/main/java/fr/pedalons/` sauf mention contraire.

---

## 1. En une page

Une personne de l'équipe donne **un départ** (le lieu de l'équipe par défaut), **une arrivée** (le
départ par défaut, ou le café d'arrivée), **une direction** (huit caps ou « peu importe »), **une
distance** et **un curseur de fréquentation** (de « routes prises rarement » à « routes prises
souvent » par l'équipe). Pédalons propose trois parcours **faits uniquement de routes que l'équipe
a déjà dans ses parcours**, sans demi-tour, avec le moins possible de routes reprises en sens
inverse et de croisements. Elle en choisit un, l'ouvre dans l'éditeur, l'enregistre comme parcours.

Le cas d'usage visé (décision du 13 novembre 2026) n'est pas la boucle pure : **départ toujours
au même endroit, arrivée à un café pas très loin**, avec si besoin un même tronçon à l'aller et au
retour pour sortir de chez soi et y revenir. La boucle (arrivée = départ) et l'aller simple (arrivée
lointaine) sont deux cas du même calcul.

Ce qui rend la fonction faisable aujourd'hui alors que la recherche du 17 octobre
([`2026-10-17-generateur-boucles.md`](../research/2026-10-17-generateur-boucles.md)) la jugeait
bridée : **les parcours de l'équipe forment un graphe**, et ce graphe est petit. Les méthodes que
la recherche réservait à un graphe local (§7.4 : 2-cœur contre les impasses, chemins à arêtes
disjointes contre le réemprunt, liste noire d'arêtes) deviennent applicables **sans réimporter
OSM, sans héberger de routeur (OPS-48) et sans aucun appel Stadia**. Le graphe vient des parcours,
pas de la carte.

Trois morceaux :

| Morceau | Quoi | Taille |
|---|---|---|
| **Réseau** | Chaque trace d'équipe est appariée à des arêtes de rue identifiées ; l'union de ces arêtes est le réseau de l'équipe, avec sa fréquentation | M, plus une évolution d'osm-route-details |
| **Générateur** | Recherche de parcours sur ce réseau : contraintes dures (que des routes de l'équipe, pas de demi-tour, pas d'impasse), réemprunts et croisements bornés et pénalisés, notation, trois propositions variées | M |
| **Site** | Panneau « Générer un parcours » sur la page des parcours de l'équipe, carte des propositions, ouverture dans l'éditeur | M |

Volume mesuré le 13 novembre 2026 sur la base locale (migration biketeam) : l'équipe la plus
fournie a 2 656 parcours, 162 000 km de traces, 1,8 million de points (≈ 90 m entre deux points
de la géométrie simplifiée). Une fois les recouvrements fusionnés, le réseau est de l'ordre de
quelques milliers de km et de quelques dizaines de milliers d'arêtes : il tient en mémoire, et une
recherche s'y fait en millisecondes.

---

## 2. Ce que la fonction garantit

**Entrées** :
- départ S (point ; défaut le lieu de l'équipe) ;
- arrivée E (point ; défaut S) ;
- cap θ (N, NE… ou aucun), pris en compte seulement quand l'arrivée est proche du départ
  (|SE| < D/2) : au-delà, c'est l'axe S → E qui donne la direction ;
- distance D (10 à 300 km) ;
- fréquentation f ∈ [0, 1] : 0 = préférer les routes que l'équipe prend rarement, 1 = celles
  qu'elle prend souvent, 0,5 = indifférent (§5.2) ;
- le **type** : route, gravel ou VTT (§5.5), le `SurfaceType` déjà porté par chaque parcours
  (`Route.surfaceType`).

**Garanties dures** (une proposition qui en viole une n'est jamais rendue) :

1. **Que des routes de l'équipe** : chaque mètre du parcours est sur une arête du réseau.
2. **Pas de demi-tour** : à chaque jonction, le changement de cap entre l'arête d'arrivée et celle
   de départ reste sous 150° (caps mesurés à 30–50 m de la jonction, pour ignorer le dessin fin
   d'un carrefour). Pas de demi-tour au milieu d'une arête non plus : on ne quitte une arête que par
   son autre bout.
3. **Pas d'impasse** : on n'entre dans un cul-de-sac que s'il contient le départ ou l'arrivée.
   Ailleurs, en ressortir imposerait un demi-tour (point 2).
4. **Réemprunt borné** : une arête reprise (dans l'autre sens ou dans le même) ne l'est **que dans
   une « queue » collée au départ ou à l'arrivée** (le tronçon commun pour sortir de chez soi et y
   revenir), et cette queue fait au plus 15 % de D. Au milieu du parcours, aucun réemprunt : un
   aller-retour au milieu serait un épi.
5. **Croisements bornés** : le parcours repasse au plus deux fois par une jonction déjà franchie
   (figure en 8), hors queue.
6. **Distance à ±10 %** de D (la recherche rappelle qu'une longueur exacte est NP-difficile).

**Préférences notées** (§5.3) : longueur de queue et croisements les plus faibles possible
(idéalement zéro), direction respectée, fréquentation conforme à f, peu de jonctions, pas de
« couloir » parcouru deux fois (§5.2).

---

## 3. Le réseau : apparier les traces à des arêtes de rue

### 3.1 Option recommandée — les arêtes appariées par osm-route-details

osm-route-details apparie déjà chaque trace au réseau OSM par HMM (la chaîne d'osm-surface) pour
rendre la typologie, et **chaque parcours d'équipe passe déjà par lui** dans la file
`elevation_refresh` (mode `full`). Il ne rend aujourd'hui que des `segments[]` homogènes
(`RouteDetailsResponse.Segment` : bornes, revêtement, `way_kind`, `matched`), **sans identifiant
d'arête**. Demande à lui faire (dépôt séparé, même propriétaire) :

- une option `options.edges: true` qui ajoute `edges[]` : pour chaque arête du graphe de rues
  parcourue, dans l'ordre, ~~`way_id`~~ (impossible, voir plus bas), `from_node` et `to_node` (identifiants **stables d'une mise à
  jour des données à l'autre**, nœuds OSM de préférence), `from_index` / `to_index` et `from_m` /
  `to_m` sur la trace, `length_m`, `oneway`, la géométrie **recalée sur la rue** (polyligne) et
  les cumuls de D+ / D− aux deux bornes ;
- les arêtes coupées aux jonctions du graphe de rues, pas aux bornes des ways OSM (une way traverse
  plusieurs carrefours) ;
- `matched: false` conservé : un tronçon hors réseau n'entre pas dans le graphe.

**Ce qu'osm-route-details peut tenir (réponse du 13 novembre 2026, api `1.7`).** Ses tuiles
(VersaTiles shortbread z14) ne portent **aucun identifiant OSM** : pas de `way_id`, et les ways
sont fusionnées. Les nœuds ont donc un **identifiant géométrique** : la coordonnée du carrefour sur
la grille z14 / 4096 (≈ 0,5 m), stable tant que le nœud OSM ne bouge pas. Une arête est coupée
aux nœuds de degré ≠ 2 du graphe des voies ouvertes au vélo (`from_degree`, `to_degree`). Une
arête partielle dont le bout non atteint sort du couloir de 100 m autour de la trace a ce bout
`null`. Côté Pédalons, la construction du graphe **fusionne les nœuds à moins de 2–3 m**, ce qui
couvre les sommets fusionnés par la simplification comme une mise à jour des tuiles
(`data_versions.streets`). Une arête dont un bout est inconnu compte comme une impasse et sort du
cœur. Accord donné le même jour ; trois points demandés en retour : recoudre aux bords de tuiles,
un degré indépendant de la trace, un ordre et une géométrie dans le sens de parcours.

**Contrat livré et publié le 13 novembre 2026** (image `ghcr.io/glandais/osm-route-details:develop`, `sha-9f0f16f`, pas de tag `v1.7.0`). `options.edges`
(défaut `false`, en `fast` comme en `full`), `meta.api_version = "1.7"`, clé d'idempotence
inchangée. Par arête de `edges[]`, dans l'ordre de la trace : `from_m`/`to_m`,
`from_index`/`to_index` (mêmes règles que `segments[]`) ; `from_node`/`to_node` =
`{id: "z14:<x>:<y>", lat, lon, degree}` ou `null` hors du graphe lu, bouts de l'arête **complète**
dans le sens de parcours ; `partial`, `length_m` (null si un bout est inconnu), `traversed_m`,
`from_offset_m`/`to_offset_m` ; `oneway` `both|forward|against` ; `geometry` en polyligne Google
précision 6, recalée, dans le sens de parcours ; `from_/to_gain_cum_m`, `from_/to_loss_cum_m` ;
`structure`, `surface`, `way_kind` seulement s'ils sont homogènes. `segments[].unmatched_reason`
`closed_to_bicycles|off_network|no_data`. `capabilities.data.edges` annonce la grille, la
précision, `way_id: false` et `oneway_bicycle: false`. Les trois points demandés sont tenus et
testés : bords de tuile recousus (une tuile voisine non lue donne un bout `null`, pas une fausse
impasse), degré indépendant de la trace, ordre et sens. En plus : un aller-retour de moins de 5 m
au carrefour (débord de la projection HMM) est annulé, et un bout d'arête de moins de 5 m en tête
ou en queue est rattaché à sa voisine. Référence : `contract/openapi.json` et
`docs/design/02-contrat-interface.md` §4.3 bis du dépôt osm-route-details. C'est le lot 1 qui fait
la correspondance avec les records d'entrée du générateur (lot 2).

Ce que ça donne : une topologie **exacte** (deux traces qui passent au même carrefour partagent le
même nœud, quelle que soit la dérive GPS), une géométrie propre sur la rue pour le parcours rendu,
le revêtement et le D+ par arête, et **aucun appel de plus** : la réponse est celle que la file
demande déjà.

**Stockage.** Une colonne JSONB nullable `gpx_tracks.network_edges` (document versionné, compact :
nœuds, way, bornes, polyligne encodée par `PolylineCodec`), écrite par le worker
`elevation_refresh` avec le profil et le revêtement. Migration additive : l'ancienne release
l'ignore (déploiement roulant). Rattrapage par la file existante, comme le recalcul du parc du
7 novembre (`OPS-58`) ; à cadencer pour l'équipe à 2 656 parcours.

**Le graphe d'équipe** est construit à la demande, en mémoire, à partir des `network_edges` des
parcours non supprimés de l'équipe, et gardé en cache (Caffeine, clé équipe + révision du réseau =
max `updated_at` des traces et nombre de parcours). Par arête : géométrie, longueur, D+ dans
chaque sens, revêtement, **fréquentation** (nombre de parcours distincts qui l'empruntent) et sens
observés. Les nœuds de degré 2 sont contractés.

### 3.2 Repli — fusion géométrique dans la JVM

Si l'évolution d'osm-route-details n'est pas retenue : densifier chaque trace (~10 m), accrocher
incrémentalement chaque point au nœud existant le plus proche à moins de 20 m et de cap compatible,
détecter les jonctions par divergence des faisceaux, contracter. C'est le problème de « construction
de carte à partir de traces GPS » : faisable, mais fragile exactement là où le générateur a besoin
de certitude (routes parallèles, deux voies d'une 2×2, carrefours mal détectés qui créent de faux
demi-tours ou de fausses impasses), et la géométrie rendue reste celle d'une trace GPS. **Non
recommandé**, gardé comme plan B.

### 3.3 Ce qui alimente le réseau

Tous les parcours **non supprimés** de l'équipe, quelle que soit leur visibilité : le générateur
est réservé à qui peut créer un parcours dans l'équipe (§6), et le parcours rendu ne dit pas de quel
parcours vient une arête. Les parcours importés de biketeam sont des
parcours de l'équipe comme les autres et y entrent (2 656 pour l'équipe la plus fournie). Seuls les
GPX enregistrés joints aux sorties, s'il y en a, n'y entrent pas : ce sont des traces de personnes,
pas des parcours de l'équipe (§10.4).

---

## 4. Ce que le réseau ne sait pas

- **Les sens uniques** : les tuiles ne portent que le `oneway` général d'OSM, pas
  `oneway:bicycle=no`, donc les contresens cyclables sont inconnus. Une arête parcourue à contresens
  sort en `oneway: "against"` : c'est probablement un contresens cyclable. Règle retenue : une arête
  à sens unique n'est autorisée que dans le sens où l'équipe l'a déjà parcourue.
- **Les routes fermées au vélo** (réponse d'osm-route-details du 13 novembre 2026, vérifiée dans
  son code). Couvertes automatiquement : motorway, trunk et routes taguées `bicycle=no` (ou
  agricultural, forestry, psv, emergency, discouraged). Le HMM les garde comme candidates hors
  graphe ; une trace qui les suit y reste, et non sur la parallèle, et sort en `matched: false`
  avec `unmatched_reason: closed_to_bicycles` (api `1.7`). Elle ne produit aucune arête.
  **Non couvertes** : `access=no/private/destination`, `highway=construction` et tous les
  `*:conditional`, absents des tuiles. Une route privée ouverte pour un événement est vue comme une
  route ordinaire et entre au réseau. Le garde-fou est côté Pédalons : exclusion manuelle (§10.8).
- **Les arêtes rares** : une route prise une seule fois par un parcours de 2019 n'a pas le même
  statut qu'une route prise par 300. Le curseur f (§5.2) laisse choisir entre découvrir et rester
  sur les classiques ; pas de seuil dur.
- **Les travaux et fermetures** : rien. Le générateur ne propose que ce que l'équipe a roulé ;
  l'avertissement habituel de l'éditeur s'applique.

---

## 5. Le générateur

Classe pure, sans base ni CDI (`service/route/generator/`), testable sur des graphes construits à
la main. Entrée : graphe d'équipe, S, E, θ, D, f, préférences ; sortie : jusqu'à trois parcours.

### 5.1 Préparation

1. **Accroche** : S et E au nœud ou au point d'arête le plus proche, à moins de 2 km. Au-delà :
   `GENERATOR_START_TOO_FAR` (ou `…_END_…`).
2. **Ponts et composante** : on calcule les ponts (au sens des graphes : arêtes dont la coupure
   déconnecte) et les composantes 2-arête-connexes. Le milieu du parcours reste dans une composante
   (le 2-cœur de la recherche, son §4.4) : sans réemprunt, on ne traverse pas un pont deux fois.
   Les ponts ne servent qu'à la queue : le chemin de S (ou E) jusqu'à sa composante, s'il est sur
   une branche, est pris à l'aller et au retour et compte dans la queue (§2 point 4).
3. **Faisabilité** : si D < 1,05 × (plus court chemin S → E), `GENERATOR_DISTANCE_TOO_SHORT` ; si
   la composante fait moins de 1,5 × D de routes dans un rayon de D/2 autour de S et E,
   `GENERATOR_NETWORK_TOO_SMALL`, avec un message qui le dit.

### 5.2 Recherche de candidats

Le graphe est parcouru **par arêtes orientées** (état = arête et sens) : la contrainte de demi-tour
et les sens uniques se vérifient pendant la recherche, pas après. Deux familles, une centaine de
candidats en tout, chacune en quelques millisecondes :

- **Aller par un côté, revenir par l'autre** (Bhandari/Suurballe, recherche §4) : pour une série
  de nœuds de retournement T, deux chemins à arêtes disjointes T → S et T → E (un puits virtuel
  relié à S et E rend le calcul identique à celui de la boucle). T est choisi pour que
  d(S,T) + d(T,E) ≈ D et, quand θ compte, dans le cap θ ± 35°. Le demi-tour à T est vérifié et T
  écarté s'il y en a un.
- **Polygone sur le graphe** (GraphHopper `round_trip`, recherche §3, avec une **liste noire**) :
  deux ou trois sommets tirés entre S et E dans le cap θ, écart déduit de D et corrigé par la
  sécante sur les essais précédents ; chaque jambe est un plus court chemin qui **interdit** les
  arêtes déjà prises hors queue, et celles d'un même couloir (arêtes dont la géométrie court à
  moins de 25 m d'une arête prise sur plus de 200 m : les deux chaussées d'une 2×2, une piste le
  long de la route).

**La queue** : dans un rayon de 15 % de D autour de S et de E, le réemprunt est permis mais coûte
(pénalité croissante avec la longueur reprise) ; ailleurs il est interdit. Un nœud déjà franchi
coûte une pénalité de croisement.

**Le poids d'une arête** pendant la recherche :

  longueur × exp(β · (1 − 2f) · z) × (1 + pénalité de jonction) × pénalité de revêtement

où z ∈ [0, 1] est la fréquentation normalisée de l'arête (log du nombre de parcours qui la prennent,
rapporté au maximum de l'équipe). Avec f = 1, les arêtes fréquentées coûtent moins ; avec f = 0,
ce sont les rares ; avec f = 0,5 la fréquentation ne joue pas. β est réglé sur le banc (§9), comme
les pénalités.

### 5.3 Notation et choix

Un candidat qui viole une garantie du §2 est jeté. Les autres sont notés sur :

- l'écart de distance à D ;
- la longueur de la queue et le nombre de croisements (zéro visé) ;
- l'écart de direction quand θ compte : cap de S vers le **barycentre** du parcours, comparé à θ ;
- l'écart entre f et la fréquentation moyenne z le long du parcours (pondérée par la longueur) ;
- le nombre de jonctions par 10 km (un parcours lisible tourne peu) ;
- le recouvrement de couloir résiduel (f2 de la recherche).

On rend les trois meilleurs **différents entre eux** (moins de 50 % d'arêtes communes deux à
deux). Paramètre `seed` pour « Autres propositions », comme la graine de GraphHopper.

### 5.4 Le parcours rendu

Concaténation des géométries recalées des arêtes, dans le sens de parcours, D+ et D− sommés par
arête, revêtement par tronçon. Pas d'appel externe pour l'afficher ; le pipeline habituel
(route-details `full`) tourne quand la personne l'enregistre.

### 5.5 Route, gravel, VTT

Demandé le 13 novembre 2026. Deux sources par arête, toutes deux déjà là :

- **le type des parcours qui l'empruntent** : chaque parcours porte `Route.surfaceType`
  (`ROAD`, `GRAVEL`, `MTB`, `MIXED`). La fréquentation d'une arête est comptée **par type**
  (dans l'équipe la plus fournie : 2 018 parcours route, 635 gravel, 3 VTT, le 13 novembre 2026) ;
- **sa typologie OSM** dans `edges[]` (réponse d'osm-route-details du 13 novembre 2026, lue dans
  son code) :
  - `way_kind` : `major_road` (primary, secondary, tertiary), `minor_road` (unclassified,
    residential, living_street, service…), `track`, `path`, `cycleway`, `footway`, `steps`,
    `unknown` (motorway, trunk, pedestrian, bridleway sont hors du graphe vélo sauf `bicycle=yes`) ;
  - `surface.class` (`paved` | `unpaved` | `unknown`) et `surface.detail` : revêtus `asphalt`,
    `concrete`, `paving_stones`, `sett`, `cobblestone` ; non revêtus `compacted`, `fine_gravel`,
    `gravel`, `dirt`, `sand`, `grass`, `wood`, `rock`. `detail` n'existe que sur un tag brut
    (`source: tagged`) ; sinon la classe est **déduite** (`inferred_tracktype`,
    `inferred_highway`) et un `track` « unpaved » déduit ne dit rien de sa roulabilité ;
  - `tracktype`, et `bicycle` / `foot` normalisés (`yes` | `limited` | `no`, absents si non tagués) :
    lus dans les tuiles mais **non exposés en 1.7** ; ajoutés en api `1.8` (publiée le 13 novembre 2026, image
    `ghcr.io/glandais/osm-route-details:sha-ce4ec11`, `rules_version` inchangée) : `tracktype` `grade1`…`grade5`, `bicycle` et `foot`
    `yes` | `limited` | `no`, présents seulement si tagués et homogènes sur l'arête. Absent veut
    dire non tagué ou mélangé, **pas interdit**. Ni `smoothness`, ni `mtb:scale`, ni largeur : absents des tuiles.

Règles proposées (dures, puis préférences). « Prise par » = au moins un parcours non exclu de ce
type l'a empruntée :

| Type demandé | Arêtes admises | Préférences |
|---|---|---|
| **Route** | `major_road`, `minor_road`, `cycleway` revêtus ; revêtement inconnu ou `track` revêtu (`grade1`, `asphalt`…) seulement si prise par un parcours `ROAD`. Jamais `path`, `footway`, `steps` ni un non-revêtu, même pris par un parcours route (souvent une erreur de tracé ou un détour) | fréquentation des parcours `ROAD` et `MIXED` |
| **Gravel** | tout le réseau routier ; `track` et `cycleway` ; non-revêtu roulant (`compacted`, `fine_gravel`, `gravel`, `grade1`–`grade3` en 1.8) ; `path`, `footway`, `dirt`, `sand`, `grass`, `rock` seulement si prise par un parcours `GRAVEL` ou `MIXED`. Jamais `steps` | non-revêtu roulant favorisé (part de chemins réglée au banc) ; fréquentation `GRAVEL` et `MIXED`, puis `ROAD` |
| **VTT** | tout le réseau ; `steps` seulement si prise par un parcours `MTB` | non-revêtus et `path` nettement favorisés ; fréquentation `MTB`, puis `GRAVEL` |

Le curseur f (§5.2) s'applique à la fréquentation **du type demandé**. Quand le réseau de ce type
est trop maigre (les 3 parcours VTT ci-dessus), z retombe sur la fréquentation tous types
confondus, sans changer les arêtes admises, et la réponse le signale. La réponse donne aussi la
part de non-revêtu de chaque proposition (`unpavedShare`). Remplace l'option `surface` (`ROAD` |
`ANY`) des versions précédentes de ce plan.

---

## 6. Contrat

`POST /api/teams/{teamSlug}/route-generator` (version mineure, `14.13.0`) :

- **Requête** : `start` (lat, lon ; défaut le lieu de l'équipe), `end` (lat, lon ; défaut
  `start`), `bearing` (enum `N…NW`, nullable), `distanceKm`, `familiarity` (0 à 1, défaut 0,5),
  `type` (`ROAD` | `GRAVEL` | `MTB`, défaut `ROAD`), `seed`.
- **Réponse** : `candidates[]` : `polyline` (encodée), `distanceM`, `ascentM`, `descentM`,
  `bearingDeviationDeg` (null quand θ ne compte pas), `familiarity` (z moyen du parcours, 0 à 1),
  `unpavedShare`, `sharedM` (longueur de la queue), `crossings`, et le cadre de la carte ; `network` : km de routes de la composante, nombre de
  parcours pris en compte, `incomplete` si des parcours n'ont pas encore leurs `network_edges`.
- **Erreurs** : `GENERATOR_START_TOO_FAR`, `GENERATOR_END_TOO_FAR`,
  `GENERATOR_DISTANCE_TOO_SHORT`, `GENERATOR_NETWORK_TOO_SMALL`, `GENERATOR_NO_ROUTE` (rien dans
  la tolérance : le message propose une autre distance), `ROUTE_PLANNER_DISABLED`.
- **Droits** : `PlannerAccess.check(teamSlug)` — créer un parcours dans l'équipe et planificateur
  activé. **Pas** `checkRouting` : aucun fournisseur n'est appelé, rien n'est facturé. Une limite
  de débit par personne (calcul CPU) suffit.
- **Requêtes** : le graphe en cache, zéro requête par candidat ; une construction de graphe = une
  requête sur `gpx_tracks` de l'équipe. Un `…QueryCountTest` le fige.

Le parcours choisi devient un aperçu par `POST /api/gpx-previews/from-points` (existant), puis un
parcours par le chemin habituel : **l'enregistrement compte dans le quota d'enregistrements du
planificateur** comme un tracé (`PlannerQuota`, `BILL-10`), décision §10.3.

`POST /api/teams/{teamSlug}/route-generator` est le nom de l'endpoint pour les deux cas, boucle
et aller simple.

---

## 7. Site (`WEB-179`)

- Entrée : bouton « Générer un parcours » sur la page des parcours de l'équipe et dans le panneau
  d'ouverture de l'éditeur, visible si le planificateur est activé.
- Panneau : départ (lieu de l'équipe, ou clic sur la carte), arrivée (« Au départ » par défaut,
  ou clic sur la carte : le café), rose des vents à huit caps plus « Peu importe » (grisée quand
  l'arrivée est loin), curseur de distance, curseur « Routes prises rarement ↔ souvent par
  l'équipe », choix Route / Gravel / VTT (par défaut celui qui domine dans les parcours de
  l'équipe).
- Résultat : les trois parcours sur la carte, une couleur chacune, le réseau de l'équipe en fond
  pâle (pour comprendre pourquoi le parcours passe là), une fiche par parcours (distance, D+, fréquentation,
  tronçon commun aller-retour s'il y en a un), « Autres propositions ».
- « Ouvrir dans l'éditeur » charge le parcours **comme une ligne importée**, pas comme des ancres à
  router : rerouter par Stadia le ferait quitter les routes de l'équipe. La provenance des points
  (B12 du plan de l'éditeur) le permet déjà.
- Textes épicènes (BRANDING §8) : « Aucun parcours trouvé sur les routes de l'équipe pour 120 km.
  Essayez une autre distance ou un autre départ. »

## 8. Application (`MOB-154`, plus tard)

L'app n'a pas d'éditeur de parcours ni d'aperçus GPX. Un écran de génération qui crée directement
le parcours est possible ensuite ; hors périmètre de ce plan.

---

## 9. Tests

- **Générateur, en unitaire** (pas de base) : graphes à la main — une impasse au milieu d'une
  boucle, un pont entre deux composantes, une 2×2 (deux arêtes parallèles), un rond-point, un
  départ sur une branche (queue), une arrivée différente du départ, un sens unique observé dans un
  seul sens, f = 0 et f = 1 sur deux chemins de fréquentations opposées. Pour chaque proposition rendue,
  les garanties du §2 vérifiées par un contrôleur indépendant de la recherche.
- **Banc réel** : une commande (hors suite) qui tire 50 départs × 4 distances × 8 caps (boucles et arrivées à 3–15 km) sur le réseau
  d'une base migrée et sort taux de réussite, écart de distance et de cap, temps. Sert à régler β, les pénalités et
  les seuils, et à valider le §3.1 avant le site.
- **Backend** : construction du graphe à partir de `network_edges` fictifs, cache invalidé à
  l'enregistrement et à la suppression d'un parcours, droits (non-membre 404, planificateur coupé),
  nombre de requêtes. À lancer par le propriétaire (règle du dépôt).
- **Site** : Vitest sur le panneau ; un e2e qui génère sur une équipe semée de quelques parcours.

---

## 10. Décisions du propriétaire (13 novembre 2026)

1. **Source du réseau** : `edges[]` d'osm-route-details (§3.1), avec un identifiant de nœud
   géométrique puisque les tuiles n'ont pas d'identifiant OSM. La fusion géométrique (§3.2) reste un
   repli.
2. **Départ et arrivée** : pas seulement une boucle pure. Le cas visé est un départ fixe et une
   arrivée proche (le café). Un tronçon commun à l'aller et au retour pour partir et arriver est
   accepté. Ailleurs, éviter de reprendre une route en sens inverse et de se croiser trop souvent :
   bornés et pénalisés (§2 points 4 et 5), pas interdits partout.
3. **Quota** : l'enregistrement d'un parcours généré compte comme un tracé (`BILL-10`).
4. **Sources** : tous les parcours de l'équipe, ceux importés de biketeam compris (ce sont de vrais
   parcours). Pas les GPX enregistrés joints aux sorties.
5. **Aller simple A → B** : dans le premier lot, par le champ `end`.
6. **Fréquentation** : un curseur 0 à 1 (rarement ↔ souvent) en entrée, plutôt qu'un seuil.
7. **D+ cible** : pas au premier lot ; le D+ est affiché seulement.
9. **Type route / gravel / VTT** en entrée (§5.5), sur `Route.surfaceType` et la typologie OSM.
8. **Exclusion manuelle** : une case par parcours, « Ne pas utiliser pour générer des parcours »
   (`Route.excludedFromGenerator`, migration additive, champ du DTO de parcours), modifiable par qui
   peut modifier le parcours, à cocher sur les parcours d'événement (route privée ou fermée ouverte
   exceptionnellement). Ses arêtes sortent du réseau sauf si un autre parcours non exclu les prend.
   Le cache du graphe est invalidé quand la case change. Premier lot (lot 3 pour le backend, lot 4
   pour la case dans l'éditeur de parcours). L'exclusion d'un tronçon précis sur la carte reste
   pour plus tard.

## 11. Lots

| Lot | Contenu | Dépend de |
|---|---|---|
| **0** | `edges[]` dans osm-route-details (dépôt séparé) | décision 10.1 |
| **1** | `network_edges` : migration, client, écriture par le worker, rattrapage | 0 |
| **2** | Générateur pur + contrôleur + tests unitaires + banc | 1 (le banc) ; le code peut commencer avant sur des graphes à la main |
| **3** | Graphe d'équipe en cache, endpoint, case `excludedFromGenerator`, contrat `14.13.0` | 1, 2 |
| **4** | Site (panneau, case dans l'éditeur de parcours) | 3 |

## 12. Délibérément dehors

- **Importer OSM ou héberger un routeur** (pgRouting, GraphHopper) : la recherche §7.4 le
  posait comme seule voie vers des garanties ; le réseau d'équipe les donne sans revenir sur
  OPS-48. Un parcours qui sortirait des routes de l'équipe n'est pas l'objet de cette fonction.
- **Compléter par Stadia** quand le réseau est trop petit : mélangerait deux promesses (« routes
  de l'équipe » et « routes quelconques ») et coûterait des appels. Le message d'erreur le dit.
- **Réseau partagé entre équipes** ou entre domaines : les parcours d'une équipe ne nourrissent
  que ses propositions (cloisonnement par domaine et par équipe).
