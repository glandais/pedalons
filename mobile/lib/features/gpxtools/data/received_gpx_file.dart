import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../routes/domain/gpx_check.dart';

/// Vrai pour l'adresse d'un **fichier** remis à l'app — « Ouvrir avec
/// Pédalons » ou un partage (docs/LEDGER_*.md MOB-191) : `file://` sur iOS
/// (la copie de `Documents/Inbox`), `content://` (ou un vieux `file://`) sur
/// Android. app_links la remet par le même flux que les liens web ;
/// `_DeepLinkHandler` l'écarte du routeur, qui n'en ferait qu'une page
/// introuvable.
bool isReceivedFileUri(Uri uri) =>
    uri.scheme == 'file' || uri.scheme == 'content';

/// Ce qui rend lisible le fichier reçu à [isReceivedFileUri].
abstract interface class ReceivedFileReader {
  /// Le fichier, lisible par `dart:io`, ou `null` s'il ne l'est pas.
  Future<GpxFile?> read(Uri uri);
}

/// Le lecteur de l'appareil.
///
/// Un `file://` se lit tel quel : iOS en a fait une copie à l'app (Info.plist,
/// `LSSupportsOpeningDocumentsInPlace` faux). Un `content://` n'a pas de
/// chemin : `MainActivity` le copie dans le cache (canal `received_file`).
class DeviceReceivedFileReader implements ReceivedFileReader {
  const DeviceReceivedFileReader();

  static const MethodChannel _channel = MethodChannel(
    'fr.pedalons.mobile/received_file',
  );

  @override
  Future<GpxFile?> read(Uri uri) async {
    if (uri.scheme == 'file' && !Platform.isAndroid) {
      final File file = File(uri.toFilePath());
      if (!await file.exists()) return null;
      return GpxFile(
        path: file.path,
        name: uri.pathSegments.isEmpty ? file.path : uri.pathSegments.last,
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
/// s'accumulerait dans l'Inbox ou le cache.
Future<void> deleteReceivedCopy(GpxFile file) async {
  try {
    await File(file.path).delete();
  } on FileSystemException {
    // Déjà partie : rien à faire.
  }
}
