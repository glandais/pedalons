import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../api/pedalons_api_client.dart';
import '../../../../config/paths.dart';
import '../../../../core/config/config_provider.dart';
import '../../../../core/config/map_style_options.dart';
import '../../../../core/geo/polyline_index.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../keys.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../teams/providers/team_providers.dart';
import '../../domain/planner_quota.dart';
import '../../domain/planner_result.dart';
import '../../domain/route_generator.dart';
import '../../providers/route_editor_providers.dart';

/// Le type proposé par défaut : celui des parcours les plus nombreux de
/// l'équipe (trois comptes, comme au site). Un compte en échec laisse ROAD.
final generatorDominantTypeProvider = FutureProvider.autoDispose
    .family<RouteGeneratorType, String>((Ref ref, String teamSlug) async {
      final RoutesClient client = ref.watch(routesClientProvider);
      Future<int?> count(SurfaceType type) async {
        try {
          return (await client.countRoutes(
            teamSlug: teamSlug,
            surfaceType: type,
          )).total;
        } on Object {
          return null;
        }
      }

      final List<int?> counts = await Future.wait(<Future<int?>>[
        count(SurfaceType.road),
        count(SurfaceType.gravel),
        count(SurfaceType.mtb),
      ]);
      return dominantGeneratorType(
        road: counts[0],
        gravel: counts[1],
        mtb: counts[2],
      );
    });

/// Les lieux de l'équipe qui ont une position : une page suffit, une équipe
/// en a une poignée (même lecture que le site).
final generatorPlacesProvider = FutureProvider.autoDispose
    .family<List<PlaceDetailDto>, String>((Ref ref, String teamSlug) async {
      final PlaceListResponse page = await ref
          .watch(placesClientProvider)
          .listPlaces(teamSlug: teamSlug, size: 100);
      return page.places;
    });

/// Le générateur de parcours (docs/LEDGER_*.md MOB-154) : les réglages sous
/// une carte, puis une à trois propositions à faire glisser, dont l'une
/// s'ouvre dans l'éditeur de parcours — le planificateur embarqué l'importe,
/// et c'est son enregistrement qui la garde (et compte dans le quota).
///
/// Ouvert à qui peut créer un parcours dans l'équipe, planificateur actif :
/// la règle du serveur (`PlannerAccess`). Quelqu'un d'autre lit un refus.
class RouteGeneratorPage extends ConsumerWidget {
  const RouteGeneratorPage({
    super.key,
    required this.teamSlug,
    this.initialSettings,
  });

  final String teamSlug;

  /// Les réglages d'arrivée, depuis une retouche ; `null` : ceux par défaut.
  final GeneratorSettings? initialSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TeamDetailDto> team = ref.watch(
      teamDetailProvider(teamSlug),
    );
    final bool? canManage = ref.watch(canManageRoutesProvider(teamSlug));

    Widget shell(Widget body) => PdlScreenScaffold(
      appBar: PdlAppBar(
        title: 'routeGenerator.title'.tr(),
        onBack: () => context.pop(),
        backSemanticLabel: 'common.back'.tr(),
      ),
      body: body,
    );

    final Object? error = team.hasValue ? null : team.error;
    if (error != null) {
      return shell(
        PdlEmptyState(
          variant: PdlEmptyVariant.error,
          title: 'common.loadError'.tr(),
          message: getErrorMessage(error),
          actions: <Widget>[
            PdlButton(
              label: 'common.retry'.tr(),
              onPressed: () => ref.invalidate(teamDetailProvider(teamSlug)),
            ),
          ],
        ),
      );
    }
    final TeamDetailDto? value = team.value;
    if (value == null || canManage == null) {
      return shell(const Center(child: CircularProgressIndicator.adaptive()));
    }
    if (!canManage || !value.enableRoutes || !value.enableRoutePlanner) {
      return shell(
        PdlEmptyState(
          variant: PdlEmptyVariant.empty,
          icon: PdlIcons.admin,
          title: 'routes.editor.forbiddenTitle'.tr(),
          message: value.enableRoutePlanner
              ? 'routes.editor.forbiddenMessage'.tr()
              : 'routeGenerator.errors.disabled'.tr(),
          actions: <Widget>[
            PdlButton(
              label: 'common.back'.tr(),
              variant: PdlButtonVariant.outline,
              onPressed: () => context.pop(),
            ),
          ],
        ),
      );
    }
    return _GeneratorScreen(team: value, initialSettings: initialSettings);
  }
}

/// Ce que la carte attend d'un toucher.
enum _Picking { none, start, end }

class _GeneratorScreen extends ConsumerStatefulWidget {
  const _GeneratorScreen({required this.team, this.initialSettings});

  final TeamDetailDto team;
  final GeneratorSettings? initialSettings;

  @override
  ConsumerState<_GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends ConsumerState<_GeneratorScreen> {
  late GeneratorSettings _settings =
      widget.initialSettings ?? const GeneratorSettings();
  _Picking _picking = _Picking.none;

  /// La génération en vol ; un numéro plus récent rend la réponse caduque
  /// (« Annuler », réglages changés).
  int _run = 0;
  bool _loading = false;
  bool _slow = false;
  Timer? _slowTimer;
  RouteGeneratorResponse? _response;
  RouteGeneratorType? _responseType;
  Object? _error;
  int _selected = 0;
  final PageController _pages = PageController(viewportFraction: 0.9);

  TeamDetailDto get _team => widget.team;
  GeneratorPoint? get _teamStart => teamGeneratorPoint(_team);
  GeneratorPoint? get _start => _settings.start ?? _teamStart;
  bool get _showingResults => _response != null || _loading;

  @override
  void dispose() {
    _slowTimer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  /// Le type des parcours les plus nombreux de l'équipe, lu à chaque `build`
  /// — qui garde son fournisseur en vie, réglages à l'écran ou non.
  RouteGeneratorType? _dominant;

  RouteGeneratorType get _type =>
      _settings.type ?? _dominant ?? RouteGeneratorType.road;

  String _distanceText(double meters) =>
      AppFormatters.formatDistanceRounded(meters, ref.read(unitSystemProvider));

  void _update(GeneratorSettings next) => setState(() => _settings = next);

  /// Une distance plus courte d'un quart, au cran de 5 km du curseur.
  double get _shorterKm => ((_settings.distanceKm * 0.75 / 5).round() * 5)
      .toDouble()
      .clamp(kGeneratorMinKm, kGeneratorMaxKm);

  // ── Génération ─────────────────────────────────────────────────────────

  bool get _quotaSpent {
    final bool platformAdmin =
        ref.read(authProvider).user?.platformRole == 'PLATFORM_ADMIN';
    return isPlannerQuotaSpent(
      _team.plannerQuota,
      platformAdmin: platformAdmin,
    );
  }

  /// Pourquoi « Générer » est indisponible, ou `null`.
  String? get _blocker {
    if (_start == null) return 'routeGenerator.start.noLocation'.tr();
    if (!_settings.loop && _settings.end == null) {
      return 'routeGenerator.end.missing'.tr();
    }
    return null;
  }

  Future<void> _generate({bool nextSeed = false}) async {
    if (_blocker != null) return;
    final RouteGeneratorType type = _type;
    final GeneratorSettings settings =
        (nextSeed ? _settings.copyWith(seed: _settings.seed + 1) : _settings)
            .copyWith(type: type);
    final int run = ++_run;
    _slowTimer?.cancel();
    setState(() {
      _settings = settings;
      _picking = _Picking.none;
      _loading = true;
      _slow = false;
      _error = null;
      if (!nextSeed) _response = null;
    });
    _slowTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && run == _run) setState(() => _slow = true);
    });
    try {
      final RouteGeneratorResponse response = await ref
          .read(routeGeneratorClientProvider)
          .generateRoutes(
            teamSlug: _team.slug,
            body: buildGeneratorRequest(
              settings,
              type,
              resolvedStart: _teamStart,
            ),
          );
      if (!mounted || run != _run) return;
      setState(() {
        _loading = false;
        _response = response.candidates.isEmpty ? null : response;
        _responseType = type;
        _selected = 0;
        if (response.candidates.isEmpty) {
          _error = StateError('empty');
        }
      });
      if (_pages.hasClients) _pages.jumpToPage(0);
    } on Object catch (error) {
      if (!mounted || run != _run) return;
      setState(() {
        _loading = false;
        _response = null;
        _error = error;
      });
    } finally {
      if (run == _run) _slowTimer?.cancel();
    }
  }

  void _cancel() {
    _run++;
    _slowTimer?.cancel();
    setState(() {
      _loading = false;
      _slow = false;
    });
  }

  void _backToSettings() {
    _run++;
    setState(() {
      _response = null;
      _loading = false;
      _error = null;
    });
  }

  /// L'éditeur est ouvert : un second appui n'en pousse pas un second
  /// (deux WebViews), jusqu'au retour (docs/LEDGER_*.md MOB-186).
  bool _opening = false;

  Future<void> _use() async {
    if (_opening) return;
    final RouteGeneratorResponse? response = _response;
    final RouteGeneratorType? type = _responseType;
    if (response == null || type == null) return;
    if (_quotaSpent) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('routeGenerator.quotaSpent'.tr())),
      );
      return;
    }
    final GeneratedRouteDto candidate = response.candidates[_selected];
    // Au-dessus du générateur : revenir de l'éditeur retrouve les propositions.
    _opening = true;
    await context.push<void>(
      Paths.routeNew(_team.slug),
      extra: GeneratedHandoff(
        polyline: candidate.polyline,
        type: type,
        distanceM: candidate.distanceM,
        name: 'routeGenerator.generatedName'.tr(
          namedArgs: <String, String>{
            'distance': _distanceText(candidate.distanceM),
          },
        ),
      ),
    );
    _opening = false;
  }

  // ── Départ et arrivée ──────────────────────────────────────────────────

  void _mapTapped(double lon, double lat) {
    final GeneratorPoint point = GeneratorPoint(
      lng: lon,
      lat: lat,
      kind: GeneratorPointKind.picked,
    );
    switch (_picking) {
      case _Picking.start:
        _update(_settings.copyWith(start: point));
      case _Picking.end:
        _update(_settings.copyWith(end: point, loop: false));
      case _Picking.none:
        return;
    }
    setState(() => _picking = _Picking.none);
  }

  Future<void> _choosePoint({required bool start}) async {
    final List<PlaceDetailDto> places =
        ref.read(generatorPlacesProvider(_team.slug)).value ??
        const <PlaceDetailDto>[];
    final List<GeneratorPoint> offered = <GeneratorPoint>[
      for (final PlaceDetailDto p in places)
        if (start ? p.startPlace : p.endPlace) ?placeGeneratorPoint(p),
    ];
    final GeneratorPoint? team = _teamStart;
    final Object? choice = await PdlSheet.show<Object>(
      context: context,
      builder: (BuildContext sheetContext) => PdlSheet(
        title:
            (start
                    ? 'routeGenerator.start.sheetTitle'
                    : 'routeGenerator.end.sheetTitle')
                .tr(),
        bodyPadding: EdgeInsets.zero,
        footer: const SafeArea(
          top: false,
          child: SizedBox(height: PdlSpacing.chipGap),
        ),
        children: <Widget>[
          PdlSettingRow(
            icon: PdlIcons.locate,
            title: 'routeGenerator.start.pick'.tr(),
            onTap: () => Navigator.of(sheetContext).pop(_Picking.start),
          ),
          if (start && team != null)
            PdlSettingRow(
              icon: PdlIcons.team,
              title: 'routeGenerator.start.team'.tr(),
              onTap: () => Navigator.of(sheetContext).pop(team),
            ),
          for (final GeneratorPoint p in offered)
            PdlSettingRow(
              icon: start ? PdlIcons.placeStart : PdlIcons.placeEnd,
              title: p.name ?? '',
              onTap: () => Navigator.of(sheetContext).pop(p),
            ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    if (choice is GeneratorPoint) {
      _update(
        start
            ? _settings.copyWith(start: choice)
            : _settings.copyWith(end: choice, loop: false),
      );
    } else {
      setState(() => _picking = start ? _Picking.start : _Picking.end);
    }
  }

  String _pointLabel(GeneratorPoint? point, {required bool start}) {
    if (point == null) {
      return (start
              ? 'routeGenerator.start.label'
              : 'routeGenerator.end.missing')
          .tr();
    }
    return switch (point.kind) {
      GeneratorPointKind.team => 'routeGenerator.start.team'.tr(),
      GeneratorPointKind.place => point.name ?? '',
      GeneratorPointKind.picked => 'routeGenerator.start.picked'.tr(),
    };
  }

  // ── Carte ──────────────────────────────────────────────────────────────

  List<PdlMapTrack>? _tracksCache;
  RouteGeneratorResponse? _tracksOf;

  List<PdlMapTrack> _tracks(PdlColors c) {
    final RouteGeneratorResponse? response = _response;
    if (response == null) return const <PdlMapTrack>[];
    if (identical(_tracksOf, response) && _tracksCache != null) {
      return _tracksCache!;
    }
    _tracksOf = response;
    return _tracksCache = <PdlMapTrack>[
      for (int i = 0; i < response.candidates.length; i++)
        PdlMapTrack(
          id: 'candidate$i',
          lines: <List<List<double>>>[
            <List<double>>[
              for (final LngLat p in decodePolyline6(
                response.candidates[i].polyline,
              ))
                <double>[p.lng, p.lat],
            ],
          ],
          color: c.mapTrack,
        ),
    ];
  }

  PdlMapBox? get _fitBox {
    final RouteGeneratorResponse? response = _response;
    if (response != null) {
      final BoundsDto b = response.candidates[_selected].bounds;
      return PdlMapBox(
        minLon: b.minLon,
        minLat: b.minLat,
        maxLon: b.maxLon,
        maxLat: b.maxLat,
      );
    }
    final GeneratorPoint? start = _start;
    if (start == null) return null;
    // Une boîte autour du départ, à l'échelle de la distance voulue.
    final double span = (_settings.distanceKm / 4 / 111).clamp(0.05, 0.6);
    PdlMapBox box = PdlMapBox(
      minLon: start.lng - span,
      minLat: start.lat - span,
      maxLon: start.lng + span,
      maxLat: start.lat + span,
    );
    final GeneratorPoint? end = _settings.effectiveEnd;
    if (end != null) {
      box = box.union(
        PdlMapBox(
          minLon: end.lng,
          minLat: end.lat,
          maxLon: end.lng,
          maxLat: end.lat,
        ),
      );
    }
    return box;
  }

  Widget _map(PdlColors c) {
    final ResolvedMapStyle? style = ref
        .watch(mapStyleProvider(Theme.of(context).brightness))
        .value;
    if (style == null) return ColoredBox(color: c.surfaceAlt);
    final GeneratorPoint? start = _start;
    final GeneratorPoint? end = _settings.effectiveEnd;
    final List<PdlMapTrack> tracks = _tracks(c);
    return Semantics(
      label: 'routeGenerator.mapLabel'.tr(),
      child: PdlMap(
        key: keys.routeGenerator.map,
        styleUrl: style.url,
        credit: servedMapCredit(style),
        scale: servedMapScale(ref),
        tracks: tracks,
        selectedTrackId: tracks.isEmpty ? null : 'candidate$_selected',
        onTrackSelected: (String? id) {
          final int? index = id == null
              ? null
              : int.tryParse(id.replaceFirst('candidate', ''));
          if (index == null) return;
          setState(() => _selected = index);
          if (_pages.hasClients) {
            _pages.animateToPage(
              index,
              duration: PdlMotion.stateChange,
              curve: Curves.easeOut,
            );
          }
        },
        start: start == null
            ? null
            : PdlMapPoint(lon: start.lng, lat: start.lat),
        end: end == null ? null : PdlMapPoint(lon: end.lng, lat: end.lat),
        initialCenter: start == null
            ? null
            : PdlMapPoint(lon: start.lng, lat: start.lat),
        initialZoom: 10,
        fitBox: _fitBox,
        onMapTapped: _picking == _Picking.none ? null : _mapTapped,
        overlays: <Widget>[
          if (_picking != _Picking.none)
            Positioned(
              left: PdlSpacing.section,
              right: PdlSpacing.section,
              top: PdlSpacing.cardTight,
              child: PdlBanner(
                key: keys.routeGenerator.pickHint,
                tone: PdlBannerTone.info,
                icon: PdlIcons.place,
                message:
                    (_picking == _Picking.start
                            ? 'routeGenerator.start.pickHint'
                            : 'routeGenerator.end.pickHint')
                        .tr(),
                onDismiss: () => setState(() => _picking = _Picking.none),
                dismissSemanticLabel: 'common.close'.tr(),
              ),
            ),
        ],
      ),
    );
  }

  // ── Écran ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    _dominant = ref.watch(generatorDominantTypeProvider(_team.slug)).value;
    final bool results = _showingResults;
    final double height = MediaQuery.sizeOf(context).height;
    return PopScope(
      canPop: !results,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _backToSettings();
      },
      child: PdlScreenScaffold(
        appBar: PdlAppBar(
          title: 'routeGenerator.title'.tr(),
          onBack: () => Navigator.of(context).maybePop(),
          backSemanticLabel: 'common.back'.tr(),
        ),
        actionBar: _actionBar(),
        body: Column(
          children: <Widget>[
            SizedBox(height: height * (results ? 0.42 : 0.3), child: _map(c)),
            Expanded(child: results ? _resultsPanel(c) : _settingsPanel(c)),
          ],
        ),
      ),
    );
  }

  PdlActionBar _actionBar() {
    if (_loading) {
      return PdlActionBar(
        children: <Widget>[
          PdlButton(
            label: 'routeGenerator.cancel'.tr(),
            variant: PdlButtonVariant.outline,
            onPressed: _cancel,
          ),
        ],
      );
    }
    if (_response != null) {
      return PdlActionBar(
        children: <Widget>[
          PdlButton(
            key: keys.routeGenerator.moreButton,
            label: 'routeGenerator.more'.tr(),
            icon: PdlIcons.refresh,
            variant: PdlButtonVariant.outline,
            onPressed: () => _generate(nextSeed: true),
          ),
          PdlButton(
            key: keys.routeGenerator.useButton,
            label: 'routeGenerator.card.use'.tr(),
            icon: PdlIcons.check,
            // Quota épuisé : le bouton reste, et dit pourquoi il n'ouvre rien.
            onPressed: _use,
          ),
        ],
      );
    }
    return PdlActionBar(
      children: <Widget>[
        PdlButton(
          key: keys.routeGenerator.generateButton,
          label: 'routeGenerator.generate'.tr(),
          icon: PdlIcons.route,
          enabled: _blocker == null,
          onPressed: _generate,
        ),
      ],
    );
  }

  Widget _label(String text, [Widget? trailing]) {
    final PdlTypography t = context.pdlText;
    final PdlColors c = context.pdl;
    return Padding(
      padding: const EdgeInsets.only(bottom: PdlSpacing.chipGap),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              text,
              style: t.sub.copyWith(
                color: c.textDimmed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _settingsPanel(PdlColors c) {
    final PdlTypography t = context.pdlText;
    final RouteGeneratorType type = _type;
    final GeneratorPoint? end = _settings.end;
    final bool far = isEndFar(
      _start,
      _settings.effectiveEnd,
      _settings.distanceKm,
    );
    final int discoveryStop = (_settings.discovery * kDiscoveryStops).round();
    final Object? error = _error;
    const SizedBox gap = SizedBox(height: PdlSpacing.detailSubsectionGap);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        PdlSpacing.section,
        PdlSpacing.section,
        PdlSpacing.section,
        PdlSpacing.section * 2,
      ),
      children: <Widget>[
        if (error != null) ...<Widget>[
          _ErrorBlock(
            error: error,
            distance: _distanceText(_settings.distanceKm * 1000),
            minDistance: _distanceText(kGeneratorMinKm * 1000),
            maxDistance: _distanceText(kGeneratorMaxKm * 1000),
            onRetry: _generate,
            onShorter: _shorterKm < _settings.distanceKm
                ? () {
                    _update(_settings.copyWith(distanceKm: _shorterKm));
                    _generate();
                  }
                : null,
            shorterLabel: _distanceText(_shorterKm * 1000),
            onMoreDiscovery: _settings.discovery < 1
                ? () {
                    _update(
                      _settings.copyWith(
                        discovery: (_settings.discovery + 0.25).clamp(0, 1),
                      ),
                    );
                    _generate();
                  }
                : null,
            onOtherStart: () => _choosePoint(start: true),
          ),
          gap,
        ],
        // ── Départ ──
        _label('routeGenerator.start.label'.tr()),
        _PointButton(
          key: keys.routeGenerator.startField,
          icon: PdlIcons.placeStart,
          iconColor: c.mapStart,
          label: _pointLabel(_start, start: true),
          onTap: () => _choosePoint(start: true),
        ),
        gap,
        // ── Type ──
        _label('routeGenerator.type.label'.tr()),
        PdlSegmented<RouteGeneratorType>(
          key: keys.routeGenerator.typeSegments,
          value: type,
          onChanged: (RouteGeneratorType v) =>
              _update(_settings.copyWith(type: v)),
          segments: <PdlSegment<RouteGeneratorType>>[
            for (final RouteGeneratorType v
                in RouteGeneratorType.$valuesDefined)
              PdlSegment<RouteGeneratorType>(
                value: v,
                label: 'routes.surfaceType.${v.json!.toLowerCase()}'.tr(),
              ),
          ],
        ),
        gap,
        // ── Distance ──
        _label(
          'routeGenerator.distance.label'.tr(),
          Text(_distanceText(_settings.distanceKm * 1000), style: t.statValue),
        ),
        _GeneratorSlider(
          key: keys.routeGenerator.distanceSlider,
          value: _settings.distanceKm,
          min: kGeneratorMinKm,
          max: kGeneratorMaxKm,
          divisions: ((kGeneratorMaxKm - kGeneratorMinKm) / 5).round(),
          semanticValue: _distanceText(_settings.distanceKm * 1000),
          lowLabel: _distanceText(kGeneratorMinKm * 1000),
          highLabel: _distanceText(kGeneratorMaxKm * 1000),
          onChanged: (double v) => _update(_settings.copyWith(distanceKm: v)),
        ),
        gap,
        // ── Arrivée ──
        _label('routeGenerator.end.label'.tr()),
        PdlSegmented<bool>(
          key: keys.routeGenerator.endSegments,
          value: _settings.loop,
          onChanged: (bool loop) {
            _update(_settings.copyWith(loop: loop));
            if (!loop && end == null) _choosePoint(start: false);
          },
          segments: <PdlSegment<bool>>[
            PdlSegment<bool>(
              value: true,
              label: 'routeGenerator.end.loop'.tr(),
            ),
            PdlSegment<bool>(
              value: false,
              label: 'routeGenerator.end.elsewhere'.tr(),
            ),
          ],
        ),
        if (!_settings.loop) ...<Widget>[
          const SizedBox(height: PdlSpacing.chipGap),
          _PointButton(
            key: keys.routeGenerator.endField,
            icon: PdlIcons.placeEnd,
            iconColor: c.mapEnd,
            label: _pointLabel(end, start: false),
            onTap: () => _choosePoint(start: false),
          ),
        ],
        gap,
        // ── Direction ── ignorée quand l'arrivée est loin, et dit pourquoi.
        _label('routeGenerator.bearing.label'.tr()),
        if (far)
          Text(
            'routeGenerator.bearing.farHint'.tr(),
            style: t.sub.copyWith(color: c.textDimmed),
          )
        else
          PdlChipRow(
            padding: EdgeInsets.zero,
            children: <Widget>[
              PdlChip(
                key: keys.routeGenerator.bearing('any'),
                label: 'routeGenerator.bearing.any'.tr(),
                selected: _settings.bearing == null,
                onTap: () => _update(_settings.copyWith(bearing: () => null)),
              ),
              for (final CompassPoint p in CompassPoint.$valuesDefined)
                PdlChip(
                  key: keys.routeGenerator.bearing(p.json!),
                  label: 'routeGenerator.bearing.${p.json}'.tr(),
                  selected: _settings.bearing == p,
                  onTap: () => _update(_settings.copyWith(bearing: () => p)),
                ),
            ],
          ),
        gap,
        // ── Routes de l'équipe ↔ Découverte ──
        _label(
          'routeGenerator.discovery.label'.tr(),
          Text(
            'routeGenerator.discovery.stop$discoveryStop'.tr(),
            style: t.bodyStrong,
          ),
        ),
        _GeneratorSlider(
          key: keys.routeGenerator.discoverySlider,
          value: _settings.discovery,
          min: 0,
          max: 1,
          divisions: kDiscoveryStops,
          semanticValue: 'routeGenerator.discovery.stop$discoveryStop'.tr(),
          lowLabel: 'routeGenerator.discovery.low'.tr(),
          highLabel: 'routeGenerator.discovery.high'.tr(),
          onChanged: (double v) => _update(_settings.copyWith(discovery: v)),
        ),
        // ── Chemins ── hors route seulement.
        if (type != RouteGeneratorType.road) ...<Widget>[
          gap,
          _label('routeGenerator.unpaved.label'.tr()),
          PdlSegmented<RouteGeneratorUnpaved>(
            key: keys.routeGenerator.unpavedSegments,
            value: _settings.unpaved,
            onChanged: (RouteGeneratorUnpaved v) =>
                _update(_settings.copyWith(unpaved: v)),
            segments: <PdlSegment<RouteGeneratorUnpaved>>[
              for (final RouteGeneratorUnpaved v
                  in RouteGeneratorUnpaved.$valuesDefined)
                PdlSegment<RouteGeneratorUnpaved>(
                  value: v,
                  label: 'routeGenerator.unpaved.${v.json!.toLowerCase()}'.tr(),
                ),
            ],
          ),
        ],
        if (_blocker case final String why) ...<Widget>[
          gap,
          Text(why, style: t.sub.copyWith(color: c.textDimmed)),
        ],
      ],
    );
  }

  Widget _resultsPanel(PdlColors c) {
    final PdlTypography t = context.pdlText;
    final RouteGeneratorResponse? response = _response;
    if (response == null) {
      return Padding(
        key: keys.routeGenerator.loading,
        padding: const EdgeInsets.all(PdlSpacing.section),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator.adaptive(strokeWidth: 3),
            ),
            const SizedBox(width: PdlSpacing.cardTight),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('routeGenerator.generating'.tr(), style: t.bodyStrong),
                  if (_slow)
                    Text(
                      'routeGenerator.slow'.tr(),
                      style: t.sub.copyWith(color: c.textDimmed),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final UnitSystem units = ref.watch(unitSystemProvider);
    final int count = response.candidates.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            PdlSpacing.section,
            PdlSpacing.cardTight,
            PdlSpacing.section,
            PdlSpacing.chipGap,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'routeGenerator.count'.plural(count),
                  style: t.sectionTitle,
                ),
              ),
              PdlButton(
                label: 'routeGenerator.editSettings'.tr(),
                variant: PdlButtonVariant.outline,
                size: PdlButtonSize.sm,
                icon: PdlIcons.filter,
                onPressed: _backToSettings,
              ),
            ],
          ),
        ),
        if (_loading)
          const LinearProgressIndicator(minHeight: 2)
        else
          const SizedBox(height: 2),
        Expanded(
          child: PageView.builder(
            controller: _pages,
            itemCount: count,
            onPageChanged: (int i) => setState(() => _selected = i),
            itemBuilder: (BuildContext context, int i) => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PdlSpacing.chipGap / 2,
                vertical: PdlSpacing.chipGap,
              ),
              child: _CandidateCard(
                key: keys.routeGenerator.card(i),
                index: i,
                count: count,
                candidate: response.candidates[i],
                selected: i == _selected,
                units: units,
                onTap: () => setState(() => _selected = i),
              ),
            ),
          ),
        ),
        if (response.partialCoverage || response.networkPreparedAt != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PdlSpacing.section,
              0,
              PdlSpacing.section,
              PdlSpacing.chipGap,
            ),
            child: Text(
              response.partialCoverage
                  ? 'routeGenerator.partialCoverage'.tr()
                  : 'routeGenerator.useHint'.tr(),
              style: t.xs.copyWith(color: c.textDimmed),
            ),
          ),
      ],
    );
  }
}

/// Un bouton de lieu (départ, arrivée) : icône, libellé, chevron.
class _PointButton extends StatelessWidget {
  const _PointButton({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return Semantics(
      button: true,
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: PdlRadii.mdAll,
          side: BorderSide(color: c.border),
        ),
        child: InkWell(
          borderRadius: PdlRadii.mdAll,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: PdlMetrics.tapTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PdlSpacing.cardTight,
              ),
              child: Row(
                children: <Widget>[
                  Icon(icon, color: iconColor, size: 20),
                  const SizedBox(width: PdlSpacing.chipGap),
                  Expanded(
                    child: Text(
                      label,
                      style: t.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(PdlIcons.chevronDown, color: c.textDimmed, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Un curseur à une poignée, habillé comme `PdlRangeFilter`.
class _GeneratorSlider extends StatelessWidget {
  const _GeneratorSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.semanticValue,
    required this.lowLabel,
    required this.highLabel,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final int divisions;
  final String semanticValue;
  final String lowLabel;
  final String highLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: c.primary,
            inactiveTrackColor: c.neutralSoft,
            thumbColor: c.surface,
            overlayColor: c.primary.withValues(alpha: 0.12),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            showValueIndicator: ShowValueIndicator.onDrag,
            valueIndicatorColor: c.neutralOnSoft,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: semanticValue,
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(lowLabel, style: t.monoAxis),
              Text(highLabel, style: t.monoAxis),
            ],
          ),
        ),
      ],
    );
  }
}

/// Une proposition : distance, dénivelé, part sur les routes de l'équipe,
/// part non revêtue.
class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    super.key,
    required this.index,
    required this.count,
    required this.candidate,
    required this.selected,
    required this.units,
    required this.onTap,
  });

  final int index;
  final int count;
  final GeneratedRouteDto candidate;
  final bool selected;
  final UnitSystem units;
  final VoidCallback onTap;

  String _percent(double share) => '${(share * 100).round()} %';

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final double? ascent = candidate.ascentM;
    final bool? reached = candidate.unpavedTargetReached;
    final double? target = candidate.unpavedTarget;
    return PdlCard(
      selected: selected,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'routeGenerator.card.title'.tr(
                    namedArgs: <String, String>{'index': '${index + 1}'},
                  ),
                  style: t.cardTitle,
                ),
              ),
              Text(
                '${index + 1} / $count',
                style: t.xs.copyWith(color: c.textDimmed),
              ),
            ],
          ),
          const SizedBox(height: PdlSpacing.chipGap),
          PdlStatRow(
            stats: <PdlStat>[
              PdlStat(
                icon: PdlIcons.distance,
                value: AppFormatters.formatDistance(candidate.distanceM, units),
              ),
              if (ascent != null)
                PdlStat(
                  icon: PdlIcons.elevationUp,
                  value: AppFormatters.formatElevationGain(ascent, units),
                ),
            ],
          ),
          const SizedBox(height: PdlSpacing.chipGap),
          _Line(
            icon: PdlIcons.team,
            text: 'routeGenerator.card.teamShare'.tr(
              namedArgs: <String, String>{
                'share': _percent(candidate.teamShare),
              },
            ),
          ),
          _Line(
            icon: PdlIcons.surfaceGravel,
            text: 'routeGenerator.card.unpaved'.tr(
              namedArgs: <String, String>{
                'share': _percent(candidate.unpavedShare),
              },
            ),
          ),
          if (reached == false && target != null)
            _Line(
              icon: PdlIcons.info,
              text:
                  (candidate.unpavedShare > target
                          ? 'routeGenerator.card.unpavedAbove'
                          : 'routeGenerator.card.unpavedBelow')
                      .tr(),
            ),
          if (candidate.sharedM >= 100)
            _Line(
              icon: PdlIcons.route,
              text: 'routeGenerator.card.shared'.tr(
                namedArgs: <String, String>{
                  'distance': AppFormatters.formatDistance(
                    candidate.sharedM,
                    units,
                  ),
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return Padding(
      padding: const EdgeInsets.only(top: PdlSpacing.badgeGap),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: c.textDimmed),
          const SizedBox(width: PdlSpacing.chipGap),
          Expanded(child: Text(text, style: t.sub)),
        ],
      ),
    );
  }
}

/// L'échec d'une génération : le message, et ce qui peut aider — réessayer
/// quand c'est utile, sinon des réglages proposés en un geste.
class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({
    required this.error,
    required this.distance,
    required this.minDistance,
    required this.maxDistance,
    required this.onRetry,
    required this.onShorter,
    required this.shorterLabel,
    required this.onMoreDiscovery,
    required this.onOtherStart,
  });

  final Object error;
  final String distance;
  final String minDistance;
  final String maxDistance;
  final VoidCallback onRetry;
  final VoidCallback? onShorter;
  final String shorterLabel;
  final VoidCallback? onMoreDiscovery;
  final VoidCallback onOtherStart;

  @override
  Widget build(BuildContext context) {
    final bool empty = error is StateError;
    final String message = empty
        ? 'routeGenerator.errors.noRoute'.tr(
            namedArgs: <String, String>{'distance': distance},
          )
        : generatorErrorMessage(
            error,
            distance: distance,
            minDistance: minDistance,
            maxDistance: maxDistance,
          );
    final bool settings = empty || isSettingsGeneratorError(error);
    final bool retry = !empty && isRetryableGeneratorError(error);
    return Column(
      key: keys.routeGenerator.error,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PdlBanner(
          tone: retry ? PdlBannerTone.danger : PdlBannerTone.warn,
          icon: PdlIcons.warning,
          title: settings ? 'routeGenerator.noProposalTitle'.tr() : null,
          message: message,
          action: retry
              ? PdlButton(
                  key: keys.routeGenerator.retryButton,
                  label: 'routeGenerator.retry'.tr(),
                  size: PdlButtonSize.sm,
                  variant: PdlButtonVariant.outline,
                  onPressed: onRetry,
                )
              : null,
        ),
        if (settings) ...<Widget>[
          const SizedBox(height: PdlSpacing.cardTight),
          PdlChipRow(
            padding: EdgeInsets.zero,
            children: <Widget>[
              if (onShorter != null)
                PdlChip(
                  label: shorterLabel,
                  icon: PdlIcons.distance,
                  onTap: onShorter,
                ),
              if (onMoreDiscovery != null)
                PdlChip(
                  label: 'routeGenerator.moreDiscovery'.tr(),
                  icon: PdlIcons.map,
                  onTap: onMoreDiscovery,
                ),
              PdlChip(
                label: 'routeGenerator.otherStart'.tr(),
                icon: PdlIcons.placeStart,
                onTap: onOtherStart,
              ),
            ],
          ),
        ],
      ],
    );
  }
}
