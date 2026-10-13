import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/share_link.dart';
import '../../../../keys.dart';
import '../../../participants/domain/participant_query.dart';
import '../../../participants/presentation/widgets/participant_list_view.dart';
import '../../../participants/providers/participant_list_provider.dart';
import '../../domain/ride_group_tab.dart';
import '../../domain/ride_weather_display.dart';
import '../../domain/solo_group.dart';
import '../../providers/ride_detail_provider.dart';
import '../../providers/ride_group_selection_provider.dart';
import '../../providers/ride_registration_controller.dart';
import '../../providers/ride_scroll_target_provider.dart';
import '../../providers/ride_weather_provider.dart';
import '../widgets/registration_failure_banner.dart';
import '../widgets/ride_group_action_bar.dart';
import '../widgets/ride_group_overview_tab.dart';
import '../widgets/ride_group_weather_tab.dart';

/// La page d'**un** groupe d'une sortie (ledger `MOB-67`).
///
/// Seulement pour une sortie à **plusieurs** groupes : celle d'une sortie
/// solo ou sans groupe cède la place au détail de la sortie dès qu'elle est
/// chargée ([leavesGroupPage], ledger `MOB-69`) — la route reste valide, pour
/// les liens déjà partagés et ceux d'une sortie qui regagnerait un groupe.
///
/// Elle remplace l'écran « Météo du parcours », qui faisait doublon : la météo
/// complète d'un groupe est son onglet Météo. En-tête « Groupe X » sur le nom
/// de la sortie, pastilles des autres groupes, puis trois onglets — Aperçu,
/// Météo, Participants — et la barre d'inscription collée en bas.
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
    this.initialTab = RideGroupTab.overview,
  });

  final String teamSlug;
  final String rideSlug;
  final String groupId;
  final RideGroupTab initialTab;

  @override
  ConsumerState<RideGroupPage> createState() => _RideGroupPageState();
}

class _RideGroupPageState extends ConsumerState<RideGroupPage> {
  late String _groupId = widget.groupId;
  late RideGroupTab _tab = widget.initialTab;

  RideKey get _rideKey =>
      RideKey(teamSlug: widget.teamSlug, rideSlug: widget.rideSlug);

  @override
  void initState() {
    super.initState();
    _shareSelection();
  }

  /// La sélection partagée avec le détail se pose **après** le cadre : pas
  /// pendant un build, où Riverpod lève.
  void _shareSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(selectedRideGroupProvider(_rideKey).notifier).state = _groupId;
    });
  }

  void _selectGroup(String id) {
    if (id == _groupId) return;
    setState(() => _groupId = id);
    _shareSelection();
  }

  void _openTab(RideGroupTab tab) => setState(() => _tab = tab);

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
  /// `?tab=` est abandonné ; l'onglet Météo devient un défilement du détail
  /// jusqu'à sa carte météo, qui déroule le leg du groupe.
  void _leaveForRide() {
    if (!mounted) return;
    if (_tab == RideGroupTab.weather) {
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
    // L'onglet Participants se tire aussi : sa liste n'est pas dans le détail.
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
                  'rides.groupPage.title'.tr(
                    namedArgs: <String, String>{'name': group.name},
                  ),
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

  Widget _content(
    RideDto ride,
    RideGroupDto group,
    RideRegistrationState registration,
  ) {
    final RideKey key = _rideKey;
    final RideRegistrationController controller = ref.read(
      rideRegistrationProvider(key).notifier,
    );
    // Une sortie terminée ou annulée ne demande même pas sa météo.
    final RideWeatherDto? weather = ride.isPast || ride.isCancelled
        ? null
        : ref.watch(rideWeatherProvider(key)).value;
    final WeatherLegDto? leg = weather == null
        ? null
        : weatherLegOfGroup(weather.legs, group.id);

    final Widget body = switch (_tab) {
      RideGroupTab.overview => SliverToBoxAdapter(
        child: RideGroupOverviewTab(
          rideKey: key,
          ride: ride,
          group: group,
          leg: leg,
          onOpenTab: _openTab,
          onSelectGroup: _selectGroup,
        ),
      ),
      RideGroupTab.weather => RideGroupWeatherTab(
        rideKey: key,
        ride: ride,
        groupId: group.id,
      ),
      RideGroupTab.participants => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: PdlSpacing.section),
          child: ParticipantListView(
            // Une liste par groupe : changer de pastille repart de zéro.
            key: ValueKey<String>('participants_${group.id}'),
            source: RideParticipantSource(
              teamSlug: ride.team.slug,
              rideSlug: ride.slug,
              groupId: group.id,
            ),
            count: group.countParticipants,
            organizerId: group.leader?.id,
            team: ride.team,
            alwaysSearchable: true,
            searchHintKey: 'participants.searchByName',
            noMatchMessageKey: 'participants.noMatchGeneric',
          ),
        ),
      ),
    };

    return PdlScreenScaffold(
      key: keys.rideGroup.page,
      appBar: _appBar(ride: ride, group: group),
      onRefresh: _refresh,
      toolbar: _toolbar(ride, group),
      actionBar: RideGroupActionBar(
        rideKey: key,
        ride: ride,
        group: group,
        onOpenGroup: _selectGroup,
      ),
      slivers: <Widget>[
        if (registration.failure != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              PdlSpacing.section,
              PdlSpacing.section,
              PdlSpacing.section,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: registrationFailureBanner(
                registration.failure!,
                controller,
              ),
            ),
          ),
        body,
        const SliverToBoxAdapter(child: SizedBox(height: PdlSpacing.section)),
      ],
    );
  }

  /// Les pastilles des groupes, puis les trois onglets — épinglés : changer
  /// d'onglet reste à portée au bas de la frise des points de passage.
  Widget _toolbar(RideDto ride, RideGroupDto group) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (ride.groups.length > 1) ...<Widget>[
          Semantics(
            label: 'rides.groupPage.groups'.tr(),
            container: true,
            child: PdlChipRow(
              children: <Widget>[
                for (final RideGroupDto g in ride.groups)
                  PdlChip(
                    key: keys.rideGroup.groupChip(g.id),
                    label: '${g.name} · ${_fill(g)}',
                    selected: g.id == group.id,
                    onTap: () => _selectGroup(g.id),
                  ),
              ],
            ),
          ),
          const SizedBox(height: PdlSpacing.chipGap),
        ],
        // `PdlSegmented` exige une largeur bornée : la colonne de la barre
        // d'outils la lui donne.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
          child: PdlSegmented<RideGroupTab>(
            value: _tab,
            onChanged: _openTab,
            segments: <PdlSegment<RideGroupTab>>[
              PdlSegment<RideGroupTab>(
                key: keys.rideGroup.tabOverview,
                value: RideGroupTab.overview,
                label: 'rides.groupPage.tabs.overview'.tr(),
              ),
              PdlSegment<RideGroupTab>(
                key: keys.rideGroup.tabWeather,
                value: RideGroupTab.weather,
                label: 'rides.groupPage.tabs.weather'.tr(),
              ),
              PdlSegment<RideGroupTab>(
                key: keys.rideGroup.tabParticipants,
                value: RideGroupTab.participants,
                label: 'rides.groupPage.tabs.participants'.tr(),
              ),
            ],
          ),
        ),
      ],
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
