import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Charge les polices que l'app embarque — Inter et Material Icons, d'après
/// le `FontManifest.json` du bundle de test — puis Roboto (le défaut Material
/// d'un widget sans famille) depuis le SDK Flutter, et Menlo, la pile mono,
/// si la machine l'a.
Future<void> loadGalleryFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final List<dynamic> manifest = json.decode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;
  final Set<String> loaded = <String>{};
  for (final dynamic entry in manifest) {
    final Map<String, dynamic> family = entry as Map<String, dynamic>;
    final FontLoader loader = FontLoader(family['family'] as String);
    for (final dynamic font in family['fonts'] as List<dynamic>) {
      loader.addFont(
        rootBundle.load((font as Map<String, dynamic>)['asset'] as String),
      );
    }
    await loader.load();
    loaded.add(loader.family);
  }
  for (final String required in <String>['Inter', 'MaterialIcons']) {
    if (!loaded.contains(required)) {
      throw StateError('Police $required absente du FontManifest.json');
    }
  }

  final Directory? fonts = _sdkMaterialFonts();
  if (fonts != null) {
    final FontLoader roboto = FontLoader('Roboto');
    for (final String name in <String>[
      'Roboto-Regular',
      'Roboto-Medium',
      'Roboto-Bold',
    ]) {
      final File f = File('${fonts.path}/$name.ttf');
      if (f.existsSync()) {
        roboto.addFont(Future<ByteData>.value(_bytes(f)));
      }
    }
    await roboto.load();
  }

  final File menlo = File('/System/Library/Fonts/Menlo.ttc');
  if (menlo.existsSync()) {
    await (FontLoader(
      'Menlo',
    )..addFont(Future<ByteData>.value(_bytes(menlo)))).load();
  }
}

ByteData _bytes(File f) => ByteData.sublistView(f.readAsBytesSync());

/// `bin/cache/artifacts/material_fonts` du SDK : par `FLUTTER_ROOT` si
/// l'outil la pose, sinon en remontant depuis `flutter_tester`
/// (`<sdk>/bin/cache/artifacts/engine/<plateforme>/flutter_tester`).
Directory? _sdkMaterialFonts() {
  final List<String> roots = <String>[
    if (Platform.environment['FLUTTER_ROOT'] case final String root) root,
    File(Platform.resolvedExecutable)
        .parent
        .parent
        .parent
        .parent
        .parent
        .parent
        .path,
  ];
  for (final String root in roots) {
    final Directory d = Directory('$root/bin/cache/artifacts/material_fonts');
    if (d.existsSync()) return d;
  }
  return null;
}
