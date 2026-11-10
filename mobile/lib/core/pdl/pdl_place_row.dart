import 'package:flutter/material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';

/// Les deux bouts d'un parcours. La couleur est celle des marqueurs
/// cartographiques : vert au départ, rouge à l'arrivée — la même que sur la
/// carte, sinon la lecture croisée ne se fait pas.
enum PdlPlaceKind { start, end }

/// B4 — Ligne de lieu : pastille de 10 px, nom, adresse.
///
/// Le nom est en `bodyStrong` et l'adresse en `xs` : c'est le nom qu'on
/// cherche (« Fonderies »), l'adresse ne sert qu'à lever un doute.
class PdlPlaceRow extends StatelessWidget {
  const PdlPlaceRow({
    super.key,
    required this.kind,
    required this.name,
    this.address,
    this.trailing,
    this.onTap,
  }) : _link = false,
       semanticLabel = null;

  /// La variante « lien d'itinéraire » des écrans de détail (ledger `MOB-132`,
  /// KIT §8 : « liens noirs soulignés qui ouvrent l'itinéraire ») : drapeau
  /// vert (départ) ou rouge (arrivée) de 16 px, [name] en 14 couleur de texte
  /// — pas la couleur de lien —, souligné discret (`textPlaceholder`).
  ///
  /// Avec [onTap], la ligne entière est tactile sur 44 px de haut et se lit
  /// comme un lien nommé [semanticLabel] (« Itinéraire vers Place de la
  /// Mairie », `common.directionsTo`, traduit par l'écran). Sans [onTap] —
  /// ni coordonnées ni adresse, rien à ouvrir —, le nom reste un texte simple,
  /// sans soulignement.
  const PdlPlaceRow.link({
    super.key,
    required this.kind,
    required this.name,
    this.onTap,
    this.semanticLabel,
  }) : _link = true,
       address = null,
       trailing = null;

  final PdlPlaceKind kind;
  final String name;
  final String? address;

  /// Action de bout de ligne — « Itinéraire », « Copier l'adresse ».
  final Widget? trailing;

  final VoidCallback? onTap;

  /// Lu à la place du nom par le lecteur d'écran — variante [PdlPlaceRow.link].
  final String? semanticLabel;

  final bool _link;

  @override
  Widget build(BuildContext context) {
    if (_link) return _buildLink(context);
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final Color dot = kind == PdlPlaceKind.start ? c.mapStart : c.mapEnd;

    final Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          // 6 px de marge haute : la pastille s'aligne sur la première ligne
          // du nom, pas sur le haut de la boîte.
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(name, style: t.bodyStrong),
              if (address != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(address!, style: t.xs),
              ],
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[const SizedBox(width: 8), trailing!],
      ],
    );

    if (onTap == null) return content;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: content,
        ),
      ),
    );
  }

  Widget _buildLink(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final Color flag = kind == PdlPlaceKind.start ? c.mapStart : c.mapEnd;
    final bool tappable = onTap != null;

    final TextStyle base = t.sub.copyWith(color: c.text);
    final Widget content = Row(
      children: <Widget>[
        Icon(PdlIcons.placeFlag, size: 16, color: flag),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            name,
            style: tappable
                ? base.copyWith(
                    decoration: TextDecoration.underline,
                    decorationColor: c.textPlaceholder,
                  )
                : base,
          ),
        ),
      ],
    );

    if (!tappable) return content;
    return Semantics(
      link: true,
      label: semanticLabel ?? name,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: PdlRadii.mdAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: PdlMetrics.tapTarget),
            child: Align(alignment: Alignment.centerLeft, child: content),
          ),
        ),
      ),
    );
  }
}
