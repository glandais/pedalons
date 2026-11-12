import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';

/// Une position d'un [PdlSegmented].
@immutable
class PdlSegment<T> {
  const PdlSegment({
    required this.value,
    required this.label,
    this.icon,
    this.key,
    this.iconOnly = false,
  });

  final T value;
  final Key? key;
  final String label;
  final IconData? icon;

  /// L'icône seule, le libellé devenant le nom accessible et l'infobulle du
  /// segment : le sélecteur de vue d'une liste (Liste · Calendrier), dont les
  /// icônes se lisent seules. Exige une [icon].
  final bool iconOnly;
}

/// A14 — Sélecteur segmenté à 2 ou 3 positions.
///
/// **Ce n'est pas un `SegmentedButton` Material.** Le composant M3 impose sa
/// forme, une coche animée devant le libellé sélectionné et une bordure
/// continue ; la charte veut un conteneur `neutralSoft` de rayon 8 avec une
/// pastille `surface` de rayon 6 qui glisse. Rien de tout cela n'est
/// paramétrable, d'où cette implémentation.
///
/// Chaque segment mesure au moins [PdlMetrics.tapTarget] de haut, et tous ont
/// la même largeur (`.seg span { flex: 1 }`). Ce dernier point a une
/// conséquence à connaître : le widget **exige une largeur bornée**. Le poser
/// dans les `actions` d'une `AppBar` ou dans une `Row` non contrainte lève ;
/// donnez-lui une `SizedBox` ou une cellule de largeur connue.
///
/// La pastille active porte une ombre en mode clair et une **bordure** en mode
/// sombre : `PdlShadows.segThumb` rend une liste vide en sombre, où une ombre
/// ne porte pas.
class PdlSegmented<T> extends StatelessWidget {
  const PdlSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.dense = false,
  });

  final List<PdlSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  /// Des marges internes resserrées (2 au lieu de 3 autour et entre les
  /// segments, aucune au lieu de 4 dans chacun) : de quoi tenir trois
  /// libellés longs sans les couper à 390 pt de large — « Toutes les dates /
  /// Je participe / Plus tôt » (114 pt de texte pour 116 de segment). Le
  /// texte, lui, garde sa taille, et chaque segment sa hauteur de cible.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final Brightness brightness = Theme.of(context).brightness;
    final List<BoxShadow> thumbShadow = PdlShadows.segThumb(brightness);

    final double gutter = dense ? 2 : 3;
    return Container(
      padding: EdgeInsets.all(gutter),
      decoration: BoxDecoration(
        color: c.neutralSoft,
        borderRadius: PdlRadii.mdAll,
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < segments.length; i++) ...<Widget>[
            if (i > 0) SizedBox(width: gutter),
            Expanded(
              child: _Segment<T>(
                key: segments[i].key,
                segment: segments[i],
                selected: segments[i].value == value,
                onTap: () => onChanged(segments[i].value),
                surface: c.surface,
                selectedText: c.text,
                unselectedText: c.textDimmed,
                border: brightness == Brightness.dark ? c.border : null,
                shadow: thumbShadow,
                style: t.buttonSm,
                padding: dense ? 0 : 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    super.key,
    required this.segment,
    required this.selected,
    required this.onTap,
    required this.surface,
    required this.selectedText,
    required this.unselectedText,
    required this.border,
    required this.shadow,
    required this.style,
    required this.padding,
  });

  final PdlSegment<T> segment;
  final bool selected;
  final VoidCallback onTap;
  final Color surface;
  final Color selectedText;
  final Color unselectedText;
  final Color? border;
  final List<BoxShadow> shadow;
  final TextStyle style;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final Color foreground = selected ? selectedText : unselectedText;

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: PdlMotion.stateChange,
          curve: PdlMotion.stateChangeCurve,
          constraints: const BoxConstraints(minHeight: PdlMetrics.tapTarget),
          padding: EdgeInsets.symmetric(horizontal: padding),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? surface : null,
            borderRadius: PdlRadii.segThumbAll,
            border: selected && border != null
                ? Border.all(color: border!)
                : null,
            boxShadow: selected ? shadow : null,
          ),
          child: segment.iconOnly && segment.icon != null
              ? Tooltip(
                  message: segment.label,
                  excludeFromSemantics: true,
                  child: Icon(
                    segment.icon,
                    size: 16,
                    color: foreground,
                    semanticLabel: segment.label,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (segment.icon != null) ...<Widget>[
                      Icon(segment.icon, size: 16, color: foreground),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        segment.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: style.copyWith(color: foreground),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
