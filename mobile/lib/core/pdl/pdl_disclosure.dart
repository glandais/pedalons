import 'package:flutter/material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';
import 'pdl_card.dart';

/// Le bloc repliable des écrans de détail (ledger `MOB-134`) : « Points du
/// parcours », « Cols et montées », « Météo le long du parcours ».
///
/// Une carte bordée ([PdlCard]) dont l'en-tête — titre en `cardTitle`, une ou
/// deux lignes de méta en `xs` ([subtitles] : « 2 points », « Passages estimés
/// à 28 km/h »), chevron — est **tactile sur toute sa largeur**, 56 px de
/// haut au moins (jamais moins que `PdlMetrics.tapTarget`). Le contenu
/// ([child]) se déplie dessous ; replié, il n'est pas construit.
///
/// Le lecteur d'écran lit un bouton, son titre, ses sous-titres et l'état
/// déplié / replié (`SemanticsProperties.expanded`).
///
/// Non contrôlé : [initiallyExpanded] fixe l'état de départ, [onChanged]
/// prévient l'écran qui voudrait s'en souvenir. Ne traduit rien.
class PdlDisclosure extends StatefulWidget {
  const PdlDisclosure({
    super.key,
    required this.title,
    required this.child,
    this.subtitles = const <String>[],
    this.initiallyExpanded = false,
    this.onChanged,
    this.contentPadding = const EdgeInsets.fromLTRB(
      PdlSpacing.card,
      0,
      PdlSpacing.card,
      PdlSpacing.card,
    ),
  });

  final String title;

  /// Une ou deux lignes de méta sous le titre, déjà formatées.
  final List<String> subtitles;

  final Widget child;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onChanged;

  /// Marge du contenu déplié — celle de la carte, sans le haut que l'en-tête
  /// occupe déjà.
  final EdgeInsetsGeometry contentPadding;

  /// Hauteur minimale de l'en-tête (`min-height: 56px` des maquettes).
  static const double headerMinHeight = 56;

  @override
  State<PdlDisclosure> createState() => _PdlDisclosureState();
}

class _PdlDisclosureState extends State<PdlDisclosure> {
  late bool _expanded = widget.initiallyExpanded;

  void _toggle() {
    setState(() => _expanded = !_expanded);
    widget.onChanged?.call(_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    final Widget header = Semantics(
      button: true,
      expanded: _expanded,
      child: InkWell(
        onTap: _toggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: PdlDisclosure.headerMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PdlSpacing.card,
              vertical: PdlSpacing.chipGap,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(widget.title, style: t.cardTitle),
                      for (final String line in widget.subtitles)
                        Text(line, style: t.xs),
                    ],
                  ),
                ),
                const SizedBox(width: PdlSpacing.cardTight),
                ExcludeSemantics(
                  child: Icon(
                    _expanded ? PdlIcons.chevronUp : PdlIcons.chevronDown,
                    size: 20,
                    color: c.textDimmed,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return PdlCard(
      padding: PdlCardPadding.none,
      child: AnimatedSize(
        duration: reduceMotion ? Duration.zero : PdlMotion.stateChange,
        curve: PdlMotion.stateChangeCurve,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            header,
            if (_expanded)
              Padding(padding: widget.contentPadding, child: widget.child),
          ],
        ),
      ),
    );
  }
}
