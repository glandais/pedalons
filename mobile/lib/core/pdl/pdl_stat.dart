import 'package:flutter/material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_typography.dart';

/// Le sens d'une statistique de relief : dénivelé positif ou négatif.
enum PdlStatTrend { none, up, down }

/// A6 — Une statistique : icône, valeur, libellé.
///
/// En ligne (`.stat`), la valeur est en 14/600 sur `text` et le libellé en
/// 14/400 sur `textDimmed` : c'est le chiffre qu'on lit, pas l'unité.
/// [big] passe en colonne et monte la valeur à 17/600.
///
/// [trend] recolore l'ensemble en `successOnSoft` / `dangerOnSoft` — le vert
/// et le rouge de la charte veulent dire « ça monte » et « ça descend », pas
/// « bien » et « mal ».
class PdlStat extends StatelessWidget {
  const PdlStat({
    super.key,
    required this.value,
    this.icon,
    this.label,
    this.big = false,
    this.trend = PdlStatTrend.none,
  });

  final String value;
  final IconData? icon;
  final String? label;
  final bool big;
  final PdlStatTrend trend;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    final Color? trendColor = switch (trend) {
      PdlStatTrend.none => null,
      PdlStatTrend.up => c.successOnSoft,
      PdlStatTrend.down => c.dangerOnSoft,
    };

    final TextStyle valueStyle = (big ? t.statBigValue : t.statValue).copyWith(
      color: trendColor,
    );
    final TextStyle labelStyle = t.sub.copyWith(color: trendColor);

    final Widget iconWidget = icon == null
        ? const SizedBox.shrink()
        : Icon(icon, size: 16, color: trendColor ?? c.textDimmed);

    if (big) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[iconWidget, const SizedBox(height: 2)],
          Text(value, style: valueStyle),
          if (label != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(label!, style: labelStyle),
          ],
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (icon != null) ...<Widget>[iconWidget, const SizedBox(width: 5)],
        // Souple : une valeur longue — « ven. 16 → dim. 18 oct. » —
        // passe à la ligne au lieu de déborder de la carte.
        Flexible(child: Text(value, style: valueStyle)),
        if (label != null) ...<Widget>[
          const SizedBox(width: 4),
          Text(label!, style: labelStyle),
        ],
      ],
    );
  }
}
