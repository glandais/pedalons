import 'package:easy_localization/easy_localization.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/material.dart' hide Visibility;
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../keys.dart';

/// Les trois visibilités d'une équipe, dans l'ordre du site : « Équipe
/// uniquement », « Non répertorié », « Public ».
const List<Visibility> kTeamVisibilities = <Visibility>[
  Visibility.team,
  Visibility.publicUnlisted,
  Visibility.public,
];

/// Le libellé d'une visibilité d'équipe ; vide pour une valeur que cette
/// version de l'app ne connaît pas.
String teamVisibilityLabel(Visibility visibility) {
  final String? json = visibility.json;
  return json == null ? '' : 'visibility.${json.toLowerCase()}'.tr();
}

/// L'icône d'une visibilité, celle de son badge.
IconData teamVisibilityIcon(Visibility visibility) => switch (visibility) {
  Visibility.public => PdlIcons.visibilityPublic,
  Visibility.publicUnlisted => PdlIcons.visibilityUnlisted,
  _ => PdlIcons.visibilityTeam,
};

/// La feuille « Visibilité de l'équipe » des paramètres (docs/LEDGER_*.md
/// MOB-166) : les trois choix du site. Rend la visibilité choisie, ou `null`
/// si la feuille se ferme sans choix.
///
/// Elle ne dit rien de ce qu'un passage en « Équipe uniquement » fait au
/// contenu : c'est l'enregistrement qui le demande, comme au site.
Future<Visibility?> showTeamVisibilitySheet(
  BuildContext context, {
  required Visibility current,
}) {
  return PdlSheet.show<Visibility>(
    context: context,
    builder: (BuildContext sheetContext) {
      final PdlColors c = sheetContext.pdl;
      final PdlTypography t = sheetContext.pdlText;
      return PdlSheet(
        title: 'teams.editor.visibility'.tr(),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PdlSpacing.section,
                0,
                PdlSpacing.section,
                PdlSpacing.chipGap,
              ),
              child: Text(
                'teams.editor.visibilityHint'.tr(),
                style: t.xs.copyWith(color: c.textDimmed),
              ),
            ),
            for (final Visibility v in kTeamVisibilities)
              PdlSettingRow(
                key: keys.teamEditor.visibilityOption(v.json!),
                icon: teamVisibilityIcon(v),
                title: teamVisibilityLabel(v),
                trailing: v == current
                    ? Icon(PdlIcons.check, size: 20, color: c.primary)
                    : const SizedBox.shrink(),
                onTap: () => Navigator.of(sheetContext).pop(v),
              ),
          ],
        ),
      );
    },
  );
}
