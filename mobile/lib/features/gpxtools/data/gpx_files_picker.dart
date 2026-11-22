import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../routes/domain/gpx_check.dart';

/// Ce qui fait choisir **plusieurs** GPX — « Fusionner des fichiers »
/// (docs/LEDGER_*.md MOB-178). Le pendant multiple de `GpxFilePicker`, à part
/// pour ne pas toucher les implémentations de celui-ci.
abstract interface class GpxFilesPicker {
  /// Les fichiers choisis, vide si l'utilisateur annule. Un fichier sans
  /// chemin lisible est laissé de côté.
  Future<List<GpxFile>> pickMany();
}

/// Le sélecteur du système, `FileType.any` pour la même raison que
/// `SystemGpxFilePicker` : `gpx` n'a pas de type uniforme sur iOS.
class SystemGpxFilesPicker implements GpxFilesPicker {
  const SystemGpxFilesPicker();

  @override
  Future<List<GpxFile>> pickMany() async {
    final List<PlatformFile> picked = await FilePicker.pickFiles();
    final List<GpxFile> files = <GpxFile>[];
    for (final PlatformFile f in picked) {
      final String? path = f.path;
      if (path == null) continue;
      final int size = await f.length() ?? await File(path).length();
      files.add(GpxFile(path: path, name: f.name, size: size));
    }
    return files;
  }
}

/// Un `StateProvider` exprès, comme `gpxFilePickerProvider` : un test Patrol
/// le remplace dans l'app lancée.
final gpxFilesPickerProvider = StateProvider<GpxFilesPicker>(
  (ref) => const SystemGpxFilesPicker(),
);
