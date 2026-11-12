import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_typography.dart';
import '../utils/formatters.dart';

/// La seconde ligne d'un rendez-vous lu d'ailleurs : une petite icône et
/// « heure de Tokyo (ven. 01:00 chez vous) » (docs/LEDGER_*.md API-60,
/// plan §7). Ne rend rien quand le fuseau de l'entité a, à l'[instant], le
/// décalage du lecteur — le cas courant.
///
/// [instant] est la valeur du contrat (UTC), jamais une heure murale déjà
/// convertie : c'est elle qui situe le décalage et le jour du lecteur.
class ZoneMentionLine extends StatelessWidget {
  const ZoneMentionLine({super.key, required this.instant, required this.zone});

  /// Lit [iso] (un instant du contrat) ; rien quand il est absent ou illisible.
  static Widget? maybe(String? iso, String? zone) {
    final DateTime? instant = iso == null ? null : DateTime.tryParse(iso);
    if (instant == null) return null;
    if (AppFormatters.formatZoneMention(instant, zone) == null) return null;
    return ZoneMentionLine(instant: instant, zone: zone);
  }

  final DateTime instant;
  final String? zone;

  @override
  Widget build(BuildContext context) {
    final String? mention = AppFormatters.formatZoneMention(instant, zone);
    if (mention == null) return const SizedBox.shrink();
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(PdlIcons.otherTimezone, size: 14, color: c.textDimmed),
        const SizedBox(width: 4),
        Flexible(
          child: Text(mention, style: t.xs.copyWith(color: c.textDimmed)),
        ),
      ],
    );
  }
}
