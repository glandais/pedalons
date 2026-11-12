import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../api/generated/export.dart';
import '../pdl/pdl.dart';
import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';

// La portée d'une liste inter-équipes, **une seule forme dans toute l'app**
// (règle RL2 des listes, KIT §10) : une puce « Portée », neutre au défaut,
// teintée hors du défaut, qui ouvre une feuille à coche — sans chevrons, une
// valeur par ligne. Le fil d'accueil et Explorer y choisissent un rôle (quatre
// valeurs) ; le calendrier global, seul, une équipe.

/// Les quatre portées d'une liste inter-équipes, dans l'ordre de la feuille :
/// « Toutes les équipes / Membre / Organisateur / Administrateur ».
const List<MinRole?> kMembershipScopes = <MinRole?>[
  null,
  MinRole.member,
  MinRole.organizer,
  MinRole.admin,
];

/// Le nom d'une portée : le rôle minimum, ou « Toutes les équipes » sans rôle.
String membershipScopeLabel(MinRole? scope) => switch (scope) {
  MinRole.member => 'roles.member'.tr(),
  MinRole.organizer => 'roles.organizer'.tr(),
  MinRole.admin => 'roles.admin'.tr(),
  _ => 'lists.scope.all'.tr(),
};

/// Un choix de la feuille à coche : sa valeur et son libellé.
typedef CheckOption<T> = ({T value, String label});

/// La feuille à coche d'une puce exclusive : une ligne par valeur, une coche
/// sur la valeur courante, **pas de chevron** — choisir referme la feuille.
///
/// Rend l'**indice** choisi, `null` si la feuille est fermée sans choix : une
/// valeur nulle (« Toutes les équipes ») ne se confond pas avec un abandon.
Future<int?> showCheckSheet<T>(
  BuildContext context, {
  required String title,
  required List<CheckOption<T>> options,
  required T selected,
  Key Function(int index)? rowKey,
}) {
  return PdlSheet.show<int>(
    context: context,
    builder: (BuildContext sheetContext) => PdlSheet(
      title: title,
      bodyPadding: EdgeInsets.zero,
      footer: const SafeArea(top: false, child: SizedBox(height: 8)),
      children: <Widget>[
        for (int i = 0; i < options.length; i++)
          PdlSettingRow(
            key: rowKey?.call(i),
            title: options[i].label,
            // Une coche sur la valeur courante, rien sur les autres : sans
            // `trailing`, la ligne poserait un chevron, qui promet un niveau
            // de plus là où choisir referme la feuille.
            trailing: options[i].value == selected
                ? Icon(
                    PdlIcons.check,
                    size: 20,
                    color: sheetContext.pdl.primary,
                  )
                : const SizedBox.shrink(),
            onTap: () => Navigator.of(sheetContext).pop(i),
          ),
      ],
    ),
  );
}

/// La puce « Portée » d'une liste inter-équipes : le rôle minimum.
///
/// [defaultScope] est la portée d'ouverture de la liste (« Membre », ou
/// « Toutes les équipes » pour qui n'a aucune équipe — règle RL1) : la puce
/// n'est teintée qu'à l'écart de ce défaut.
class MembershipScopeChip extends StatelessWidget {
  const MembershipScopeChip({
    super.key,
    required this.scope,
    required this.defaultScope,
    required this.onChanged,
  });

  final MinRole? scope;
  final MinRole? defaultScope;
  final ValueChanged<MinRole?> onChanged;

  @override
  Widget build(BuildContext context) => PdlScopeSelector(
    label: membershipScopeLabel(scope),
    active: scope != defaultScope,
    semanticLabel: 'lists.scope.title'.tr(),
    onTap: () async {
      final int? picked = await showCheckSheet<MinRole?>(
        context,
        title: 'lists.scope.title'.tr(),
        selected: scope,
        options: <CheckOption<MinRole?>>[
          for (final MinRole? s in kMembershipScopes)
            (value: s, label: membershipScopeLabel(s)),
        ],
      );
      if (picked != null) onChanged(kMembershipScopes[picked]);
    },
  );
}
