import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../api/generated/export.dart';
import '../../../../../core/material.dart';
import '../../../../../core/pdl/pdl.dart';
import '../../../../../core/preferences/user_preferences_provider.dart';
import '../../../../../core/theme/pdl_colors.dart';
import '../../../../../core/theme/pdl_icons.dart';
import '../../../../../core/theme/pdl_tokens.dart';
import '../../../../../core/theme/pdl_typography.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../keys.dart';
import '../../../../rides/presentation/widgets/editor/editor_section.dart';
import '../../../domain/gpx_check.dart';
import '../../../domain/planner_quota.dart';
import '../../../domain/planner_result.dart';
import 'gpx_refused_banner.dart';
import 'planner_preview_card.dart';
import 'planner_quota_message.dart';

/// Le tracé actuel que la section montre en modification : celui d'un
/// parcours ([currentTrackOfRoute]) ou d'un aperçu des outils GPX
/// (docs/LEDGER_*.md MOB-178). Les vignettes peuvent porter le gabarit
/// `{size}`.
typedef CurrentTrack = ({
  String name,
  double distance,
  double elevationGain,
  String? thumbnailLight,
  String? thumbnailDark,
});

CurrentTrack currentTrackOfRoute(RouteDetailDto route) => (
  name: route.name,
  distance: route.distance,
  elevationGain: route.elevationGain,
  thumbnailLight: route.media.assets.thumbnailLight?.url,
  thumbnailDark: route.media.assets.thumbnailDark?.url,
);

/// La section « Tracé » de l'éditeur de parcours (ledger `MOB-79`), et de
/// celui d'un aperçu GPX (`MOB-178`).
///
/// * **Création** ([current] nul) : le fichier choisi ([picked]) — nom,
///   taille, « distance et dénivelé calculés à l'envoi » — et « Changer ».
/// * **Modification** : le tracé actuel (vignette, distance, D+), « Remplacer
///   le GPX », et l'avertissement qu'un nouveau fichier remplace tout le
///   tracé. Un fichier choisi ([picked]) se montre avec « Garder le tracé
///   actuel » ([onCancelReplace]).
///
/// Avec le planificateur ([onDraw] non nul, ledger `MOB-170`) : « Tracer sur
/// la carte » à la création, « Modifier le tracé » à côté de « Remplacer le
/// GPX » en modification — désactivé, avec sa raison, si le quota du mois est
/// épuisé ([quotaSpent]). Un tracé dessiné ([drawn]) se montre en carte
/// d'aperçu ([PlannerPreviewCard]) ; un fichier choisi ensuite passe devant.
/// [unvalidated] : la carte a été quittée sans « Terminer » après des
/// retouches. [plannerWarning] : un avertissement du planificateur (état non
/// relu).
///
/// [refused] : le fichier a été refusé (à la lecture, ou par le serveur à
/// l'envoi) — son bandeau ouvre la section. [busy] : lecture ou envoi en
/// cours, les boutons attendent.
class RouteTrackSection extends ConsumerWidget {
  const RouteTrackSection({
    super.key,
    this.current,
    this.picked,
    this.refused,
    required this.busy,
    required this.onPick,
    this.onCancelReplace,
    this.onDraw,
    this.quotaSpent,
    this.drawn,
    this.unvalidated = false,
    this.plannerWarning,
  });

  final CurrentTrack? current;
  final GpxFile? picked;
  final GpxRefused? refused;
  final bool busy;
  final VoidCallback onPick;
  final VoidCallback? onCancelReplace;

  /// Ouvre le planificateur ; nul, il n'est pas proposé (planificateur fermé
  /// à l'équipe, ou parcours à plusieurs traces).
  final VoidCallback? onDraw;
  final PlannerQuotaRefusal? quotaSpent;
  final PlannerResult? drawn;
  final bool unvalidated;
  final String? plannerWarning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CurrentTrack? route = current;
    final GpxFile? file = picked;
    final GpxRefused? refusal = refused;

    return EditorSection(
      key: keys.routeEditor.trackSection,
      title: 'routes.editor.track'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (refusal != null) ...<Widget>[
            GpxRefusedBanner(
              refused: refusal,
              onPickAnother: onPick,
              busy: busy,
            ),
            const SizedBox(height: PdlSpacing.chipGap),
          ],
          if (plannerWarning != null) ...<Widget>[
            PdlBanner(
              key: keys.routeEditor.plannerWarning,
              tone: PdlBannerTone.warn,
              icon: PdlIcons.warning,
              message: plannerWarning!,
            ),
            const SizedBox(height: PdlSpacing.chipGap),
          ],
          if (route == null)
            ..._creation(file)
          else
            ..._edition(context, ref, route, file),
          if (unvalidated) ...<Widget>[
            const SizedBox(height: PdlSpacing.chipGap),
            PdlBanner(
              key: keys.routeEditor.plannerUnvalidated,
              tone: PdlBannerTone.warn,
              icon: PdlIcons.warning,
              message: 'routes.editor.trackUnvalidated'.tr(),
            ),
          ],
        ],
      ),
    );
  }

  /// Le tracé dessiné à montrer : aucun quand un fichier choisi passe devant.
  PlannerResult? get _shownDrawing => picked == null ? drawn : null;

  /// « Tracer sur la carte » ou, une fois un tracé dessiné (ou en
  /// modification), « Modifier le tracé » — et la raison d'un quota épuisé.
  List<Widget> _drawButton({required bool edit}) {
    final VoidCallback? draw = onDraw;
    if (draw == null) return const <Widget>[];
    final PlannerQuotaRefusal? quota = quotaSpent;
    return <Widget>[
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: PdlButton(
          key: edit
              ? keys.routeEditor.trackEditButton
              : keys.routeEditor.drawButton,
          label: edit
              ? 'routes.editor.trackEdit'.tr()
              : 'routes.editor.drawButton'.tr(),
          icon: PdlIcons.map,
          variant: PdlButtonVariant.outline,
          size: PdlButtonSize.sm,
          enabled: !busy && quota == null,
          onPressed: draw,
        ),
      ),
      if (quota != null) ...<Widget>[
        const SizedBox(height: PdlSpacing.badgeGap),
        PlannerQuotaMessage(
          key: keys.routeEditor.quotaMessage,
          refusal: quota,
          help: true,
        ),
      ],
      const SizedBox(height: PdlSpacing.chipGap),
    ];
  }

  List<Widget> _creation(GpxFile? file) {
    final PlannerResult? drawing = _shownDrawing;
    return <Widget>[
      if (file != null)
        _pickedRow(
          file,
          subtitle: 'routes.editor.trackComputed'.tr(),
          semanticLabel: 'routes.editor.trackChange'.tr(),
        ),
      if (drawing != null) ...<Widget>[
        PlannerPreviewCard(stats: drawing.stats),
        const SizedBox(height: PdlSpacing.chipGap),
      ],
      ..._drawButton(edit: drawing != null),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: PdlButton(
          key: keys.routeEditor.trackChangeButton,
          label: drawing == null
              ? 'routes.editor.trackChange'.tr()
              : 'routes.editor.importButton'.tr(),
          icon: PdlIcons.fileAdd,
          variant: PdlButtonVariant.text,
          size: PdlButtonSize.sm,
          enabled: !busy,
          onPressed: onPick,
        ),
      ),
    ];
  }

  List<Widget> _edition(
    BuildContext context,
    WidgetRef ref,
    CurrentTrack route,
    GpxFile? file,
  ) {
    final UnitSystem units = ref.watch(unitSystemProvider);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final String? thumbnail = dark
        ? route.thumbnailDark ?? route.thumbnailLight
        : route.thumbnailLight;

    return <Widget>[
      PdlCardMedia(
        tone: PdlMediaTone.ride,
        icon: PdlIcons.route,
        imageUrl: thumbnail,
        height: PdlMetrics.media,
        borderRadius: PdlRadii.mdAll,
        semanticLabel: route.name,
      ),
      const SizedBox(height: PdlSpacing.chipGap),
      PdlStatRow(
        stats: <PdlStat>[
          PdlStat(
            icon: PdlIcons.distance,
            value: AppFormatters.formatDistance(route.distance, units),
          ),
          PdlStat(
            icon: PdlIcons.elevationUp,
            value: AppFormatters.formatElevationGain(
              route.elevationGain,
              units,
            ),
          ),
        ],
      ),
      const SizedBox(height: PdlSpacing.chipGap),
      if (file != null) ...<Widget>[
        _pickedRow(
          file,
          subtitle: 'routes.editor.trackReplacing'.tr(),
          semanticLabel: 'routes.editor.trackReplaceCancel'.tr(),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: PdlButton(
            key: keys.routeEditor.trackReplaceCancel,
            label: 'routes.editor.trackReplaceCancel'.tr(),
            variant: PdlButtonVariant.text,
            size: PdlButtonSize.sm,
            enabled: !busy && onCancelReplace != null,
            onPressed: onCancelReplace,
          ),
        ),
        const SizedBox(height: PdlSpacing.chipGap),
      ],
      if (_shownDrawing case final PlannerResult drawing) ...<Widget>[
        PlannerPreviewCard(stats: drawing.stats),
        if (drawing.hasTrack) ...<Widget>[
          const SizedBox(height: PdlSpacing.badgeGap),
          Text(
            'routes.editor.trackDrawnReplacing'.tr(),
            style: context.pdlText.sub.copyWith(color: context.pdl.textDimmed),
          ),
        ],
        const SizedBox(height: PdlSpacing.chipGap),
      ],
      ..._drawButton(edit: true),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: PdlButton(
          key: keys.routeEditor.trackReplaceButton,
          label: 'routes.editor.trackReplace'.tr(),
          icon: PdlIcons.gpx,
          variant: PdlButtonVariant.outline,
          size: PdlButtonSize.sm,
          enabled: !busy,
          onPressed: onPick,
        ),
      ),
      const SizedBox(height: PdlSpacing.chipGap),
      PdlBanner(
        key: keys.routeEditor.trackWarning,
        tone: PdlBannerTone.warn,
        icon: PdlIcons.warning,
        message: 'routes.editor.trackWarning'.tr(),
      ),
    ];
  }

  /// Le fichier choisi : nom, « GPX », taille et [subtitle]. Sans action : le
  /// geste pour le changer est le bouton dessous ([semanticLabel] n'est lu
  /// que si la ligne en porte une).
  Widget _pickedRow(
    GpxFile file, {
    required String subtitle,
    required String semanticLabel,
  }) {
    return PdlAttachmentRow(
      name: file.name,
      type: 'GPX',
      icon: PdlIcons.gpx,
      subtitle: '${AppFormatters.formatFileSize(file.size)} · $subtitle',
      actionSemanticLabel: semanticLabel,
    );
  }
}
