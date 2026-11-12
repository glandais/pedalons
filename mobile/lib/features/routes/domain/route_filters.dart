import 'package:flutter/foundation.dart';

import '../../../api/generated/export.dart';

/// Upper bound of the distance slider, in meters. Beyond it the filter is
/// treated as "no maximum".
const double kRouteDistanceMaxMeters = 300000;

/// Step of the distance slider, in meters.
const double kRouteDistanceStepMeters = 5000;

/// Upper bound of the elevation-gain slider, in meters.
const double kRouteElevationMaxMeters = 5000;

/// Step of the elevation-gain slider, in meters.
const double kRouteElevationStepMeters = 50;

/// Sort defaults, mirroring `frontend/src/components/route/routeFilterDefaults.ts`.
const RouteSortBy kDefaultRouteSortBy = RouteSortBy.dateTime;
const SortDirection kDefaultRouteSortDir = SortDirection.desc;

/// Les trois rayons de « Autour de moi », en mètres. Trois et pas un curseur :
/// un rayon se choisit par ordre de grandeur, pas au kilomètre près.
const List<double> kRouteNearRadiiMeters = <double>[10000, 25000, 50000];

/// Rayon retenu quand la proximité s'arme sans choix explicite — celui de
/// l'API (`nearRadius` vaut 25 000 m par défaut).
const double kDefaultRouteNearRadiusMeters = 25000;

/// Les deux vues de l'écran 21 — la liste (en « Vignettes » ou en « Lignes »,
/// voir [RouteListDensity]) ou la carte. Un seul contrôle les offre toutes les
/// trois : « Vignettes · Lignes · Carte » (règle RL9 des listes, KIT §10).
///
/// **La vue n'est pas un filtre** : elle ne vit donc pas dans [RouteFilters],
/// qui est la clé de famille de la liste. La faire entrer ici rejouerait tout
/// le jeu de résultats à chaque bascule Liste ↔ Carte, alors que les deux vues
/// montrent *le même* jeu.
enum RouteViewMode { list, map }

/// Les deux densités de la vue Liste.
enum RouteListDensity {
  /// `RouteCard`, bandeau média de 208 px.
  cards,

  /// `CompactRouteRow`, ligne de 100 px — la vue « Lignes ».
  compact,
}

/// Au-delà de ce nombre de résultats, la liste bascule d'office en compact :
/// 2 585 vignettes de 208 px, c'est 40 écrans de défilement pour trouver un
/// parcours dont on connaît le nom.
const int kRouteCompactThreshold = 200;

/// A single filter dimension, used to label chips and to remove one filter at
/// a time.
enum RouteFilterField {
  search,
  distance,
  elevationGain,
  hilliness,
  surfaceType,
  windDirection,
  proximity,

  /// Tags `ROUTE` de l'équipe (ledger `MOB-39`) — seulement quand la portée
  /// est une équipe : le serveur ne filtre par tag que sur les listes d'une
  /// équipe (plan des tags, D7).
  tags,
}

/// Immutable identity of a route result set.
///
/// This doubles as the provider family key, which is what makes a filter
/// change produce a brand new list (reset + scroll to top) instead of merging
/// into the previous one.
///
/// Elle porte quatre familles de contraintes, et **la portée en fait partie** :
/// `teamSlug` et `minRole` changent la source des données autant que
/// `surfaceType` change son contenu, et les deux doivent produire une liste
/// neuve.
///
/// **Le compteur du bouton de filtres compte exactement ce que « Effacer les
/// filtres » lève** (règle RL4, KIT §10) : la recherche, chaque critère, les
/// tags, et la portée quand elle s'écarte de son défaut. Ni l'équipe de la
/// page, qui n'est pas un filtre, ni le tri.
@immutable
class RouteFilters {
  /// Portée — l'équipe interrogée, ou `null` pour toutes celles que
  /// l'utilisateur peut voir. Change l'endpoint, pas le filtre.
  final String? teamSlug;

  /// Portée — rôle minimum dans l'équipe propriétaire du parcours.
  final MinRole? minRole;

  /// La portée d'ouverture de la liste : « Membre » dans Explorer, ou
  /// « Toutes les équipes » pour qui n'a aucune équipe (règle RL1) ; nulle
  /// dans la section d'une équipe. « Effacer les filtres » y ramène [minRole].
  final MinRole? defaultMinRole;

  final String? search;

  /// Distances and elevations are in meters, like the API.
  final double? minDistance;
  final double? maxDistance;
  final double? minElevationGain;
  final double? maxElevationGain;

  final Hilliness? hilliness;
  final SurfaceType? surfaceType;
  final WindDirection? windDirection;

  /// Proximité — `nearLat` et `nearLon` vont toujours ensemble : une latitude
  /// seule n'est pas une position.
  final double? nearLat;
  final double? nearLon;
  final double? nearRadius;
  final NearType nearType;

  final RouteSortBy sortBy;
  final SortDirection sortDir;

  /// Tags `ROUTE` choisis, triés (`normalizeTagSelection`) ; un parcours sort
  /// s'il en porte **au moins un** (D6). Vide : pas de filtre.
  ///
  /// Les tags sont ceux d'**une** équipe : [copyWith] les lève dès que la
  /// portée change, et le dépôt ne les envoie qu'aux endpoints d'équipe.
  final List<String> tagIds;

  /// Ordre d'ajout des filtres, du plus ancien au plus récent.
  ///
  /// **Volontairement hors de [operator ==] et de [hashCode]** : deux jeux de
  /// filtres identiques posés dans un ordre différent désignent le même jeu de
  /// résultats et doivent partager le même notifier. Cet ordre ne sert qu'à
  /// départager deux filtres *à égalité* dans la règle de suggestion de l'état
  /// « cul-de-sac » (§3.1) — « à égalité, le plus récemment ajouté ».
  final List<RouteFilterField> addedOrder;

  const RouteFilters({
    this.teamSlug,
    this.minRole,
    this.defaultMinRole,
    this.search,
    this.minDistance,
    this.maxDistance,
    this.minElevationGain,
    this.maxElevationGain,
    this.hilliness,
    this.surfaceType,
    this.windDirection,
    this.nearLat,
    this.nearLon,
    this.nearRadius,
    this.nearType = NearType.startOrEnd,
    this.sortBy = kDefaultRouteSortBy,
    this.sortDir = kDefaultRouteSortDir,
    this.tagIds = const <String>[],
    this.addedOrder = const <RouteFilterField>[],
  });

  /// Vrai quand la position est renseignée — le seul cas où `nearLat` et
  /// `nearLon` partent à l'API.
  bool get hasProximity => nearLat != null && nearLon != null;

  double get effectiveNearRadius => nearRadius ?? kDefaultRouteNearRadiusMeters;

  /// Fields the user has actually constrained, in a stable order.
  ///
  /// Sorting is not a filter and never appears here ; la portée non plus, elle
  /// a son propre sélecteur — voir [scopeIsDefault].
  List<RouteFilterField> get activeFields => <RouteFilterField>[
    if (search != null && search!.isNotEmpty) RouteFilterField.search,
    if (minDistance != null || maxDistance != null) RouteFilterField.distance,
    if (minElevationGain != null || maxElevationGain != null)
      RouteFilterField.elevationGain,
    if (hilliness != null) RouteFilterField.hilliness,
    if (surfaceType != null) RouteFilterField.surfaceType,
    if (windDirection != null) RouteFilterField.windDirection,
    if (hasProximity) RouteFilterField.proximity,
    if (tagIds.isNotEmpty) RouteFilterField.tags,
  ];

  /// Vrai quand la portée est celle d'ouverture de la liste. L'équipe de la
  /// page ([teamSlug]) n'est pas une portée choisie : elle n'y entre pas.
  bool get scopeIsDefault => minRole == defaultMinRole;

  /// La pastille du bouton de filtres : **ce que [cleared] lève**, un par
  /// filtre — la recherche, chaque critère, les tags, la portée écartée de son
  /// défaut (règle RL4). Jamais au repos.
  int get activeCount => activeFields.length + (scopeIsDefault ? 0 : 1);

  bool get hasDefaultSort =>
      sortBy == kDefaultRouteSortBy && sortDir == kDefaultRouteSortDir;

  bool get isDefault =>
      activeFields.isEmpty && scopeIsDefault && hasDefaultSort;

  /// Les filtres actifs, du plus récemment ajouté au plus ancien.
  ///
  /// Départage la règle de suggestion du « cul-de-sac » quand deux filtres
  /// libèrent exactement le même nombre de résultats.
  List<RouteFilterField> get activeFieldsNewestFirst {
    final List<RouteFilterField> active = activeFields;
    final List<RouteFilterField> ordered = <RouteFilterField>[
      for (final RouteFilterField f in addedOrder.reversed)
        if (active.contains(f)) f,
    ];
    // Les champs jamais passés par `copyWith` (état restauré, filtre posé par
    // un lien) ferment la marche : on ne peut rien dire de leur ancienneté.
    for (final RouteFilterField f in active) {
      if (!ordered.contains(f)) ordered.add(f);
    }
    return ordered;
  }

  /// The filter most likely responsible for an empty result set, **sans appel
  /// réseau**.
  ///
  /// C'est le repli de la règle de §3.1 (celle qui interroge `count` avec
  /// chaque filtre levé et retient le plus généreux) : elle sert tant que les
  /// comptes ne sont pas revenus, et quand ils échouent.
  ///
  /// Ordered from narrowest to broadest. Search comes last because dropping
  /// the user's own words is the least helpful suggestion.
  RouteFilterField? get narrowestField {
    const List<RouteFilterField> priority = <RouteFilterField>[
      RouteFilterField.elevationGain,
      RouteFilterField.distance,
      RouteFilterField.proximity,
      RouteFilterField.windDirection,
      RouteFilterField.hilliness,
      RouteFilterField.surfaceType,
      RouteFilterField.tags,
      RouteFilterField.search,
    ];
    final Set<RouteFilterField> active = activeFields.toSet();
    for (final RouteFilterField field in priority) {
      if (active.contains(field)) return field;
    }
    return null;
  }

  /// A copy without [field], keeping everything else — including the sort and
  /// the scope.
  RouteFilters without(RouteFilterField field) {
    return switch (field) {
      RouteFilterField.search => copyWith(search: null),
      RouteFilterField.distance => copyWith(
        minDistance: null,
        maxDistance: null,
      ),
      RouteFilterField.elevationGain => copyWith(
        minElevationGain: null,
        maxElevationGain: null,
      ),
      RouteFilterField.hilliness => copyWith(hilliness: null),
      RouteFilterField.surfaceType => copyWith(surfaceType: null),
      RouteFilterField.windDirection => copyWith(windDirection: null),
      RouteFilterField.proximity => copyWith(
        nearLat: null,
        nearLon: null,
        nearRadius: null,
      ),
      RouteFilterField.tags => copyWith(tagIds: const <String>[]),
    };
  }

  /// « Effacer les filtres », dans la feuille comme dans le vide filtré
  /// (règle RL4) : la recherche, les critères et les tags levés, **la portée
  /// remise à son défaut**, le tri gardé — il n'est pas un filtre — et
  /// l'équipe de la page aussi.
  RouteFilters get cleared => RouteFilters(
    teamSlug: teamSlug,
    minRole: defaultMinRole,
    defaultMinRole: defaultMinRole,
    sortBy: sortBy,
    sortDir: sortDir,
  );

  /// [copyWith] clears a field when its argument is explicitly null, which is
  /// what filter removal needs. Pass only the fields you mean to change.
  RouteFilters copyWith({
    Object? teamSlug = _unset,
    Object? minRole = _unset,
    Object? search = _unset,
    Object? minDistance = _unset,
    Object? maxDistance = _unset,
    Object? minElevationGain = _unset,
    Object? maxElevationGain = _unset,
    Object? hilliness = _unset,
    Object? surfaceType = _unset,
    Object? windDirection = _unset,
    Object? nearLat = _unset,
    Object? nearLon = _unset,
    Object? nearRadius = _unset,
    NearType? nearType,
    RouteSortBy? sortBy,
    SortDirection? sortDir,
    List<String>? tagIds,
  }) {
    final String? nextTeamSlug = identical(teamSlug, _unset)
        ? this.teamSlug
        : teamSlug as String?;
    final RouteFilters next = RouteFilters(
      teamSlug: nextTeamSlug,
      minRole: identical(minRole, _unset) ? this.minRole : minRole as MinRole?,
      defaultMinRole: defaultMinRole,
      search: identical(search, _unset) ? this.search : search as String?,
      minDistance: identical(minDistance, _unset)
          ? this.minDistance
          : minDistance as double?,
      maxDistance: identical(maxDistance, _unset)
          ? this.maxDistance
          : maxDistance as double?,
      minElevationGain: identical(minElevationGain, _unset)
          ? this.minElevationGain
          : minElevationGain as double?,
      maxElevationGain: identical(maxElevationGain, _unset)
          ? this.maxElevationGain
          : maxElevationGain as double?,
      hilliness: identical(hilliness, _unset)
          ? this.hilliness
          : hilliness as Hilliness?,
      surfaceType: identical(surfaceType, _unset)
          ? this.surfaceType
          : surfaceType as SurfaceType?,
      windDirection: identical(windDirection, _unset)
          ? this.windDirection
          : windDirection as WindDirection?,
      nearLat: identical(nearLat, _unset) ? this.nearLat : nearLat as double?,
      nearLon: identical(nearLon, _unset) ? this.nearLon : nearLon as double?,
      nearRadius: identical(nearRadius, _unset)
          ? this.nearRadius
          : nearRadius as double?,
      nearType: nearType ?? this.nearType,
      sortBy: sortBy ?? this.sortBy,
      sortDir: sortDir ?? this.sortDir,
      // Changer d'équipe lève les tags : ceux d'une autre équipe ne
      // désignent rien ici, et le serveur les ignorerait en silence.
      tagIds:
          tagIds ??
          (nextTeamSlug == this.teamSlug ? this.tagIds : const <String>[]),
      addedOrder: addedOrder,
    );
    return next._withOrderFrom(this);
  }

  /// Rejoue l'ordre d'ajout : les champs devenus actifs passent en queue, ceux
  /// qui se sont éteints en sortent.
  RouteFilters _withOrderFrom(RouteFilters previous) {
    final Set<RouteFilterField> active = activeFields.toSet();
    final List<RouteFilterField> order = <RouteFilterField>[
      for (final RouteFilterField f in previous.addedOrder)
        if (active.contains(f)) f,
    ];
    for (final RouteFilterField f in activeFields) {
      if (!order.contains(f)) order.add(f);
    }
    if (listEquals(order, addedOrder)) return this;
    return RouteFilters(
      teamSlug: teamSlug,
      minRole: minRole,
      defaultMinRole: defaultMinRole,
      search: search,
      minDistance: minDistance,
      maxDistance: maxDistance,
      minElevationGain: minElevationGain,
      maxElevationGain: maxElevationGain,
      hilliness: hilliness,
      surfaceType: surfaceType,
      windDirection: windDirection,
      nearLat: nearLat,
      nearLon: nearLon,
      nearRadius: nearRadius,
      nearType: nearType,
      sortBy: sortBy,
      sortDir: sortDir,
      tagIds: tagIds,
      addedOrder: List<RouteFilterField>.unmodifiable(order),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteFilters &&
          other.teamSlug == teamSlug &&
          other.minRole == minRole &&
          other.defaultMinRole == defaultMinRole &&
          other.search == search &&
          other.minDistance == minDistance &&
          other.maxDistance == maxDistance &&
          other.minElevationGain == minElevationGain &&
          other.maxElevationGain == maxElevationGain &&
          other.hilliness == hilliness &&
          other.surfaceType == surfaceType &&
          other.windDirection == windDirection &&
          other.nearLat == nearLat &&
          other.nearLon == nearLon &&
          other.nearRadius == nearRadius &&
          other.nearType == nearType &&
          other.sortBy == sortBy &&
          other.sortDir == sortDir &&
          listEquals(other.tagIds, tagIds);

  @override
  int get hashCode => Object.hash(
    teamSlug,
    minRole,
    defaultMinRole,
    search,
    minDistance,
    maxDistance,
    minElevationGain,
    maxElevationGain,
    hilliness,
    surfaceType,
    windDirection,
    nearLat,
    nearLon,
    nearRadius,
    nearType,
    sortBy,
    sortDir,
    Object.hashAll(tagIds),
  );
}

const Object _unset = Object();
