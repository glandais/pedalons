import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../routes/domain/gpx_check.dart';

/// Vrai pour l'adresse d'un **fichier** remis à l'app — « Ouvrir avec
/// Pédalons » ou un partage (docs/LEDGER_*.md MOB-191). app_links la remet
/// par le même flux que les liens web ; `_DeepLinkHandler` l'écarte du
/// routeur, qui n'en ferait qu'une page introuvable. `content://` n'arrive
/// plus (le relais Android le copie d'abord) : s'il arrivait, le fichier
/// serait dit illisible plutôt que d'ouvrir une page introuvable.
bool isReceivedFileUri(Uri uri) =>
    uri.scheme == 'file' || uri.scheme == 'content';

/// Ce qui rend lisible le fichier reçu à [isReceivedFileUri].
abstract interface class ReceivedFileReader {
  /// Le fichier, lisible par `dart:io`, ou `null` s'il ne l'est pas.
  Future<GpxFile?> read(Uri uri);
}

/// Le lecteur de l'appareil. Il ne rend **que la copie faite pour l'app**,
/// jamais le fichier d'origine : l'écran « Fichier reçu » efface ce qu'il a
/// reçu en se fermant.
///
/// - Android : `ReceivedFileActivity` a copié le fichier dans
///   `cache/received/` et remet l'adresse `file://` de la copie. Une adresse
///   hors de ce dossier (un intent explicite d'une autre app) est refusée.
/// - iOS : l'URL est celle du fichier de la personne (ouverture sur place) ;
///   `ReceivedFilePlugin` (AppDelegate.swift) l'a copié pendant l'événement,
///   le canal `received_file` en rend la copie.
class DeviceReceivedFileReader implements ReceivedFileReader {
  const DeviceReceivedFileReader();

  static const MethodChannel _channel = MethodChannel(
    'fr.pedalons.mobile/received_file',
  );

  @override
  Future<GpxFile?> read(Uri uri) async {
    if (uri.scheme != 'file') return null;
    if (Platform.isAndroid) {
      final Directory cache = await getTemporaryDirectory();
      final File file = File(uri.toFilePath());
      if (!file.path.startsWith('${cache.path}/received/') ||
          !await file.exists()) {
        return null;
      }
      return GpxFile(
        path: file.path,
        name: uri.pathSegments.last,
        size: await file.length(),
      );
    }
    final Map<Object?, Object?>? copied = await _channel
        .invokeMethod<Map<Object?, Object?>>('copy', <String, String>{
          'uri': uri.toString(),
        });
    if (copied == null) return null;
    return GpxFile(
      path: copied['path']! as String,
      name: copied['name']! as String,
      size: (copied['size']! as num).toInt(),
    );
  }
}

/// Remplacé dans les tests.
final receivedFileReaderProvider = Provider<ReceivedFileReader>(
  (Ref ref) => const DeviceReceivedFileReader(),
);

/// Efface la copie d'un fichier reçu, une fois l'écran « Fichier reçu » fermé :
/// le fichier envoyé vit sur le serveur, la copie n'a plus d'usage et
/// s'accumulerait dans le cache.
Future<void> deleteReceivedCopy(GpxFile file) async {
  try {
    await File(file.path).delete();
  } on FileSystemException {
    // Déjà partie : rien à faire.
  }
}
