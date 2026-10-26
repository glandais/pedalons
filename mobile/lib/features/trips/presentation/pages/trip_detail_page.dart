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
import '../../../../core/utils/share_link.dart';
import '../../../../core/widgets/markdown_content.dart';
import '../../../../core/widgets/media_attachments.dart';
import '../../../calendar/presentation/widgets/calendar_subscription_card.dart';
import '../../../comments/data/comment_repository.dart';
import '../../../comments/presentation/widgets/comment_thread.dart';
import '../../../moderation/presentation/moderation_menu.dart';
import '../../../participants/presentation/widgets/participants_sheet.dart';
import '../../../teams/providers/team_providers.dart';
import '../../../tags/presentation/content_tags.dart';
import '../../providers/trip_detail_provider.dart';
import '../../providers/trip_participation_controller.dart';
import '../../providers/trip_stage_selection_provider.dart';
import '../../domain/trip_weather_map.dart';
import '../../providers/trip_weather_provider.dart';
import '../widgets/stage_card.dart';
import '../widgets/trip_elevation.dart';
import '../widgets/trip_map.dart';
import '../widgets/trip_summary_card.dart';
import '../../../feedback/presentation/report_problem_button.dart';
import '../../../../keys.dart';
import '../../../../core/utils/push_location.dart';

/// L'écran 24 — le voyage.
///
/// De la v1 il reste la liste d'étapes et la description ; tout le reste est
/// neuf. La v1 n'avait ni carte, ni distance totale, ni dénivelé cumulé, ni
/// date de fin, ni profil, ni commentaires — un voyage de sept jours y était
/// une date de départ suivie de sept lignes.
class TripDetailPage extends ConsumerWidget {
  const TripDetailPage({
    super.key,
    required this.teamSlug,
    required this.tripSlug,
  });

  final String teamSlug;
  final String tripSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TripKey key = TripKey(teamSlug: teamSlug, tripSlug: tripSlug);
    // Le voyage se lit sur le contrôleur, pas sur le détail : c'est lui qui
    // porte la bascule optimiste.
    final TripParticipationState participation = ref.watch(
      tripParticipationProvider(key),
    );

    return participation.trip.when(
      data: (TripDto trip) => _TripDetailContent(tripKey: key, trip: trip),
      loading: () => const _TripDetailSkeleton(),
      error: (Object error, StackTrace stack) =>
          _TripDetailError(tripKey: key, error: error),
    );
  }
}

// ─────────────────────────────────────────────────────────────── contenu

class _TripDetailContent extends ConsumerWidget {
  const _TripDetailContent({required this.tripKey, required this.trip});

  final TripKey tripKey;
  final TripDto trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool? isMember = ref.watch(teamMembershipProvider(trip.team.slug));
    final bool canSeeNames = ref.watch(
      canSeeMemberNamesProvider(trip.team.slug),
    );
    final List<TripStageDto> stages = trip.orderedStages;
    final String? selected = ref.watch(selectedStageProvider(tripKey));
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
          // calendrier — le bouton disparaît plutôt que d'échouer.
          if (isMember == true)
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
        SliverToBoxAdapter(child: _identity(context)),
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
        if (isMember == false)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: PdlBanner(
                tone: PdlBannerTone.warn,
                message: 'trips.notMemberBanner'.tr(),
                action: PdlButton(
                  label: 'teams.viewTeam'.tr(),
                  variant: PdlButtonVariant.outline,
                  size: PdlButtonSize.sm,
                  onPressed: () =>
                      pushLocation(context, Paths.team(trip.team.slug)),
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TripSummaryCard(
              trip: trip,
              onShowParticipants: canSeeNames
                  ? () => ParticipantsSheet.openTrip(context, trip)
                  : null,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: TripMap(
            tripKey: tripKey,
            trip: trip,
            selectedStageId: selected,
            onSelect: select,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(PdlSpacing.section),
            child: TripElevationSection(tripKey: tripKey, trip: trip),
          ),
        ),
        SliverToBoxAdapter(
          child: _stages(
            context,
            stages,
            selected,
            select,
            _stageSummaries(ref),
          ),
        ),
        if (trip.media.markdown.trim().isNotEmpty)
          SliverToBoxAdapter(child: _description(context)),
        // Section à part, et non un appendice de la description : un voyage
        // peut porter un road book sans une ligne de texte.
        if (trip.media.assets.attachments.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: MediaAttachments(
                attachments: trip.media.assets.attachments,
                spacingBefore: 0,
              ),
            ),
          ),
        if (canSeeNames && trip.participants.isNotEmpty)
          SliverToBoxAdapter(child: _participants(context)),
        if (participation.failure != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _failureBanner(context, ref, participation.failure!),
            ),
          ),
        // `commentCount` absent signifie « vous n'avez pas le droit de lire les
        // commentaires » : le fil n'est pas monté du tout.
        if (trip.commentCount != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(PdlSpacing.section),
              child: CommentThread(
                target: CommentTarget(
                  entity: CommentEntity.trip,
                  teamSlug: trip.team.slug,
                  slug: trip.slug,
                ),
                canComment: isMember ?? false,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: PdlSpacing.section)),
      ],
      actionBar: _actionBar(context, ref, participation, isMember),
    );
  }

  // ── Barre d'action ──────────────────────────────────────────────────────
  /// **Une seule action pleine et colorée par écran** (§1.0.4) : « Participer »
  /// est en plein, « Ne plus participer » en contour. Un voyage annulé ou passé
  /// n'en propose aucune — s'inscrire à ce qui a eu lieu n'a pas de sens, et un
  /// bouton qui échouerait serait pire qu'un bouton absent.
  Widget? _actionBar(
    BuildContext context,
    WidgetRef ref,
    TripParticipationState participation,
    bool? isMember,
  ) {
    if (trip.isCancelled || trip.isPast || isMember == false) return null;

    final TripParticipationController controller = ref.read(
      tripParticipationProvider(tripKey).notifier,
    );

    return PdlActionBar(
      children: <Widget>[
        if (trip.registered)
          PdlButton(
            key: keys.trip.leaveButton,
            label: 'trips.leave'.tr(),
            variant: PdlButtonVariant.outline,
            fullWidth: true,
            loading: participation.pending,
            loadingLabel: 'trips.leaving'.tr(),
            onPressed: controller.leave,
          )
        else
          PdlButton(
            key: keys.trip.joinButton,
            label: 'trips.join'.tr(),
            fullWidth: true,
            loading: participation.pending,
            loadingLabel: 'trips.joining'.tr(),
            onPressed: controller.join,
          ),
      ],
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
          ? PdlButton(
              label: 'teams.viewTeam'.tr(),
              variant: PdlButtonVariant.outline,
              size: PdlButtonSize.sm,
              onPressed: () =>
                  pushLocation(context, Paths.team(trip.team.slug)),
            )
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

  // ── Participants en pastilles ───────────────────────────────────────────
  /// Les noms, pas seulement des avatars : sur un voyage à trois inscrits, la
  /// question « qui vient ? » se lit sans ouvrir de feuille.
  Widget _participants(BuildContext context) {
    final PdlColors c = context.pdl;

    return Padding(
      key: keys.trip.participants,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PdlSectionHeader(
            title: 'participants.title'.tr(),
            count: '${trip.participantCount}',
            action: PdlButton(
              label: 'common.viewAll'.tr(),
              variant: PdlButtonVariant.text,
              size: PdlButtonSize.sm,
              onPressed: () => ParticipantsSheet.openTrip(context, trip),
            ),
          ),
          Wrap(
            spacing: PdlSpacing.badgeGap,
            runSpacing: PdlSpacing.badgeGap,
            children: <Widget>[
              for (final PublicUserDto person in trip.participants)
                PdlBadge(
                  label: person.displayName,
                  tone: PdlDerivedTones.registered(c),
                  size: PdlBadgeSize.lg,
                ),
              // `participants` n'est que l'aperçu des premiers inscrits
              // (ledger `API-12`) : le reste est dans la feuille.
              if (trip.participantCount > trip.participants.length)
                PdlBadge(
                  label: '+${trip.participantCount - trip.participants.length}',
                  tone: PdlDerivedTones.registered(c),
                  size: PdlBadgeSize.lg,
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 2 · Identité ────────────────────────────────────────────────────────
  Widget _identity(BuildContext context) {
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
            onTap: () => pushLocation(context, Paths.team(trip.team.slug)),
          ),
          const SizedBox(height: 2),
          Text(trip.name, key: keys.trip.title, style: t.screenTitle),
          const SizedBox(height: PdlSpacing.chipGap),
          Wrap(
            spacing: PdlSpacing.badgeGap,
            runSpacing: PdlSpacing.badgeGap,
            children: <Widget>[
              if (trip.isPast && !trip.isCancelled)
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
              if (trip.registered)
                PdlBadge(
                  label: 'trips.registered'.tr(),
                  tone: PdlDerivedTones.registered(c),
                  icon: PdlIcons.check,
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

  IconData _visibilityIcon(String visibility) => switch (visibility) {
    'PUBLIC' => PdlIcons.visibilityPublic,
    'PUBLIC_UNLISTED' => PdlIcons.visibilityUnlisted,
    _ => PdlIcons.visibilityTeam,
  };

  // ── 3 · Étapes ──────────────────────────────────────────────────────────
  /// Le résumé météo de chaque étape, par `stageId` — une seule lecture pour
  /// tout le voyage. Rien pour un voyage terminé ou annulé (sans même appeler
  /// l'API), ni tant que la météo n'est pas là ou qu'elle a échoué : la ligne
  /// est un enrichissement de la carte, pas un état à part.
  Map<String, RideWeatherSummaryDto> _stageSummaries(WidgetRef ref) {
    if (trip.isPast || trip.isCancelled) {
      return const <String, RideWeatherSummaryDto>{};
    }
    final TripWeatherDto? weather = ref
        .watch(tripWeatherProvider(tripKey))
        .value;
    if (weather == null || !tripWeatherShowsAnything(weather)) {
      return const <String, RideWeatherSummaryDto>{};
    }
    return <String, RideWeatherSummaryDto>{
      for (final TripStageWeatherDto s in weather.stages)
        if (s.stageId != null && s.summary != null) s.stageId!: s.summary!,
    };
  }

  Widget _stages(
    BuildContext context,
    List<TripStageDto> stages,
    String? selected,
    ValueChanged<String> select,
    Map<String, RideWeatherSummaryDto> summaries,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PdlSectionHeader(
            title: 'trips.stages'.tr(),
            count: stages.isEmpty ? null : '${stages.length}',
          ),
          if (stages.isEmpty)
            PdlEmptyState(
              variant: PdlEmptyVariant.empty,
              icon: PdlIcons.stage,
              title: 'trips.noStageTitle'.tr(),
              message: 'trips.noStageMessage'.tr(),
            )
          else
            for (final TripStageDto stage in stages)
              Padding(
                padding: const EdgeInsets.only(bottom: PdlSpacing.feedGap),
                child: StageCard(
                  key: keys.trip.stageCard(stage.slug),
                  stage: stage,
                  weather: summaries[stage.id],
                  selected: stage.id == selected,
                  onSelect: () => select(stage.id),
                  onTap: () => context.push(
                    Paths.stage(trip.team.slug, trip.slug, stage.slug),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  // ── 4 · Description ─────────────────────────────────────────────────────
  Widget _description(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PdlSectionHeader(title: 'trips.description'.tr()),
          MarkdownContent(
            data: trip.media.markdown,
            images: trip.media.assets.images,
          ),
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
