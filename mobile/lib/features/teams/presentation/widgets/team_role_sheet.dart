import '../../../../api/generated/export.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../keys.dart';

/// Les rôles qu'une personne qui administre l'équipe peut donner, dans
/// l'ordre du site : Administrateur, Organisateur, Membre.
const List<TeamRole> kAssignableTeamRoles = <TeamRole>[
  TeamRole.admin,
  TeamRole.organizer,
  TeamRole.member,
];

/// La feuille « Rôle de {nom} » de la gestion des membres (docs/LEDGER_*.md
/// MOB-167). Rend le rôle choisi, ou `null` si la feuille se ferme sans choix.
Future<TeamRole?> showTeamRoleSheet(
  BuildContext context, {
  required String title,
  required TeamRole current,
}) {
  return PdlSheet.show<TeamRole>(
    context: context,
    builder: (BuildContext sheetContext) {
      final PdlColors c = sheetContext.pdl;
      return PdlSheet(
        title: title,
        bodyPadding: EdgeInsets.zero,
        footer: const SafeArea(top: false, child: SizedBox(height: 8)),
        children: <Widget>[
          for (final TeamRole role in kAssignableTeamRoles)
            PdlSettingRow(
              key: keys.teamAdminMembers.roleOption(role.json!),
              title: AppFormatters.roleName(role.json!),
              trailing: role == current
                  ? Icon(PdlIcons.check, size: 20, color: c.primary)
                  : const SizedBox.shrink(),
              onTap: () => Navigator.of(sheetContext).pop(role),
            ),
        ],
      );
    },
  );
}
