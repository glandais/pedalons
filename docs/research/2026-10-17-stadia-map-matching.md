# Recalage Stadia Maps (`map_match/v1`) pour inverser un parcours : tests exploratoires

Essais du 17 octobre 2026, sur l'hôte européen de Stadia Maps. Contexte : plan `docs/plans/2026-10-17-editeur-parcours-web.md`, tâche B2, question Q6.
**37 requêtes consommées sur 40** : 29 `map_match/v1` et 8 `route/v1`.

Les essais ont porté sur des GPX réels du propriétaire (agglomération nantaise, côte atlantique, Mont Ventoux) et sur deux routes tracées avec le planificateur. Ces fichiers, les scripts d'essai et les réponses brutes **ne sont pas versés au dépôt**, qui est public : ils révéleraient des trajets personnels. Pour la même raison, ce document ne donne aucune coordonnée et décrit les lieux sans nommer les rues. Les noms entre accents graves (`city_rev`, `long_rev_gaps2`…) désignent les cas d'essai.

## En bref

- **Le recalage tel quel ne suffit pas.** Il donne, selon la densité des points envoyés, soit des **boucles et des demi-tours absurdes**, soit un **résultat discontinu** (plusieurs morceaux dans `alternates`). Sur 197 km, j'ai obtenu 11 morceaux.
- **Une chaîne en trois temps donne un résultat continu et propre** :
  1. un recalage `map_snap` d'une trace simplifiée ;
  2. une seule requête `route/v1` qui relie les morceaux entre eux ;
  3. un nettoyage géométrique local des boucles, sans requête.

  L'écart de distance avec la trace inversée brute devient **+0,1 % sur 73 km** (route du planificateur), +1,3 % sur 118 km et +1,2 à +2,6 % en centre-ville. Il ne reste aucun passage répété. Il faut donc compter 1 ou 2 requêtes, pas 1.

## 1. Endpoint et format

- **URL** : `POST https://api-eu.stadiamaps.com/map_match/v1`. C'est le `trace_route` de Valhalla.
  - Même authentification que le backend : en-tête `Authorization: Stadia-Auth <clé>`, jamais en paramètre d'URL.
  - Même `costing` que le routage : `bicycle` avec `costing_options.bicycle.bicycle_type`, repris de `RouterProfile`.
- **Corps testé** :
  ```json
  {"costing":"bicycle","costing_options":{"bicycle":{"bicycle_type":"hybrid"}},
   "shape_match":"map_snap","units":"kilometers","encoded_polyline":"<polyline6>"}
  ```
  - `shape: [{"lat":…,"lon":…}]` est aussi accepté (test `dups`), mais le corps est environ 15 fois plus gros.
  - La doc de Stadia annonce **la précision 6** en entrée et en sortie. Je l'ai vérifié en décodant les réponses : le décodeur `Polyline6Decoder` du backend convient.
- **`shape_match`** :
  - `edge_walk` échoue sur toute trace qui n'est pas une sortie Valhalla brute. Même sur une route Stadia simplifiée à 5 m, il renvoie HTTP 400 et l'erreur `443` « Exact route match algorithm failed ».
  - `walk_or_snap`, la valeur par défaut, retombe alors sur `map_snap`. Sur la trace inversée, sa réponse est **identique octet pour octet** à celle de `map_snap` (`city_rev` contre `city_rev_ws`).
  - → **Utiliser `map_snap` explicitement.**
- **`trace_options`** :
  - `turn_penalty_factor=500` n'a rien corrigé : la même boucle reste, et le résultat passe de +11,3 % à +8,5 % (`city_rev_tp`).
  - `max_route_distance_factor` et `max_route_time_factor`, à 20 ou à 100, donnent une réponse **identique octet pour octet** (`city_rev_d25_f20` et `_f100`). Soit Stadia les ignore ou les plafonne, soit ils ne sont pas la cause des coupures.
  - `search_radius` et `gps_accuracy` n'ont pas été testés : les traces du planificateur sont déjà sur le réseau.
- **Réponse** : la même que celle de `route/v1`.
  - `trip.legs[].shape` en polyline6, `trip.legs[].maneuvers`, `trip.summary.length` en km et `trip.locations`.
  - Plus **`alternates[].trip`** : *chaque discontinuité du recalage y renvoie un morceau supplémentaire*. Ce ne sont pas des variantes, c'est la suite de la trace.
  - Le type de manœuvre 13 signale un demi-tour.
  - La réponse est lourde : 300 Ko pour 197 km. `directions_type: "none"` devrait l'alléger, mais je ne l'ai pas testé.

## 2. Limites (mesurées : la doc de Stadia ne les publie pas pour le recalage)

| Limite | Mesure | Erreur au-delà |
|---|---|---|
| Points | **16 000** max (20 428 refusés) | HTTP 400, `error_code` **153** : « Too many shape points: (20428). The limit is 16000 » |
| Longueur | **200 km** max (197,2 km acceptés, 203,9 km refusés) | HTTP 400, `error_code` **154** : « Path distance exceeds the max distance limit: 200000 meters », le même code que `RouterService.ERROR_PATH_DISTANCE_EXCEEDED` |
| Espacement | deux points consécutifs à plus de 2 km sont traités comme un nouveau trajet (la doc l'annonce) | aucune erreur : un **morceau de plus** dans `alternates`. Vu sur `long_fwd` : un trou de 2 257 m a coupé la trace en deux |

- **Découpage** : il n'est nécessaire qu'au-delà de 200 km ou de 16 000 points. Sous 200 km, une trace simplifiée reste très loin de 16 000 points (567 points pour 73 km à 5 m).
- **Au-delà de 200 km** : découper en tronçons de 190 km au plus, avec un recouvrement d'environ 1 km. Recoller au premier point du recouvrement où les deux recalages coïncident (moins de 5 m), puis passer le même nettoyage des boucles. Ce recollage n'a pas été testé : le budget ne le permettait pas, et le refus à 200 km est net.
- **Avant l'envoi**, densifier tout segment de plus de 1 km . C'est sans effet ailleurs.

## 3. Fidélité dans le sens normal

| Trace | Points | Écart de distance | Hausdorff | Part à plus de 20 m | Remarque |
|---|---|---|---|---|---|
| Nantes, parcours de club, km 0 à 10 (1 point tous les 70 m environ) | 127 | +0,69 % | 4 m | 0 % | continu |
| Nantes, second parcours, km 0 à 10 (dense) | 414 | +0,01 % | 2 m | 0 % | continu |
| St Naz, 118 km | 875 | sans objet | 25 m | 0 % (0,03 % de la référence) | **2 morceaux** à cause du trou de 2,26 km |
| Ventoux, 53 km | 2 184 | sans objet | 1 m | 0 % | **2 morceaux** sur un chemin du versant de Malaucène que le profil vélo refuse |
| Boucle de 197 km | 2 477 | sans objet | 177 m | 12 % | **7 morceaux** : GPX non tracé avec Valhalla, chemins refusés au vélo |

Dans le sens normal, la fidélité géométrique est excellente : quelques mètres. En revanche, un GPX importé, qui n'a pas été tracé avec Valhalla, se coupe là où le réseau vélo de Valhalla ne passe pas. Une route du planificateur, elle, est par construction praticable dans son sens.

## 4. La trace inversée

### 4a. Le recalage brut

| Cas | Envoi | Morceaux | Écart de distance avec la trace inversée brute | Passages répétés (artefacts) | Demi-tours |
|---|---|---|---|---|---|
| `city_rev` Nantes, 10 km | 127 points | 1 | **+11,3 %** (+1,13 km) | 785 m | 1 |
| `city_rev_d25` (même trace densifiée à 25 m) | 457 points | **5** | sans objet | 0 | 0 |
| `plan_rev_dp5` route Stadia, 6,6 km, simplifiée à 5 m | 70 points | 1 | **+17,6 %** | 445 m | 1 |
| `plan_rev` même route, dense | 510 points | **5** | sans objet | 0 | 0 |
| `long_rev` St Naz, 118 km | 875 points | 5 | sans objet | 80 m | 0 |
| `long_rev_dp20` | 366 points | 4 | sans objet | 195 m | 1 |
| `lim_pts15k` (densifiée à 7,6 m) | 15 939 points | **13** | sans objet | 50 m | 0 |
| `mtn_rev` / `mtn_rev_dp5` Ventoux | 2 184 / 607 points | 3 | sans objet | 0 | 0 |
| `r200_rev` boucle de 197 km | 2 477 points | **11** | sans objet | 150 m | 1 |
| `plan2_rev_dp5` route Stadia, 73 km, simplifiée à 5 m | 567 points | 4 | sans objet | 230 m | 0 |

**Deux défauts, qui varient en sens opposés avec la densité de l'envoi.**

1. **Points espacés : boucles absurdes.** Le recalage doit « visiter » chaque point. Quand un point tombe sur une rue à sens unique dans le mauvais sens, il fait un tour de pâté de maisons pour y passer, parfois deux fois. Exemples, dans le centre de Nantes :
   - un quai, une rue et une place parcourus deux fois de suite : une boucle de 680 m autour d'une rue vraisemblablement à sens unique dans le sens de la trace inversée. Le détour légal est juste ; c'est sa répétition qui est absurde ;
   - les allées d'un parc : une boucle de 325 m parcourue deux fois ;
   - un pâté de maisons du centre historique fait deux fois ;
   - une boucle de 150 m entre un quai et une rue perpendiculaire ;
   - deux demi-tours (manœuvre de type 13) : l'un sur le quai de la première boucle, l'autre en fin de trace, où le dernier point tombe sur l'autre chaussée d'une voie à deux chaussées.
2. **Points denses : discontinuités.** Sur une rue interdite, chaque point est trop proche du suivant pour justifier un détour. Le recalage abandonne alors et coupe la trace : sa réponse contient des morceaux de 0 à 20 m et un trou. Exemples :
   - la même rue à sens unique, en 4 coupures ;
   - près de Saint-Nazaire, sur une route départementale à deux chaussées : une bretelle de sortie, un giratoire et la piste cyclable d'un giratoire ;
   - **sur la route du planificateur, aux points de contrôle eux-mêmes**, dont un à Savenay. Une ancre posée hors de l'axe produit un éperon, dont l'inverse n'est pas toujours légal.

Le recalage de Valhalla ne choisit donc pas « le plus court détour légal » de lui-même. Il le trouve si les points sont espacés, mais il le répète ; il y renonce si les points sont denses.

### 4b. La chaîne qui fonctionne (mesurée)

1. **Envoyer la trace inversée simplifiée** (Douglas-Peucker à 5 m, segments de plus de 1 km densifiés) en `map_snap`. C'est une requête.
2. **S'il y a des `alternates`** :
   - trier les morceaux le long de la trace et écarter ceux de moins de 50 m ;
   - rogner chaque bord de trou d'environ 100 m ;
   - relier les trous par **une seule** requête `route/v1` dont les locations sont `[fin₀, début₁, fin₁, début₂, …]`, en ne gardant que les legs pairs (0, 2, 4…), c'est-à-dire les trous. Cela fait au plus 24 trous par requête, à cause de la limite de 50 locations.
   - Sans rognage, les trous sont reliés de façon absurde : 8,6 km routés pour un trou de 287 m (`long_rev_gaps2`). Avec `heading` sur les locations, la requête échoue (HTTP 400, erreur 442 : aucun chemin).
3. **Supprimer les boucles, sans requête**. Quand le tracé repasse à moins de 6 m d'un point déjà parcouru, entre 30 m et 3 km plus loin, couper ce qui est entre les deux passages. Ne pas couper là où la trace brute passe elle-même deux fois. Le résultat reste légal : chaque moitié vient d'un chemin légal, et si les deux passages sont de sens opposés, la rue est à double sens.

| Résultat final | Morceaux | Écart de distance avec la trace inversée brute | Hausdorff | Passages répétés | Requêtes |
|---|---|---|---|---|---|
| `city_rev_final` Nantes, 10 km | 1 | **+1,2 %** (avant : +11,3 %) | 64 m | 0 | 1 |
| `plan_rev_final` route Stadia, 6,6 km | 1 | **+2,6 %** (avant : +17,6 %) | 79 m | 0 | 1 |
| `long_rev_final` 118 km | 1 | **+1,3 %** | 207 m | 0 | 2 |
| `plan2_rev_final` route Stadia, 73 km | 1 | **+0,1 %** | 356 m (voir les risques) | 0 | 2 |

Les écarts qui restent sont des détours plausibles :
- les rues voisines dans l'hypercentre de Nantes (16 % de la longueur à plus de 20 m, des écarts de 50 à 80 m) ;
- la chaussée opposée des voies à deux chaussées ;
- au plus 760 m d'écart autour des bretelles de la départementale près de Saint-Nazaire.

Un trou isolé peut coûter cher : 513 m en ligne droite ont été routés en 3,5 km sur la piste cyclable unidirectionnelle de cette départementale (`long_rev_gaps3`). C'est le plus court chemin légal pour les données OSM ; il faut l'accepter ou l'afficher.

## 5. Densité

- Simplifier aide plutôt que nuit. Sur une trace dense de Nantes inversée (second parcours), la référence étant la trace complète :
  - complète, 414 points : +0,71 %, Hausdorff 34 m, 0,4 % à plus de 20 m ;
  - **simplifiée à 5 m, 75 points : +0,97 %, 33 m, 0,4 %** ;
  - **simplifiée à 20 m, 31 points : +0,91 %, 33 m, 0,4 %**, p95 5,5 m.
- La densité est le facteur qui décide des coupures :
  - St Naz inversé : 4 morceaux à 20 m, 5 tel quel (875 points), 13 à 15 939 points ;
  - route du planificateur : 1 morceau à 5 m, contre 5 en dense.
- **Ne pas densifier**, sauf les segments de plus de 1 km. **Envoyer les points simplifiés à 5 m**, qui sont déjà ceux du planificateur. Les boucles que cela provoque se nettoient sans requête ; les coupures, elles, coûtent une requête. 20 m reste fidèle, mais 5 m garde mieux les points proches des petits carrefours.
- En dessous de 200 km, on reste très loin de la limite de 16 000 points.

## 6. Temps de réponse (aller-retour depuis le poste, hôte européen)

| Taille | Temps |
|---|---|
| 2 ou 3 points | 0,09 à 0,10 s |
| Environ 10 km, 30 à 450 points | 0,12 à 0,33 s |
| 53 km, 600 ou 2 200 points | 0,13 à 0,14 s |
| 73 km, 567 points | 0,37 s |
| 118 km, 366 ou 875 points | 0,33 à 0,51 s |
| 118 km, 15 939 points (59 Ko envoyés) | 0,44 s |
| 197 km, 2 477 points (réponse de 300 Ko) | 0,35 à 0,48 s |
| `route/v1` pour les trous | 0,10 à 0,15 s |
| Refus de limite (codes 153 et 154) | 0,11 à 0,14 s |

Le délai de lecture de 15 s du client `stadiamaps` est donc très large.

## 7. Erreurs et cas limites

- **Trace hors réseau** : 1 km de la trace `saz` décalé de 300 m dans les champs (`offnet`). Pas d'erreur : HTTP 200 et **2 morceaux**. La partie hors réseau est sautée (trou de 876 m). Le même mécanisme de raccord s'applique, mais l'écart avec la trace est alors réel : il faut avertir.
- **Trace très courte** : 2 points à 30 m l'un de l'autre. HTTP 200, 15 m recalés : la trace est raccourcie au réseau.
- **Points identiques** : 3 fois le même point. HTTP 200 et une longueur de 0. Le client doit traiter une longueur nulle comme un échec et se replier.
- **Points en double** : chaque point envoyé deux fois, au format `shape`. Résultat identique au cas sans doublon (+0,01 %, Hausdorff 2 m). Inoffensif, mais à dédoublonner quand même pour la taille.
- **`edge_walk`** sur une trace qui n'est pas une sortie Valhalla brute : HTTP 400, erreur `443`.
- **Non observés, mais à traiter comme dans `RouterService.toRoutingException`** :
  - les erreurs `171`, `442`, `444` (« Map Match algorithm failed ») et `445` → repli ;
  - 429 (quota) → `ROUTING_QUOTA_EXCEEDED` ;
  - 5xx → repli.

## Paramètres recommandés

- **Endpoint** : `POST {STADIAMAPS_URL}/map_match/v1`, sur l'hôte européen et avec la même authentification. Ce serait une seconde méthode de `StadiaMapsClient`, ou un client voisin.
- **Corps** : `costing` et `costing_options` repris du profil choisi, comme `RouterProfile.getCostingOptions()`, `shape_match: "map_snap"`, `encoded_polyline` en précision 6, `units: "kilometers"`. Pas de `trace_options` (sans effet mesuré). Essayer `directions_type: "none"` pour alléger la réponse (non testé).
- **Préparation** :
  1. inverser ;
  2. dédoublonner ;
  3. simplifier par Douglas-Peucker à 5 m, ce que fait déjà le planificateur ;
  4. densifier les segments de plus de 1 km ;
  5. refuser ou découper au-delà de 200 km (erreur 154) ;
  6. laisser au moins 2 points.
- **Post-traitement côté backend** :
  1. rassembler `trip` et `alternates` ;
  2. s'il y a plusieurs morceaux, écarter ceux de moins de 50 m, rogner 100 m de chaque côté des trous, puis faire une seule requête `route/v1` avec des legs alternés, sans `heading` ;
  3. supprimer les boucles : retour à moins de 6 m après 30 m à 3 km, en **ne coupant ni un passage que la trace brute fait deux fois, ni un point de contrôle** ;
  4. passer le résultat dans `GpxPipeline.process`, comme le routage ;
  5. ré-ancrer les points de contrôle sur le point le plus proche.
- **Repli sur la géométrie inversée brute, avec un avertissement** :
  - en cas d'erreur Stadia ;
  - si la longueur est nulle ;
  - si le raccord échoue ;
  - si le résultat dépasse la trace inversée de plus de 25 % par exemple (seuil à calibrer).
- **Coût** : 1 requête quand le résultat est continu (les deux cas urbains testés), 2 sinon. Sur les traces longues testées, c'était toujours 2.

## Risques

- **Points de contrôle** :
  - le nettoyage des boucles a supprimé un éperon de 950 m qui menait au point de contrôle de Savenay. C'est l'écart de 356 m de `plan2_rev_final`. Le nettoyage doit protéger les ancres, sinon le ré-ancrage tombe à côté ;
  - les ancres sont aussi les endroits où le recalage coupe le plus souvent.
- **Détours longs** sur les pistes cyclables unidirectionnelles et les bretelles (3,5 km pour 500 m). Ils sont légaux selon OSM mais surprennent l'auteur : il faut les signaler, par exemple en surlignant les écarts de plus de 50 m.
- **Paramètres sans effet** : `max_route_distance_factor`, `max_route_time_factor` et `turn_penalty_factor` ne règlent rien. Si Stadia change de version de Valhalla, les comportements de boucle et de coupure peuvent changer : garder un test e2e qui simule une réponse avec des `alternates` et une boucle.
- **Heuristiques** : le nettoyage des boucles et le rognage (seuils de 6 m, 30 m à 3 km, 100 m, 50 m) ont été calibrés sur 5 cas. Un parcours qui fait volontairement une petite boucle n'est protégé que si la trace brute passe deux fois au même endroit à moins de 8 m.
- **Limite de 200 km** : un aller-retour de plus de 200 km au total reste possible, puisque seul le retour est recalé. Une inversion de plus de 200 km demande en revanche le découpage, non testé.
- **Hors réseau et chemins non cartographiés** : la partie est sautée, pas suivie. Le raccord peut y inventer un itinéraire différent.
- **Taille des réponses** : jusqu'à 300 Ko avec les manœuvres ; à ne pas journaliser.
- **Quota** : 1 à 2 requêtes par inversion ou par aller-retour. Annuler et rétablir ne doivent pas en relancer.
