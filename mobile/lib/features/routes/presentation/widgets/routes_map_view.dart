import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/app_config.dart';
import '../../../../config/paths.dart';
import '../../../../core/config/config_provider.dart';
import '../../../../core/config/map_style_options.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/route_tile_urls.dart';
import '../../data/tile_token_repository.dart';
import '../../domain/route_filters.dart';
import '../../providers/route_list_provider.dart';
import 'routes_near_me_controls.dart';

/// La vue Carte de la parcothèque.
///
/// **Elle rend les vraies tuiles vectorielles**, comme le web : tous les
/// parcours de la zone, sans plafond, sans pilule de troncature et sans le
/// `N+1` d'appels de détail que le repli GeoJSON payait. Ce qui l'a rendu
/// possible est le jeton signé — voir l'en-tête de
/// `core/pdl/map/pdl_mass_layer.dart`.
///
/// **Le tap ne coûte aucune requête** : les propriétés du parcours touché
/// voyagent dans la tuile (`slug`, `name`, `team_slug`, `distance`,
/// `elevation_gain`), et c'est exactement ce que fait la carte web.
class RoutesMapView extends ConsumerStatefulWidget {
  const RoutesMapView({
    super.key,
    required this.filters,
    required this.onChanged,
    this.fullscreen = false,
  });

  final RouteFilters filters;
  final ValueChanged<RouteFilters> onChanged;

  /// Vrai dans la page plein écran, que cette vue construit elle-même — voir
  /// `PdlMapHero.fullscreenBuilder`. La page est une **seconde instance** :
  /// elle reprend un jeton et cadre sur les mêmes filtres, ce que la carte
  /// plein écran faisait déjà en repartant du `fitBox`. Elle y gagne la
  /// pilule, la carte flottante et les commandes « autour de moi », que la
  /// copie du hero laissait tomber sans le dire.
  final bool fullscreen;

  @override
  ConsumerState<RoutesMapView> createState() => _RoutesMapViewState();
}

class _RoutesMapViewState extends ConsumerState<RoutesMapView>
    with WidgetsBindingObserver {
  final PdlMapController _controller = PdlMapController();

  String? _token;
  Object? _tokenError;

  /// Le parcours touché, lu **dans la tuile**.
  _MassRoute? _selected;

  /// Les filtres du premier cadre : ce sont eux, et eux seuls, qui cadrent la
  /// carte.
  late final RouteFilters _framingFilters = widget.filters;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ensureToken();
  }

  @override
  void didUpdateWidget(RoutesMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filters != oldWidget.filters) {
      // Un filtre a changé : la zone regardée ne bouge pas, son contenu si —
      // et l'URL de tuile change avec lui, donc MapLibre redemande ses tuiles
      // tout seul. Le parcours sélectionné, lui, peut ne plus être dans le jeu.
      setState(() => _selected = null);
    }
  }

  /// Le cas qui mord vraiment : téléphone en poche, retour vingt minutes plus
  /// tard sur un jeton périmé. `maplibre` n'expose aucun événement d'erreur de
  /// tuile, donc le Dart ne peut ni le détecter ni l'annoncer — sans ce
  /// déclencheur, l'utilisateur revient sur une carte vide.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(tileTokenRepositoryProvider).needsRenewal) {
      _ensureToken();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ensureToken() async {
    try {
      final String token = await ref
          .read(tileTokenRepositoryProvider)
          .current();
      if (!mounted) return;
      setState(() {
        _token = token;
        _tokenError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _tokenError = e);
    }
  }

  String? get _tileUrl {
    final String? token = _token;
    if (token == null) return null;
    final String? teamSlug = widget.filters.teamSlug;
    return teamSlug == null
        ? RouteTileUrls.allRoutes(
            apiBaseUrl: AppConfig.apiBaseUrl,
            token: token,
            filters: widget.filters,
          )
        : RouteTileUrls.teamRoutes(
            apiBaseUrl: AppConfig.apiBaseUrl,
            teamSlug: teamSlug,
            token: token,
            filters: widget.filters,
          );
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final Brightness brightness = Theme.of(context).brightness;
    final AsyncValue<ResolvedMapStyle?> style = ref.watch(
      mapStyleProvider(brightness),
    );
    final AsyncValue<PdlMapBox?> bounds = ref.watch(
      routeBoundsProvider(_framingFilters),
    );
    final AsyncValue<MapCenterDto> center = ref.watch(defaultCenterProvider);

    final ResolvedMapStyle? resolved = style.value;
    if (resolved == null) {
      return _MapPending(error: style.error, onRetry: _reloadConfig);
    }

    final PdlMapBox? fitBox = _proximityBox() ?? bounds.value;

    return PdlMapHero(
      isFullscreen: widget.fullscreen,
      fullscreenBuilder: widget.fullscreen
          ? null
          : (BuildContext context) => RoutesMapView(
              filters: widget.filters,
              onChanged: widget.onChanged,
              fullscreen: true,
            ),
      labels: PdlMapHeroLabels(
        enterFullscreen: 'map.fullscreen'.tr(),
        exitFullscreen: 'map.exitFullscreen'.tr(),
        chooseBackground: 'map.background'.tr(),
        backgroundSheetTitle: 'map.background'.tr(),
        hillshade: 'map.hillshade'.tr(),
      ),
      styles: servedMapStyleOptions(ref),
      hillshadeEnabled: servedHillshadeEnabled(ref),
      onHillshadeChanged: (bool on) =>
          ref.read(hillshadeEnabledProvider.notifier).set(on),
      selectedStyleId: resolved.style.id,
      onStyleSelected: (String id) =>
          ref.read(mapStyleIdProvider.notifier).select(id),
      pill: _pill(),
      floatingCard: _floatingCard(),
      foreground: Positioned(
        left: PdlSpacing.sectionTightV,
        top: PdlSpacing.sectionTightV + PdlMetrics.tapTarget + 8,
        right: PdlSpacing.sectionTightV + PdlMetrics.tapTarget + 8,
        child: RoutesNearMeControls(
          filters: widget.filters,
          onChanged: widget.onChanged,
        ),
      ),
      mapBuilder: (BuildContext context) => PdlMap(
        hillshade: servedHillshade(context, ref),
        styleUrl: resolved.url,
        credit: servedMapCredit(resolved),
        controller: _controller,
        massTileUrl: _tileUrl,
        massTileColor: c.mapTrack,
        onMassFeatureTapped: _onFeatureTapped,
        initialCenter: center.value == null
            ? null
            : PdlMapPoint(lon: center.value!.lon, lat: center.value!.lat),
        initialZoom: center.value?.zoom.toDouble() ?? 5,
        fitBox: fitBox,
      ),
    );
  }

  void _onFeatureTapped(Map<String, Object?>? properties) {
    final _MassRoute? route = _MassRoute.fromTile(properties);
    if (route == null && _selected == null) return;
    setState(() => _selected = route);
  }

  void _reloadConfig() => ref.invalidate(appConfigProvider);

  /// La boîte à cadrer quand « Autour de moi » est armé : le carré de rayon
  /// choisi autour de la position. Sans elle, changer de rayon ne changerait
  /// que la liste.
  PdlMapBox? _proximityBox() {
    final RouteFilters f = widget.filters;
    if (!f.hasProximity) return null;
    final double lat = f.nearLat!;
    final double lon = f.nearLon!;
    // 1° de latitude ≈ 111 km ; en longitude, autant divisé par le cosinus de
    // la latitude. Le plancher évite une division par zéro aux pôles.
    final double dLat = f.effectiveNearRadius / 111000;
    final double dLon =
        dLat / math.max(0.05, math.cos(lat * math.pi / 180).abs());
    return PdlMapBox(
      minLon: lon - dLon,
      minLat: lat - dLat,
      maxLon: lon + dLon,
      maxLat: lat + dLat,
    );
  }

  /// La seule pilule qui reste : celle qui **dit** qu'aucune tuile ne peut être
  /// demandée. Une carte muette qui ne montre rien se lit comme une région sans
  /// parcours.
  Widget? _pill() {
    if (_tokenError != null) {
      return PdlMapPill(
        icon: PdlIcons.error,
        label: getErrorMessage(_tokenError!),
        onPressed: _ensureToken,
      );
    }
    if (_token == null) {
      return PdlMapPill(icon: PdlIcons.refresh, label: 'common.loading'.tr());
    }
    return null;
  }

  Widget? _floatingCard() {
    final _MassRoute? route = _selected;
    if (route == null) return null;
    return _SelectedRouteCard(route: route);
  }
}

/// Le parcours touché, tel que la tuile le porte.
///
/// Les clés viennent du type `route_mvt_row` du backend, et ce sont les mêmes
/// que celles que lit la carte web (`RoutesTileMap.tsx`). Les nombres arrivent
/// en `num` : une tuile ne distingue pas l'entier du flottant.
@immutable
class _MassRoute {
  const _MassRoute({
    required this.slug,
    required this.teamSlug,
    required this.name,
    this.distance,
    this.elevationGain,
  });

  final String slug;
  final String teamSlug;
  final String name;
  final double? distance;
  final double? elevationGain;

  static _MassRoute? fromTile(Map<String, Object?>? properties) {
    if (properties == null) return null;
    final Object? slug = properties['slug'];
    final Object? teamSlug = properties['team_slug'];
    // Sans slug ni équipe, la carte flottante n'aurait nulle part où mener.
    if (slug is! String || teamSlug is! String) return null;
    return _MassRoute(
      slug: slug,
      teamSlug: teamSlug,
      name: properties['name'] is String ? properties['name']! as String : slug,
      distance: _toDouble(properties['distance']),
      elevationGain: _toDouble(properties['elevation_gain']),
    );
  }

  static double? _toDouble(Object? value) =>
      value is num ? value.toDouble() : null;
}

/// La carte flottante d'un parcours sélectionné.
///
/// Elle se contente de ce que la tuile porte : **aucun appel** n'est fait au
/// tap. C'est aussi pourquoi il n'y a pas de vignette — la tuile n'en transporte
/// pas, et la chercher coûterait la requête qu'on vient d'économiser.
class _SelectedRouteCard extends ConsumerWidget {
  const _SelectedRouteCard({required this.route});

  final _MassRoute route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);

    return PdlMapFloatingCard(
      onTap: () => context.push(Paths.route(route.teamSlug, route.slug)),
      child: Row(
        children: <Widget>[
          PdlThumb(size: PdlMetrics.thumbSm, fallbackIcon: PdlIcons.route),
          const SizedBox(width: PdlSpacing.cardTight),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  route.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.cardTitle.copyWith(color: c.text),
                ),
                const SizedBox(height: 4),
                PdlStatRow(stats: _stats(units)),
              ],
            ),
          ),
          const SizedBox(width: PdlSpacing.chipGap),
          PdlButton(
            size: PdlButtonSize.sm,
            label: 'common.open'.tr(),
            onPressed: () =>
                context.push(Paths.route(route.teamSlug, route.slug)),
          ),
        ],
      ),
    );
  }

  /// Même formatage que `routeStats` de la carte de liste — les unités passent
  /// toujours par `AppFormatters`, jamais par un `km` codé en dur.
  List<PdlStat> _stats(UnitSystem units) => <PdlStat>[
    if (route.distance != null)
      PdlStat(
        icon: PdlIcons.distance,
        value: AppFormatters.formatDistance(route.distance!, units),
      ),
    if (route.elevationGain != null)
      PdlStat(
        icon: PdlIcons.elevationUp,
        value: AppFormatters.formatElevation(route.elevationGain!, units),
      ),
  ];
}

/// Un écran de carte qui n'a pas encore son fond : `ConfigDto` est en vol, ou
/// n'est pas venu.
class _MapPending extends StatelessWidget {
  const _MapPending({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: PdlEmptyState(
        variant: PdlEmptyVariant.error,
        title: 'common.loadError'.tr(),
        message: getErrorMessage(error!),
        actions: <Widget>[
          PdlButton(
            label: 'common.retry'.tr(),
            variant: PdlButtonVariant.outline,
            size: PdlButtonSize.sm,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
