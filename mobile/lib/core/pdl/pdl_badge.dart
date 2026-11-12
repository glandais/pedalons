import '../material.dart';

import '../theme/enum_colors.dart' show PdlTone;
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';

/// Les deux tailles de badge de la charte (`.badge` et `.badge--lg`).
enum PdlBadgeSize {
  /// 18 px de haut, texte 10/700, gouttières 8.
  sm,

  /// 22 px de haut, texte 11/700, gouttières 10.
  lg,
}

/// A2 — Étiquette de type, de statut, de visibilité, de rôle, de revêtement ou
/// de catégorie de col.
///
/// La teinte arrive **toujours** par un [PdlTone] : `core/pdl` ne connaît aucun
/// DTO, c'est l'appelant qui traduit son enum en teinte via l'extension
/// `tone(PdlColors)` de `core/theme/enum_colors.dart`.
///
/// Rendu doux par défaut (fond pâle, texte foncé de la même famille) ; les
/// familles dont le [PdlTone.filledStyle] est vrai — les catégories de col —
/// se rendent en aplat. [filled] force l'un ou l'autre.
///
/// Le libellé est **mis en capitales** : `text-transform: uppercase` est porté
/// par `.badge`, pas par les chaînes traduites.
class PdlBadge extends StatelessWidget {
  const PdlBadge({
    super.key,
    required this.label,
    required this.tone,
    this.size = PdlBadgeSize.sm,
    this.icon,
    this.filled,
    this.dot = false,
  });

  final String label;
  final PdlTone tone;
  final PdlBadgeSize size;

  /// Icône interne, rendue à 11 px devant le libellé.
  final IconData? icon;

  /// Force l'aplat (`true`) ou le doux (`false`). Par défaut, la famille
  /// décide via [PdlTone.filledStyle].
  final bool? filled;

  /// Une pastille pleine devant le libellé, de la couleur du texte : l'état
  /// « en cours » d'une sortie (« ● EN COURS »), qui dit un instant présent
  /// plutôt qu'une catégorie. Ignorée quand [icon] est donnée.
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    final bool isFilled = filled ?? tone.filledStyle;
    final Color background = isFilled ? tone.fill : tone.soft;
    final Color foreground = isFilled ? tone.onFill : tone.onSoft;
    final bool large = size == PdlBadgeSize.lg;

    // `minHeight` et non `height` : à fort agrandissement typographique un
    // badge doit grandir, pas rogner ses capitales.
    return Container(
      constraints: BoxConstraints(minHeight: large ? 22 : 18),
      padding: EdgeInsets.symmetric(horizontal: large ? 10 : 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: PdlRadii.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 11, color: foreground),
            const SizedBox(width: 4),
          ] else if (dot) ...<Widget>[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (large ? t.badgeLg : t.badge).copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
