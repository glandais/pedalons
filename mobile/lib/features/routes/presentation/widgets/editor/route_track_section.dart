import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../api/generated/export.dart';
import '../../../../../core/pdl/pdl.dart';
import '../../../../../core/preferences/user_preferences_provider.dart';
import '../../../../../core/theme/pdl_icons.dart';
import '../../../../../core/theme/pdl_tokens.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../keys.dart';
import '../../../../rides/presentation/widgets/editor/editor_section.dart';
import '../../../domain/gpx_check.dart';
import 'gpx_refused_banner.dart';

/// La section « Tracé » de l'éditeur de parcours (ledger `MOB-79`).
///
/// * **Création** ([current] nul) : le fichier choisi ([picked]) — nom,
///   taille, « distance et dénivelé calculés à l'envoi » — et « Changer ».
/// * **Modification** : le tracé actuel (vignette, distance, D+), « Remplacer
///   le GPX », et l'avertissement qu'un nouveau fichier remplace tout le
///   tracé. Un fichier choisi ([picked]) se montre avec « Garder le tracé
///   actuel » ([onCancelReplace]).
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
  });

  final RouteDetailDto? current;
  final GpxFile? picked;
  final GpxRefused? refused;
  final bool busy;
  final VoidCallback onPick;
  final VoidCallback? onCancelReplace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RouteDetailDto? route = current;
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
          if (route == null)
            ..._creation(file)
          else
            ..._edition(context, ref, route, file),
        ],
      ),
    );
  }

  List<Widget> _creation(GpxFile? file) => <Widget>[
    if (file != null)
      _pickedRow(
        file,
        subtitle: 'routes.editor.trackComputed'.tr(),
        semanticLabel: 'routes.editor.trackChange'.tr(),
      ),
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: PdlButton(
        key: keys.routeEditor.trackChangeButton,
        label: 'routes.editor.trackChange'.tr(),
        icon: PdlIcons.fileAdd,
        variant: PdlButtonVariant.text,
        size: PdlButtonSize.sm,
        enabled: !busy,
        onPressed: onPick,
      ),
    ),
  ];

  List<Widget> _edition(
    BuildContext context,
    WidgetRef ref,
    RouteDetailDto route,
    GpxFile? file,
  ) {
    final UnitSystem units = ref.watch(unitSystemProvider);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final String? thumbnail = dark
        ? route.media.assets.thumbnailDark?.url
        : route.media.assets.thumbnailLight?.url;

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
