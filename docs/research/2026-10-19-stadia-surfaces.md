# Surface par point chez Stadia : essais du 19 octobre 2026 (C1 de WEB-100)

Essais réels contre l'API Stadia Maps (environ 140 appels, ~2 800 crédits), pour concevoir C1 du
[plan de l'éditeur de parcours](../plans/2026-10-17-editeur-parcours-web.md). Rapport anonymisé :
ni coordonnées, ni rues ; les traces GPX personnelles utilisées ne sont pas versées, et les parcours
sont désignés par leur type et leur longueur.

## 1. `/route/v1` ne porte pas la surface, mais `rough`

- La façade de Stadia valide le corps : `format: "pbf"` est refusé (`expected geojson, json, osrm`) ;
  `filters` et `attributes` sont ignorés sans erreur ; `format: "osrm"` et ses `annotations` ne
  renvoient aucune surface.
- Chaque `maneuver` porte `rough: true` (non revêtu : `compacted` et pire) avec
  `begin_shape_index` / `end_shape_index`. Comparé mètre par mètre à `trace_attributes` en
  `edge_walk` jambe par jambe :

  | Parcours | Accord | Signalé à tort | Non revêtu manqué |
  |---|---|---|---|
  | Gravel de moyenne montagne | 95,5 % | 4,5 % | 0 |
  | Route de montagne | 98,4 % | 1,6 % | 0 |
  | VTT en forêt | 99,2 % | 0,8 % | 0 |
  | Gravel de plaine | 100 % | 0 | 0 |
  | Ville | 100 % | 0 | 0 |

  `rough` vaut pour toute la manœuvre : il surestime un peu, ne rate jamais un passage non revêtu.

## 2. `trace_attributes/v1`

- **Clés d'arête renvoyées** : `surface`, `unpaved`, `road_class`, `use`, `cycle_lane`,
  `bicycle_network`, `sac_scale`, `tunnel`, `bridge`, `length` (km), `begin_shape_index`,
  `end_shape_index`, `way_id`, `names`, `speed`, `weighted_grade`, `lane_count`, `density`,
  `sidewalk`, `shoulder`, `traversability`, `max_upward_grade` / `max_downward_grade` (sans filtre).
  Racine : `shape` (polyline6), `matched_points` (`type`, `edge_index`, `distance_along_edge`,
  `distance_from_trace_point`), `osm_changeset`, `admins`, `confidence_score`.
- **Valeurs vues** : `surface` paved_smooth, paved, paved_rough, compacted, dirt, gravel, path ;
  `use` road, cycleway, track, path, footway, service_road, driveway, living_street,
  parking_aisle, steps, ramp, turn_channel, pedestrian_crossing ; `cycle_lane` none, shared,
  dedicated, separated.
- **`edge_walk` est inutilisable sur un tracé simplifié** (400, code 443), même sur des jambes
  brutes enchaînées : il faut **`map_snap`**.
- **`map_snap` sur le tracé enregistré** (simplifié à 3 m, ~1 point tous les 90 m), avec une
  projection des changements d'arête sur notre distance cumulée : accord avec la vérité jambe par
  jambe de 99,6 à 100 % (revêtu / non revêtu) et de 99,5 à 100 % (surface exacte) sur les cinq
  parcours ci-dessus.
- **Défaut** : `map_snap` insère un détour à chaque demi-tour sur un point de passage (+0,7 à
  +2,9 km mesurés) ; `type: break` n'y change rien. Une règle de tolérance le neutralise : quand la
  distance recalée entre deux points dépasse 1,2 × la distance réelle + 30 m, l'intervalle est coupé
  à mi-chemin, sans interpolation.
- **Traces réelles bruitées** (part de distance inconnue, costing vélo) : route de montagne 130 km,
  0 % ; col 89 km, 0 % ; montagne 111 km avec 2,2 km de tunnel, 0 % (tunnel bien recalé) ; gravel
  57 km, 0,8 % ; VTT 59 km, 0 % ; ville 24 km, 0 % ; sentier de montagne 21 km, 0,7 % ; randonnée
  12 km, 6,5 % (0,9 % en costing piéton) ; tunnel routier interdit aux vélos, 68,5 % (0 % en
  costing auto).
- **Hors réseau** : un éperon en ligne droite dans un champ sort `unmatched` (inconnu, correct) ;
  une ligne droite densifiée qui longe des chemins est faussement recalée sur eux. Les morceaux
  DIRECT de l'état doivent être forcés à « hors réseau ».
- **Costing** : `avoid_bad_surfaces: 1` rend les passages non revêtus `unmatched` (gravel 57 km :
  38,9 % inconnu au lieu de 0,8 %, non revêtu vu 11 % au lieu de 53 %) — à proscrire.
  `bicycle_type` road ou mountain : réponses identiques.
- **Limites** (non publiées, mesurées) : 16 000 points (16 100 → 400, code 153), 200 km (205 km →
  400, code 154). Un découpage en tranches avec 500 m de recouvrement donne 100 % d'accord avec un
  appel unique.
- **Erreurs** : 1 point → 400 code 123 ; en mer → 400 code 171 ; `map_snap` impossible → 400 code
  444 ; latitude invalide → code 154 (à tort) ; deux points identiques → 200 vide.
- **Latence** 0,09 à 0,5 s (0,23 à 0,33 s pour 130 à 195 km) ; réponses identiques octet pour octet
  sur 5 répétitions.
- **Taille** (130 km) : 1,36 Mo sans filtre ; 244 Ko (57 Ko en gzip) avec un filtre minimal
  (surface, indices, matched, shape) ; 342 Ko avec `use`, `road_class`, `cycle_lane`.
- **Tarif** (stadiamaps.com/pricing) : « Trace Attributes 20/req », comme le routage.

## 3. Stockage

Plages `[de, à, valeur]` en mètres, fusionnées, plages de moins de 20 m absorbées par leur voisine :
3 plages (78 o) pour la route de montagne de 130 km ; 103 plages (2,6 Ko) pour le VTT de 59 km, pire
cas ; 165 plages (7,3 Ko) en ajoutant `use` et `cycle_lane`.

## 4. Coût

20 crédits par tranche de 190 km, soit 20 pour la plupart des parcours (440 au plus pour 4 000 km).
Une séance d'édition de 30 à 100 gestes coûte déjà 600 à 2 000 crédits de routage : la surface y
ajoute 1 à 3 %. Rattrapage : 20 crédits par parcours existant.
