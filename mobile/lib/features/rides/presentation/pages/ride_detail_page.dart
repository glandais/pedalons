import 'package:easy_localization/easy_localization.dart';
// `Visibility` est à la fois un widget Flutter et un enum du contrat.
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/scroll_reveal.dart';
import '../../../../core/utils/share_link.dart';
import '../../../../core/widgets/detail_section.dart';
import '../../../../core/widgets/detail_stat_tiles.dart';
import '../../../../core/widgets/markdown_content.dart';
import '../../../../core/widgets/media_attachments.dart';
import '../../../comments/data/comment_repository.dart';
import '../../../comments/presentation/widgets/comment_thread.dart';
import '../../../moderation/presentation/moderation_menu.dart';
import '../../../participants/presentation/widgets/participants_sheet.dart';
import '../../../teams/domain/publication_timing.dart';
import '../../../teams/providers/team_providers.dart';
import '../../../tags/presentation/content_tags.dart';
import '../../providers/ride_detail_provider.dart';
import '../../providers/ride_editor_providers.dart';
import '../widgets/ride_manage_menu.dart';
import '../../providers/ride_group_selection_provider.dart';
import '../../../routes/domain/track_surfaces.dart';
import '../../providers/ride_registration_controller.dart';
import '../../providers/ride_scroll_target_provider.dart';
import '../../domain/ride_weather_display.dart';
import '../../domain/ride_weather_map.dart';
import '../../domain/solo_group.dart';
import '../../providers/ride_weather_provider.dart';
import 'ride_group_page.dart' show kRideGroupWeatherTab;
import '../widgets/registration_failure_banner.dart';
import '../widgets/ride_departure_block.dart';
import '../widgets/ride_group_participants_section.dart';
import '../widgets/ride_group_stats.dart';
import '../widgets/ride_groups_section.dart';
import '../widgets/ride_registration_control.dart';
import '../widgets/ride_route_section.dart';
import '../widgets/ride_weather_widgets.dart';
import '../widgets/weather_section.dart';
import '../../../feedback/presentation/report_problem_button.dart';
import '../../../../keys.dart';
import '../../../../core/utils/push_location.dart';
import '../../../../screenshots/screenshot_mode.dart';

/// L'écran 12 — détail d'une sortie et inscription à un groupe.
///
/// Trois variantes, selon le nombre de groupes :
///
/// * **Sortie solo** (un groupe) et **sortie sans groupe** — une page qui
///   défile (ledger `MOB-134`, lot 7, KIT §8, maquettes
///   `sortie-solo-mobile-cible`, `sortie-sans-groupe-mobile-cible`) :
///   identité, bandeaux, bloc de départ, tuiles, « Parcours »,
///   « Description », « Personnes inscrites » (solo), « Météo »,
///   « Commentaires ». Une sortie solo n'a pas de page de groupe : ce détail
///   l'est (ledger `MOB-69`) — l'heure du groupe, son inscription dans le bloc
///   de départ, sa météo.
/// * **Plusieurs groupes** — la même ossature (ledger `MOB-134`, lot 8, KIT
///   §8, maquettes `sortie-groupes-meme-heure-mobile-cible`,
///   `sortie-groupes-heures-differentes-mobile-cible`) : identité, bandeaux,
///   bloc de départ à l'heure de **mon** groupe, tuiles « Votre groupe : B »,
///   « Parcours » de toutes les couches, « Description », « Groupes » (une
///   carte par groupe, l'inscription sur chacune), « Météo » au départ de
///   mon groupe, « Commentaires ».
///
/// **Pas de hero** : la vignette statique du tracé doublait la carte
/// interactive qui la suit, et coûtait 210 px de haut avant la première
/// information.
class RideDetailPage extends ConsumerWidget {
  const RideDetailPage({
    super.key,
    required this.teamSlug,
    required this.rideSlug,
    this.now,
  });

  final String teamSlug;
  final String rideSlug;

  /// Un instant, pour les tests ; maintenant sinon.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RideKey key = RideKey(teamSlug: teamSlug, rideSlug: rideSlug);
    final RideRegistrationState registration = ref.watch(
      rideRegistrationProvider(key),
    );

    return registration.ride.when(
      data: (RideDto ride) =>
          _RideDetailContent(rideKey: key, ride: ride, now: now),
      loading: () => const _RideDetailSkeleton(),
      error: (Object error, StackTrace stack) =>
          _RideDetailError(rideKey: key, error: error),
    );
  }
}

// ─────────────────────────────────────────────────────────────── contenu

class _RideDetailContent extends ConsumerStatefulWidget {
  const _RideDetailContent({
    required this.rideKey,
    required this.ride,
    this.now,
  });

  final RideKey rideKey;
  final RideDto ride;
  final DateTime? now;

  @override
  ConsumerState<_RideDetailContent> createState() => _RideDetailContentState();
}

class _RideDetailContentState extends ConsumerState<_RideDetailContent> {
  final ScrollController _scroll = ScrollController();

  /// L'ancre de la météo, cible du défilement « météo » (ledger `MOB-69`) :
  /// la section Météo du détail.
  final GlobalKey _weatherAnchor = GlobalKey();

  /// Un défilement vers la météo est déjà planifié pour ce cadre.
  bool _scrollScheduled = false;

  /// Captures des stores seulement : l'ancre des cartes de groupe (ou des
  /// personnes inscrites d'une sortie solo), et le défilement qui l'attend
  /// tant que la météo n'a pas sa hauteur.
  final GlobalKey _groupsAnchor = GlobalKey();
  bool _scrollToGroups = false;

  /// La carte de « Parcours » : le toucher d'un point de la frise météo la
  /// remonte à l'écran, pour qu'on y voie le réticule.
  final GlobalKey _mapAnchor = GlobalKey();

  /// Le point de la frise dont le réticule est sur la carte : son `index` et
  /// sa distance. `null` : aucun.
  ({int index, double distance})? _cursor;

  RideKey get rideKey => widget.rideKey;
  RideDto get ride => widget.ride;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// La météo se demande-t-elle ? Pas pour une sortie annulée, ni une fois
  /// arrivée : l'API la sert jusqu'à la fin du groupe (ledger `API-170`) ou
  /// de la sortie, et répondrait `OUT_OF_RANGE` au-delà. Une sortie partie
  /// mais pas rentrée la garde (SYNTHESE §6.2) — à plusieurs groupes, tant
  /// que le dernier n'est pas arrivé (`RideDto.endDateTime`, le plus tardif
  /// de ses groupes) : un groupe plus tardif roule encore.
  bool get _asksWeather {
    if (ride.isCancelled) return false;
    final RideGroupDto? solo = soloGroupOf(ride);
    final PublicationPhase phase = solo == null
        ? ridePhase(ride, now: widget.now)
        : rideGroupPhase(ride, solo, now: widget.now);
    return phase != PublicationPhase.finished;
  }

  /// Le leg que l'écran déroule : celui du groupe d'une sortie solo, le leg
  /// unique d'une sortie sans groupe ([rideOwnLeg]) ; `null` à plusieurs
  /// groupes, où la météo est celle de mon groupe ([_multiGroupSlivers]).
  WeatherLegDto? _ownLeg(RideWeatherDto? dto) =>
      dto == null ? null : rideOwnLeg(dto, ride);

  void _maybeScrollToGroups() {
    if (!_scrollToGroups) return;
    if (_asksWeather && ref.watch(rideWeatherProvider(rideKey)).isLoading) {
      return;
    }
    _scrollToGroups = false;
    void reveal() {
      final BuildContext? anchor = _groupsAnchor.currentContext;
      if (mounted && anchor != null) Scrollable.ensureVisible(anchor);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => reveal());
    // Le profil et le revêtement du parcours, au-dessus des cartes, arrivent
    // après la météo et repoussent les groupes vers le bas : on recadre une
    // fois qu'ils ont leur hauteur. La capture attend de toute façon des
    // images stables.
    for (final int s in <int>[2, 4]) {
      Future<void>.delayed(Duration(seconds: s), reveal);
    }
  }

  /// Défile jusqu'à la météo une fois la prévision là — sans elle, le bloc
  /// n'a pas encore sa hauteur, et l'on s'arrêterait au-dessus.
  void _maybeScrollToWeather() {
    if (_scrollScheduled || !ref.watch(rideScrollToWeatherProvider(rideKey))) {
      return;
    }
    final bool weatherSettled =
        !_asksWeather || !ref.watch(rideWeatherProvider(rideKey)).isLoading;
    if (!weatherSettled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!mounted) return;
      ref.read(rideScrollToWeatherProvider(rideKey).notifier).state = false;
      revealInScroll(context, _scroll, _weatherAnchor);
    });
  }

  /// Pose le réticule d'un point de la frise et remonte jusqu'à la carte ;
  /// le même point retouché l'ôte, sans défiler (comme la page d'un groupe,
  /// docs/LEDGER_*.md MOB-134).
  void _toggleCursor(WeatherCheckpointDto checkpoint) {
    final bool off = _cursor?.index == checkpoint.indexField;
    setState(() {
      _cursor = off
          ? null
          : (index: checkpoint.indexField, distance: checkpoint.distance);
    });
    if (off) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) revealInScroll(context, _scroll, _mapAnchor);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool canManage =
        ref.watch(canManageRidesProvider(ride.team.slug)) ?? false;
    final RideGroupDto? solo = soloGroupOf(ride);
    final bool multi = ride.groups.length > 1;

    // Captures des stores seulement : la météo d'un groupe, poussée par-dessus
    // le détail une fois celui-ci chargé — sa page défilée jusqu'à sa section
    // Météo. Une sortie solo n'a pas de page de groupe : le détail défile
    // jusqu'à sa section Météo.
    if (screenshotTakePush('rideGroupWeather')) {
      final RideGroupDto? group = multi
          ? _groupById(resolvedRideGroupId(ref, rideKey, ride))
          : null;
      if (solo != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(rideScrollToWeatherProvider(rideKey).notifier).state =
                true;
          }
        });
      } else if (group != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) _openGroup(group, toWeather: true);
        });
      }
    }
    _maybeScrollToWeather();
    // Captures des stores seulement : le détail cadré sur ses cartes de
    // groupe, que la météo au départ pousse sous la carte.
    if (screenshotTakePush('rideGroups')) _scrollToGroups = true;
    _maybeScrollToGroups();

    // Le mode de la carte et du profil (ledgers `MOB-94`, `MOB-105`). Écouté
    // sans reconstruire la page pour le garder vivant tant qu'elle est
    // montée : `autoDispose`, il tomberait sinon le temps d'un aller-retour
    // par une autre page.
    ref.listen(
      rideMapColorModeProvider(rideKey),
      (RouteColorBy? _, RouteColorBy _) {},
    );
    // Une prévision perdue au refetch ramène « Météo » sur la pente :
    // revenue, elle ne recolore pas le tracé sans nouveau choix (plan
    // 2026-10-24-weather-on-map §4, la règle de `RideGroupPage`).
    if (!multi && _asksWeather) {
      ref.listen(rideWeatherProvider(rideKey), (
        _,
        AsyncValue<RideWeatherDto> next,
      ) {
        if (!showsWindOnMap(_ownLeg(next.value))) dropWindMode(ref, rideKey);
      });
    }

    return PdlScreenScaffold(
      scrollController: _scroll,
      // Le détail **et** la météo : la prévision vit dans son propre provider,
      // et un rafraîchissement qui ne la reprendrait pas laisserait une carte
      // périmée sous un détail frais.
      onRefresh: () async {
        ref.invalidate(rideDetailProvider(rideKey));
        ref.invalidate(rideWeatherProvider(rideKey));
        try {
          await ref.read(rideDetailProvider(rideKey).future);
        } catch (_) {
          // L'échec se rend par l'état d'erreur de l'écran.
        }
      },
      appBar: PdlAppBar(
        // Pas de titre : le corps le porte déjà en 22/700, juste dessous,
        // avec sa ligne d'équipe et ses badges. Le répéter en 17 dans la
        // barre le dit deux fois sur le même écran.
        onBack: () => context.pop(),
        backSemanticLabel: 'common.back'.tr(),
        actions: <Widget>[
          PdlAppBarAction(
            icon: PdlIcons.share,
            semanticLabel: 'routes.share'.tr(),
            onPressed: () => _share(context),
          ),
          // L'organisateur modifie d'un geste, et trouve le reste — publier,
          // annuler, supprimer, signaler — sous `⋯` (ledger `MOB-80`).
          if (canManage && !ride.deleted)
            PdlAppBarAction(
              key: keys.rideManage.editButton,
              icon: PdlIcons.edit,
              semanticLabel: 'rides.manage.edit'.tr(),
              onPressed: () =>
                  context.push(Paths.rideEdit(ride.team.slug, ride.slug)),
            ),
          PdlAppBarAction(
            key: keys.ride.moreButton,
            icon: PdlIcons.more,
            semanticLabel: 'moderation.more'.tr(),
            onPressed: canManage
                ? () => showRideManageMenu(context, ref, ride)
                : () => showDetailModerationMenu(
                    context,
                    subject: ModerationSubject(
                      teamSlug: ride.team.slug,
                      type: ReportTargetType.ride,
                      id: ride.id,
                      teamName: ride.team.name,
                    ),
                  ),
          ),
        ],
      ),
      slivers: multi ? _multiGroupSlivers(context) : _singleSlivers(solo),
    );
  }

  Future<void> _share(BuildContext context) => shareAppLink(
    context,
    title: ride.name,
    path: Paths.ride(ride.team.slug, ride.slug),
  );

  // Ouvre la page d'un groupe : il devient le groupe sélectionné, que le
  // détail montre encore au retour (ledger `MOB-67`).
  void _openGroup(RideGroupDto group, {bool toWeather = false}) {
    selectRideGroup(ref, rideKey, group.id);
    final String path = Paths.rideGroup(ride.team.slug, ride.slug, group.id);
    context.push(toWeather ? '$path?tab=$kRideGroupWeatherTab' : path);
  }

  // ═════════════════════════════════════ sortie solo, sortie sans groupe

  /// La sortie à un seul groupe ([solo]) ou sans groupe ([solo] nul), dans
  /// l'ordre des maquettes `sortie-solo-mobile-cible` et
  /// `sortie-sans-groupe-mobile-cible` (KIT §8).
  List<Widget> _singleSlivers(RideGroupDto? solo) {
    final RideRegistrationState registration = ref.watch(
      rideRegistrationProvider(rideKey),
    );
    final bool asksWeather = _asksWeather;
    final AsyncValue<RideWeatherDto>? weatherState = asksWeather
        ? ref.watch(rideWeatherProvider(rideKey))
        : null;
    final RideWeatherDto? weather = weatherState?.value;
    final WeatherLegDto? leg = _ownLeg(weather);
    final UnitSystem units = ref.watch(unitSystemProvider);
    final List<DetailStatTile> tiles = solo == null
        ? rideStatTiles(ride, units)
        : rideGroupStatTiles(solo, units);
    final bool showsRoute = RideRouteSection.shows(
      ride,
      solo,
      groupOnly: false,
    );
    // Le réticule ne vaut que sur une carte à dessiner et une frise prévue.
    final bool cursorEnabled = showsRoute && showsWindOnMap(leg);
    final bool hasDescription =
        ride.media.markdown.trim().isNotEmpty ||
        ride.media.assets.attachments.isNotEmpty;

    EdgeInsets block({double top = PdlSpacing.section}) =>
        EdgeInsets.fromLTRB(PdlSpacing.section, top, PdlSpacing.section, 0);

    return <Widget>[
      SliverToBoxAdapter(child: _identity(context, single: true)),
      ..._banners(),
      // Les échecs d'inscription, juste au-dessus du bouton qui les cause :
      // persistants, ils nomment le groupe et portent l'action qui résout
      // l'exclusivité.
      if (solo != null && registration.failure != null)
        SliverPadding(
          padding: block(top: 0).copyWith(bottom: PdlSpacing.section),
          sliver: SliverToBoxAdapter(
            child: registrationFailureBanner(
              registration.failure!,
              ref.read(rideRegistrationProvider(rideKey).notifier),
              onViewTeam: () =>
                  pushLocation(context, Paths.team(ride.team.slug)),
            ),
          ),
        ),
      SliverPadding(
        padding: block(top: 0),
        sliver: SliverToBoxAdapter(
          child: RideDepartureBlock(
            key: keys.ride.departureBlock,
            ride: ride,
            // L'heure **du groupe** : une seule heure sur tout l'écran
            // (SYNTHESE §6.1). Sans groupe, celle de la sortie.
            group: solo,
            arrival: solo == null
                ? null
                : rideGroupArrivalLine(ride, solo, leg),
            trailing:
                solo != null &&
                    RideRegistrationControl.shows(
                      ref,
                      ride,
                      solo,
                      now: widget.now,
                    )
                ? RideRegistrationControl(
                    rideKey: rideKey,
                    ride: ride,
                    group: solo,
                    now: widget.now,
                  )
                : null,
            places: ridePlaceLinks(context, ride),
            footnote: solo == null ? 'rides.departureBlock.noGroup'.tr() : null,
            now: widget.now,
          ),
        ),
      ),
      if (tiles.isNotEmpty)
        SliverPadding(
          padding: block(top: PdlSpacing.chipGap),
          sliver: SliverToBoxAdapter(
            child: DetailStatTiles(key: keys.ride.statTiles, tiles: tiles),
          ),
        ),
      if (showsRoute)
        SliverToBoxAdapter(
          child: KeyedSubtree(
            key: keys.ride.routeSection,
            child: RideRouteSection(
              rideKey: rideKey,
              ride: ride,
              group: solo,
              groupOnly: false,
              weatherLeg: leg,
              weatherAttribution: weather?.attribution,
              cursorDistance: cursorEnabled ? _cursor?.distance : null,
              colorByKey: keys.ride.mapColorBy,
              windChipKey: keys.ride.windMapChip,
              profileColorByKey: keys.ride.profileColorBy,
              mapKey: _mapAnchor,
            ),
          ),
        ),
      if (hasDescription)
        SliverToBoxAdapter(
          child: KeyedSubtree(
            key: keys.ride.descriptionSection,
            child: _descriptionSection(),
          ),
        ),
      if (solo != null)
        SliverToBoxAdapter(
          child: KeyedSubtree(
            key: _groupsAnchor,
            child: KeyedSubtree(
              key: keys.ride.participantsSection,
              child: RideGroupParticipantsSection(
                rideKey: rideKey,
                ride: ride,
                group: solo,
                now: widget.now,
              ),
            ),
          ),
        ),
      if (weatherState != null)
        SliverToBoxAdapter(
          child: KeyedSubtree(
            key: _weatherAnchor,
            child: KeyedSubtree(
              key: keys.ride.weatherBlock,
              child: _weatherSection(
                solo,
                weatherState,
                leg,
                cursorEnabled: cursorEnabled,
              ),
            ),
          ),
        ),
      // `commentCount` absent signifie « vous n'avez pas le droit de lire les
      // commentaires » — un non-membre n'est même pas informé qu'il y en a
      // zéro. On ne monte donc pas le fil.
      if (ride.commentCount != null)
        SliverPadding(
          padding: block(top: PdlSpacing.detailSectionGap),
          sliver: SliverToBoxAdapter(
            child: KeyedSubtree(
              key: keys.ride.commentsSection,
              child: _comments(countAtEnd: true),
            ),
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: PdlSpacing.section)),
    ];
  }

  /// « Description » : le texte (`media.markdown`) puis les pièces jointes.
  Widget _descriptionSection() {
    final List<AssetDto> attachments = ride.media.assets.attachments;
    return DetailSection(
      title: 'rides.description'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (ride.media.markdown.trim().isNotEmpty)
            MarkdownContent(
              data: ride.media.markdown,
              images: ride.media.assets.images,
            ),
          MediaAttachments(attachments: attachments),
        ],
      ),
    );
  }

  /// La section Météo, repliée : les commentaires la suivent. Le départ est
  /// celui du leg quand il le porte (le rendez-vous à l'heure du groupe, API
  /// 13.4.0), sinon celui de la sortie. [group] : le groupe de la sortie
  /// solo, ou le mien à plusieurs groupes ([departureOnly] : ni vent ni
  /// frise).
  Widget _weatherSection(
    RideGroupDto? group,
    AsyncValue<RideWeatherDto> state,
    WeatherLegDto? leg, {
    required bool cursorEnabled,
    bool departureOnly = false,
  }) {
    void retry() => ref.invalidate(rideWeatherProvider(rideKey));
    return state.when(
      loading: () => Padding(
        padding: const EdgeInsets.fromLTRB(
          PdlSpacing.section,
          PdlSpacing.detailSectionGap,
          PdlSpacing.section,
          0,
        ),
        child: PdlSkeleton(
          key: keys.ride.weatherLoading,
          height: 120,
          borderRadius: PdlRadii.cardAll,
        ),
      ),
      // Un échec réseau se lit comme `UNAVAILABLE` : « Réessayer » suffit.
      error: (Object _, StackTrace _) => WeatherSection(
        view: RideWeatherView.unavailable,
        timezone: ride.timezone,
        onRetry: retry,
      ),
      data: (RideWeatherDto dto) => WeatherSection(
        view: rideWeatherViewOf(
          dto.status,
          canSeeNoLocation: watchCanSeeWeatherNoLocation(ref, ride.team.slug),
        ),
        timezone: ride.timezone,
        departure: dto.departure,
        departureAt: ride.dateTime,
        groupStartAt: group?.startAt,
        leg: leg,
        departureOnly: departureOnly,
        attribution: dto.attribution,
        fetchedAt: dto.fetchedAt == null
            ? null
            : DateTime.tryParse(dto.fetchedAt!),
        availableFrom: dto.availableFrom == null
            ? null
            : DateTime.tryParse(dto.availableFrom!),
        collapsed: true,
        // Sans groupe, la vitesse par défaut n'est le fait de personne.
        speedDefaultKey: group == null
            ? 'rides.weather.legSpeedDefaultRide'
            : 'rides.weather.legSpeedDefault',
        onRetry: retry,
        onCheckpointTap: cursorEnabled ? _toggleCursor : null,
        selectedCheckpoint: cursorEnabled ? _cursor?.index : null,
      ),
    );
  }

  // ═══════════════════════════════════════════════════ plusieurs groupes

  /// La sortie à plusieurs groupes, dans l'ordre des maquettes
  /// `sortie-groupes-meme-heure-mobile-cible` et
  /// `sortie-groupes-heures-differentes-mobile-cible` (KIT §8, ledger
  /// `MOB-134`, lot 8). Inscrite dans un groupe ([RideDto.joinedGroup]),
  /// l'écran parle de lui : son heure en gros, ses tuiles, sa météo au départ.
  List<Widget> _multiGroupSlivers(BuildContext context) {
    final bool canSeeNames = ref.watch(
      canSeeMemberNamesProvider(ride.team.slug),
    );
    final RideGroupDto? mine = ride.joinedGroup;
    // La sélection est initialisée sur *mon* groupe quand j'en ai un : c'est
    // celui qu'on veut voir en premier sur la carte comme dans le profil.
    final String? selected = resolvedRideGroupId(ref, rideKey, ride);
    // La sélection de l'écran est un **parcours** : celui du groupe
    // sélectionné, ou le parcours principal touché sur la carte quand aucun
    // groupe ne le roule — aucune carte de groupe ne s'allume alors.
    final bool routeOnly =
        ref.watch(selectedRideRouteOverrideProvider(rideKey)) != null;
    final String? selectedRoute = resolvedRideRouteSlug(ref, rideKey, ride);
    final AsyncValue<RideWeatherDto>? weatherState = _asksWeather
        ? ref.watch(rideWeatherProvider(rideKey))
        : null;
    final RideWeatherDto? weather = weatherState?.value;
    // La météo au départ de mon groupe (`WeatherLegDto.departure`, ledger
    // `API-169`) ; inscrite nulle part, celle de la sortie.
    final WeatherLegDto? myLeg = mine == null || weather == null
        ? null
        : weatherLegOfGroup(weather.legs, mine.id);
    final List<DetailStatTile> tiles = mine == null
        ? const <DetailStatTile>[]
        : rideGroupStatTiles(mine, ref.watch(unitSystemProvider));
    final bool showsRoute = RideRouteSection.shows(
      ride,
      null,
      groupOnly: false,
    );
    final bool hasDescription =
        ride.media.markdown.trim().isNotEmpty ||
        ride.media.assets.attachments.isNotEmpty;

    EdgeInsets block({double top = PdlSpacing.section}) =>
        EdgeInsets.fromLTRB(PdlSpacing.section, top, PdlSpacing.section, 0);

    return <Widget>[
      SliverToBoxAdapter(child: _identity(context, single: false)),
      ..._banners(),
      SliverPadding(
        padding: block(top: 0),
        sliver: SliverToBoxAdapter(
          child: RideDepartureBlock(
            key: keys.ride.departureBlock,
            ride: ride,
            // Mon heure en gros, puis « Groupe B · premier départ 09:00 »
            // quand elle n'est pas celle de la sortie. Ni inscription — elle
            // se fait par groupe — ni arrivée estimée.
            group: mine,
            firstDeparture: true,
            places: ridePlaceLinks(context, ride),
            now: widget.now,
          ),
        ),
      ),
      if (tiles.isNotEmpty)
        SliverPadding(
          padding: block(top: PdlSpacing.chipGap),
          sliver: SliverToBoxAdapter(
            child: DetailStatTiles(
              key: keys.ride.statTiles,
              heading: 'rides.departureBlock.yourGroupTitle'.tr(
                namedArgs: <String, String>{'group': mine!.name},
              ),
              tiles: tiles,
            ),
          ),
        ),
      if (showsRoute)
        SliverToBoxAdapter(
          child: KeyedSubtree(
            key: keys.ride.routeSection,
            child: RideRouteSection(
              rideKey: rideKey,
              ride: ride,
              group: routeOnly ? null : _groupById(selected),
              groupOnly: false,
              actions: false,
              profileTitle: 'rides.selectedGroupProfile'.tr(),
              colorByKey: keys.ride.mapColorBy,
              profileColorByKey: keys.ride.profileColorBy,
              mapKey: _mapAnchor,
            ),
          ),
        ),
      if (hasDescription)
        SliverToBoxAdapter(
          child: KeyedSubtree(
            key: keys.ride.descriptionSection,
            child: _descriptionSection(),
          ),
        ),
      SliverToBoxAdapter(
        child: KeyedSubtree(
          key: _groupsAnchor,
          child: RideGroupsSection(
            rideKey: rideKey,
            ride: ride,
            selectedRouteSlug: selectedRoute,
            weather: weather,
            onSelect: (String id) => selectRideGroup(ref, rideKey, id),
            onOpenGroup: _openGroup,
            onShowParticipants: canSeeNames
                ? (RideGroupDto g) => ParticipantsSheet.open(context, ride, g)
                : null,
            onShowRideParticipants: canSeeNames
                ? () => ParticipantsSheet.openRide(context, ride)
                : null,
            onViewTeam: () => pushLocation(context, Paths.team(ride.team.slug)),
            now: widget.now,
          ),
        ),
      ),
      if (weatherState != null)
        SliverToBoxAdapter(
          child: KeyedSubtree(
            key: _weatherAnchor,
            child: KeyedSubtree(
              key: keys.ride.weatherBlock,
              child: _weatherSection(
                mine,
                weatherState,
                myLeg,
                cursorEnabled: false,
                departureOnly: true,
              ),
            ),
          ),
        ),
      if (ride.commentCount != null)
        SliverPadding(
          padding: block(top: PdlSpacing.detailSectionGap),
          sliver: SliverToBoxAdapter(
            child: KeyedSubtree(
              key: keys.ride.commentsSection,
              child: _comments(countAtEnd: true),
            ),
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: PdlSpacing.section)),
    ];
  }

  // ═══════════════════════════════════════════════════════ blocs communs

  // ── Identité ────────────────────────────────────────────────────────────
  /// La ligne d'équipe, le titre, les badges, les tags.
  ///
  /// Les badges disent où en est la sortie, par sa phase (`ridePhase`,
  /// SYNTHESE §6.2) : « Terminée » à la place du statut une fois arrivée,
  /// « En cours » après la visibilité entre le départ et l'arrivée. [single]
  /// — sortie solo ou sans groupe — omet « Inscrit · groupe » : le badge
  /// « J'y vais » du bloc de départ le dit déjà.
  Widget _identity(BuildContext context, {required bool single}) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final RideGroupDto? mine = single ? null : ride.joinedGroup;
    final PublicationPhase phase = ridePhase(ride, now: widget.now);

    return Padding(
      padding: const EdgeInsets.all(PdlSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Le logo d'équipe quand elle en a un (`TeamPublicationDto.logoUrl`,
          // API 5.8.0), sinon les initiales teintées.
          PdlTeamLine(
            label: ride.team.name,
            imageUrl: ride.team.logoUrl,
            onTap: () => pushLocation(context, Paths.team(ride.team.slug)),
          ),
          const SizedBox(height: 2),
          Text(ride.name, key: keys.ride.title, style: t.screenTitle),
          const SizedBox(height: PdlSpacing.chipGap),
          Wrap(
            spacing: PdlSpacing.badgeGap,
            runSpacing: PdlSpacing.badgeGap,
            children: <Widget>[
              if (phase == PublicationPhase.finished && !ride.isCancelled)
                PdlBadge(
                  key: keys.ride.finishedBadge,
                  label: 'rides.finished'.tr(),
                  tone: PdlDerivedTones.done(c),
                )
              else
                PdlBadge(
                  label: 'status.${ride.status.toLowerCase()}'.tr(),
                  tone: Status.fromJson(ride.status).tone(c),
                ),
              PdlBadge(
                label: 'visibility.${ride.visibility.toLowerCase()}'.tr(),
                tone: Visibility.fromJson(ride.visibility).tone(c),
                icon: _visibilityIcon(ride.visibility),
              ),
              if (phase == PublicationPhase.underWay)
                PdlBadge(
                  key: keys.ride.underWayBadge,
                  label: 'teams.agenda.underWay'.tr(),
                  tone: PdlDerivedTones.underWay(c),
                  dot: true,
                ),
              if (mine != null)
                PdlBadge(
                  label: 'rides.registeredIn'.tr(
                    namedArgs: <String, String>{'group': mine.name},
                  ),
                  tone: PdlDerivedTones.registered(c),
                  icon: PdlIcons.check,
                ),
            ],
          ),
          // Tous les tags sur la fiche, sous les badges : ceux-ci disent où en
          // est la sortie, les tags de quoi elle parle (ledger `MOB-39`).
          if (ride.tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: PdlSpacing.chipGap),
            ContentTagRow(tags: ride.tags),
          ],
        ],
      ),
    );
  }

  IconData _visibilityIcon(String visibility) => switch (visibility) {
    'PUBLIC' => PdlIcons.visibilityPublic,
    'PUBLIC_UNLISTED' => PdlIcons.visibilityUnlisted,
    _ => PdlIcons.visibilityTeam,
  };

  // ── Bandeaux : supprimée, annulée, non-membre ───────────────────────────
  List<Widget> _banners() {
    final bool? isMember = ref.watch(teamMembershipProvider(ride.team.slug));
    return <Widget>[
      if (ride.deleted)
        SliverToBoxAdapter(
          child: PdlBanner(
            key: keys.rideManage.deletedBanner,
            tone: PdlBannerTone.warn,
            icon: PdlIcons.delete,
            message: 'rides.manage.deletedBanner'.tr(),
            fullBleed: true,
          ),
        ),
      if (ride.isCancelled)
        SliverToBoxAdapter(
          child: PdlBanner(
            key: keys.ride.cancelledBanner,
            tone: PdlBannerTone.danger,
            icon: PdlIcons.cancelled,
            title: 'rides.cancelledTitle'.tr(),
            message: 'rides.cancelledMessage'.tr(),
            fullBleed: true,
          ),
        ),
      if (isMember == false)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: PdlBanner(
              tone: PdlBannerTone.warn,
              message: 'rides.notMemberBanner'.tr(),
              action: PdlButton(
                label: 'teams.viewTeam'.tr(),
                variant: PdlButtonVariant.outline,
                size: PdlButtonSize.sm,
                onPressed: () =>
                    pushLocation(context, Paths.team(ride.team.slug)),
              ),
            ),
          ),
        ),
    ];
  }

  // ── Commentaires ────────────────────────────────────────────────────────
  Widget _comments({required bool countAtEnd}) {
    final bool? isMember = ref.watch(teamMembershipProvider(ride.team.slug));
    return CommentThread(
      target: CommentTarget(
        entity: CommentEntity.ride,
        teamSlug: ride.team.slug,
        slug: ride.slug,
      ),
      canComment: isMember ?? false,
      countAtEnd: countAtEnd,
    );
  }

  RideGroupDto? _groupById(String? id) {
    if (id == null) return null;
    for (final RideGroupDto g in ride.groups) {
      if (g.id == id) return g;
    }
    return null;
  }
}

// ────────────────────────────────────────────────────── chargement, erreur

/// Squelette **structuré** : les blocs de la page, pas un rond qui tourne.
///
/// Le brief §5 en demande cinq sur une liste ; sur un détail, ce sont les
/// blocs réels qui se dessinent en gris, ce qui annonce la forme de la page.
class _RideDetailSkeleton extends StatelessWidget {
  const _RideDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return PdlScreenScaffold(
      appBar: PdlAppBar(
        onBack: () => context.pop(),
        backSemanticLabel: 'common.back'.tr(),
      ),
      body: ListView(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(PdlSpacing.section),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const PdlSkeleton(height: 12, width: 120),
                const SizedBox(height: PdlSpacing.chipGap),
                const PdlSkeleton(height: 20, width: 220),
                const SizedBox(height: 14),
                for (int i = 0; i < 3; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: PdlSpacing.feedGap),
                  const PdlSkeleton(height: 60),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RideDetailError extends ConsumerWidget {
  const _RideDetailError({required this.rideKey, required this.error});

  final RideKey rideKey;
  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ApiError resolved = resolveApiError(error);
    final bool notFound = resolved.code == 'NOT_FOUND';

    return PdlScreenScaffold(
      appBar: PdlAppBar(
        onBack: () => context.pop(),
        backSemanticLabel: 'common.back'.tr(),
      ),
      body: Center(
        child: PdlEmptyState(
          key: keys.ride.loadError,
          variant: notFound
              ? PdlEmptyVariant.notFound
              : (resolved.isOffline
                    ? PdlEmptyVariant.error
                    : PdlEmptyVariant.error),
          icon: resolved.isOffline ? PdlIcons.offline : null,
          title: resolved.title ?? 'common.loadError'.tr(),
          message: resolved.message,
          actions: <Widget>[
            PdlButton(
              key: keys.ride.loadErrorRetryButton,
              label: 'common.retry'.tr(),
              variant: PdlButtonVariant.outline,
              onPressed: () => ref.invalidate(rideDetailProvider(rideKey)),
            ),
            ReportProblemButton(error: error),
          ],
        ),
      ),
    );
  }
}
