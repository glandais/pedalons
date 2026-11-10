import 'package:flutter/material.dart';

import '../pdl/pdl.dart';
import '../theme/pdl_colors.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';

/// Une tuile de [DetailStatTiles] : libellé et valeur déjà formatée. La valeur
/// ne répète pas le libellé (KIT §8 : « Étapes 3 », pas « 3 étapes »).
@immutable
class DetailStatTile {
  const DetailStatTile({required this.label, required this.value});

  final String label;
  final String value;
}

/// Les tuiles de chiffres des écrans de détail (ledger `MOB-134`) : carte
/// bordée, grille de deux colonnes, libellé `xs` au-dessus de la valeur.
///
/// L'ordre est **celui de l'appelant**, qui suit la règle du KIT §8 : ligne 1
/// Distance | Dénivelé, ligne 2 Durée | Vitesse (groupe, étape, sortie solo)
/// ou Étapes (voyage). Deux tuiles tiennent sur une ligne, sans trou.
/// [heading] pose un intitulé pleine largeur en tête (« Votre groupe : B »,
/// 12/600 sur `primaryOnSoft`).
///
/// Bâti sur [PdlCard] et [PdlMetaGrid] / [PdlMetaCell], la grille méta de
/// `MOB-113` : elle passe déjà à une colonne quand le texte grossit.
/// `PdlStatCellRow` ne convenait pas — valeur au-dessus du libellé, centrée,
/// sur une seule rangée et sans bordure.
class DetailStatTiles extends StatelessWidget {
  const DetailStatTiles({super.key, required this.tiles, this.heading});

  final List<DetailStatTile> tiles;
  final String? heading;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty && heading == null) return const SizedBox.shrink();
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    return PdlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (heading != null) ...<Widget>[
            Semantics(
              header: true,
              child: Text(
                heading!,
                style: t.xs.copyWith(
                  fontWeight: FontWeight.w600,
                  color: c.primaryOnSoft,
                ),
              ),
            ),
            if (tiles.isNotEmpty) const SizedBox(height: PdlSpacing.chipGap),
          ],
          if (tiles.isNotEmpty)
            PdlMetaGrid(
              cells: <Widget>[
                for (final DetailStatTile tile in tiles)
                  MergeSemantics(
                    child: PdlMetaCell(label: tile.label, value: tile.value),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
