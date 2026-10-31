import 'package:dio/dio.dart' show Dio, Options, Response, ResponseType;
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../api/generated/export.dart';
import '../../api/pedalons_api_client.dart';
import '../../keys.dart';
import '../pdl/pdl.dart';
import '../theme/pdl_icons.dart';
import 'share_link.dart';

/// Où va un fichier qu'on télécharge : sur le téléphone, ou vers une autre app.
enum AssetDestination { device, share }

/// Demande où envoyer [asset] — `null` si la personne referme la feuille.
///
/// **Sur Android seulement.** La feuille de partage d'iOS propose toujours
/// « Enregistrer dans Fichiers » ; celle d'Android n'offre d'enregistrement
/// que si une app (Files, Drive…) s'y est déclarée pour ce type de fichier, et
/// sur bien des téléphones (HyperOS, entre autres) il n'y en a aucune : la
/// trace ne pouvait alors qu'être envoyée, jamais gardée. iOS va donc droit au
/// partage.
///
/// À appeler **avant** de passer l'écran en « téléchargement en cours » : la
/// feuille ne doit pas s'ouvrir sous un bandeau d'attente.
Future<AssetDestination?> pickAssetDestination(BuildContext context) async {
  if (defaultTargetPlatform != TargetPlatform.android) {
    return AssetDestination.share;
  }
  return PdlSheet.show<AssetDestination>(
    context: context,
    builder: (BuildContext sheetContext) => PdlSheet(
      title: 'media.destinationTitle'.tr(),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PdlSettingRow(
            key: keys.assetDestination.saveToDevice,
            title: 'media.saveToDevice'.tr(),
            icon: PdlIcons.download,
            showDivider: true,
            onTap: () =>
                Navigator.of(sheetContext).pop(AssetDestination.device),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PdlSettingRow(
            key: keys.assetDestination.share,
            title: 'media.shareFile'.tr(),
            icon: PdlIcons.share,
            onTap: () => Navigator.of(sheetContext).pop(AssetDestination.share),
          ),
        ),
      ],
    ),
  );
}

/// Télécharge [asset] et le remet à [destination] : le sélecteur « Enregistrer
/// sous » du système, ou la feuille de partage.
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
/// Rend `true` quand le fichier a été enregistré sur le téléphone — de quoi
/// afficher une confirmation —, `false` après un partage ou si la personne a
/// annulé le sélecteur. [origin] ancre la feuille de partage sur iPad
/// ([shareOriginOf]). Lève en cas d'échec ; c'est à l'appelant d'afficher son
/// bandeau.
Future<bool> deliverAsset(
  WidgetRef ref,
  AssetDto asset,
  AssetDestination destination, {
  required Rect origin,
}) async {
  final Dio dio = ref.read(dioProvider);
  final String mimeType = _mimeTypeOf(asset);
  switch (destination) {
    case AssetDestination.device:
      // Le sélecteur écrit des octets, pas un chemin : un GPX ou une pièce
      // jointe pèse quelques Mo au plus.
      final Response<List<int>> response = await dio.get<List<int>>(
        asset.url,
        options: Options(responseType: ResponseType.bytes),
      );
      final Uri? saved = await FilePicker.saveFile(
        fileName: asset.fileName,
        bytes: Uint8List.fromList(response.data ?? const <int>[]),
        mimeType: mimeType,
      );
      return saved != null;
    case AssetDestination.share:
      final String path =
          '${(await getTemporaryDirectory()).path}/${asset.fileName}';
      await dio.download(asset.url, path);
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(path, mimeType: mimeType)],
          sharePositionOrigin: origin,
        ),
      );
      return false;
  }
}

/// Le type du fichier, que l'intent Android porte et dont dépendent les apps
/// proposées.
///
/// Sans lui, `share_plus` le devine par l'extension avec le paquet `mime`, qui
/// ne connaît ni `.gpx` ni `.fit` : le fichier partait en
/// `application/octet-stream`, et les apps GPS ne se proposaient pas.
String _mimeTypeOf(AssetDto asset) {
  final String name = asset.fileName.toLowerCase();
  if (name.endsWith('.gpx')) return 'application/gpx+xml';
  if (name.endsWith('.fit')) return 'application/vnd.ant.fit';
  final String type = asset.contentType;
  return type.isEmpty ? 'application/octet-stream' : type;
}
