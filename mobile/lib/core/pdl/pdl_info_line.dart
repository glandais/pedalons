import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_typography.dart';

/// A16 — Ligne « libellé / valeur » d'un bloc d'informations.
///
/// Padding vertical 8, filet bas `borderSubtle`. Ce n'est **pas** un
/// [PdlSettingRow] : rien n'y est cliquable, et la ligne peut donc descendre
/// sous 44 px. Passer [showDivider] à `false` sur la dernière ligne d'un bloc
/// évite le filet en doublon avec celui du conteneur.
class PdlInfoLine extends StatelessWidget {
  const PdlInfoLine({
    super.key,
    required this.label,
    this.value,
    this.valueWidget,
    this.showDivider = true,
  }) : assert(
         value != null || valueWidget != null,
         'une ligne d\'information porte une valeur',
       );

  final String label;
  final String? value;

  /// Valeur non textuelle — badge, avatar, groupe de badges.
  final Widget? valueWidget;

  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: showDivider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: c.borderSubtle)),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: Text(label, style: t.sub)),
          const SizedBox(width: 12),
          Flexible(
            child:
                valueWidget ??
                Text(value!, textAlign: TextAlign.right, style: t.bodyStrong),
          ),
        ],
      ),
    );
  }
}
