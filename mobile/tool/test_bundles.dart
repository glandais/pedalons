// Regroupe les fichiers de test/ en quelques paquets, pour `tool/test.sh`.
//
// `flutter test` compile chaque fichier `*_test.dart` à part, avec un seul
// compilateur : sur ~260 fichiers, la compilation (les « loading » du
// reporter) pesait près de la moitié du temps et laissait la moitié des cœurs
// à attendre. Un paquet importe plusieurs fichiers et appelle leur `main` dans
// un `group` nommé d'après le fichier : les dépendances communes ne se
// compilent plus qu'une fois par paquet, et les paquets tournent en parallèle.
//
// Chaque `group` commence par `resetTestGlobals` (test/support/bundle_isolation.dart),
// qui rend à l'isolate l'état statique d'un lancement neuf.
//
// Un fichier qui charge de vraies polices (`FontLoader`, les galeries de
// `test/dev/`) change le rendu du texte pour tout l'isolate : il reste seul
// dans son paquet. Un fichier peut aussi le demander par la ligne
// `// test-bundle: isolate`.
//
// Usage : dart tool/test_bundles.dart [nombre de paquets]
import 'dart:io';

const String outDir = '.dart_tool/test_bundles';

final List<RegExp> _isolateMarkers = <RegExp>[
  RegExp(r'\bFontLoader\b'),
  RegExp(r'gallery_fonts\.dart'),
  RegExp(r'^// test-bundle: isolate$', multiLine: true),
];

void main(List<String> args) {
  final int count = args.isEmpty
      ? Platform.numberOfProcessors
      : int.parse(args.first);

  final List<File> files =
      Directory('test')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('_test.dart'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));

  final List<List<String>> bundles = <List<String>>[];
  final List<_Bin> bins = List<_Bin>.generate(count, (_) => _Bin());
  final List<File> pooled = <File>[];
  for (final File file in files) {
    final String source = file.readAsStringSync();
    if (_isolateMarkers.any((RegExp r) => r.hasMatch(source))) {
      bundles.add(<String>[_relative(file)]);
    } else {
      pooled.add(file);
    }
  }

  // Le plus gros d'abord, dans le paquet le moins chargé : la taille du
  // fichier tient lieu de durée, assez bien pour équilibrer.
  pooled.sort((File a, File b) => b.lengthSync().compareTo(a.lengthSync()));
  for (final File file in pooled) {
    final _Bin bin = bins.reduce((_Bin a, _Bin b) => a.weight <= b.weight ? a : b);
    bin
      ..weight += file.lengthSync()
      ..paths.add(_relative(file));
  }
  bundles.addAll(
    bins.where((_Bin b) => b.paths.isNotEmpty).map((_Bin b) => b.paths..sort()),
  );

  final Directory out = Directory(outDir);
  if (out.existsSync()) out.deleteSync(recursive: true);
  out.createSync(recursive: true);

  for (int i = 0; i < bundles.length; i++) {
    final List<String> paths = bundles[i];
    final StringBuffer b = StringBuffer()
      ..writeln('// Généré par tool/test_bundles.dart — ne pas éditer.')
      ..writeln("import 'package:flutter_test/flutter_test.dart';")
      ..writeln()
      ..writeln("import '../../test/support/bundle_isolation.dart';");
    for (int j = 0; j < paths.length; j++) {
      b.writeln("import '../../test/${paths[j]}' as t$j;");
    }
    b
      ..writeln()
      ..writeln('void main() {');
    for (int j = 0; j < paths.length; j++) {
      b
        ..writeln("  group('${paths[j]}', () {")
        ..writeln('    setUpAll(resetTestGlobals);')
        ..writeln('    t$j.main();')
        ..writeln('  });');
    }
    b.writeln('}');
    File(
      '$outDir/bundle_${i.toString().padLeft(2, '0')}_test.dart',
    ).writeAsStringSync(b.toString());
  }
  stdout.writeln(
    '${files.length} fichiers de test en ${bundles.length} paquets '
    '(${files.length - pooled.length} isolés) dans $outDir',
  );
}

String _relative(File file) => file.path.substring('test/'.length);

class _Bin {
  int weight = 0;
  final List<String> paths = <String>[];
}
