import 'package:flutter/material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_typography.dart';
import '../../api/generated/models/unit_system.dart';
import '../utils/formatters.dart';

/// La ligne de chiffres d'une carte de groupe ou d'étape (ledger `MOB-132`,
/// KIT §8) : « 78,0 km · 980 m D+ · 25 km/h », chaque valeur précédée de son
/// icône de 14 px, le tout en 14 atténué. Une valeur absente disparaît ;
/// sans aucune, rien n'est rendu. Passe à la ligne entre deux valeurs, jamais
/// au milieu d'une.
///
/// Pas un `PdlStatRow` : `PdlStat` met la valeur en 14/600 couleur de texte
/// et l'icône à 16, la charte de cette ligne est en 14/400 atténué.
class PublicationStatsLine extends StatelessWidget {
  const PublicationStatsLine({
    super.key,
    this.distanceMeters,
    this.elevationGainMeters,
    this.speedKmh,
    this.units = UnitSystem.metric,
  });

  final num? distanceMeters;
  final num? elevationGainMeters;

  /// En km/h, comme `RideGroupDto.averageSpeed`.
  final num? speedKmh;
  final UnitSystem units;

  /// Écart entre deux valeurs (`gap: 10px` des maquettes) et entre l'icône
  /// et sa valeur (`gap: 3px`).
  static const double _entryGap = 10;
  static const double _iconGap = 3;
  static const double _iconSize = 14;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    final List<(IconData, String)> entries = <(IconData, String)>[
      if (distanceMeters != null)
        (
          PdlIcons.distance,
          AppFormatters.formatDistance(distanceMeters!, units),
        ),
      if (elevationGainMeters != null)
        (
          PdlIcons.elevationUp,
          AppFormatters.formatElevationGain(elevationGainMeters!, units),
        ),
      if (speedKmh != null)
        (PdlIcons.speed, AppFormatters.formatSpeed(speedKmh!, units)),
    ];
    if (entries.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: _entryGap,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        for (final (IconData icon, String value) in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: _iconSize, color: c.textDimmed),
              const SizedBox(width: _iconGap),
              Text(value, style: t.sub),
            ],
          ),
      ],
    );
  }
}
