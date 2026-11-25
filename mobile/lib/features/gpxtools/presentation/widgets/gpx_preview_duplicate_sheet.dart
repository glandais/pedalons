import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/widgets/duplicate_name_sheet.dart';
import '../../../../keys.dart';
import '../../data/gpx_preview_repository.dart';

/// Ouvre « Dupliquer le fichier » et rend la copie, `null` si la feuille est
/// fermée sans dupliquer (docs/LEDGER_*.md MOB-178, `WEB-180` au site). Toute
/// personne connectée peut copier un aperçu dont elle a le lien : la copie
/// est à elle, l'original reste tel quel, et rien ne compte dans un quota.
Future<GpxPreviewDto?> showGpxPreviewDuplicateSheet(
  BuildContext context,
  GpxPreviewDto preview,
) => PdlSheet.show<GpxPreviewDto>(
  context: context,
  builder: (BuildContext _) => Consumer(
    builder: (BuildContext _, WidgetRef ref, Widget? _) =>
        DuplicateNameSheet<GpxPreviewDto>(
          key: keys.gpxTools.duplicateSheet,
          title: 'gpxTools.preview.duplicate.title'.tr(),
          nameLabel: 'gpxTools.preview.duplicate.nameLabel'.tr(),
          submitLabel: 'gpxTools.preview.duplicate.submit'.tr(),
          initialName: 'gpxTools.preview.duplicate.defaultName'.tr(
            namedArgs: <String, String>{'name': preview.name},
          ),
          nameKey: keys.gpxTools.duplicateName,
          submitKey: keys.gpxTools.duplicateSubmit,
          onSubmit: (String name) => ref
              .read(gpxPreviewRepositoryProvider)
              .copy(preview.id, name: name),
        ),
  ),
);
