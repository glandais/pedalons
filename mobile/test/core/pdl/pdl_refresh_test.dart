import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pdl/pdl.dart';

/// Le « tirer pour rafraîchir » et sa secousse.
///
/// Le geste ne rendait rien au doigt : il fallait regarder le tourniquet pour
/// savoir que le seuil était franchi. Le test tient les deux moitiés — la
/// secousse part au déclenchement, et **pas** pendant la traction, sans quoi
/// un simple défilement ferait vibrer le téléphone.
void main() {
  late List<MethodCall> platform;

  setUp(() {
    platform = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          platform.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  List<MethodCall> haptics() => platform
      .where((MethodCall call) => call.method == 'HapticFeedback.vibrate')
      .toList();

  Widget host({required Future<void> Function() onRefresh}) => MaterialApp(
    home: Scaffold(
      body: PdlRefresh(
        onRefresh: onRefresh,
        child: ListView(
          children: <Widget>[
            for (int i = 0; i < 20; i++)
              SizedBox(height: 60, child: Text('$i')),
          ],
        ),
      ),
    ),
  );

  testWidgets('le déclenchement secoue, et rafraîchit', (
    WidgetTester tester,
  ) async {
    bool refreshed = false;

    await tester.pumpWidget(host(onRefresh: () async => refreshed = true));
    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(refreshed, isTrue);
    expect(haptics(), hasLength(1));
    expect(haptics().single.arguments, 'HapticFeedbackType.mediumImpact');
  });

  testWidgets('une traction sous le seuil ne secoue pas', (
    WidgetTester tester,
  ) async {
    bool refreshed = false;

    await tester.pumpWidget(host(onRefresh: () async => refreshed = true));
    // 20 px : le doigt bouge, le seuil n'est pas atteint.
    await tester.drag(find.byType(ListView), const Offset(0, 20));
    await tester.pumpAndSettle();

    expect(refreshed, isFalse);
    expect(haptics(), isEmpty);
  });
}
