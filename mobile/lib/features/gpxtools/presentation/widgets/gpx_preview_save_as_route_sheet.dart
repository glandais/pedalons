import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../keys.dart';
import '../../../routes/domain/planner_quota.dart';
import '../../../routes/presentation/widgets/editor/planner_quota_message.dart';
import '../../../teams/domain/team_permissions.dart';
import '../../../teams/providers/team_providers.dart';
import '../../../visibility/domain/content_visibility.dart';
import '../../data/gpx_preview_repository.dart';

/// Le parcours créé et son équipe.
typedef SavedPreviewRoute = ({String teamSlug, RouteDto route});

/// Ouvre « Enregistrer comme parcours » (docs/LEDGER_*.md MOB-178) et rend
/// le parcours créé, `null` si la feuille est fermée sans enregistrer.
Future<SavedPreviewRoute?> showGpxPreviewSaveAsRouteSheet(
  BuildContext context,
  GpxPreviewDto preview,
) => PdlSheet.show<SavedPreviewRoute>(
  context: context,
  builder: (BuildContext _) => GpxPreviewSaveAsRouteSheet(preview: preview),
);

/// Les équipes où [preview] peut devenir un parcours : celles où la personne
/// organise et dont la section Parcours est ouverte (`enableRoutes`), dans
/// l'ordre de « Mes équipes ». [GpxPreviewTeamChoice.closed] : un tracé
/// **dessiné** ne devient un parcours que là où le tracé d'itinéraire est
/// ouvert — l'équipe reste listée, grisée avec sa raison, plutôt que cachée
/// (le serveur répondrait `ROUTE_PLANNER_DISABLED`). Un fichier importé va
/// partout.
List<GpxPreviewTeamChoice> gpxPreviewTeamChoices(
  GpxPreviewDto preview,
  List<TeamDetailDto> teams,
) => <GpxPreviewTeamChoice>[
  for (final TeamDetailDto team in teams)
    if (team.enableRoutes && isTeamOrganizer(teamRole: teamRoleOf(team)))
      (team: team, closed: preview.drawn && !team.enableRoutePlanner),
];

typedef GpxPreviewTeamChoice = ({TeamDetailDto team, bool closed});

/// Le choix d'une équipe, puis « Enregistrer » : le parcours prend le nom de
/// l'aperçu, la surface route, une description vide et la visibilité par
/// défaut de l'équipe — ce qu'envoie le site. Un tracé dessiné compte dans
/// le quota de l'équipe (`BILL-10`) : un refus ouvre la feuille du quota, la
/// feuille restant ouverte.
class GpxPreviewSaveAsRouteSheet extends ConsumerStatefulWidget {
  const GpxPreviewSaveAsRouteSheet({super.key, required this.preview});

  final GpxPreviewDto preview;

  @override
  ConsumerState<GpxPreviewSaveAsRouteSheet> createState() =>
      _GpxPreviewSaveAsRouteSheetState();
}

class _GpxPreviewSaveAsRouteSheetState
    extends ConsumerState<GpxPreviewSaveAsRouteSheet> {
  String? _selected;
  bool _saving = false;
  String? _error;

  Future<void> _save(List<GpxPreviewTeamChoice> choices) async {
    if (_saving) return;
    final TeamDetailDto? team = choices
        .where((GpxPreviewTeamChoice c) => c.team.slug == _selected)
        .map((GpxPreviewTeamChoice c) => c.team)
        .firstOrNull;
    if (team == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final RouteDto route = await ref
          .read(gpxPreviewRepositoryProvider)
          .createRoute(
            widget.preview.id,
            teamSlug: team.slug,
            request: RouteRequest(
              name: widget.preview.name,
              media: const MediaDto(
                markdown: '',
                assets: AssetsDto(
                  images: <AssetDto>[],
                  attachments: <AssetDto>[],
                ),
              ),
              surfaceType: SurfaceType.road.json!,
              visibility: defaultContentVisibilityOf(team).json!,
            ),
          );
      if (mounted) {
        Navigator.of(context).pop((teamSlug: team.slug, route: route));
      }
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() => _saving = false);
      final PlannerQuotaRefusal? quota = plannerQuotaRefusalOf(error);
      if (quota != null) {
        await showPlannerQuotaSheet(context, quota);
        return;
      }
      final String? code = resolveApiError(error, stackTrace).code;
      setState(
        () => _error = code == 'ROUTE_PLANNER_DISABLED'
            ? 'gpxTools.preview.plannerClosedForTeam'.tr()
            : getErrorMessage(error, stackTrace),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final AsyncValue<List<TeamDetailDto>> teams = ref.watch(myTeamsProvider);
    final List<GpxPreviewTeamChoice> choices = gpxPreviewTeamChoices(
      widget.preview,
      teams.value ?? const <TeamDetailDto>[],
    );
    final bool anyClosed = choices.any((GpxPreviewTeamChoice c) => c.closed);

    final Widget body = teams.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(PdlSpacing.section),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace stack) => Padding(
        padding: const EdgeInsets.all(PdlSpacing.section),
        child: PdlBanner(
          tone: PdlBannerTone.danger,
          message: getErrorMessage(error, stack),
          action: PdlButton(
            label: 'common.retry'.tr(),
            variant: PdlButtonVariant.text,
            size: PdlButtonSize.sm,
            onPressed: () => ref.invalidate(myTeamsProvider),
          ),
        ),
      ),
      data: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PdlSpacing.section,
                0,
                PdlSpacing.section,
                PdlSpacing.chipGap,
              ),
              child: PdlBanner(
                tone: PdlBannerTone.danger,
                icon: PdlIcons.error,
                message: _error!,
                onDismiss: () => setState(() => _error = null),
                dismissSemanticLabel: 'common.close'.tr(),
              ),
            ),
          if (choices.isEmpty)
            Padding(
              padding: const EdgeInsets.all(PdlSpacing.section),
              child: Text(
                'gpxTools.preview.noTeam'.tr(),
                style: t.sub.copyWith(color: c.textDimmed),
              ),
            ),
          if (anyClosed)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PdlSpacing.section,
                0,
                PdlSpacing.section,
                PdlSpacing.chipGap,
              ),
              child: Text(
                'gpxTools.preview.drawnNeedsPlanner'.tr(),
                style: t.xs.copyWith(color: c.textDimmed),
              ),
            ),
          for (final GpxPreviewTeamChoice choice in choices)
            PdlSettingRow(
              key: keys.gpxTools.saveAsRouteTeam(choice.team.slug),
              leading: PdlAvatar(
                name: choice.team.name,
                imageUrl: choice.team.logoUrl,
                size: 28,
              ),
              title: choice.team.name,
              subtitle: choice.closed
                  ? 'gpxTools.preview.plannerClosedShort'.tr()
                  : null,
              trailing: _selected == choice.team.slug
                  ? Icon(PdlIcons.check, size: 20, color: c.primary)
                  : const SizedBox.shrink(),
              onTap: choice.closed || _saving
                  ? null
                  : () => setState(() => _selected = choice.team.slug),
            ),
        ],
      ),
    );

    return PdlSheet(
      key: keys.gpxTools.saveAsRouteSheet,
      title: 'gpxTools.preview.saveAsRoute'.tr(),
      headerAction: PdlButton(
        label: 'common.close'.tr(),
        variant: PdlButtonVariant.text,
        size: PdlButtonSize.sm,
        onPressed: () => Navigator.of(context).pop(),
      ),
      bodyPadding: EdgeInsets.zero,
      footer: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(PdlSpacing.section),
          child: PdlButton(
            key: keys.gpxTools.saveAsRouteSubmit,
            label: 'gpxTools.preview.save'.tr(),
            loading: _saving,
            enabled: _selected != null,
            fullWidth: true,
            onPressed: () => _save(choices),
          ),
        ),
      ),
      body: SingleChildScrollView(child: body),
    );
  }
}
