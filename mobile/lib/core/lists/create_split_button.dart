import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

import '../material.dart';
import '../pdl/pdl.dart';
import '../theme/enum_colors.dart';
import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';

/// Une création proposée par un [CreateSplitButton].
class CreateAction {
  const CreateAction({
    required this.key,
    required this.label,
    required this.icon,
    required this.location,
    this.subtitle,
    this.group,
    this.tone,
  });

  final Key key;
  final String label;
  final IconData icon;
  final String location;
  final String? subtitle;

  /// La teinte métier de l'icône dans la feuille — celle du site (`ThemeIcon`
  /// « light » de la famille) : sortie, voyage, publication par leur type,
  /// parcours en indigo.
  final PdlTone Function(PdlColors c)? tone;

  /// La section de la feuille ; des actions consécutives du même groupe
  /// partagent son titre.
  final String? group;

  CreateAction withGroup(String group) => CreateAction(
    key: key,
    label: label,
    icon: icon,
    location: location,
    subtitle: subtitle,
    group: group,
    tone: tone,
  );
}

/// « Créer une sortie ▾ », comme le site (`CreateSplitButton`) : la première
/// action en bouton, toutes derrière le chevron, dans une feuille par
/// sections. Une seule action : le bouton seul.
///
/// [compact] est la forme de la barre d'outils d'une liste (règle RL13) :
/// petit, libellé court « Créer », le lecteur d'écran lisant le nom complet
/// de l'action.
class CreateSplitButton extends StatelessWidget {
  const CreateSplitButton({
    super.key,
    required this.actions,
    required this.primaryKey,
    required this.menuKey,
    this.compact = false,
  });

  final List<CreateAction> actions;
  final Key primaryKey;
  final Key menuKey;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final CreateAction primary = actions.first;
    final PdlButtonSize size = compact ? PdlButtonSize.sm : PdlButtonSize.md;
    final Widget primaryButton = compact
        ? Semantics(
            label: primary.label,
            excludeSemantics: true,
            button: true,
            onTap: () => context.push(primary.location),
            child: PdlButton(
              key: primaryKey,
              label: 'lists.create'.tr(),
              icon: PdlIcons.add,
              size: size,
              onPressed: () => context.push(primary.location),
            ),
          )
        : PdlButton(
            key: primaryKey,
            label: primary.label,
            icon: PdlIcons.add,
            fullWidth: true,
            onPressed: () => context.push(primary.location),
          );
    final Widget? menuButton = actions.length > 1
        ? Semantics(
            label: 'teams.dashboard.create.other'.tr(),
            child: PdlButton(
              key: menuKey,
              label: '',
              icon: PdlIcons.chevronDown,
              size: size,
              onPressed: () => _openSheet(context),
            ),
          )
        : null;
    return Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: <Widget>[
        if (compact) primaryButton else Expanded(child: primaryButton),
        if (menuButton != null) ...<Widget>[
          const SizedBox(width: PdlSpacing.chipGap),
          menuButton,
        ],
      ],
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final String? location = await PdlSheet.show<String>(
      context: context,
      builder: (BuildContext sheetContext) {
        final PdlTypography t = sheetContext.pdlText;
        final List<Widget> rows = <Widget>[];
        for (int i = 0; i < actions.length; i++) {
          final CreateAction action = actions[i];
          final String? group = action.group;
          if (group != null && (i == 0 || actions[i - 1].group != group)) {
            rows.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(group, style: t.sub),
              ),
            );
          }
          rows.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PdlSettingRow(
                key: action.key,
                title: action.label,
                subtitle: action.subtitle,
                icon: action.icon,
                leading: _toneIcon(sheetContext, action),
                showDivider:
                    i < actions.length - 1 && actions[i + 1].group == group,
                onTap: () => Navigator.of(sheetContext).pop(action.location),
              ),
            ),
          );
        }
        return PdlSheet(
          title: 'teams.dashboard.create.title'.tr(),
          children: rows,
        );
      },
    );
    if (location != null && context.mounted) context.push(location);
  }
}

/// L'icône d'une ligne dans sa pastille de famille ; nulle sans teinte, la
/// ligne garde alors son icône nue.
Widget? _toneIcon(BuildContext context, CreateAction action) {
  final PdlTone Function(PdlColors c)? tone = action.tone;
  if (tone == null) return null;
  final PdlTone t = tone(context.pdl);
  return Container(
    width: PdlMetrics.chipVisual,
    height: PdlMetrics.chipVisual,
    decoration: BoxDecoration(
      color: t.soft,
      borderRadius: const BorderRadius.all(PdlRadii.md),
    ),
    child: Icon(action.icon, size: 18, color: t.onSoft),
  );
}
