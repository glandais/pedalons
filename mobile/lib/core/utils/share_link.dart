import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/app_config.dart';

/// Partage **un lien**, et non un titre nu.
///
/// Les six boutons de partage de l'app envoyaient le nom de l'objet et rien
/// d'autre : « Les Cyclos du Dimanche » collé dans une conversation ne mène
/// nulle part, et le destinataire n'a aucun moyen de retrouver l'équipe.
///
/// L'URL est construite sur [AppConfig.deepLinkHost] à partir du chemin de
/// `Paths`, donc **c'est un app link** : il ouvre l'app chez qui l'a installée
/// et le site chez les autres — voir `docs/APP_LINKS.md`.
///
/// `uri` et `text` s'excluent dans `share_plus` ; c'est `uri` qu'on garde,
/// parce qu'iOS en tire un aperçu (titre et favicon) là où un texte contenant
/// une URL reste une ligne grise. Le nom passe par `title`/`subject`, qui
/// alimentent le titre du sélecteur Android et l'objet d'un e-mail.
Future<void> shareAppLink(
  BuildContext context, {
  required String title,
  required String path,
}) async {
  await SharePlus.instance.share(
    ShareParams(
      uri: Uri.parse(
        '${AppConfig.deepLinkScheme}://${AppConfig.deepLinkHost}$path',
      ),
      title: title,
      subject: title,
      sharePositionOrigin: shareOriginOf(context),
    ),
  );
}

/// Le rectangle d'où part la feuille de partage : celui de [context].
///
/// Sur iPad la feuille s'ancre au bouton ; sans rectangle elle s'ancre au
/// centre de l'écran, ce qui la fait pointer vers rien.
Rect shareOriginOf(BuildContext context) {
  final RenderBox? box = context.findRenderObject() as RenderBox?;
  return box == null ? Rect.zero : box.localToGlobal(Offset.zero) & box.size;
}
