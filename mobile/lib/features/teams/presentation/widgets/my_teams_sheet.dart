import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../keys.dart';
import 'team_sections.dart';

/// Ouvre « Mes équipes » depuis l'en-tête de [team], ouvert sur [section]
/// (ledger `MOB-87`).
///
/// [teams] arrive dans l'ordre du serveur — par nom, puis par identifiant —,
/// celui du site : la feuille ne retrie pas. L'équipe affichée est cochée
/// quand j'en suis membre ; un visiteur voit ses équipes sans coche.
///
/// Changer d'équipe passe par `go`, comme le retour de l'en-tête : la pile de
/// l'onglet Équipes est remplacée, et « retour » ne déroule pas les équipes
/// visitées une à une.
Future<void> showMyTeamsSheet(
  BuildContext context, {
  required TeamDetailDto team,
  required TeamSectionKind section,
  required List<TeamDetailDto> teams,
}) {
  return PdlSheet.show<void>(
    context: context,
    builder: (BuildContext sheetContext) => _MyTeamsSheet(
      team: team,
      teams: teams,
      // La navigation part du contexte de l'en-tête, pas de la feuille, qui
      // n'existe plus une fois refermée.
      onGo: (String location) {
        Navigator.of(sheetContext).pop();
        context.go(location);
      },
      onClose: () => Navigator.of(sheetContext).pop(),
      section: section,
    ),
  );
}

class _MyTeamsSheet extends StatelessWidget {
  const _MyTeamsSheet({
    required this.team,
    required this.teams,
    required this.section,
    required this.onGo,
    required this.onClose,
  });

  final TeamDetailDto team;
  final List<TeamDetailDto> teams;
  final TeamSectionKind section;
  final ValueChanged<String> onGo;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;

    return PdlSheet(
      key: keys.team.switcherSheet,
      title: 'teams.switcher.title'.tr(),
      bodyPadding: EdgeInsets.zero,
      footer: const SafeArea(top: false, child: SizedBox(height: 8)),
      children: <Widget>[
        for (final TeamDetailDto other in teams)
          // La coche est muette : `selected` dit aux lecteurs d'écran quelle
          // ligne est l'équipe courante, comme `aria-current` sur le site. Les
          // autres lignes n'en portent pas, pour ne pas lire « non
          // sélectionné » sur chacune.
          Semantics(
            selected: other.id == team.id ? true : null,
            child: PdlSettingRow(
              key: keys.team.switcherRow(other.slug),
              leading: PdlAvatar(
                name: other.name,
                imageUrl: other.logoUrl,
                size: 32,
              ),
              title: other.name,
              trailing: other.id == team.id
                  ? Icon(PdlIcons.check, size: 20, color: c.primary)
                  : const SizedBox.shrink(),
              // L'équipe courante referme la feuille sans rien recharger.
              onTap: other.id == team.id
                  ? onClose
                  : () => onGo(switchTargetSection(other, section).currentPath),
            ),
          ),
        PdlSettingRow(
          key: keys.team.switcherAllTeams,
          title: 'teams.switcher.allTeams'.tr(),
          onTap: () => onGo(Paths.teams()),
        ),
      ],
    );
  }
}
