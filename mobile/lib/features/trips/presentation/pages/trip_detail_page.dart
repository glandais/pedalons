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
import '../../../../core/utils/directions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/share_link.dart';
import '../../../../core/widgets/day_box.dart';
import '../../../../core/widgets/detail_section.dart';
import '../../../../core/widgets/detail_stat_tiles.dart';
import '../../../../core/widgets/markdown_content.dart';
import '../../../../core/widgets/media_attachments.dart';
import '../../../../core/widgets/zone_mention_line.dart';
import '../../../../core/widgets/team_banner.dart';
import '../../../../keys.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../calendar/presentation/widgets/calendar_subscription_card.dart';
import '../../../comments/data/comment_repository.dart';
import '../../../comments/presentation/widgets/comment_thread.dart';
import '../../../feedback/presentation/report_problem_button.dart';
import '../../../moderation/presentation/moderation_menu.dart';
import '../../../participants/presentation/widgets/participants_sheet.dart';
import '../../../tags/presentation/content_tags.dart';
import '../../../teams/domain/publication_timing.dart';
import '../../domain/trip_weather_map.dart';
import '../../providers/trip_detail_provider.dart';
import '../../providers/trip_participation_controller.dart';
import '../../providers/trip_stage_selection_provider.dart';
import '../../providers/trip_weather_provider.dart';
import '../widgets/stage_card.dart';
import '../widgets/trip_elevation.dart';
import '../widgets/trip_map.dart';

/// L'écran du voyage, **le même pour une ou plusieurs étapes** (ledger
/// `MOB-134`, lot 9, KIT §8, maquettes `voyage-etapes-mobile-cible`,
/// `voyage-une-etape-mobile-cible`) — une page qui défile, de haut en bas :
///
/// 1. l'identité (équipe, titre, badges dont la phase, tags) ;
/// 2. les bandeaux (annulé, non-membre) et l'échec d'inscription ;
/// 3. le bloc de départ : dates du voyage, lieu de la première étape en lien
///    d'itinéraire, et l'inscription à droite de l'heure — « Rejoindre », ou
///    le badge « J'y vais » ;
/// 4. les tuiles : Distance | Dénivelé (cumulés), Durée | Étapes ;
/// 5. « Parcours » : la carte de toutes les étapes, sans légende — chaque
///    carte d'étape porte sa couleur —, l'interrupteur Étapes | Météo et le
///    profil ;
/// 6. « Description » et ses pièces jointes ;
/// 7. « Étapes » : une carte par étape ;
/// 8. « Personnes inscrites » ;
/// 9. les commentaires.
///
/// **Pas de section Météo**, même à une étape (décision du 2026-11-10) : la
/// météo est sur les cartes d'étape et sur la page de chaque étape. Pas de
/// barre d'action non plus : l'inscription est dans le bloc de départ.
class TripDetailPage extends ConsumerWidget {
  const TripDetailPage({
    super.key,
    required this.teamSlug,
    required this.tripSlug,
    this.now,
  });

  final String teamSlug;
  final String tripSlug;

  /// Un instant, pour les tests ; maintenant sinon.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TripKey key = TripKey(teamSlug: teamSlug, tripSlug: tripSlug);
    // Le voyage se lit sur le contrôleur, pas sur le détail : c'est lui qui
    // porte la bascule optimiste.
    final TripParticipationState participation = ref.watch(
      tripParticipationProvider(key),
    );

    return participation.trip.when(
      data: (TripDto trip) =>
          _TripDetailContent(tripKey: key, trip: trip, now: now),
      loading: () => const _TripDetailSkeleton(),
      error: (Object error, StackTrace stack) =>
          _TripDetailError(tripKey: key, error: error),
    );
  }
}

/// Les tuiles d'un voyage, dans l'ordre du KIT §8 : Distance | Dénivelé
/// (cumulés), puis Durée | Étapes. Une valeur inconnue ôte sa tuile plutôt
/// que d'écrire « 0 km » : un voyage dont aucune étape n'a de parcours n'a
/// pas une distance nulle, il n'en a pas.
List<DetailStatTile> tripStatTiles(TripDto trip, UnitSystem units) {
  final String? duration = tripDurationLabel(trip);
  return <DetailStatTile>[
    if (trip.totalDistance != null)
      DetailStatTile(
        label: 'trips.summary.totalDistance'.tr(),
        value: AppFormatters.formatDistance(trip.totalDistance!, units),
      ),
    if (trip.totalElevationGain != null)
      DetailStatTile(
        label: 'trips.summary.totalElevation'.tr(),
        value: AppFormatters.formatElevation(trip.totalElevationGain!, units),
      ),
    if (duration != null)
      DetailStatTile(label: 'trips.summary.duration'.tr(), value: duration),
    if (trip.stageCount > 0)
      DetailStatTile(label: 'trips.stages'.tr(), value: '${trip.stageCount}'),
  ];
}

/// « 3 jours », « 1 jour » — `endDate` nul signifie un voyage d'un jour, par
/// contrat. Le départ se lit dans le fuseau de la première étape, la fin dans
/// celui de la dernière ([TripTiming.endsAt]) : la durée compte les jours
/// vécus. `null` sans date de départ lisible.
String? tripDurationLabel(TripDto trip) {
  final DateTime? start = trip.startsAt;
  if (start == null) return null;
  final DateTime end = trip.endsAt ?? start;
  // Comptés sur des dates UTC : un écart de minuits locaux perd une heure au
  // passage à l'heure d'été, et `inDays` tomberait d'un jour.
  final int days =
      DateTime.utc(
        end.year,
        end.month,
        end.day,
      ).difference(DateTime.utc(start.year, start.month, start.day)).inDays +
      1;
  return 'trips.summary.days'.plural(days < 1 ? 1 : days);
}

// ─────────────────────────────────────────────────────────────── contenu

class _TripDetailContent extends ConsumerWidget {
  const _TripDetailContent({
    required this.tripKey,
    required this.trip,
    this.now,
  });

  final TripKey tripKey;
  final TripDto trip;
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ce que le backend dit de **ce** voyage (docs/LEDGER_*.md MOB-137) :
    // jamais déduit du rôle ni de la visibilité de l'équipe.
    final ContentPermissionsDto permissions = trip.permissions;
    final bool canRegister = permissions.canRegister ?? false;
    final VoidCallback? viewTeam = teamLinkOf(context, trip.team);
    final List<TripStageDto> stages = trip.orderedStages;
    final String? selected = ref.watch(selectedStageProvider(tripKey));
    final PublicationPhase phase = tripPhase(trip, now: now);
    // Le mode « Météo » de la carte d'ensemble (ledger `MOB-94`) : gardé en
    // vie tant que la page est montée, éteint quand plus aucune étape n'a de
    // prévision.
    listenTripMapWindMode(
      ref,
      tripKey,
      trip,
      stillShows: (Map<String, WeatherLegDto> legs) => legs.isNotEmpty,
    );

    void select(String id) =>
        ref.read(selectedStageProvider(tripKey).notifier).state = id;

    final TripParticipationState participation = ref.watch(
      tripParticipationProvider(tripKey),
    );
    final List<DetailStatTile> tiles = tripStatTiles(
      trip,
      ref.watch(unitSystemProvider),
    );
    final bool hasDescription =
        trip.media.markdown.trim().isNotEmpty ||
        trip.media.assets.attachments.isNotEmpty;

    EdgeInsets block({double top = PdlSpacing.section}) =>
        EdgeInsets.fromLTRB(PdlSpacing.section, top, PdlSpacing.section, 0);

    return PdlScreenScaffold(
      // Le détail est relu ; le contrôleur de participation l'adopte, et la
      // page reste affichée pendant l'appel (`skipLoadingOnRefresh`). Un échec
      // n'a pas à remonter jusqu'à l'indicateur : le détail passe en erreur et
      // l'écran d'erreur, avec son « Réessayer », prend la place.
      onRefresh: () async {
        ref.invalidate(tripWeatherProvider(tripKey));
        try {
          ref.invalidate(tripDetailProvider(tripKey));
          await ref.read(tripDetailProvider(tripKey).future);
        } catch (_) {}
      },
      appBar: PdlAppBar(
        // Pas de titre : le corps le porte déjà en 22/700, juste dessous,
        // avec sa ligne d'équipe et ses badges. Le répéter en 17 dans la
        // barre le dit deux fois sur le même écran.
        onBack: () => context.pop(),
        backSemanticLabel: 'common.back'.tr(),
        actions: <Widget>[
          // Aucun endpoint ICS par publication (§5.2) : « Ajouter à mon
          // calendrier » ouvre l'abonnement d'équipe de l'écran 22, qui porte
          // le voyage parmi ses événements. Un non-membre n'a pas ce
          // calendrier — le bouton disparaît plutôt que d'échouer. La règle de
          // l'Agenda de l'équipe (membre ou administration de la plateforme)
          // est celle de `canSeeParticipants`, et l'équipe doit se consulter.
          if (permissions.canSeeParticipants == true && trip.team.accessible)
            PdlAppBarAction(
              icon: PdlIcons.date,
              semanticLabel: 'trips.addToCalendar'.tr(),
              onPressed: () => _openCalendarSubscription(context),
            ),
          PdlAppBarAction(
            icon: PdlIcons.share,
            semanticLabel: 'routes.share'.tr(),
            onPressed: () => _share(context),
          ),
          PdlAppBarAction(
            key: keys.trip.moreButton,
            icon: PdlIcons.more,
            semanticLabel: 'moderation.more'.tr(),
            onPressed: () => showDetailModerationMenu(
              context,
              subject: ModerationSubject(
                teamSlug: trip.team.slug,
                type: ReportTargetType.trip,
                id: trip.id,
                teamName: trip.team.name,
              ),
            ),
          ),
        ],
      ),
      slivers: <Widget>[
        SliverToBoxAdapter(child: _identity(context, phase)),
        if (trip.isCancelled)
          SliverToBoxAdapter(
            child: PdlBanner(
              key: keys.trip.cancelledBanner,
              tone: PdlBannerTone.danger,
              icon: PdlIcons.cancelled,
              title: 'trips.cancelledTitle'.tr(),
              message: 'trips.cancelledMessage'.tr(),
              fullBleed: true,
            ),
          ),
        // Ni inscription ni noms pour qui n'est pas membre (`canComment` :
        // membre ou administration de la plateforme). Une équipe que
        // l'appelant ne peut pas consulter n'offre pas de lien vers elle.
        if (permissions.canComment != true)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: PdlBanner(
                key: keys.trip.notMemberBanner,
                tone: PdlBannerTone.warn,
                message: viewTeam == null
                    ? 'trips.privateTeamBanner'.tr()
                    : 'trips.notMemberBanner'.tr(),
                action: viewTeam == null
                    ? null
                    : PdlButton(
                        label: 'teams.viewTeam'.tr(),
                        variant: PdlButtonVariant.outline,
                        size: PdlButtonSize.sm,
                        onPressed: viewTeam,
                      ),
              ),
            ),
          ),
        // L'échec d'inscription, juste au-dessus du bouton qui le cause.
        if (participation.failure != null)
          SliverPadding(
            padding: block(top: 0).copyWith(bottom: PdlSpacing.section),
            sliver: SliverToBoxAdapter(
              child: _failureBanner(context, ref, participation.failure!),
            ),
          ),
        if (_departure(context, ref, participation, canRegister, phase)
            case final Widget departure)
          SliverPadding(
            padding: block(top: 0),
            sliver: SliverToBoxAdapter(child: departure),
          ),
        if (tiles.isNotEmpty)
          SliverPadding(
            padding: block(top: PdlSpacing.chipGap),
            sliver: SliverToBoxAdapter(
              child: DetailStatTiles(key: keys.trip.statTiles, tiles: tiles),
            ),
          ),
        if (TripMap.shows(trip))
          SliverToBoxAdapter(
            child: KeyedSubtree(
              key: keys.trip.routeSection,
              child: DetailSection(
                title: 'rides.routeSection.title'.tr(),
                bleed: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TripMap(
                      tripKey: tripKey,
                      trip: trip,
                      selectedStageId: selected,
                      onSelect: select,
                    ),
                    Padding(
                      padding: block(),
                      child: TripElevationSection(tripKey: tripKey, trip: trip),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (hasDescription)
          SliverToBoxAdapter(
            child: KeyedSubtree(
              key: keys.trip.descriptionSection,
              child: _description(),
            ),
          ),
        SliverToBoxAdapter(
          child: KeyedSubtree(
            key: keys.trip.stagesSection,
            child: _stages(
              context,
              stages,
              selected,
              select,
              _stageSummaries(ref, phase),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: KeyedSubtree(
            key: keys.trip.participants,
            child: _participants(context, ref, participation),
          ),
        ),
        // `commentCount` absent signifie « vous n'avez pas le droit de lire les
        // commentaires » : le fil n'est pas monté du tout.
        if (trip.commentCount != null)
          SliverPadding(
            padding: block(top: PdlSpacing.detailSectionGap),
            sliver: SliverToBoxAdapter(
              child: KeyedSubtree(
                key: keys.trip.commentsSection,
                child: CommentThread(
                  target: CommentTarget(
                    entity: CommentEntity.trip,
                    teamSlug: trip.team.slug,
                    slug: trip.slug,
                  ),
                  canComment: permissions.canComment ?? false,
                  countAtEnd: true,
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: PdlSpacing.section)),
      ],
    );
  }

  // ── Inscription ─────────────────────────────────────────────────────────
  /// À droite de l'heure de départ : « Rejoindre » tant que le voyage n'est
  /// pas terminé — un voyage en cours reste ouvert, ses étapes suivantes sont
  /// à rouler (la règle du serveur, `TripService.joinTrip`) —, pour un membre
  /// de l'équipe et un voyage maintenu ; inscrit, le badge « J'y vais », qui
  /// reste sur un voyage annulé. Se désinscrire est le lien du pied de
  /// « Personnes inscrites ». Rien sinon.
  Widget? _registrationControl(
    BuildContext context,
    WidgetRef ref,
    TripParticipationState participation,
    bool canRegister,
    PublicationPhase phase,
  ) {
    if (trip.registered) {
      return PdlBadge(
        key: keys.trip.goingBadge,
        label: 'rides.registered'.tr(),
        tone: PdlDerivedTones.registered(context.pdl),
        size: PdlBadgeSize.lg,
      );
    }
    // `canRegister` : membre et voyage publié, pas terminé — le backend le
    // calcule sur le détail (docs/LEDGER_*.md MOB-137).
    if (trip.isCancelled ||
        phase == PublicationPhase.finished ||
        !canRegister) {
      return null;
    }
    return PdlButton(
      key: keys.trip.joinButton,
      label: 'trips.join'.tr(),
      loading: participation.pending,
      loadingLabel: 'trips.joining'.tr(),
      onPressed: ref.read(tripParticipationProvider(tripKey).notifier).join,
    );
  }

  Widget _failureBanner(
    BuildContext context,
    WidgetRef ref,
    TripParticipationFailure failure,
  ) {
    final TripParticipationController controller = ref.read(
      tripParticipationProvider(tripKey).notifier,
    );

    return PdlBanner(
      tone: PdlBannerTone.danger,
      title: 'trips.participationFailedTitle'.tr(),
      message: failure.message,
      onDismiss: controller.dismissFailure,
      dismissSemanticLabel: 'common.close'.tr(),
      action: failure.reason == TripParticipationFailureReason.notMember
          ? (trip.team.accessible
                ? PdlButton(
                    label: 'teams.viewTeam'.tr(),
                    variant: PdlButtonVariant.outline,
                    size: PdlButtonSize.sm,
                    onPressed: teamLinkOf(context, trip.team),
                  )
                : null)
          : PdlButton(
              label: 'common.retry'.tr(),
              variant: PdlButtonVariant.outline,
              size: PdlButtonSize.sm,
              onPressed: trip.registered ? controller.leave : controller.join,
            ),
    );
  }

  Future<void> _share(BuildContext context) => shareAppLink(
    context,
    title: trip.name,
    path: Paths.trip(trip.team.slug, trip.slug),
  );

  Future<void> _openCalendarSubscription(BuildContext context) {
    return PdlSheet.show<void>(
      context: context,
      builder: (BuildContext _) => PdlSheet(
        title: 'calendar.subscription.title'.tr(),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
            child: CalendarSubscriptionCard(teamSlug: trip.team.slug),
          ),
        ],
      ),
    );
  }

  // ── Personnes inscrites ─────────────────────────────────────────────────
  /// Le titre et le compte, la grappe d'avatars et « Voir toutes les
  /// personnes inscrites », puis, inscrit, le lien « Se désinscrire ».
  ///
  /// **Aucun nom pour un non-membre** (`permissions.canSeeParticipants`,
  /// calculé par le backend, ledgers `API-144`, `MOB-137`) : le compte seul,
  /// ni visages ni liste.
  Widget _participants(
    BuildContext context,
    WidgetRef ref,
    TripParticipationState participation,
  ) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final bool canSeeNames = trip.permissions.canSeeParticipants ?? false;
    final String? currentUserId = ref.watch(
      authProvider.select((AuthState s) => s.user?.id),
    );
    final int count = trip.participantCount;
    final bool canLeave = trip.registered && !trip.isCancelled;

    return DetailSection(
      title: 'participants.title'.tr(),
      count: '$count',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (canSeeNames && trip.participants.isNotEmpty) ...<Widget>[
            const SizedBox(height: PdlSpacing.chipGap),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: PdlAvatarStack(
                key: keys.trip.participantsAvatars,
                people: <PdlAvatarEntry>[
                  for (final PublicUserDto p in trip.participants)
                    PdlAvatarEntry(
                      name: p.displayName,
                      imageUrl: p.avatarUrl,
                      isCurrentUser: p.id == currentUserId,
                    ),
                ],
                // `participants` n'est que l'aperçu des premiers inscrits
                // (ledger `API-12`) : le « +N » compte le reste.
                total: count,
                onTap: () => ParticipantsSheet.openTrip(context, trip),
                semanticLabel: 'trips.participants'.plural(
                  count,
                  namedArgs: <String, String>{'count': '$count'},
                ),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: PdlButton(
                key: keys.trip.viewAllParticipants,
                label: 'rides.groupPage.viewAllParticipants'.tr(),
                variant: PdlButtonVariant.text,
                size: PdlButtonSize.sm,
                icon: PdlIcons.chevronRight,
                onPressed: () => ParticipantsSheet.openTrip(context, trip),
              ),
            ),
          ] else if (count == 0) ...<Widget>[
            const SizedBox(height: PdlSpacing.chipGap),
            Text('participants.emptyTripMessage'.tr(), style: t.sub),
          ],
          // « Se désinscrire » : un lien discret en couleur de danger, sur
          // 44 px de haut, comme « Quitter le groupe » d'une sortie — pas un
          // bouton qui pèserait autant que « Rejoindre ». Sans confirmation.
          if (canLeave)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Semantics(
                button: true,
                enabled: !participation.pending,
                child: InkWell(
                  key: keys.trip.leaveButton,
                  onTap: participation.pending
                      ? null
                      : ref
                            .read(tripParticipationProvider(tripKey).notifier)
                            .leave,
                  borderRadius: PdlRadii.mdAll,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: PdlMetrics.tapTarget,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: 1,
                      child: Text(
                        participation.pending
                            ? 'trips.leaving'.tr()
                            : 'trips.leave'.tr(),
                        style: t.sub.copyWith(
                          color: participation.pending
                              ? c.textDimmed
                              : c.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Identité ────────────────────────────────────────────────────────────
  /// La ligne d'équipe, le titre, les badges, les tags. Les badges disent où
  /// en est le voyage, par sa phase ([tripPhase]) : « Terminé » à la place du
  /// statut une fois la dernière étape arrivée, « En cours » après la
  /// visibilité entre le premier départ et la dernière arrivée. L'inscription
  /// n'y est plus : le badge « J'y vais » du bloc de départ la dit.
  Widget _identity(BuildContext context, PublicationPhase phase) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    return Padding(
      padding: const EdgeInsets.all(PdlSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PdlTeamLine(
            label: trip.team.name,
            imageUrl: trip.team.logoUrl,
            onTap: teamLinkOf(context, trip.team),
          ),
          const SizedBox(height: 2),
          Text(trip.name, key: keys.trip.title, style: t.screenTitle),
          const SizedBox(height: PdlSpacing.chipGap),
          Wrap(
            spacing: PdlSpacing.badgeGap,
            runSpacing: PdlSpacing.badgeGap,
            children: <Widget>[
              if (phase == PublicationPhase.finished && !trip.isCancelled)
                PdlBadge(
                  key: keys.trip.finishedBadge,
                  label: 'trips.finished'.tr(),
                  tone: PdlDerivedTones.done(c),
                )
              else
                PdlBadge(
                  label: 'status.${trip.status.toLowerCase()}'.tr(),
                  tone: Status.fromJson(trip.status).tone(c),
                ),
              PdlBadge(
                label: 'visibility.${trip.visibility.toLowerCase()}'.tr(),
                tone: Visibility.fromJson(trip.visibility).tone(c),
                icon: _visibilityIcon(trip.visibility),
              ),
              if (phase == PublicationPhase.underWay)
                PdlBadge(
                  key: keys.trip.underWayBadge,
                  label: 'teams.agenda.underWay'.tr(),
                  tone: PdlDerivedTones.underWay(c),
                  dot: true,
                ),
            ],
          ),
          if (trip.tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: PdlSpacing.chipGap),
            ContentTagRow(tags: trip.tags),
          ],
        ],
      ),
    );
  }

  /// Le bloc de départ du voyage, sous l'identité (BRANDING §7.8, ledgers
  /// `BRAND-8`, `MOB-134`) : boîte du jour turquoise, « Départ 08:30 » (la
  /// première étape), pastille « Aujourd'hui » / « Demain » avant le départ,
  /// la plage du voyage au format unique, la mention de fuseau sur l'heure
  /// affichée ; l'inscription à droite ; dessous, le lieu de départ de la
  /// première étape, en lien d'itinéraire (KIT §8).
  Widget? _departure(
    BuildContext context,
    WidgetRef ref,
    TripParticipationState participation,
    bool canRegister,
    PublicationPhase phase,
  ) {
    final DateTime? instant = DateTime.tryParse(trip.dateTime);
    if (instant == null) return null;
    final String zone = trip.timezone;
    final String endZone = trip.endTimezone;
    final DateTime wall = AppFormatters.toZoneTime(instant, zone);

    final String headline = 'rides.departureBlock.departs'.tr(
      namedArgs: <String, String>{'time': AppFormatters.formatTime(wall)},
    );
    // « Aujourd'hui », « Demain » : seulement avant le départ — parti, le
    // jour se lit dans la plage.
    final String? relative =
        phase != PublicationPhase.upcoming || trip.isCancelled
        ? null
        : AppFormatters.formatDepartureRelative(instant, zone, now: now);
    final String span =
        tripDaySpan(
          trip.dateTime,
          trip.endDateTime,
          timezone: zone,
          endTimezone: endZone,
          now: now,
        ) ??
        AppFormatters.formatDepartureDate(instant, zone, now: now);
    final String? mention = AppFormatters.formatZoneMention(instant, zone);
    final List<TripStageDto> stages = trip.orderedStages;
    final PlaceDetailDto? start = stages.isEmpty
        ? null
        : stages.first.startPlace;

    return PdlDepartureBlock(
      key: keys.trip.departureBlock,
      dayBox: dayBoxFor(
        wall,
        tone: PublicationType.trip.tone(context.pdl),
        now: now,
      ),
      headline: headline,
      relativeLabel: relative,
      details: <String>[span],
      zoneMention: mention == null
          ? null
          : ZoneMentionLine(instant: instant, zone: zone),
      semanticLabel: <String>[headline, ?relative, span, ?mention].join(', '),
      trailing: _registrationControl(
        context,
        ref,
        participation,
        canRegister,
        phase,
      ),
      places: <Widget>[
        if (start != null)
          PdlPlaceRow.link(
            key: keys.trip.startPlaceLink,
            kind: PdlPlaceKind.start,
            name: start.name,
            semanticLabel: 'common.directionsTo'.tr(
              namedArgs: <String, String>{'place': start.name},
            ),
            onTap: placeDirectionsUri(start) != null
                ? () => openPlaceDirections(context, start)
                : null,
          ),
      ],
    );
  }

  IconData _visibilityIcon(String visibility) => switch (visibility) {
    'PUBLIC' => PdlIcons.visibilityPublic,
    'PUBLIC_UNLISTED' => PdlIcons.visibilityUnlisted,
    _ => PdlIcons.visibilityTeam,
  };

  // ── Étapes ──────────────────────────────────────────────────────────────
  /// Le résumé météo de chaque étape, par `stageId` — une seule lecture pour
  /// tout le voyage. Rien pour un voyage terminé ou annulé (sans même appeler
  /// l'API), ni tant que la météo n'est pas là ou qu'elle a échoué : la ligne
  /// est un enrichissement de la carte, pas un état à part. Une étape
  /// arrivée ([tripStagePhase] terminée) n'a pas de ligne : une prévision
  /// pour ce qui a eu lieu ne dit rien.
  Map<String, RideWeatherSummaryDto> _stageSummaries(
    WidgetRef ref,
    PublicationPhase phase,
  ) {
    if (phase == PublicationPhase.finished || trip.isCancelled) {
      return const <String, RideWeatherSummaryDto>{};
    }
    final TripWeatherDto? weather = ref
        .watch(tripWeatherProvider(tripKey))
        .value;
    if (weather == null || !tripWeatherShowsAnything(weather)) {
      return const <String, RideWeatherSummaryDto>{};
    }
    final Set<String> arrived = <String>{
      for (final TripStageDto s in trip.stages)
        if (tripStagePhase(trip, s, now: now) == PublicationPhase.finished)
          s.id,
    };
    return <String, RideWeatherSummaryDto>{
      for (final TripStageWeatherDto s in weather.stages)
        if (s.stageId != null &&
            s.summary != null &&
            !arrived.contains(s.stageId))
          s.stageId!: s.summary!,
    };
  }

  Widget _stages(
    BuildContext context,
    List<TripStageDto> stages,
    String? selected,
    ValueChanged<String> select,
    Map<String, RideWeatherSummaryDto> summaries,
  ) {
    return DetailSection(
      title: 'trips.stages'.tr(),
      count: stages.isEmpty ? null : 'trips.stageCount'.plural(stages.length),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (stages.isEmpty)
            PdlEmptyState(
              variant: PdlEmptyVariant.empty,
              icon: PdlIcons.stage,
              title: 'trips.noStageTitle'.tr(),
              message: 'trips.noStageMessage'.tr(),
            )
          else
            for (int i = 0; i < stages.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : PdlSpacing.chipGap),
                child: StageCard(
                  key: keys.trip.stageCard(stages[i].slug),
                  stage: stages[i],
                  weather: summaries[stages[i].id],
                  selected: stages[i].id == selected,
                  onSelect: () => select(stages[i].id),
                  onTap: () => context.push(
                    Paths.stage(trip.team.slug, trip.slug, stages[i].slug),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  // ── Description ─────────────────────────────────────────────────────────
  /// « Description » : le texte (`media.markdown`) puis les pièces jointes —
  /// un voyage peut porter un road book sans une ligne de texte.
  Widget _description() {
    return DetailSection(
      title: 'trips.description'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (trip.media.markdown.trim().isNotEmpty)
            MarkdownContent(
              data: trip.media.markdown,
              images: trip.media.assets.images,
            ),
          MediaAttachments(attachments: trip.media.assets.attachments),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────── chargement, erreur

class _TripDetailSkeleton extends StatelessWidget {
  const _TripDetailSkeleton();

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
                for (int i = 0; i < 4; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: PdlSpacing.feedGap),
                  const PdlSkeleton(height: 64),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TripDetailError extends ConsumerWidget {
  const _TripDetailError({required this.tripKey, required this.error});

  final TripKey tripKey;
  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ApiError resolved = resolveApiError(error);

    return PdlScreenScaffold(
      appBar: PdlAppBar(
        onBack: () => context.pop(),
        backSemanticLabel: 'common.back'.tr(),
      ),
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
              onPressed: () => ref.invalidate(tripDetailProvider(tripKey)),
            ),
            ReportProblemButton(error: error),
          ],
        ),
      ),
    );
  }
}
