import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';

/// Les quatre variantes du bouton unique de l'application.
enum PdlButtonVariant {
  /// Aplat primaire. **Une seule par zone d'écran.**
  fill,

  /// Contour neutre.
  outline,

  /// Action textuelle en `link` — l'ancien `.btn--txt`.
  text,

  /// Action destructive : un **contour** rouge, jamais un aplat.
  danger,
}

/// Les deux tailles. `sm` compacte la typographie et les gouttières,
/// **jamais la cible tactile**.
enum PdlButtonSize { md, sm }

/// A3 — Le bouton unique de l'application.
///
/// Il absorbe ce que trois plans avaient éclaté en `PdlTextButton`,
/// `PdlTextAction` et `PdlLoadingButton` : ces noms sont interdits, tout passe
/// par [variant] et [loading].
///
/// Deux règles tiennent toute la classe :
///
/// * **Hauteur minimale 44 px dans toutes les tailles.** `sm` descend la
///   typographie de 15/600 à 14/600 et les gouttières de 16 à 14 ; la cible
///   reste à 44 (`pedalons.css` : `.btn--sm { min-height: 44px }`).
/// * **`danger` est un contour.** Un aplat rouge pleine largeur en bas d'un
///   écran de réglages se confond avec l'action principale ; la charte réserve
///   l'aplat à la primaire.
///
/// [loading] passe le fond en `disabledBg`, coupe l'action et **substantive le
/// libellé** ([loadingLabel] : « Inscription... » et non « S'inscrire »).
class PdlButton extends StatelessWidget {
  const PdlButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = PdlButtonVariant.fill,
    this.size = PdlButtonSize.md,
    this.fullWidth = false,
    this.pill = false,
    this.icon,
    this.loading = false,
    this.enabled = true,
    this.loadingLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final PdlButtonVariant variant;
  final PdlButtonSize size;
  final bool fullWidth;

  /// Rayon pilule au lieu du rayon 8.
  final bool pill;

  /// Icône de tête, 18 px (16 px en `text`).
  final IconData? icon;

  /// En cours : fond `disabledBg`, action coupée, [loadingLabel] affiché.
  final bool loading;

  final bool enabled;

  /// Libellé substantivé affiché pendant [loading]. À défaut, [label].
  final String? loadingLabel;

  bool get _interactive => enabled && !loading && onPressed != null;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final bool isText = variant == PdlButtonVariant.text;
    final bool small = size == PdlButtonSize.sm;

    final TextStyle baseStyle = isText
        ? t.textButton
        : (small ? t.buttonSm : t.button);

    // `null` vaut « pas de fond du tout » : le bouton textuel est rendu en
    // [MaterialType.transparency], pas en aplat de la couleur du fond.
    Color? background;
    Color foreground;
    Color? borderColor;

    if (loading || !_interactive) {
      background = isText ? null : c.disabledBg;
      foreground = c.disabledText;
      borderColor = null;
    } else {
      switch (variant) {
        case PdlButtonVariant.fill:
          background = c.primary;
          foreground = c.onPrimary;
          borderColor = null;
        case PdlButtonVariant.outline:
          background = c.surface;
          foreground = c.text;
          borderColor = c.border;
        case PdlButtonVariant.danger:
          background = c.surface;
          foreground = c.dangerOnSoft;
          borderColor = c.danger;
        case PdlButtonVariant.text:
          background = null;
          foreground = c.link;
          borderColor = null;
      }
    }

    final BorderRadius radius = pill ? PdlRadii.pillAll : PdlRadii.mdAll;
    final double horizontal = isText ? 6 : (small ? 14 : 16);
    final double iconSize = isText ? 16 : 18;
    final String shownLabel = loading ? (loadingLabel ?? label) : label;

    // Un bouton sans libellé — device, partage — n'est pas un bouton texte
    // avec une icône devant : c'est une icône seule. Lui garder la
    // même rangée [icône, gouttière, `Text` vide] la décentrait, le `Text`
    // vide occupant quand même un créneau que la rangée centrait avec le
    // reste. Carré, sans gouttière, l'icône y est seule au milieu.
    final bool iconOnly = !loading && icon != null && shownLabel.isEmpty;

    final Widget content = iconOnly
        ? Icon(icon, size: iconSize, color: foreground)
        : Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (loading) ...<Widget>[
                SizedBox(
                  width: iconSize,
                  height: iconSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                  ),
                ),
                SizedBox(width: isText ? 5 : 8),
              ] else if (icon != null) ...<Widget>[
                Icon(icon, size: iconSize, color: foreground),
                SizedBox(width: isText ? 5 : 8),
              ],
              Flexible(
                child: Text(
                  shownLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: baseStyle.copyWith(color: foreground),
                ),
              ),
            ],
          );

    return Semantics(
      button: true,
      enabled: _interactive,
      child: Material(
        type: background == null
            ? MaterialType.transparency
            : MaterialType.canvas,
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: borderColor == null
              ? BorderSide.none
              : BorderSide(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _interactive ? onPressed : null,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: PdlMetrics.tapTarget,
              minWidth: iconOnly
                  ? PdlMetrics.tapTarget
                  : (fullWidth ? double.infinity : 0),
            ),
            child: iconOnly
                ? Center(child: content)
                : Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontal),
                    child: content,
                  ),
          ),
        ),
      ),
    );
  }
}
