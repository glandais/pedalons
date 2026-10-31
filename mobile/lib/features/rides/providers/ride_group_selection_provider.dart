import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../api/generated/export.dart';
import '../../../core/pdl/elevation/elevation_samples.dart';
import '../../routes/data/route_repository.dart';
import '../../routes/domain/route_elevation_builder.dart';
import '../../routes/domain/track_slope_colors.dart';
import '../../routes/domain/track_surfaces.dart';
import '../../routes/domain/track_wind_bars.dart';
import '../../routes/presentation/widgets/waypoint_selection.dart';
import '../domain/ride_route_layers.dart';
import '../domain/solo_group.dart';
import 'ride_detail_provider.dart';

/// Le parcours pointé quand **aucun groupe ne le roule** — le parcours
/// principal de la sortie, touché sur la carte.
///
/// La sélection de l'écran est un parcours : celui du groupe sélectionné, ou
/// celui-ci quand il est posé. Toucher un tracé que roule un groupe
/// sélectionne ce groupe (voir `groupForRoute`) et efface cette valeur ;
/// sélectionner un groupe l'efface aussi. Elle n'existe donc que pour la seule
/// couche sans groupe.
final selectedRideRouteOverrideProvider = StateProvider.autoDispose
    .family<String?, RideKey>((Ref ref, RideKey key) => null);

/// Les parcours décochés dans la feuille des couches, partagés par la carte
/// encastrée et son plein écran.
final hiddenRideRoutesProvider = StateProvider.autoDispose
    .family<Set<String>, RideKey>((Ref ref, RideKey key) => const <String>{});

/// Ce qui colore la carte d'un groupe — ou d'une sortie solo — et son
/// profil : Pente | Revêtement | Météo (ledger `MOB-105`, après `MOB-91`).
///
/// En mémoire, partagé par la carte encastrée, son plein écran et le profil,
/// et **sur la pente par défaut** : on ne change pas le sens des couleurs sans
/// que la personne l'ait choisi. Un mode indisponible se lit comme la pente
/// (`resolveRouteColorBy`) ; un refetch qui perd la prévision ramène le choix
/// « Météo » sur la pente (`RideGroupPage`, `RideDetailPage`), pour qu'une
/// prévision revenue ne recolore pas le tracé sans nouveau choix.
final rideMapColorModeProvider = StateProvider.autoDispose
    .family<RouteColorBy, RideKey>(
      (Ref ref, RideKey key) => RouteColorBy.grade,
    );

/// Ramène le choix « Météo » de [rideMapColorModeProvider] sur la pente — une
/// prévision perdue au refetch. Un autre choix (le revêtement) reste.
void dropWindMode(WidgetRef ref, RideKey key) {
  final StateController<RouteColorBy> mode = ref.read(
    rideMapColorModeProvider(key).notifier,
  );
  if (mode.state == RouteColorBy.wind) mode.state = RouteColorBy.grade;
}

/// Allume ([on]) le mode « Météo » de [rideMapColorModeProvider], ou le
/// ramène sur la pente ([dropWindMode]) : la puce et l'interrupteur de la
/// carte d'une sortie solo à deux parcours, qui n'a que « Météo » à basculer.
void setRideMapWindMode(WidgetRef ref, RideKey key, bool on) {
  if (on) {
    ref.read(rideMapColorModeProvider(key).notifier).state = RouteColorBy.wind;
  } else {
    dropWindMode(ref, key);
  }
}

/// Le groupe pointé, **un seul pour tout l'écran**.
///
/// Il pilote simultanément la carte de groupe sélectionnée, la pilule posée sur
/// la carte, l'entrée active de la légende, l'épaisseur et l'opacité des
/// tracés, et la source du profil altimétrique. Un état unique, parce que cinq
/// états séparés se désynchronisent au premier tap.
///
/// `null` signifie « pas encore choisi » : l'écran initialise à
/// `registeredGroupId ?? groups.first.id` une fois le détail chargé, ce qui
/// place d'emblée le lecteur sur *son* groupe.
final selectedRideGroupProvider = StateProvider.autoDispose
    .family<String?, RideKey>((Ref ref, RideKey key) => null);

/// Le groupe sélectionné de l'écran d'une sortie, valeur par défaut comprise :
/// le groupe unique d'une sortie solo, sinon le choix du lecteur, sinon *son*
/// groupe, sinon le premier.
///
/// [listen] à `false` hors d'un `build` — dans un callback, `ref.watch` est
/// interdit.
String? resolvedRideGroupId(
  WidgetRef ref,
  RideKey key,
  RideDto ride, {
  bool listen = true,
}) {
  final RideGroupDto? solo = soloGroupOf(ride);
  final String? chosen = listen
      ? ref.watch(selectedRideGroupProvider(key))
      : ref.read(selectedRideGroupProvider(key));
  return solo?.id ??
      chosen ??
      ride.registeredGroupId ??
      (ride.groups.isEmpty ? null : ride.groups.first.id);
}

/// Le parcours sélectionné de l'écran d'une sortie : celui touché sur la
/// carte quand aucun groupe ne le roule, sinon celui du groupe sélectionné,
/// sinon celui de la sortie.
String? resolvedRideRouteSlug(WidgetRef ref, RideKey key, RideDto ride) {
  final String? override = ref.watch(selectedRideRouteOverrideProvider(key));
  if (override != null) return override;
  final String? groupId = resolvedRideGroupId(ref, key, ride);
  for (final RideGroupDto g in ride.groups) {
    if (g.id == groupId) return effectiveRouteSlug(ride, g);
  }
  return ride.routeSlug;
}

/// Sélectionne un groupe — donc son parcours, dont la trace s'allume avec
/// celles des groupes qui le partagent.
void selectRideGroup(WidgetRef ref, RideKey key, String groupId) {
  ref.read(selectedRideRouteOverrideProvider(key).notifier).state = null;
  ref.read(selectedRideGroupProvider(key).notifier).state = groupId;
}

/// Sélectionne un parcours touché sur la carte. Le groupe sélectionné reste
/// s'il le roule ; sinon le premier groupe qui le roule le devient — la carte
/// de groupe allumée et les chiffres du profil suivent ainsi la trace. Le
/// parcours principal, que personne ne roule, se sélectionne seul.
void selectRideRoute(WidgetRef ref, RideKey key, RideDto ride, String slug) {
  final String? group = groupForRoute(
    ride,
    slug,
    current: resolvedRideGroupId(ref, key, ride, listen: false),
  );
  if (group != null) {
    selectRideGroup(ref, key, group);
  } else {
    ref.read(selectedRideRouteOverrideProvider(key).notifier).state = slug;
  }
}

/// Le point de parcours choisi sur l'écran d'une sortie (ledger `MOB-84`),
/// partagé par la carte des groupes, son plein écran et le profil du groupe
/// sélectionné. Un changement de groupe laisse une clé orpheline : la carte
/// l'ignore (clé absente) et la liste ne surligne rien.
final rideWaypointSelectionProvider = Provider.autoDispose
    .family<WaypointSelectionController, RideKey>((Ref ref, RideKey key) {
      final WaypointSelectionController controller =
          WaypointSelectionController();
      ref.onDispose(controller.dispose);
      return controller;
    });

/// Au-delà de ce nombre de parcours distincts, on n'en charge que les
/// premiers.
///
/// C'est le plafond serveur de `getRoutesBulk` (`RouteService.MAX_BULK_SLUGS`) :
/// sans lui, une sortie aux dizaines de groupes sur autant de parcours
/// distincts ferait 400 sur le lot et laisserait la carte vide. Une sortie
/// avec plus de cinquante parcours distincts est de toute façon pathologique
/// — le plafond est donc silencieux côté utilisateur, mais **journalisé**.
const int kRideRouteSlugCap = 50;

/// Les tracés d'une sortie, **dédoublonnés par `routeSlug`** et chargés en
/// **un seul appel groupé** au premier chargement.
///
/// Dix groupes partagent souvent trois parcours : sans déduplication (faite
/// par [distinctRouteSlugs]), le lot demanderait dix géométries pour trois
/// utiles. Et le lot lui-même remplace ce qui était encore N `getRoute` (un
/// par slug distinct) par une seule requête `getRoutesBulk`.
///
/// Le chargement ne dépend du détail de la sortie que pour calculer
/// [distinctRouteSlugs] — il n'est **pas** relancé quand le détail se
/// recharge sans que cet ensemble change (une inscription, un changement de
/// groupe, un échec réinvalident tous `rideDetailProvider`, mais ne changent
/// jamais les parcours des groupes). C'est le même principe que
/// `tripTracksProvider` : une file de slugs déjà demandés fait taire les
/// réémissions qui n'apportent rien de neuf.
///
/// Quand l'ensemble *change* vraiment (édition de la sortie), seuls les
/// nouveaux slugs repartent en requête — comme `tripTracksProvider`, les
/// géométries déjà connues restent dans l'état pendant que le complément se
/// charge, au lieu d'un `AsyncValue.loading()` sec qui viderait la carte
/// entière le temps du lot. Un slug qui sort de l'ensemble voulu est retiré
/// tout de suite, lui, sans attendre la fin du nouveau lot.
///
/// Le lot sert **aussi le profil altimétrique** de l'écran (voir
/// [rideRouteElevationProvider]) : les coordonnées portent l'altitude et le
/// cumul, il n'y a donc plus d'appel séparé pour lui.
final rideRouteGeometriesProvider = StateNotifierProvider.autoDispose
    .family<RideRouteGeometriesController, RideRouteGeometriesState, RideKey>((
      Ref ref,
      RideKey key,
    ) {
      final RideRouteGeometriesController controller =
          RideRouteGeometriesController(ref, key);
      ref.listen<AsyncValue<RideDto>>(rideDetailProvider(key), (
        AsyncValue<RideDto>? _,
        AsyncValue<RideDto> next,
      ) {
        final RideDto? ride = next.value;
        if (ride != null) controller.loadFor(ride);
      }, fireImmediately: true);
      return controller;
    });

/// Ce que la carte d'une sortie sait de ses tracés, à un instant donné.
///
/// Même forme que `TripTracksState` : une carte de géométries qui ne se
/// remplace jamais d'un coup, et un ensemble d'échecs séparé — un lot qui
/// omet un slug (inconnu, illisible) ou qui échoue tout entier rejoint
/// [failed] sans effacer ce qui était déjà chargé.
@immutable
class RideRouteGeometriesState {
  const RideRouteGeometriesState({
    this.geometries = const <String, RouteDetailDto>{},
    this.failed = const <String>{},
    this.extent,
  });

  /// Les géométries chargées, par `routeSlug`.
  final Map<String, RouteDetailDto> geometries;

  /// Les parcours dont l'appel a échoué, ou absents de la réponse groupée.
  final Set<String> failed;

  /// L'emprise servie par `RoutesBulkResponse.extent`.
  ///
  /// C'est **la** boîte de cadrage de la carte : la calculer sur les tracés
  /// obligerait à attendre que toutes les géométries soient là, et à
  /// reparcourir des milliers de sommets. Le serveur la donne déjà, et il la
  /// donne pour le lot entier — donc dès la première réponse, avant même que
  /// la carte ait un tracé à dessiner.
  ///
  /// Elle n'est retenue que quand le lot demandé couvre **tous** les parcours
  /// voulus, ce qui est le cas au premier affichage. Un lot complémentaire —
  /// des groupes qui changent de parcours pendant qu'on regarde — porte
  /// l'emprise de ce seul complément : la garder rétrécirait le cadrage sur
  /// une partie des tracés, alors que l'emprise déjà connue reste juste pour
  /// ceux qu'on affiche.
  final BoundsDto? extent;

  RideRouteGeometriesState copyWith({
    Map<String, RouteDetailDto>? geometries,
    Set<String>? failed,
    BoundsDto? extent,
  }) => RideRouteGeometriesState(
    geometries: geometries ?? this.geometries,
    failed: failed ?? this.failed,
    extent: extent ?? this.extent,
  );
}

class RideRouteGeometriesController
    extends StateNotifier<RideRouteGeometriesState> {
  RideRouteGeometriesController(this._ref, this._key)
    : super(const RideRouteGeometriesState());

  final Ref _ref;
  final RideKey _key;

  /// L'ensemble de slugs de la dernière requête envoyée — `null` avant la
  /// première. Comparé à chaque appel de [loadFor] : un ensemble inchangé
  /// n'émet aucune nouvelle requête, même si `rideDetailProvider` vient de
  /// réémettre (voir la note de tête du fichier).
  Set<String>? _requestedSlugs;

  void loadFor(RideDto ride) {
    List<String> slugs = distinctRouteSlugs(ride);
    if (slugs.length > kRideRouteSlugCap) {
      developer.log(
        'Sortie ${_key.rideSlug} : ${slugs.length} parcours distincts, '
        'plafonné à $kRideRouteSlugCap',
        name: 'rides.geometries',
      );
      slugs = slugs.take(kRideRouteSlugCap).toList();
    }

    final Set<String> wanted = slugs.toSet();
    if (_requestedSlugs != null && setEquals(_requestedSlugs, wanted)) {
      return;
    }
    _requestedSlugs = wanted;

    // Les slugs qui sortent de l'ensemble voulu sont retirés tout de suite —
    // ils n'ont aucune raison de survivre le temps du prochain lot.
    state = RideRouteGeometriesState(
      extent: state.extent,
      geometries: Map<String, RouteDetailDto>.fromEntries(
        state.geometries.entries.where(
          (MapEntry<String, RouteDetailDto> e) => wanted.contains(e.key),
        ),
      ),
      failed: state.failed.where(wanted.contains).toSet(),
    );

    // Seuls les slugs pas encore connus repartent en requête : un slug déjà
    // chargé reste affiché tel quel, il n'a pas besoin d'être retéléchargé
    // parce que d'autres groupes ont changé de parcours.
    final List<String> todo = slugs
        .where((String slug) => !state.geometries.containsKey(slug))
        .toList();
    if (todo.isEmpty) return;
    unawaited(_load(todo, full: todo.length == slugs.length));
  }

  /// Charge [slugs] en un appel groupé et fusionne le résultat dans l'état
  /// existant, sans jamais le remplacer — c'est ce qui garde à l'écran les
  /// tracés déjà connus pendant que ceux-ci se chargent.
  Future<void> _load(List<String> slugs, {required bool full}) async {
    try {
      final RoutesBulkResponse response = await _ref
          .read(routeRepositoryProvider)
          .getRoutesBulk(_key.teamSlug, slugs);
      if (!mounted) return;
      final Map<String, RouteDetailDto> loaded = <String, RouteDetailDto>{
        for (final RouteDetailDto route in response.routes) route.slug: route,
      };
      final Set<String> missing = slugs
          .where((String slug) => !loaded.containsKey(slug))
          .toSet();
      state = state.copyWith(
        geometries: <String, RouteDetailDto>{...state.geometries, ...loaded},
        failed: <String>{...state.failed, ...missing},
        extent: full ? response.extent : state.extent,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(failed: <String>{...state.failed, ...slugs});
    }
  }
}

/// Le tracé d'**un** parcours d'une sortie — lu dans le lot chargé par
/// [rideRouteGeometriesProvider], jamais par un appel séparé.
///
/// Conservé comme point d'entrée par slug pour les consommateurs (la carte de
/// groupes, qui a besoin d'observer chaque parcours indépendamment) : c'est le
/// lot sous-jacent qui est partagé et dédoublonné, pas cette façade.
final rideRouteGeometryProvider =
    Provider.family<AsyncValue<RouteDetailDto>, RouteRef>((
      Ref ref,
      RouteRef route,
    ) {
      final RideRouteGeometriesState state = ref.watch(
        rideRouteGeometriesProvider(
          RideKey(teamSlug: route.teamSlug, rideSlug: route.rideSlug),
        ),
      );
      final RouteDetailDto? found = state.geometries[route.routeSlug];
      if (found != null) return AsyncValue<RouteDetailDto>.data(found);
      if (state.failed.contains(route.routeSlug)) {
        // Absent du lot : slug inconnu, ou illisible par l'appelant (le lot
        // ne fait jamais 404 pour ça — il omet). Une erreur ici reproduit ce
        // qu'aurait fait un `getRoute` individuel en échec : la carte omet
        // ce tracé plutôt que de planter.
        return AsyncValue<RouteDetailDto>.error(
          StateError(
            'Route ${route.routeSlug} absente de la réponse groupée '
            'pour la sortie ${route.rideSlug}',
          ),
          StackTrace.current,
        );
      }
      // Ni chargé ni en échec : la requête qui le couvre est en vol.
      return const AsyncValue<RouteDetailDto>.loading();
    }, isAutoDispose: true);

/// Le profil altimétrique d'un parcours de la sortie, **prêt à peindre**.
///
/// Dérivé du lot déjà chargé pour la carte : cet écran ne fait plus d'appel
/// réseau pour son profil. Il en faisait un — l'ancien endpoint dédié — pour
/// une donnée que `rideRouteGeometryProvider` avait déjà en mémoire, la
/// géométrie portant l'altitude et le cumul sur chacune de ses coordonnées.
///
/// L'agrégation est mémorisée ici et pas dans un `build` : le painter compare
/// les échantillons **par identité**, un objet neuf à chaque frame le ferait
/// repeindre pour rien.
final rideRouteElevationProvider =
    Provider.family<AsyncValue<ElevationSamples?>, RouteRef>((
      Ref ref,
      RouteRef route,
    ) {
      return ref
          .watch(rideRouteGeometryProvider(route))
          .whenData((RouteDetailDto detail) => detail.elevationSamples());
    }, isAutoDispose: true);

/// La classe de revêtement de chaque barre du profil d'un parcours de la sortie
/// (`MOB-81`), **mémorisée** avec le profil : le painter compare ses couleurs
/// par identité, jamais de calcul dans un `build`.
///
/// `null` sans revêtement prêt ou sans profil.
final rideRouteSurfaceBarsProvider =
    Provider.family<AsyncValue<List<TrackSurface?>?>, RouteRef>((
      Ref ref,
      RouteRef route,
    ) {
      final AsyncValue<RouteDetailDto> detail = ref.watch(
        rideRouteGeometryProvider(route),
      );
      final AsyncValue<ElevationSamples?> samples = ref.watch(
        rideRouteElevationProvider(route),
      );
      return detail.whenData((RouteDetailDto d) {
        final ElevationSamples? s = samples.value;
        if (s == null || !hasTrackSurfaces(d.tracks)) return null;
        return barSurfaces(s, d.tracks);
      });
    }, isAutoDispose: true);

/// Un parcours d'une sortie donnée — la clé de cache des géométries.
class RouteRef {
  const RouteRef({
    required this.teamSlug,
    required this.rideSlug,
    required this.routeSlug,
  });

  final String teamSlug;
  final String rideSlug;
  final String routeSlug;

  @override
  bool operator ==(Object other) =>
      other is RouteRef &&
      other.teamSlug == teamSlug &&
      other.rideSlug == rideSlug &&
      other.routeSlug == routeSlug;

  @override
  int get hashCode => Object.hash(teamSlug, rideSlug, routeSlug);

  @override
  String toString() => 'RouteRef($teamSlug/$rideSlug/$routeSlug)';
}

/// Les `routeSlug` distincts d'une sortie : celui de la sortie d'abord, puis
/// ceux des groupes dans leur ordre — l'ordre des couches de la carte
/// ([rideRouteLayers]).
///
/// Le parcours de la sortie elle-même sert de repli aux groupes qui n'en
/// portent pas : c'est la même règle que le bouton « Voir le parcours ». Il
/// est demandé même quand tous les groupes ont le leur : la carte lui garde
/// sa couche (« Parcours principal »).
List<String> distinctRouteSlugs(RideDto ride) => <String>[
  for (final RideRouteLayer layer in rideRouteLayers(ride)) layer.routeSlug,
];

/// La pente des montées sous chaque barre du profil d'un parcours de la
/// sortie, et sa couleur (ledger `MOB-105`), **mémorisées** avec le profil.
///
/// `null` sans profil.
final rideRouteClimbBarsProvider =
    Provider.family<AsyncValue<ClimbBars?>, RouteRef>((
      Ref ref,
      RouteRef route,
    ) {
      final AsyncValue<RouteDetailDto> detail = ref.watch(
        rideRouteGeometryProvider(route),
      );
      final AsyncValue<ElevationSamples?> samples = ref.watch(
        rideRouteElevationProvider(route),
      );
      return detail.whenData((RouteDetailDto d) {
        final ElevationSamples? s = samples.value;
        return s == null ? null : climbBars(s, d.tracks);
      });
    }, isAutoDispose: true);

/// Le vent de [WindBarsKey.leg] sous chaque barre du profil d'un parcours de
/// la sortie et sa couleur (ledger `MOB-106`), **mémorisés** avec le profil.
///
/// `null` sans profil.
final rideRouteWindBarsProvider =
    Provider.family<AsyncValue<WindBars?>, WindBarsKey<RouteRef>>((
      Ref ref,
      WindBarsKey<RouteRef> key,
    ) {
      final AsyncValue<RouteDetailDto> detail = ref.watch(
        rideRouteGeometryProvider(key.route),
      );
      final AsyncValue<ElevationSamples?> samples = ref.watch(
        rideRouteElevationProvider(key.route),
      );
      return detail.whenData((RouteDetailDto d) {
        final ElevationSamples? s = samples.value;
        return s == null ? null : windBars(s, d.tracks, key.leg);
      });
    }, isAutoDispose: true);
