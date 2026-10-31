import 'package:dio/dio.dart' show Dio;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../api/generated/export.dart';
import '../../api/pedalons_api_client.dart';
import 'share_link.dart';

/// Télécharge [asset] dans le répertoire temporaire, puis ouvre la feuille de
/// partage du système sur le fichier.
///
/// Le seul chemin par lequel l'app remet un fichier au système : export GPX/FIT
/// d'un parcours (fiche parcours, groupes d'une sortie) comme pièce jointe d'un
/// contenu (`MediaAttachments`).
///
/// **Le téléchargement passe par le `Dio` authentifié, jamais par le
/// navigateur** : `AssetDto.url` sort sur `/api/download/{visibilité}/…`, dont
/// l'autorisation est celle du contenu porteur ; confier l'URL au système
/// ouvrirait un onglet sur une erreur 403.
///
/// [origin] ancre la feuille sur iPad ([shareOriginOf]). Lève en cas d'échec ;
/// c'est à l'appelant d'afficher son bandeau.
Future<void> downloadAndShareAsset(
  WidgetRef ref,
  AssetDto asset, {
  required Rect origin,
}) async {
  final Dio dio = ref.read(dioProvider);
  final String path =
      '${(await getTemporaryDirectory()).path}/${asset.fileName}';
  await dio.download(asset.url, path);
  await SharePlus.instance.share(
    ShareParams(files: <XFile>[XFile(path)], sharePositionOrigin: origin),
  );
}
