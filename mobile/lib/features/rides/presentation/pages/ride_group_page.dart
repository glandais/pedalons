import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/scroll_reveal.dart';
import '../../../../core/utils/share_link.dart';
import '../../../../core/widgets/detail_stat_tiles.dart';
import '../../../../keys.dart';
import '../../../participants/providers/participant_list_provider.dart';
import '../../../teams/domain/publication_timing.dart';
import '../../domain/group_title.dart';
import '../../domain/ride_weather_display.dart';
import '../../domain/ride_weather_map.dart';
import '../../domain/solo_group.dart';
import '../../providers/ride_detail_provider.dart';
import '../../providers/ride_group_selection_provider.dart';
import '../../providers/ride_registration_controller.dart';
import '../../providers/ride_scroll_target_provider.dart';
import '../../providers/ride_weather_provider.dart';
import '../widgets/registration_failure_banner.dart';
import '../widgets/ride_departure_block.dart';
import '../widgets/ride_group_participants_section.dart';
import '../widgets/ride_group_stats.dart';
import '../widgets/ride_registration_control.dart';
import '../widgets/ride_route_section.dart';
import '../widgets/ride_weather_widgets.dart';
import '../widgets/weather_section.dart';

/// La valeur de `?tab=` qui ouvre la page d'un groupe sur sa météo — hors
/// contrat, tolérée pour les liens et notifications déjà émis : la page n'a
/// plus d'onglet, elle défile jusqu'à sa section Météo. Toute autre valeur
/// (`participants`, `overview`…) est ignorée.
const String kRideGroupWeatherTab = 'weather';

/// La page d'**un** groupe d'une sortie (ledgers `MOB-67`, `MOB-134`).
///
/// Seulement pour une sortie à **plusieurs** groupes : celle d'une sortie
/// solo ou sans groupe cède la place au détail de la sortie dès qu'elle est
/// chargée ([leavesGroupPage], ledger `MOB-69`) — la route reste valide, pour
/// les liens déjà partagés et ceux d'une sortie qui regagnerait un groupe.
///
/// Une page qui défile, sans onglets ni barre d'action (maquettes
/// `groupe-mobile-cible`, `groupe-inscrit-mobile-cible`, KIT §8) :
///
/// 1. l'app bar « Groupe A » sur le nom de la sortie, et le partage ;
/// 2. les pastilles des groupes, épinglées (« A · 8/12 », une coche sur celle
///    de mon groupe) ;
/// 3. le bloc de départ : la boîte du jour, « Départ 09:00 » à l'heure **du
///    groupe**, « Arrivée estimée 12:18 », le contrôle d'inscription à droite
///    ([RideRegistrationControl]), les lieux en liens d'itinéraire ;
/// 4. les tuiles Distance | Dénivelé positif / Durée estimée | Vitesse
///    moyenne ([DetailStatTiles]) ;
/// 5. « Parcours » ([RideRouteSection]) ;
/// 6. « Personnes inscrites » ([RideGroupParticipantsSection]) ;
/// 7. « Météo » ([WeatherSection], dépliée : c'est le dernier bloc).
///
/// Ni description, ni commentaires : ils sont sur la sortie.
///
/// Le groupe montré **est** le groupe sélectionné du détail
/// (`selectedRideGroupProvider`) : la page le pose à l'ouverture et à chaque
/// pastille, si bien que le détail montre ce groupe au retour. Elle lit la
/// sortie au même contrôleur d'inscription que le détail, et la météo au même
/// provider : l'ouvrir depuis le détail ne recharge rien.
class RideGroupPage extends ConsumerStatefulWidget {
  const RideGroupPage({
    super.key,
    required this.teamSlug,
    required this.rideSlug,
    required this.groupId,
    this.scrollToWeather = false,
    this.now,
  });

  final String teamSlug;
  final String rideSlug;
  final String groupId;

  /// Défiler jusqu'à la section Météo une fois la page chargée — l'ancien
  /// `?tab=weather` ([kRideGroupWeatherTab]).
  final bool scrollToWeather;

  /// Un instant, pour les tests ; maintenant sinon.
  final DateTime? now;

  @override
  ConsumerState<RideGroupPage> createState() => _RideGroupPageState();
}

class _RideGroupPageState extends ConsumerState<RideGroupPage> {
  late String _groupId = widget.groupId;

  final ScrollController _scroll = ScrollController();

  /// L'ancre de la section Météo, et la barre épinglée qu'un défilement vers
  /// elle doit laisser au-dessus.
  final GlobalKey _weatherAnchor = GlobalKey();
  final GlobalKey _toolbarKey = GlobalKey();

  /// La carte de « Parcours », que le toucher d'un point de la frise remonte
  /// à l'écran pour qu'on y voie le réticule.
  final GlobalKey _mapAnchor = GlobalKey();

  /// Le défilement vers la météo reste à faire (`?tab=weather`).
  late bool _weatherScrollPending = widget.scrollToWeather;

  /// Le point de la frise dont le réticule est sur la carte : son `index` et
  /// sa distance. `null` : aucun.
  ({int index, double distance})? _cursor;

  RideKey get _rideKey =>
      RideKey(teamSlug: widget.teamSlug, rideSlug: widget.rideSlug);

  @override
  void initState() {
    super.initState();
    _shareSelection();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// La sélection partagée avec le détail se pose **après** le cadre : pas
  /// pendant un build, où Riverpod lève.
  void _shareSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      selectRideGroup(ref, _rideKey, _groupId);
    });
  }

  void _selectGroup(String id) {
    if (id == _groupId) return;
    // Un autre groupe : un autre parcours, un autre leg.
    setState(() {
      _groupId = id;
      _cursor = null;
    });
    _shareSelection();
  }

  /// Pose le réticule d'un point de la frise et remonte jusqu'à la carte,
  /// où il se voit ; le même point retouché l'ôte, sans défiler (décision du
  /// 2026-11-10, docs/LEDGER_*.md MOB-134).
  void _toggleCursor(WeatherCheckpointDto checkpoint) {
    final bool off = _cursor?.index == checkpoint.indexField;
    setState(() {
      _cursor = off
          ? null
          : (index: checkpoint.indexField, distance: checkpoint.distance);
    });
    if (off) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      revealInScroll(
        context,
        _scroll,
        _mapAnchor,
        topInset: _toolbarKey.currentContext?.size?.height ?? 0,
      );
    });
  }

  void _backToRide() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Paths.ride(widget.teamSlug, widget.rideSlug));
    }
  }

  /// Le départ vers le détail est planifié une seule fois : chaque
  /// reconstruction en attendant ne doit pas empiler une navigation.
  bool _leaving = false;

  void _scheduleLeaveForRide() {
    if (_leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _leaveForRide());
  }

  /// Remplace cette page par le détail de la sortie, **sans laisser d'entrée
  /// d'historique** (ledger `MOB-69`) :
  /// - le détail de la même sortie est juste dessous (ouverte depuis lui, ou
  ///   lien profond dont la hiérarchie le reconstruit) : `pop` ;
  /// - autre chose dessous (lien interne d'un texte) : `pushReplacement` ;
  /// - rien dessous (ouverture à froid) : `go`.
  ///
  /// Ouverte pour sa météo ([RideGroupPage.scrollToWeather]), elle passe la
  /// consigne au détail : il défile jusqu'à sa carte météo, qui déroule le
  /// leg du groupe.
  void _leaveForRide() {
    if (!mounted) return;
    if (widget.scrollToWeather) {
      ref.read(rideScrollToWeatherProvider(_rideKey).notifier).state = true;
    }
    final String ridePath = Paths.ride(widget.teamSlug, widget.rideSlug);
    if (context.canPop()) {
      if (_rideDetailIsBelow()) {
        context.pop();
      } else {
        context.pushReplacement(ridePath);
      }
    } else {
      context.go(ridePath);
    }
  }

  /// Vrai quand la page juste sous celle-ci est le détail de **cette**
  /// sortie, quelle que soit la langue de son chemin.
  bool _rideDetailIsBelow() {
    final List<String> stack = <String>[];
    void walk(List<RouteMatchBase> matches) {
      for (final RouteMatchBase match in matches) {
        switch (match) {
          case ImperativeRouteMatch():
            stack.add(match.matches.uri.path);
          case ShellRouteMatch():
            walk(match.matches);
          default:
            stack.add(match.matchedLocation);
        }
      }
    }

    walk(GoRouter.of(context).routerDelegate.currentConfiguration.matches);
    if (stack.length < 2) return false;
    final Set<String> ridePaths = PathVariants.ride(
      widget.teamSlug,
      widget.rideSlug,
    ).values.toSet();
    return ridePaths.contains(stack[stack.length - 2]);
  }

  Future<void> _refresh() async {
    ref.invalidate(rideDetailProvider(_rideKey));
    ref.invalidate(rideWeatherProvider(_rideKey));
    // La feuille des personnes inscrites relit sa liste à sa prochaine
    // ouverture.
    ref.invalidate(participantListProvider);
    try {
      await ref.read(rideDetailProvider(_rideKey).future);
    } catch (_) {
      // L'échec se rend par l'état d'erreur de la page.
    }
  }

  @override
  Widget build(BuildContext context) {
    final RideKey key = _rideKey;
    // Surveillé pour le garder vivant : `autoDispose`, il tomberait sinon
    // quand la page est ouverte sans le détail dessous.
    ref.watch(selectedRideGroupProvider(key));
    final RideRegistrationState registration = ref.watch(
      rideRegistrationProvider(key),
    );

    return registration.ride.when(
      loading: () => _skeleton(),
      error: (Object error, StackTrace _) => _error(error),
      data: (RideDto ride) {
        // Une sortie solo ou sans groupe n'a pas de page de groupe : son
        // détail l'est (ledger `MOB-69`). Le squelette le temps de partir.
        if (leavesGroupPage(ride)) {
          _scheduleLeaveForRide();
          return _skeleton();
        }
        final RideGroupDto? group = _groupOf(ride, _groupId);
        if (group == null) return _notFound();
        return _content(ride, group, registration);
      },
    );
  }

  RideGroupDto? _groupOf(RideDto ride, String id) {
    for (final RideGroupDto g in ride.groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  PdlAppBar _appBar({RideDto? ride, RideGroupDto? group}) {
    final PdlTypography t = context.pdlText;
    return PdlAppBar(
      onBack: _backToRide,
      backKey: keys.rideGroup.backButton,
      backSemanticLabel: 'common.back'.tr(),
      titleWidget: group == null || ride == null
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  groupTitle(group.name, 'rides.groupPage.title'.tr()),
                  style: t.barTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  ride.name,
                  style: t.xs,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
      actions: <Widget>[
        if (ride != null && group != null)
          PdlAppBarAction(
            icon: PdlIcons.share,
            semanticLabel: 'rides.groupPage.share'.tr(),
            onPressed: () => shareAppLink(
              context,
              title: '${group.name} · ${ride.name}',
              path: Paths.rideGroup(ride.team.slug, ride.slug, group.id),
            ),
          ),
      ],
    );
  }

  /// La météo se demande-t-elle ? Pas pour une sortie annulée, ni pour un
  /// groupe arrivé : l'API la sert jusqu'à la fin du groupe (ledger
  /// `API-170`), et répondrait `OUT_OF_RANGE` au-delà.
  bool _asksWeather(RideDto ride, RideGroupDto group) =>
      !ride.isCancelled &&
      rideGroupPhase(ride, group, now: widget.now) != PublicationPhase.finished;

  Widget _content(
    RideDto ride,
    RideGroupDto group,
    RideRegistrationState registration,
  ) {
    final RideKey key = _rideKey;
    final RideRegistrationController controller = ref.read(
      rideRegistrationProvider(key).notifier,
    );
    final bool asksWeather = _asksWeather(ride, group);
    final AsyncValue<RideWeatherDto>? weatherState = asksWeather
        ? ref.watch(rideWeatherProvider(key))
        : null;
    final RideWeatherDto? weather = weatherState?.value;
    final WeatherLegDto? leg = weather == null
        ? null
        : weatherLegOfGroup(weather.legs, group.id);
    // Une prévision perdue au refetch ramène le mode « Météo » de la carte
    // sur la pente : revenue, elle ne recolore pas le tracé sans nouveau
    // choix (ledgers `MOB-91`, `MOB-105`, plan 2026-10-24-weather-on-map §4).
    if (asksWeather) {
      ref.listen(rideWeatherProvider(key), (
        _,
        AsyncValue<RideWeatherDto> next,
      ) {
        final RideWeatherDto? dto = next.value;
        final WeatherLegDto? nextLeg = dto == null
            ? null
            : weatherLegOfGroup(dto.legs, group.id);
        if (!showsWindOnMap(nextLeg)) dropWindMode(ref, key);
      });
    }
    _maybeScrollToWeather(weatherState);

    // Le réticule ne vaut que sur une carte à dessiner et une frise prévue.
    final bool cursorEnabled =
        RideRouteSection.shows(ride, group) && showsWindOnMap(leg);

    EdgeInsets block({double top = PdlSpacing.section}) =>
        EdgeInsets.fromLTRB(PdlSpacing.section, top, PdlSpacing.section, 0);

    return PdlScreenScaffold(
      key: keys.rideGroup.page,
      appBar: _appBar(ride: ride, group: group),
      onRefresh: _refresh,
      scrollController: _scroll,
      toolbar: ride.groups.length > 1 ? _toolbar(ride, group) : null,
      slivers: <Widget>[
        // Les échecs d'inscription, en haut du corps : persistants, ils
        // nomment le groupe et portent l'action qui résout l'exclusivité.
        if (registration.failure != null)
          SliverPadding(
            padding: block(),
            sliver: SliverToBoxAdapter(
              child: registrationFailureBanner(
                registration.failure!,
                controller,
              ),
            ),
          ),
        SliverPadding(
          padding: block(),
          sliver: SliverToBoxAdapter(
            child: RideDepartureBlock(
              key: keys.rideGroup.departureBlock,
              ride: ride,
              group: group,
              arrival: rideGroupArrivalLine(ride, group, leg),
              trailing:
                  RideRegistrationControl.shows(
                    ref,
                    ride,
                    group,
                    now: widget.now,
                  )
                  ? RideRegistrationControl(
                      rideKey: key,
                      ride: ride,
                      group: group,
                      now: widget.now,
                    )
                  : null,
              places: ridePlaceLinks(context, ride),
              now: widget.now,
            ),
          ),
        ),
        if (_tiles(group).isNotEmpty)
          SliverPadding(
            padding: block(top: PdlSpacing.chipGap),
            sliver: SliverToBoxAdapter(
              child: DetailStatTiles(
                key: keys.rideGroup.statTiles,
                tiles: _tiles(group),
              ),
            ),
          ),
        if (RideRouteSection.shows(ride, group))
          SliverToBoxAdapter(
            child: KeyedSubtree(
              key: keys.rideGroup.routeSection,
              child: RideRouteSection(
                // Un autre groupe, un autre parcours : l'export repart à neuf.
                key: ValueKey<String>('route_${group.id}'),
                rideKey: key,
                ride: ride,
                group: group,
                weatherLeg: leg,
                weatherAttribution: weather?.attribution,
                cursorDistance: cursorEnabled ? _cursor?.distance : null,
                mapKey: _mapAnchor,
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: KeyedSubtree(
            key: keys.rideGroup.participantsSection,
            child: RideGroupParticipantsSection(
              rideKey: key,
              ride: ride,
              group: group,
              now: widget.now,
            ),
          ),
        ),
        if (weatherState != null)
          SliverToBoxAdapter(
            child: KeyedSubtree(
              key: keys.rideGroup.weatherSection,
              child: KeyedSubtree(
                key: _weatherAnchor,
                child: _weather(
                  ride,
                  group,
                  weatherState,
                  leg,
                  cursorEnabled: cursorEnabled,
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: PdlSpacing.section)),
      ],
    );
  }

  /// Distance | Dénivelé positif, puis Durée estimée | Vitesse moyenne
  /// (KIT §8) ; une tuile sans donnée disparaît.
  List<DetailStatTile> _tiles(RideGroupDto group) =>
      rideGroupStatTiles(group, ref.watch(unitSystemProvider));

  /// La section Météo, dépliée : c'est le dernier bloc de la page. Le départ
  /// est celui du leg quand il le porte (le point de rendez-vous à l'heure du
  /// groupe, API 13.4.0), sinon celui de la sortie — « de la sortie » quand le
  /// groupe part à une autre heure (ledger `BRAND-8`).
  Widget _weather(
    RideDto ride,
    RideGroupDto group,
    AsyncValue<RideWeatherDto> state,
    WeatherLegDto? leg, {
    required bool cursorEnabled,
  }) {
    final RideKey key = _rideKey;
    void retry() => ref.invalidate(rideWeatherProvider(key));
    return state.when(
      loading: () => Padding(
        padding: const EdgeInsets.fromLTRB(
          PdlSpacing.section,
          PdlSpacing.detailSectionGap,
          PdlSpacing.section,
          0,
        ),
        child: PdlSkeleton(
          key: keys.rideGroup.weatherLoading,
          height: 120,
          borderRadius: PdlRadii.cardAll,
        ),
      ),
      error: (Object _, StackTrace _) => WeatherSection(
        view: RideWeatherView.unavailable,
        timezone: ride.timezone,
        onRetry: retry,
      ),
      data: (RideWeatherDto dto) => WeatherSection(
        // `OUT_OF_RANGE`, `NO_LOCATION` pour un membre, statut inconnu : le
        // titre et une ligne d'explication.
        view: rideWeatherViewOf(
          dto.status,
          canSeeNoLocation: watchCanSeeWeatherNoLocation(ref, key.teamSlug),
        ),
        timezone: ride.timezone,
        departure: dto.departure,
        departureAt: ride.dateTime,
        groupStartAt: group.startAt,
        leg: leg,
        attribution: dto.attribution,
        fetchedAt: dto.fetchedAt == null
            ? null
            : DateTime.tryParse(dto.fetchedAt!),
        availableFrom: dto.availableFrom == null
            ? null
            : DateTime.tryParse(dto.availableFrom!),
        onRetry: retry,
        onCheckpointTap: cursorEnabled ? _toggleCursor : null,
        selectedCheckpoint: cursorEnabled ? _cursor?.index : null,
      ),
    );
  }

  /// `?tab=weather` : une fois la météo réglée (chargée, en échec, ou pas
  /// demandée), la page défile jusqu'à sa section — une fois.
  void _maybeScrollToWeather(AsyncValue<RideWeatherDto>? weather) {
    if (!_weatherScrollPending) return;
    if (weather != null && weather.isLoading) return;
    _weatherScrollPending = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealWeather());
  }

  /// La section Météo est le dernier bloc, longtemps sous l'écran : pas
  /// encore construite, on saute d'abord au bas de la page pour qu'elle le
  /// soit, puis on la cale sous la barre épinglée des pastilles.
  Future<void> _revealWeather() async {
    for (int attempt = 0; attempt < 3; attempt++) {
      if (!mounted || !_scroll.hasClients) return;
      final BuildContext? anchor = _weatherAnchor.currentContext;
      final RenderObject? box = anchor?.findRenderObject();
      if (box == null || !box.attached) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
        await WidgetsBinding.instance.endOfFrame;
        continue;
      }
      final double toolbar = _toolbarKey.currentContext?.size?.height ?? 0;
      final double target =
          RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset -
          toolbar;
      final ScrollPosition position = _scroll.position;
      _scroll.jumpTo(
        target.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
      return;
    }
  }

  /// Les pastilles des groupes, épinglées : « A · 8/12 », et une coche sur
  /// celle de mon groupe.
  Widget _toolbar(RideDto ride, RideGroupDto group) {
    final String? mine = ride.joinedGroup?.id;
    return Semantics(
      key: _toolbarKey,
      label: 'rides.groupPage.groups'.tr(),
      container: true,
      child: PdlChipRow(
        children: <Widget>[
          for (final RideGroupDto g in ride.groups)
            PdlChip(
              key: keys.rideGroup.groupChip(g.id),
              label: '${g.name} · ${_fill(g)}',
              icon: g.id == mine ? PdlIcons.check : null,
              selected: g.id == group.id,
              onTap: () => _selectGroup(g.id),
            ),
        ],
      ),
    );
  }

  /// « 11/12 », ou « 11 » sans plafond.
  String _fill(RideGroupDto g) => g.maxParticipants == null
      ? '${g.countParticipants}'
      : '${g.countParticipants}/${g.maxParticipants}';

  // ──────────────────────────────────────────── chargement, erreur, absent

  Widget _skeleton() => PdlScreenScaffold(
    appBar: _appBar(),
    body: ListView(
      padding: const EdgeInsets.all(PdlSpacing.section),
      children: const <Widget>[
        PdlSkeleton(height: 20, width: 200),
        SizedBox(height: PdlSpacing.section),
        PdlSkeleton(height: 44, borderRadius: PdlRadii.cardAll),
        SizedBox(height: PdlSpacing.section),
        PdlSkeleton(height: 220, borderRadius: PdlRadii.cardAll),
        SizedBox(height: PdlSpacing.section),
        PdlSkeleton(height: 96, borderRadius: PdlRadii.cardAll),
      ],
    ),
  );

  Widget _error(Object error) {
    final ApiError resolved = resolveApiError(error);
    return PdlScreenScaffold(
      appBar: _appBar(),
      body: Center(
        child: PdlEmptyState(
          variant: resolved.code == 'NOT_FOUND'
              ? PdlEmptyVariant.notFound
              : PdlEmptyVariant.error,
          icon: resolved.isOffline ? PdlIcons.offline : null,
          title: resolved.title ?? 'common.loadError'.tr(),
          message: resolved.message,
          actions: <Widget>[
            PdlButton(
              label: 'common.retry'.tr(),
              variant: PdlButtonVariant.outline,
              onPressed: () => ref.invalidate(rideDetailProvider(_rideKey)),
            ),
          ],
        ),
      ),
    );
  }

  /// Un lien ancien ou partagé vers un groupe retiré de la sortie : un état
  /// vide et le chemin du retour, jamais un écran blanc.
  Widget _notFound() => PdlScreenScaffold(
    appBar: _appBar(),
    body: Center(
      child: PdlEmptyState(
        key: keys.rideGroup.notFound,
        variant: PdlEmptyVariant.notFound,
        title: 'rides.groupPage.notFoundTitle'.tr(),
        message: 'rides.groupPage.notFoundMessage'.tr(),
        actions: <Widget>[
          PdlButton(
            key: keys.rideGroup.backToRide,
            label: 'rides.groupPage.backToRide'.tr(),
            variant: PdlButtonVariant.outline,
            onPressed: _backToRide,
          ),
        ],
      ),
    ),
  );
}
