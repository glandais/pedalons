import 'package:flutter/services.dart';

import '../material.dart';
import '../theme/pdl_colors.dart';

/// Le « tirer pour rafraîchir » de l'app, **avec sa secousse**.
///
/// Le geste n'avait jusqu'ici aucun retour tactile : on tirait, le tourniquet
/// apparaissait, et rien ne disait que le seuil était franchi — il fallait le
/// lire. La secousse arrive au moment où le rafraîchissement part, c'est-à-dire
/// au relâchement du doigt au-delà du seuil, jamais pendant la traction : une
/// vibration à chaque pixel tiré ferait vibrer un simple défilement.
///
/// `mediumImpact` et non `selectionClick` : c'est l'intensité que la
/// plate-forme donne elle-même au rafraîchissement iOS natif, et le geste
/// engage une requête réseau — ce n'est pas le survol d'un cran de sélecteur.
///
/// `HapticFeedback` est un canal de plate-forme, pas une E/S réseau : il ne
/// connaît ni DTO ni route, et reste donc dans `core/pdl` — le même écart,
/// déjà documenté, que le `Clipboard` de `PdlMarkdownBody`.
class PdlRefresh extends StatelessWidget {
  const PdlRefresh({super.key, required this.onRefresh, required this.child});

  /// Le rafraîchissement lui-même. La secousse part **avant** lui : elle
  /// accuse réception du geste, elle n'annonce pas la réponse du serveur.
  final Future<void> Function() onRefresh;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;

    return RefreshIndicator(
      onRefresh: () async {
        await HapticFeedback.mediumImpact();
        await onRefresh();
      },
      color: c.primary,
      backgroundColor: c.surface,
      child: child,
    );
  }
}
