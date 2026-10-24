import 'package:easy_localization/easy_localization.dart';
// `Visibility` est à la fois un widget Flutter et un enum du contrat.
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/share_link.dart';
import '../../../../core/widgets/markdown_content.dart';
import '../../../../core/widgets/media_attachments.dart';
import '../../../comments/data/comment_repository.dart';
import '../../../comments/presentation/widgets/comment_thread.dart';
import '../../../moderation/presentation/moderation_menu.dart';
import '../../../participants/presentation/widgets/participants_sheet.dart';
import '../../../teams/providers/team_providers.dart';
import '../../../tags/presentation/content_tags.dart';
import '../../providers/ride_detail_provider.dart';
import '../../providers/ride_editor_providers.dart';
import '../widgets/ride_manage_menu.dart';
import '../../providers/ride_group_selection_provider.dart';
import '../../providers/ride_registration_controller.dart';
import '../../providers/ride_scroll_target_provider.dart';
import '../../domain/ride_weather_display.dart';
import '../../domain/solo_group.dart';
import '../../providers/ride_weather_provider.dart';
import '../widgets/ride_elevation_section.dart';
import '../widgets/ride_groups_map.dart';
import '../widgets/ride_group_action_bar.dart';
import '../widgets/ride_groups_section.dart';
import '../widgets/ride_solo_group_section.dart';
import '../widgets/ride_weather_card.dart';
import '../../../feedback/presentation/report_problem_button.dart';
import '../../../../keys.dart';
import '../../../../core/utils/push_location.dart';
import '../../../../core/widgets/zone_mention_line.dart';
import '../../../../screenshots/screenshot_mode.dart';

/// L'écran 12 — détail d'une sortie et inscription à un groupe.
///
/// Réécrit intégralement. De la v1 il ne reste rien : ni l'`AlertDialog` de
/// choix de groupe, ni le bouton d'action global en bas d'écran qui ne disait
/// pas dans quel groupe il inscrivait, ni la détection d'inscription par
/// parcours de `participants[]`, ni le `SnackBar` que la barre d'onglets
/// masquait.
///
/// Sept sections, dans l'ordre : identité, bandeaux, méta, carte et profil,
/// groupes, description, commentaires. **Pas de hero** : la vignette statique
/// du tracé doublait la carte interactive qui la suit de deux blocs, et
/// coûtait 210 px de haut avant la première information.
///
/// Une sortie **solo** — un seul groupe — n'a pas de page de groupe : ce
/// détail l'est (ledger `MOB-69`). La section Groupes y cède la place à
/// `RideSoloGroupSection`, l'inscription passe dans la barre d'action de la
/// page d'un groupe, et la carte météo déroule le leg du groupe.
class RideDetailPage extends ConsumerWidget {
  const RideDetailPage({
    super.key,
    required this.teamSlug,
    required this.rideSlug,
  });

  final String teamSlug;
  final String rideSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RideKey key = RideKey(teamSlug: teamSlug, rideSlug: rideSlug);
    final RideRegistrationState registration = ref.watch(
      rideRegistrationProvider(key),
    );

    return registration.ride.when(
      data: (RideDto ride) => _RideDetailContent(rideKey: key, ride: ride),
      loading: () => const _RideDetailSkeleton(),
      error: (Object error, StackTrace stack) =>
          _RideDetailError(rideKey: key, error: error),
    );
  }
}

// ─────────────────────────────────────────────────────────────── contenu

class _RideDetailContent extends ConsumerStatefulWidget {
  const _RideDetailContent({required this.rideKey, required this.ride});

  final RideKey rideKey;
  final RideDto ride;

  @override
  ConsumerState<_RideDetailContent> createState() => _RideDetailContentState();
}

class _RideDetailContentState extends ConsumerState<_RideDetailContent> {
  /// L'ancre du bloc météo, cible du défilement « météo » (ledger `MOB-69`).
  final GlobalKey _weatherAnchor = GlobalKey();

  /// Un défilement vers la météo est déjà planifié pour ce cadre.
  bool _scrollScheduled = false;

  /// Captures des stores seulement : l'ancre des cartes de groupe, et le
  /// défilement qui l'attend tant que la météo, au-dessus, n'a pas sa hauteur.
  final GlobalKey _groupsAnchor = GlobalKey();
  bool _scrollToGroups = false;

  RideKey get rideKey => widget.rideKey;
  RideDto get ride => widget.ride;

  void _maybeScrollToGroups() {
    if (!_scrollToGroups) return;
    if (!ride.isPast &&
        !ride.isCancelled &&
        ref.watch(rideWeatherProvider(rideKey)).isLoading) {
      return;
    }
    _scrollToGroups = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? anchor = _groupsAnchor.currentContext;
      if (mounted && anchor != null) Scrollable.ensureVisible(anchor);
    });
  }

  /// Défile jusqu'au bloc météo une fois la prévision là — sans elle, le bloc
  /// n'a pas encore sa hauteur, et l'on s'arrêterait au-dessus.
  void _maybeScrollToWeather() {
    if (_scrollScheduled || !ref.watch(rideScrollToWeatherProvider(rideKey))) {
      return;
    }
    final bool weatherSettled =
        ride.isPast ||
        ride.isCancelled ||
        !ref.watch(rideWeatherProvider(rideKey)).isLoading;
    if (!weatherSettled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!mounted) return;
      ref.read(rideScrollToWeatherProvider(rideKey).notifier).state = false;
      final BuildContext? anchor = _weatherAnchor.currentContext;
      if (anchor != null) {
        Scrollable.ensureVisible(
          anchor,
          duration: PdlMotion.stateChange,
          curve: PdlMotion.stateChangeCurve,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool? isMember = ref.watch(teamMembershipProvider(ride.team.slug));
    final bool canManage =
        ref.watch(canManageRidesProvider(ride.team.slug)) ?? false;

    // Une sortie à un seul groupe : le détail **est** la page de ce groupe
    // (ledger `MOB-69`) — ni carte de groupe, ni lien vers sa page.
    final RideGroupDto? solo = soloGroupOf(ride);

    // La sélection est initialisée sur *mon* groupe quand j'en ai un : c'est
    // celui qu'on veut voir en premier sur la carte comme dans le profil.
    final String? selected =
        solo?.id ??
        ref.watch(selectedRideGroupProvider(rideKey)) ??
        ride.registeredGroupId ??
        (ride.groups.isEmpty ? null : ride.groups.first.id);

    void select(String id) =>
        ref.read(selectedRideGroupProvider(rideKey).notifier).state = id;

    // Ouvre la page d'un groupe : il devient le groupe sélectionné, que le
    // détail montre encore au retour (ledger `MOB-67`).
    void openGroup(RideGroupDto group, {String? tab}) {
      select(group.id);
      final String path = Paths.rideGroup(ride.team.slug, ride.slug, group.id);
      context.push(tab == null ? path : '$path?tab=$tab');
    }

    // Captures des stores seulement : la météo d'un groupe, poussée par-dessus
    // le détail une fois celui-ci chargé — sur l'onglet Météo de sa page. Une
    // sortie solo n'a pas de page de groupe : le détail défile jusqu'à sa
    // météo, qui déroule le leg de son groupe.
    if (screenshotTakePush('rideGroupWeather')) {
      final RideGroupDto? group = _groupById(selected);
      if (solo != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(rideScrollToWeatherProvider(rideKey).notifier).state =
                true;
          }
        });
      } else if (group != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) openGroup(group, tab: 'weather');
        });
      }
    }
    _maybeScrollToWeather();
    // Captures des stores seulement : le détail cadré sur ses cartes de
    // groupe, que la météo au départ pousse sous la carte.
    if (screenshotTakePush('rideGroups')) _scrollToGroups = true;
    _maybeScrollToGroups();

    // Le leg du groupe d'une sortie solo, pour son arrivée estimée. Une
    // sortie terminée ou annulée ne demande même pas sa météo.
    final WeatherLegDto? soloLeg;
    if (solo == null || ride.isPast || ride.isCancelled) {
      soloLeg = null;
    } else {
      final RideWeatherDto? weather = ref
          .watch(rideWeatherProvider(rideKey))
          .value;
      soloLeg = weather == null
          ? null
          : weatherLegOfGroup(weather.legs, solo.id);
    }

    return PdlScreenScaffold(
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
      // La barre d'inscription de la page d'un groupe, pour le groupe d'une
      // sortie solo : places, puis Rejoindre / Quitter / Complet.
      actionBar: solo == null
          ? null
          : RideGroupActionBar(rideKey: rideKey, ride: ride, group: solo),
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
      slivers: <Widget>[
        SliverToBoxAdapter(child: _identity(context)),
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
        SliverToBoxAdapter(child: _meta(context)),
        // La météo au départ, sous les faits qui décident si l'on y va (date,
        // lieu) et avant la carte. Celle de chaque groupe est sur sa carte et
        // dans sa page.
        SliverToBoxAdapter(
          child: KeyedSubtree(
            key: _weatherAnchor,
            child: RideWeatherCard(rideKey: rideKey, ride: ride),
          ),
        ),
        SliverToBoxAdapter(
          child: _mapAndProfile(context, ref, selected, select),
        ),
        SliverToBoxAdapter(
          child: Padding(
            key: _groupsAnchor,
            padding: const EdgeInsets.all(PdlSpacing.section),
            child: solo != null
                ? RideSoloGroupSection(
                    rideKey: rideKey,
                    ride: ride,
                    group: solo,
                    leg: soloLeg,
                    onViewTeam: () =>
                        pushLocation(context, Paths.team(ride.team.slug)),
                  )
                : RideGroupsSection(
                    rideKey: rideKey,
                    ride: ride,
                    isMember: isMember,
                    selectedGroupId: selected,
                    onSelect: select,
                    onOpenGroup: openGroup,
                    onShowParticipants: (RideGroupDto g) =>
                        ParticipantsSheet.open(context, ride, g),
                    onViewTeam: () =>
                        pushLocation(context, Paths.team(ride.team.slug)),
                  ),
          ),
        ),
        if (ride.media.markdown.trim().isNotEmpty ||
            ride.media.assets.attachments.isNotEmpty)
          SliverToBoxAdapter(child: _description(context)),
        // `commentCount` absent signifie « vous n'avez pas le droit de lire les
        // commentaires » — un non-membre n'est même pas informé qu'il y en a
        // zéro. On ne monte donc pas le fil.
        if (ride.commentCount != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(PdlSpacing.section),
              child: CommentThread(
                target: CommentTarget(
                  entity: CommentEntity.ride,
                  teamSlug: ride.team.slug,
                  slug: ride.slug,
                ),
                canComment: isMember ?? false,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: PdlSpacing.section)),
      ],
    );
  }

  Future<void> _share(BuildContext context) => shareAppLink(
    context,
    title: ride.name,
    path: Paths.ride(ride.team.slug, ride.slug),
  );

  // ── 2 · Identité ────────────────────────────────────────────────────────
  Widget _identity(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final RideGroupDto? mine = ride.joinedGroup;

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
              if (ride.isPast && !ride.isCancelled)
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

  // ── 3 · Bloc méta ───────────────────────────────────────────────────────
  Widget _meta(BuildContext context) {
    final PdlTypography t = context.pdlText;
    final DateTime? start = ride.startsAt;

    Widget cell(String label, String value, {Widget? extra}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: t.xs),
        const SizedBox(height: 2),
        Text(value, style: t.statBigValue),
        ?extra,
      ],
    );

    final List<Widget> cells = <Widget>[
      cell(
        'rides.dateAndTime'.tr(),
        start == null ? '—' : AppFormatters.formatLongDate(start),
        // L'heure de la sortie, puis « heure de Tokyo (ven. 01:00 chez vous) »
        // quand le lecteur est ailleurs (docs/LEDGER_*.md API-60).
        extra: start == null
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(AppFormatters.formatTime(start), style: t.xs),
                  ?ZoneMentionLine.maybe(ride.dateTime, ride.timezone),
                ],
              ),
      ),
      cell(
        'participants.title'.tr(),
        'rides.participants'.plural(
          ride.participantCount,
          namedArgs: <String, String>{'count': '${ride.participantCount}'},
        ),
        // Un `PdlButton(text)` et non un `Text` tappable : il porte la cible
        // de 44 px et la sémantique de bouton, que la maquette (un simple
        // lien bleu) ne donne pas.
        extra: ride.groups.isEmpty
            ? null
            : Align(
                alignment: Alignment.centerLeft,
                child: PdlButton(
                  key: keys.ride.participantsButton,
                  label: 'rides.viewParticipants'.tr(),
                  variant: PdlButtonVariant.text,
                  size: PdlButtonSize.sm,
                  onPressed: () => ParticipantsSheet.openRide(context, ride),
                ),
              ),
      ),
      if (ride.startPlace != null)
        PdlPlaceRow(
          kind: PdlPlaceKind.start,
          name: ride.startPlace!.name,
          address: ride.startPlace!.address,
        ),
      if (ride.endPlace != null)
        PdlPlaceRow(
          kind: PdlPlaceKind.end,
          name: ride.endPlace!.name,
          address: ride.endPlace!.address,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: PdlCard(
        flat: true,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // Grille 2 × 2 tant qu'une colonne reste lisible ; une colonne
            // au-delà, plutôt que quatre cellules écrasées.
            final bool twoColumns =
                constraints.maxWidth >= 320 &&
                MediaQuery.textScalerOf(context).scale(14) <= 18;
            if (!twoColumns) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (int i = 0; i < cells.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(height: PdlSpacing.meta2V),
                    cells[i],
                  ],
                ],
              );
            }
            return Wrap(
              spacing: PdlSpacing.meta2H,
              runSpacing: PdlSpacing.meta2V,
              children: <Widget>[
                for (final Widget cell in cells)
                  SizedBox(
                    width:
                        (constraints.maxWidth - PdlSpacing.meta2H) / 2 -
                        PdlSpacing.card,
                    child: cell,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── 4 · Carte, légende, profil ──────────────────────────────────────────
  Widget _mapAndProfile(
    BuildContext context,
    WidgetRef ref,
    String? selected,
    ValueChanged<String> select,
  ) {
    if (ride.groups.isEmpty && ride.routeSlug == null) {
      return const SizedBox.shrink();
    }

    final PdlTypography t = context.pdlText;
    final RideGroupDto? selectedGroup = _groupById(selected);
    final String? routeSlug = selectedGroup?.routeSlug ?? ride.routeSlug;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('rides.groupsRoute'.tr(), style: t.sectionTitle),
        ),
        RideGroupsMap(
          rideKey: rideKey,
          ride: ride,
          selectedGroupId: selected,
          onSelect: select,
        ),
        if (ride.groups.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: PdlLegendRow(
              entries: <PdlLegendEntry>[
                for (final RideGroupDto g in ride.groups)
                  PdlLegendEntry(
                    color: multiTrackColor(g.sortOrder),
                    label: g.name,
                    onTap: () => select(g.id),
                  ),
              ],
              activeIndex: ride.groups.indexWhere(
                (RideGroupDto g) => g.id == selected,
              ),
            ),
          ),
        if (routeSlug != null)
          Padding(
            padding: const EdgeInsets.all(PdlSpacing.section),
            child: RideElevationSection(
              teamSlug: ride.team.slug,
              rideSlug: ride.slug,
              routeSlug: routeSlug,
              distance: selectedGroup?.distance,
              elevationGain: selectedGroup?.elevationGain,
            ),
          ),
      ],
    );
  }

  RideGroupDto? _groupById(String? id) {
    if (id == null) return null;
    for (final RideGroupDto g in ride.groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  // ── 5 · Description et pièces jointes ───────────────────────────────────
  Widget _description(BuildContext context) {
    final List<AssetDto> attachments = ride.media.assets.attachments;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PdlSectionHeader(title: 'rides.description'.tr()),
          if (ride.media.markdown.trim().isNotEmpty)
            MarkdownContent(
              data: ride.media.markdown,
              images: ride.media.assets.images,
            ),
          // Les lignes portaient le nom du fichier sans bouton : elles
          // annonçaient une pièce jointe sans donner de quoi l'ouvrir.
          MediaAttachments(attachments: attachments),
        ],
      ),
    );
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
