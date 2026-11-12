import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_typography.dart';
import 'pdl_card.dart';

/// B19 — Bloc de prix d'une annonce.
///
/// Carte plate, icône de 24 px en `accentOrange` — la teinte de la famille
/// « annonce » —, prix en 20/700. C'est l'information qu'on cherche en premier
/// sur une annonce ; elle a droit à sa propre boîte plutôt qu'à une ligne de
/// statistique parmi d'autres.
///
/// [price] est **déjà formaté** par l'appelant : monnaie, séparateurs et
/// locale n'appartiennent pas à `core/pdl`. [note] porte « à débattre »,
/// « par jour », ou l'absence de prix.
class PdlPriceBlock extends StatelessWidget {
  const PdlPriceBlock({
    super.key,
    required this.price,
    this.note,
    this.icon = PdlIcons.price,
    this.trailing,
  });

  final String price;
  final String? note;
  final IconData icon;

  /// Action de bout de bloc — « Contacter le vendeur ».
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    return PdlCard(
      flat: true,
      child: Row(
        children: <Widget>[
          Icon(icon, size: 24, color: c.accentOrange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  price,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.screenTitle.copyWith(fontSize: 20, color: c.text),
                ),
                if (note != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(note!, style: t.xs),
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}
