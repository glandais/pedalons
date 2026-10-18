import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../domain/gpx_check.dart';

/// Ce qui fait choisir un GPX à l'utilisateur — le sélecteur de fichiers du
/// système en production, un fichier fourni d'avance dans les tests.
abstract interface class GpxFilePicker {
  /// Le fichier choisi, ou `null` si l'utilisateur annule (ou si le système
  /// ne donne pas de chemin lisible).
  Future<GpxFile?> pick();
}

/// Le sélecteur du système.
///
/// **`FileType.any`, pas `custom` + `['gpx']`** : `gpx` n'a pas de type
/// uniforme (UTI) sur iOS — les fichiers `.gpx` y seraient grisés —, et sur
/// Android le type MIME n'est pas toujours résolu. Le contrôle de l'extension
/// et du contenu se fait après le choix, dans [inspectGpxFile].
///
/// Une `PlatformException` remonte : l'écran l'affiche.
class SystemGpxFilePicker implements GpxFilePicker {
  const SystemGpxFilePicker();

  @override
  Future<GpxFile?> pick() async {
    final PlatformFile? picked = await FilePicker.pickFile(type: FileType.any);
    final String? path = picked?.path;
    if (picked == null || path == null) return null;
    // La taille que dit le sélecteur, sinon celle du fichier sur le disque.
    final int size = await picked.length() ?? await File(path).length();
    return GpxFile(path: path, name: picked.name, size: size);
  }
}

/// Le sélecteur de GPX de l'app.
///
/// Un `StateProvider` **exprès** : un test Patrol remplace le sélecteur dans
/// l'app lancée (`ProviderScope.containerOf(…).read(gpxFilePickerProvider
/// .notifier).state = …`) faute de pouvoir piloter le sélecteur natif, comme
/// `pendingPushRouteProvider` ; un test de widget le remplace par
/// `overrideWith` (docs/LEDGER_*.md MOB-79).
final gpxFilePickerProvider = StateProvider<GpxFilePicker>(
  (Ref ref) => const SystemGpxFilePicker(),
);

/// Lit le début de [file] et le soumet au contrôle local ([checkGpx]).
///
/// Un fichier illisible (supprimé entre-temps, droits) est refusé comme
/// « pas un GPX » : l'utilisateur n'a rien d'autre à faire que d'en choisir un
/// autre.
Future<GpxCheck> inspectGpxFile(GpxFile file) async {
  final BytesBuilder bytes = BytesBuilder(copy: false);
  try {
    await for (final List<int> chunk in File(
      file.path,
    ).openRead(0, kGpxProbeBytes)) {
      bytes.add(chunk);
    }
  } on FileSystemException {
    return GpxRefused(file.name, GpxRefusal.notGpx);
  }
  return checkGpx(file, _decodeHead(bytes.takeBytes()));
}

/// UTF-16 si une marque d'ordre des octets l'annonce, UTF-8 sinon (le cas de
/// presque tous les GPX), sans lever sur un octet invalide.
String _decodeHead(Uint8List bytes) {
  if (bytes.length >= 2) {
    final bool littleEndian = bytes[0] == 0xFF && bytes[1] == 0xFE;
    final bool bigEndian = bytes[0] == 0xFE && bytes[1] == 0xFF;
    if (littleEndian || bigEndian) {
      final List<int> units = <int>[
        for (int i = 2; i + 1 < bytes.length; i += 2)
          littleEndian
              ? bytes[i] | (bytes[i + 1] << 8)
              : (bytes[i] << 8) | bytes[i + 1],
      ];
      return String.fromCharCodes(units);
    }
  }
  return utf8.decode(bytes, allowMalformed: true);
}
