import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../api/pedalons_api_client.dart';
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
import '../../../../core/utils/formatters.dart';
import '../../../../keys.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../teams/providers/team_providers.dart';
import '../../domain/planner_quota.dart';
import '../../domain/planner_result.dart';
import '../../domain/route_retouch.dart';
import 'route_generator_page.dart' show generatorPlacesProvider;

/// Ouvre la retouche de [route] en plein écran (navigateur racine) ; rend ce
/// que la personne a choisi d'ouvrir, ou `null`.
Future<RetouchChoice?> openRouteRetouch(
  BuildContext context, {
  required RouteDetailDto route,
  required RouteRetouchOfferDto offer,
  required bool canEdit,
  RouteRetouchOperation? initialMode,
}) => Navigator.of(context, rootNavigator: true).push<RetouchChoice>(
  MaterialPageRoute<RetouchChoice>(
    builder: (_) => RouteRetouchPage(
      route: route,
      offer: offer,
      canEdit: canEdit,
      initialMode: initialMode,
    ),
  ),
);

/// Retoucher un parcours enregistré (docs/LEDGER_*.md MOB-185, le site :
/// `WEB-201`) : viser une autre distance, ou déplacer l'arrivée ; jusqu'à
/// trois propositions sur la carte, le tronçon changé en évidence, puis
/// « Modifier » (la trace de ce parcours remplacée dans son éditeur) ou
/// « Nouveau parcours » (une création). Rien n'est enregistré ici : l'écran
/// rend son choix à la fiche, qui ouvre l'éditeur.
class RouteRetouchPage extends ConsumerStatefulWidget {
  const RouteRetouchPage({
    super.key,
    required this.route,
    required this.offer,
    required this.canEdit,
    this.initialMode,
  });

  final RouteDetailDto route;
  final RouteRetouchOfferDto offer;

  /// L'opération choisie dans le menu (« Ajuster la distance », « Déplacer
  /// l'arrivée ») ; la page garde son segmenté pour changer d'avis.
  final RouteRetouchOperation? initialMode;

  /// « Modifier » est offert : le parcours se modifie et n'a qu'une trace.
  final bool canEdit;

  @override
  ConsumerState<RouteRetouchPage> createState() => _RouteRetouchPageState();
}

class _RouteRetouchPageState extends ConsumerState<RouteRetouchPage> {
  late RouteRetouchOperation _mode =
      widget.initialMode != null &&
          widget.offer.operations.contains(widget.initialMode)
      ? widget.initialMode!
      : _resize
      ? RouteRetouchOperation.resize
      : RouteRetouchOperation.moveEnd;
  double? _targetKm;
  GeoPoint? _endPoint;
  GeneratorPlace? _place;

  RetouchTarget? _submitted;
  int _seed = 0;
  int _run = 0;
  bool _loading = false;
  bool _slow = false;
  Timer? _slowTimer;
  RouteRetouchResponse? _response;
  Object? _error;
  int _selected = 0;
  final PageController _pages = PageController(viewportFraction: 0.9);

  RouteDetailDto get _route => widget.route;
  RouteRetouchOfferDto get _offer => widget.offer;
  bool get _resize =>
      widget.offer.operations.contains(RouteRetouchOperation.resize);
  bool get _moveEnd =>
      widget.offer.operations.contains(RouteRetouchOperation.moveEnd);
  RetouchBounds? get _bounds => retouchBounds(_offer);

  @override
  void dispose() {
    _slowTimer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  String _distance(double meters) =>
      AppFormatters.formatDistance(meters, ref.read(unitSystemProvider));

  String _elevation(double meters) =>
      AppFormatters.formatElevation(meters, ref.read(unitSystemProvider));

  void _reset() {
    _run++;
    _slowTimer?.cancel();
    _submitted = null;
    _response = null;
    _error = null;
    _loading = false;
    _selected = 0;
  }

  // ── Cible ──────────────────────────────────────────────────────────────

  RetouchTarget? get _target {
    final RetouchBounds? bounds = _bounds;
    if (_mode == RouteRetouchOperation.resize) {
      final double? km = _targetKm;
      if (km == null || bounds == null) return null;
      if (isDeadZone(km, bounds) || isOutOfRange(km, bounds)) return null;
      return RetouchResize(clampTarget(km, bounds));
    }
    final GeneratorPlace? place = _place;
    if (place != null) return RetouchMoveEnd(placeId: place.id);
    final GeoPoint? point = _endPoint;
    return point == null ? null : RetouchMoveEnd(point: point);
  }

  void _setTarget(double km) {
    final RetouchBounds? bounds = _bounds;
    if (bounds == null) return;
    setState(() {
      _targetKm = (km * 10).round() / 10;
      _reset();
    });
  }

  void _setMode(RouteRetouchOperation mode) => setState(() {
    _mode = mode;
    _reset();
  });

  void _mapTapped(double lon, double lat) {
    if (_mode != RouteRetouchOperation.moveEnd) return;
    setState(() {
      _endPoint = GeoPoint(lng: lon, lat: lat);
      _place = null;
      _reset();
    });
  }

  // ── Appel ──────────────────────────────────────────────────────────────

  Future<void> _submit({bool nextSeed = false}) async {
    final RetouchTarget? target = nextSeed ? _submitted : _target;
    if (target == null) return;
    final int seed = nextSeed ? _seed + 1 : 0;
    final int run = ++_run;
    _slowTimer?.cancel();
    setState(() {
      _submitted = target;
      _seed = seed;
      _loading = true;
      _slow = false;
      _error = null;
      if (!nextSeed) _response = null;
    });
    _slowTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && run == _run) setState(() => _slow = true);
    });
    try {
      final RouteRetouchResponse response = await ref
          .read(routeGeneratorClientProvider)
          .retouchRoute(
            routeSlug: _route.slug,
            teamSlug: _route.team.slug,
            body: routeRetouchRequest(target, seed),
          );
      if (!mounted || run != _run) return;
      setState(() {
        _loading = false;
        _response = response.candidates.isEmpty ? null : response;
        _error = response.candidates.isEmpty ? StateError('empty') : null;
        _selected = 0;
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

  // ── Choix ──────────────────────────────────────────────────────────────

  bool get _quotaSpent {
    final TeamDetailDto? team = ref
        .watch(teamDetailProvider(_route.team.slug))
        .value;
    final bool platformAdmin =
        ref.watch(authProvider).user?.platformRole == 'PLATFORM_ADMIN';
    return isPlannerQuotaSpent(
      team?.plannerQuota,
      platformAdmin: platformAdmin,
    );
  }

  void _choose(RetouchOpening opening) {
    final RetouchedRouteDto? candidate = _response?.candidates[_selected];
    if (opening != RetouchOpening.generator && candidate == null) return;
    Navigator.of(context).pop(
      RetouchChoice(
        opening,
        candidate == null || opening == RetouchOpening.generator
            ? null
            : retouchHandoff(
                candidate,
                _offer,
                opening == RetouchOpening.edit
                    ? _route.name
                    : 'routeRetouch.retouchedName'.tr(
                        namedArgs: <String, String>{'name': _route.name},
                      ),
              ),
      ),
    );
  }

  // ── Carte ──────────────────────────────────────────────────────────────

  List<List<double>> get _original => _route.tracks.isEmpty
      ? const <List<double>>[]
      : <List<double>>[
          for (final List<double> p in _route.tracks.first.line.coordinates)
            <double>[p[0], p[1]],
        ];

  List<PdlMapTrack>? _tracksCache;
  Object? _tracksOf;

  List<PdlMapTrack> _tracks(PdlColors c) {
    final RouteRetouchResponse? response = _response;
    final Object key = (response, _selected);
    if (_tracksCache != null && _tracksOf == key) return _tracksCache!;
    _tracksOf = key;
    final List<List<double>> original = _original;
    if (response == null) {
      return _tracksCache = <PdlMapTrack>[
        PdlMapTrack(
          id: 'original',
          lines: <List<List<double>>>[original],
          color: c.mapTrack,
        ),
      ];
    }
    final RetouchedRouteDto candidate = response.candidates[_selected];
    final List<List<double>> line = <List<double>>[
      for (final LngLat p in decodePolyline6(candidate.polyline))
        <double>[p.lng, p.lat],
    ];
    final List<List<double>> changed = isTruncation(candidate)
        ? const <List<double>>[]
        : changedCoords(
            line,
            candidate.changed.startIndex,
            candidate.changed.endIndex,
          );
    return _tracksCache = <PdlMapTrack>[
      PdlMapTrack(
        id: 'original',
        lines: <List<List<double>>>[original],
        color: c.neutral,
      ),
      PdlMapTrack(
        id: 'retouched',
        lines: <List<List<double>>>[line],
        color: c.mapTrack,
      ),
      if (changed.length >= 2)
        PdlMapTrack(
          id: 'changed',
          lines: <List<List<double>>>[changed],
          color: c.accentOrange,
          emphasized: true,
        ),
    ];
  }

  PdlMapPoint? get _endShown {
    final GeneratorPlace? place = _place;
    if (place != null) return PdlMapPoint(lon: place.lng, lat: place.lat);
    final GeoPoint? point = _endPoint;
    return point == null ? null : PdlMapPoint(lon: point.lng, lat: point.lat);
  }

  Widget _map(PdlColors c) {
    final ResolvedMapStyle? style = ref
        .watch(mapStyleProvider(Theme.of(context).brightness))
        .value;
    if (style == null) return ColoredBox(color: c.surfaceAlt);
    final List<List<double>> original = _original;
    final RouteRetouchResponse? response = _response;
    final BoundsDto? b = response?.candidates[_selected].bounds;
    final bool picking = _mode == RouteRetouchOperation.moveEnd;
    return Semantics(
      label: 'routeRetouch.mapLabel'.tr(),
      child: PdlMap(
        key: keys.routeRetouch.map,
        styleUrl: style.url,
        credit: servedMapCredit(style),
        scale: servedMapScale(ref),
        tracks: _tracks(c),
        selectedTrackId: response == null ? 'original' : 'retouched',
        start: original.isEmpty
            ? null
            : PdlMapPoint(lon: original.first[0], lat: original.first[1]),
        end: _endShown,
        fitBox: b == null
            ? null
            : PdlMapBox(
                minLon: b.minLon,
                minLat: b.minLat,
                maxLon: b.maxLon,
                maxLat: b.maxLat,
              ),
        onMapTapped: picking ? _mapTapped : null,
        overlays: <Widget>[
          if (picking && _endShown == null)
            Positioned(
              left: PdlSpacing.section,
              right: PdlSpacing.section,
              top: PdlSpacing.cardTight,
              child: PdlBanner(
                tone: PdlBannerTone.info,
                icon: PdlIcons.placeEnd,
                message: 'routeRetouch.moveEnd.tapHint'.tr(),
              ),
            ),
          if (response != null)
            Positioned(
              left: PdlSpacing.cardTight,
              bottom: PdlSpacing.cardTight,
              child: _Legend(colors: c),
            ),
        ],
      ),
    );
  }

  // ── Écran ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final double height = MediaQuery.sizeOf(context).height;
    final bool results = _response != null;
    return PdlScreenScaffold(
      appBar: PdlAppBar(
        title: 'routeRetouch.title'.tr(
          namedArgs: <String, String>{'name': _route.name},
        ),
        onBack: () => Navigator.of(context).maybePop(),
        backSemanticLabel: 'common.close'.tr(),
      ),
      actionBar: _actionBar(),
      body: Column(
        children: <Widget>[
          SizedBox(height: height * (results ? 0.42 : 0.34), child: _map(c)),
          Expanded(child: results ? _resultsPanel(c) : _requestPanel(c)),
        ],
      ),
    );
  }

  PdlActionBar _actionBar() {
    if (_response != null) {
      final bool spent = _quotaSpent;
      return PdlActionBar(
        children: <Widget>[
          PdlButton(
            key: keys.routeRetouch.openButton,
            label: 'routeRetouch.open'.tr(),
            variant: widget.canEdit
                ? PdlButtonVariant.outline
                : PdlButtonVariant.fill,
            enabled: !spent && !_loading,
            onPressed: () => _choose(RetouchOpening.newRoute),
          ),
          if (widget.canEdit)
            PdlButton(
              key: keys.routeRetouch.editButton,
              label: 'routeRetouch.edit'.tr(),
              icon: PdlIcons.edit,
              enabled: !spent && !_loading,
              onPressed: () => _choose(RetouchOpening.edit),
            ),
        ],
      );
    }
    return PdlActionBar(
      children: <Widget>[
        PdlButton(
          key: keys.routeRetouch.submitButton,
          label: 'routeRetouch.submit'.tr(),
          icon: PdlIcons.generate,
          loading: _loading,
          enabled: _target != null,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _requestPanel(PdlColors c) {
    final PdlTypography t = context.pdlText;
    final RetouchBounds? bounds = _bounds;
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
        if (_resize && _moveEnd) ...<Widget>[
          PdlSegmented<RouteRetouchOperation>(
            key: keys.routeRetouch.modeSegments,
            value: _mode,
            onChanged: _setMode,
            segments: <PdlSegment<RouteRetouchOperation>>[
              PdlSegment<RouteRetouchOperation>(
                value: RouteRetouchOperation.resize,
                label: 'routeRetouch.resize.action'.tr(),
              ),
              PdlSegment<RouteRetouchOperation>(
                value: RouteRetouchOperation.moveEnd,
                label: 'routeRetouch.moveEnd.action'.tr(),
              ),
            ],
          ),
          gap,
        ],
        if (_mode == RouteRetouchOperation.resize && bounds != null)
          ..._resizeFields(c, t, bounds)
        else
          ..._moveEndFields(c, t),
        if (_loading) ...<Widget>[
          gap,
          Row(
            key: keys.routeRetouch.loading,
            children: <Widget>[
              const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator.adaptive(strokeWidth: 3),
              ),
              const SizedBox(width: PdlSpacing.cardTight),
              Expanded(
                child: Text(
                  _slow
                      ? 'routeRetouch.slow'.tr()
                      : 'routeGenerator.generating'.tr(),
                  style: t.sub.copyWith(color: c.textDimmed),
                ),
              ),
            ],
          ),
        ],
        if (error != null && bounds != null) ...<Widget>[
          gap,
          _errorBlock(error, bounds),
        ],
      ],
    );
  }

  List<Widget> _resizeFields(
    PdlColors c,
    PdlTypography t,
    RetouchBounds bounds,
  ) {
    final double target = _targetKm ?? bounds.currentKm;
    final bool deadZone = isDeadZone(target, bounds);
    final bool outOfRange = isOutOfRange(target, bounds);
    final String? fieldError = _targetKm == null
        ? null
        : deadZone
        ? 'routeRetouch.resize.deadZone'.tr(
            namedArgs: <String, String>{
              'min': _distance(bounds.minChangeKm * 1000),
            },
          )
        : outOfRange
        ? 'routeRetouch.resize.outOfRange'.tr(
            namedArgs: <String, String>{
              'min': _distance(bounds.minKm * 1000),
              'max': _distance(bounds.maxKm * 1000),
            },
          )
        : null;
    // Des écarts depuis la longueur du parcours, pas depuis la cible.
    Widget step(double delta, String label) {
      final double next = bounds.currentKm + delta;
      final bool ok = !isOutOfRange(next, bounds) && !isDeadZone(next, bounds);
      return PdlChip(
        key: keys.routeRetouch.step(delta.round()),
        label: label,
        selected: _targetKm != null && (_targetKm! - next).abs() < 0.05,
        onTap: ok ? () => _setTarget(next) : null,
      );
    }

    String signed(double km) =>
        '${km > 0 ? '+' : '−'}${AppFormatters.formatDistanceRounded(km.abs() * 1000, ref.read(unitSystemProvider))}';
    return <Widget>[
      Text(
        'routeRetouch.current'.tr(
          namedArgs: <String, String>{
            'distance': _distance(bounds.currentKm * 1000),
          },
        ),
        style: t.sub.copyWith(color: c.textDimmed),
      ),
      const SizedBox(height: PdlSpacing.chipGap),
      Text(
        'routeRetouch.resize.label'.tr(),
        style: t.sub.copyWith(color: c.textDimmed, fontWeight: FontWeight.w600),
      ),
      Row(
        children: <Widget>[
          PdlButton(
            key: keys.routeRetouch.minusButton,
            label: '−',
            variant: PdlButtonVariant.outline,
            onPressed: isOutOfRange(target - 1, bounds)
                ? null
                : () => _setTarget(target - 1),
          ),
          Expanded(
            child: Text(
              _distance(target * 1000),
              key: keys.routeRetouch.targetValue,
              textAlign: TextAlign.center,
              style: t.statBigValue,
            ),
          ),
          PdlButton(
            key: keys.routeRetouch.plusButton,
            label: '+',
            variant: PdlButtonVariant.outline,
            onPressed: isOutOfRange(target + 1, bounds)
                ? null
                : () => _setTarget(target + 1),
          ),
        ],
      ),
      SliderTheme(
        data: SliderThemeData(
          trackHeight: 4,
          activeTrackColor: c.primary,
          inactiveTrackColor: c.neutralSoft,
          thumbColor: c.surface,
          overlayColor: c.primary.withValues(alpha: 0.12),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        ),
        child: Slider(
          key: keys.routeRetouch.slider,
          value: target.clamp(bounds.minKm, bounds.maxKm),
          min: bounds.minKm,
          max: bounds.maxKm,
          label: _distance(target * 1000),
          onChanged: (double v) => _setTarget(v),
        ),
      ),
      PdlChipRow(
        padding: EdgeInsets.zero,
        children: <Widget>[
          step(-10, signed(-10)),
          step(-5, signed(-5)),
          step(5, signed(5)),
          step(10, signed(10)),
        ],
      ),
      const SizedBox(height: PdlSpacing.chipGap),
      Text(
        fieldError ??
            'routeRetouch.resize.help'.tr(
              namedArgs: <String, String>{
                'min': _distance(bounds.minKm * 1000),
                'max': _distance(bounds.maxKm * 1000),
              },
            ),
        key: keys.routeRetouch.resizeHelp,
        style: t.sub.copyWith(
          color: fieldError == null ? c.textDimmed : c.dangerOnSoft,
        ),
      ),
      if (fieldError == null &&
          _targetKm != null &&
          isShortening(target, bounds.currentKm)) ...<Widget>[
        const SizedBox(height: PdlSpacing.badgeGap),
        Text(
          'routeRetouch.resize.shortenHint'.tr(),
          style: t.xs.copyWith(color: c.textDimmed),
        ),
      ],
    ];
  }

  List<Widget> _moveEndFields(PdlColors c, PdlTypography t) {
    final List<GeneratorPlace> places = <GeneratorPlace>[
      for (final PlaceDetailDto p
          in ref.watch(generatorPlacesProvider(_route.team.slug)).value ??
              const <PlaceDetailDto>[])
        if (p.endPlace) ?GeneratorPlace.of(p),
    ];
    return <Widget>[
      Text(
        'routeRetouch.moveEnd.help'.tr(),
        style: t.sub.copyWith(color: c.textDimmed),
      ),
      const SizedBox(height: PdlSpacing.chipGap),
      PdlSettingRow(
        key: keys.routeRetouch.endPicked,
        padding: EdgeInsets.zero,
        icon: PdlIcons.placeEnd,
        title:
            _place?.name ??
            (_endPoint != null
                ? 'routeRetouch.moveEnd.picked'.tr()
                : 'routeRetouch.moveEnd.none'.tr()),
      ),
      if (places.isNotEmpty) ...<Widget>[
        const SizedBox(height: PdlSpacing.chipGap),
        Text(
          'routeRetouch.moveEnd.place'.tr(),
          style: t.sub.copyWith(
            color: c.textDimmed,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: PdlSpacing.chipGap),
        PdlChipRow(
          padding: EdgeInsets.zero,
          children: <Widget>[
            for (final GeneratorPlace p in places)
              PdlChip(
                key: keys.routeRetouch.place(p.id),
                label: p.name,
                icon: PdlIcons.place,
                selected: _place?.id == p.id,
                onTap: () => setState(() {
                  _place = p;
                  _endPoint = null;
                  _reset();
                }),
              ),
          ],
        ),
      ],
    ];
  }

  Widget _errorBlock(Object error, RetouchBounds bounds) {
    final bool empty = error is StateError;
    final RetouchTarget? asked = _submitted;
    final double askedKm = asked is RetouchResize
        ? asked.targetKm
        : bounds.currentKm;
    final String message = empty
        ? 'routeRetouch.errors.noProposal'.tr()
        : routeRetouchErrorMessage(
            error,
            distance: _distance(askedKm * 1000),
            current: _distance(bounds.currentKm * 1000),
            min: _distance(bounds.minChangeKm * 1000),
            percent: '${(bounds.maxChangeShare * 100).round()} %',
          );
    final bool info = empty || isInfoRetouchError(error);
    return Column(
      key: keys.routeRetouch.error,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PdlBanner(
          tone: info ? PdlBannerTone.info : PdlBannerTone.danger,
          icon: info ? PdlIcons.info : PdlIcons.warning,
          message: message,
        ),
        const SizedBox(height: PdlSpacing.cardTight),
        Wrap(
          spacing: PdlSpacing.chipGap,
          runSpacing: PdlSpacing.chipGap,
          children: <Widget>[
            if (!empty && isNoShorter(error) && _moveEnd)
              PdlButton(
                label: 'routeRetouch.moveEnd.action'.tr(),
                size: PdlButtonSize.sm,
                variant: PdlButtonVariant.outline,
                onPressed: () => _setMode(RouteRetouchOperation.moveEnd),
              ),
            if (empty || isOtherSeedUseful(error))
              PdlButton(
                key: keys.routeRetouch.moreAfterError,
                label: 'routeRetouch.more'.tr(),
                icon: PdlIcons.refresh,
                size: PdlButtonSize.sm,
                variant: PdlButtonVariant.outline,
                onPressed: () => _submit(nextSeed: true),
              ),
            if (info)
              PdlButton(
                key: keys.routeRetouch.generatorButton,
                label: 'routeRetouch.openGenerator'.tr(),
                icon: PdlIcons.generate,
                size: PdlButtonSize.sm,
                variant: PdlButtonVariant.outline,
                onPressed: () => _choose(RetouchOpening.generator),
              ),
            if (!empty && isRetryableRetouchError(error))
              PdlButton(
                key: keys.routeRetouch.retryButton,
                label: 'routeGenerator.retry'.tr(),
                icon: PdlIcons.refresh,
                size: PdlButtonSize.sm,
                variant: PdlButtonVariant.outline,
                onPressed: () => _submit(nextSeed: _seed > 0),
              ),
          ],
        ),
      ],
    );
  }

  Widget _resultsPanel(PdlColors c) {
    final PdlTypography t = context.pdlText;
    final RouteRetouchResponse response = _response!;
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
                  'routeRetouch.count'.plural(count),
                  style: t.sectionTitle,
                ),
              ),
              PdlButton(
                key: keys.routeRetouch.moreButton,
                label: 'routeRetouch.more'.tr(),
                icon: PdlIcons.refresh,
                size: PdlButtonSize.sm,
                variant: PdlButtonVariant.outline,
                loading: _loading,
                onPressed: () => _submit(nextSeed: true),
              ),
            ],
          ),
        ),
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
              child: _RetouchCard(
                key: keys.routeRetouch.card(i),
                index: i,
                count: count,
                candidate: response.candidates[i],
                response: response,
                selected: i == _selected,
                distance: _distance,
                elevation: _elevation,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            PdlSpacing.section,
            0,
            PdlSpacing.section,
            PdlSpacing.chipGap,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _quotaSpent
                      ? 'routeGenerator.quotaSpent'.tr()
                      : (widget.canEdit
                                ? 'routeRetouch.editHelp'
                                : 'routeRetouch.openHelp')
                            .tr(),
                  style: t.xs.copyWith(color: c.textDimmed),
                ),
              ),
              PdlButton(
                label: 'routeRetouch.editSettings'.tr(),
                size: PdlButtonSize.sm,
                variant: PdlButtonVariant.outline,
                onPressed: () => setState(_reset),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Un lieu d'arrivée de l'équipe, avec sa position.
class GeneratorPlace {
  const GeneratorPlace({
    required this.id,
    required this.name,
    required this.lng,
    required this.lat,
  });

  final String id;
  final String name;
  final double lng;
  final double lat;

  static GeneratorPlace? of(PlaceDetailDto place) {
    final List<double>? c = place.geometry?.coordinates;
    if (c == null || c.length < 2) return null;
    return GeneratorPlace(id: place.id, name: place.name, lng: c[0], lat: c[1]);
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.colors});

  final PdlColors colors;

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    Widget row(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 18,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: PdlRadii.pillAll,
          ),
        ),
        const SizedBox(width: PdlSpacing.chipGap),
        Text(label, style: t.xs),
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.overlaySolid,
        borderRadius: PdlRadii.mdAll,
      ),
      child: Padding(
        padding: const EdgeInsets.all(PdlSpacing.chipGap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            row(colors.mapTrack, 'routeRetouch.legend.kept'.tr()),
            row(colors.accentOrange, 'routeRetouch.legend.new'.tr()),
            row(colors.neutral, 'routeRetouch.legend.original'.tr()),
          ],
        ),
      ),
    );
  }
}

class _RetouchCard extends StatelessWidget {
  const _RetouchCard({
    super.key,
    required this.index,
    required this.count,
    required this.candidate,
    required this.response,
    required this.selected,
    required this.distance,
    required this.elevation,
  });

  final int index;
  final int count;
  final RetouchedRouteDto candidate;
  final RouteRetouchResponse response;
  final bool selected;
  final String Function(double meters) distance;
  final String Function(double meters) elevation;

  String? get _variantKey => switch (candidate.variant) {
    'BEST' => 'routeRetouch.variant.best',
    'KEEP_ALL' => 'routeRetouch.variant.keepAll',
    'NEAREST' => 'routeRetouch.variant.nearest',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final double? before = response.originalAscentM;
    final double? after = candidate.ascentM;
    final RetouchedSpanDto span = candidate.changed;
    final String? variant = _variantKey;
    return PdlCard(
      selected: selected,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'routeRetouch.card.title'.tr(
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
          if (variant != null)
            Text(variant.tr(), style: t.sub.copyWith(color: c.textDimmed)),
          const SizedBox(height: PdlSpacing.chipGap),
          _line(
            t,
            c,
            PdlIcons.distance,
            'routeRetouch.card.distance'.tr(
              namedArgs: <String, String>{
                'before': distance(response.originalDistanceM),
                'after': distance(candidate.distanceM),
              },
            ),
          ),
          if (before != null && after != null)
            _line(
              t,
              c,
              PdlIcons.elevationUp,
              'routeRetouch.card.ascent'.tr(
                namedArgs: <String, String>{
                  'before': elevation(before),
                  'after': elevation(after),
                },
              ),
            ),
          _line(
            t,
            c,
            PdlIcons.route,
            'routeRetouch.card.kept'.tr(
              namedArgs: <String, String>{
                'percent': '${(candidate.keptShare * 100).round()} %',
              },
            ),
          ),
          _line(
            t,
            c,
            PdlIcons.edit,
            isTruncation(candidate)
                ? 'routeRetouch.card.truncated'.tr()
                : 'routeRetouch.card.changed'.tr(
                    namedArgs: <String, String>{
                      'old': distance(span.toM - span.fromM),
                      'new': distance(span.newM),
                    },
                  ),
          ),
          if (candidate.unmatchedM > 0)
            _line(t, c, PdlIcons.info, 'routeRetouch.card.unmatched'.tr()),
        ],
      ),
    );
  }

  Widget _line(PdlTypography t, PdlColors c, IconData icon, String text) =>
      Padding(
        padding: const EdgeInsets.only(top: PdlSpacing.badgeGap),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 16, color: c.textDimmed),
            const SizedBox(width: PdlSpacing.chipGap),
            Expanded(child: Text(text, style: t.sub)),
          ],
        ),
      );
}
