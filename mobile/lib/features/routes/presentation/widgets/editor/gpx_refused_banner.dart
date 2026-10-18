import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../core/pdl/pdl.dart';
import '../../../../../core/theme/pdl_icons.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../keys.dart';
import '../../../domain/gpx_check.dart';

/// La phrase d'un refus, avec le nom du fichier cité — « « notes.txt »
/// n'est pas un GPX lisible. Exportez le parcours au format GPX et
/// réessayez. »
String gpxRefusalMessage(GpxRefused refused) {
  final Map<String, String> args = <String, String>{'file': refused.fileName};
  return switch (refused.refusal) {
    GpxRefusal.notGpx => 'routes.editor.refusedNotGpx'.tr(namedArgs: args),
    GpxRefusal.empty => 'routes.editor.refusedEmpty'.tr(namedArgs: args),
    GpxRefusal.tooLarge => 'routes.editor.refusedTooLarge'.tr(
      namedArgs: <String, String>{
        ...args,
        'size': AppFormatters.formatFileSize(kGpxMaxBytes),
      },
    ),
    GpxRefusal.tooLong => 'routes.editor.refusedTooLong'.tr(namedArgs: args),
  };
}

/// Le bandeau « Fichier refusé » : à l'étape 1 de la création comme dans la
/// section Tracé quand le serveur refuse un fichier à l'envoi (ledger
/// `MOB-79`). [onPickAnother] rouvre le sélecteur ; [busy] le désactive le
/// temps de lire le fichier.
class GpxRefusedBanner extends StatelessWidget {
  const GpxRefusedBanner({
    super.key,
    required this.refused,
    required this.onPickAnother,
    this.busy = false,
  });

  final GpxRefused refused;
  final VoidCallback onPickAnother;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return PdlBanner(
      key: keys.routeEditor.refusedBanner,
      tone: PdlBannerTone.danger,
      icon: PdlIcons.error,
      title: 'routes.editor.refusedTitle'.tr(),
      message: gpxRefusalMessage(refused),
      action: PdlButton(
        key: keys.routeEditor.pickAnotherButton,
        label: 'routes.editor.pickAnother'.tr(),
        variant: PdlButtonVariant.text,
        size: PdlButtonSize.sm,
        enabled: !busy,
        onPressed: onPickAnother,
      ),
    );
  }
}
