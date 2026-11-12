import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_typography.dart';

/// B17 — Filtre de plage à deux poignées.
///
/// Rail de 4 px, plage retenue en `primary`, poignées de 20 px, bornes en
/// `monoAxis` sous le rail. Les bornes sont **formatées par l'appelant** :
/// `core/pdl` ne connaît ni les unités ni la locale.
///
/// L'implémentation s'appuie sur [RangeSlider] retaillé par un [SliderTheme] —
/// le composant Material gère déjà la sémantique, le clavier et le retour
/// haptique ; le refaire à la main coûterait ces trois choses.
class PdlRangeFilter extends StatelessWidget {
  const PdlRangeFilter({
    super.key,
    required this.values,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.lowLabel,
    required this.highLabel,
    this.divisions,
    this.semanticFormatter,
  });

  final RangeValues values;
  final double min;
  final double max;
  final ValueChanged<RangeValues> onChanged;

  /// Bornes déjà formatées — « 0 km » et « 200 km ».
  final String lowLabel;
  final String highLabel;

  final int? divisions;

  /// Rend une valeur lisible par un lecteur d'écran.
  final String Function(double value)? semanticFormatter;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: c.primary,
            inactiveTrackColor: c.neutralSoft,
            thumbColor: c.surface,
            overlayColor: c.primary.withValues(alpha: 0.12),
            rangeThumbShape: const RoundRangeSliderThumbShape(
              enabledThumbRadius: 10,
            ),
            rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
            showValueIndicator: ShowValueIndicator.onDrag,
            valueIndicatorColor: c.neutralOnSoft,
          ),
          child: RangeSlider(
            values: values,
            min: min,
            max: max,
            divisions: divisions,
            labels: semanticFormatter == null
                ? null
                : RangeLabels(
                    semanticFormatter!(values.start),
                    semanticFormatter!(values.end),
                  ),
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(lowLabel, style: t.monoAxis),
              Text(highLabel, style: t.monoAxis),
            ],
          ),
        ),
      ],
    );
  }
}
