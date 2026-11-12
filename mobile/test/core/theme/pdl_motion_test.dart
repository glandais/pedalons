import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/theme/pdl_tokens.dart';

void main() {
  group('PdlMotion.reducedOf', () {
    Future<bool> read(
      WidgetTester tester,
      FakeAccessibilityFeatures features,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = features;
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      late bool reduced;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              reduced = PdlMotion.reducedOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return reduced;
    }

    testWidgets('faux sans réglage d\'accessibilité', (tester) async {
      expect(await read(tester, const FakeAccessibilityFeatures()), isFalse);
    });

    testWidgets('vrai avec « Supprimer les animations » (Android)', (
      tester,
    ) async {
      expect(
        await read(
          tester,
          const FakeAccessibilityFeatures(disableAnimations: true),
        ),
        isTrue,
      );
    });

    // Depuis Flutter 3.50, le réglage d'iOS ne lève plus `disableAnimations`.
    testWidgets('vrai avec « Réduire les animations » (iOS)', (tester) async {
      expect(
        await read(tester, const FakeAccessibilityFeatures(reduceMotion: true)),
        isTrue,
      );
    });
  });

  test('aucun widget ne lit disableAnimations sans passer par PdlMotion', () {
    final List<String> offenders = <String>[
      for (final FileSystemEntity entity in Directory(
        'lib',
      ).listSync(recursive: true))
        if (entity is File &&
            entity.path.endsWith('.dart') &&
            !entity.path.endsWith('core/theme/pdl_tokens.dart') &&
            RegExp(r'disableAnimations|reduceMotionOf|\.reduceMotion\b')
                .hasMatch(entity.readAsStringSync()))
          entity.path,
    ];
    expect(offenders, isEmpty);
  });
}
