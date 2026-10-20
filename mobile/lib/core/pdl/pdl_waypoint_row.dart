import 'package:flutter/material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';
import 'map/pdl_waypoint_mark.dart';

/// Le pictogramme d'un point de parcours : un disque et son glyphe. Décoratif,
/// donc exclu de la sémantique : le type est dit par le texte à côté.
class PdlWaypointBadge extends StatelessWidget {
  const PdlWaypointBadge({super.key, required this.mark, this.size = 28});

  final PdlWaypointMark mark;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: mark.disc, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(mark.glyph, size: size * 0.62, color: mark.onDisc),
    ),
  );
}

/// Une ligne de la liste des points de parcours : la distance, le pictogramme,
/// le nom (ou le type quand il n'y en a pas), le type, la description.
///
/// Tout est **déjà traduit et formaté** par l'écran (`core/pdl` ne connaît ni
/// la langue ni les unités).
class PdlWaypointRow extends StatelessWidget {
  const PdlWaypointRow({
    super.key,
    required this.mark,
    required this.distanceLabel,
    required this.title,
    this.subtitle,
    this.description,
    this.semanticLabel,
    this.selected = false,
    this.onTap,
    this.showDivider = true,
  });

  final PdlWaypointMark mark;

  /// « 12,3 km » ou « Hors tracé ».
  final String distanceLabel;

  /// Le nom, ou le libellé du type quand le point n'est pas nommé.
  final String title;

  /// Le libellé du type, quand [title] est un nom.
  final String? subtitle;

  /// Au plus deux lignes.
  final String? description;

  /// Lu par les lecteurs d'écran à la place du contenu de la ligne.
  final String? semanticLabel;

  final bool selected;
  final VoidCallback? onTap;
  final bool showDivider;

  /// Largeur de la colonne des distances.
  static const double distanceWidth = 78;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    final Widget content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: PdlMetrics.tapTarget),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: distanceWidth,
              child: Text(
                distanceLabel,
                style: t.mono.copyWith(color: c.textDimmed),
              ),
            ),
            PdlWaypointBadge(mark: mark),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyStrong,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.xs.copyWith(color: c.textDimmed),
                    ),
                  if (description != null && description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.xs,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    Widget body = Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: onTap, child: content),
    );
    if (selected) {
      body = DecoratedBox(
        decoration: BoxDecoration(color: c.primarySoft),
        child: body,
      );
    }
    body = Semantics(
      button: onTap != null,
      selected: selected,
      onTap: onTap,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: semanticLabel == null ? MergeSemantics(child: body) : body,
    );

    if (!showDivider) return body;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.borderSubtle)),
      ),
      child: body,
    );
  }
}
