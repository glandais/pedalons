import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/profile/data/profile_repository.dart';
import 'package:pedalons/features/profile/presentation/widgets/paired_devices_section.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';

/// API-64 — la carte « Appareils appairés » liste chaque Karoo ou
/// Garmin, et n'en délie que celui qu'on a confirmé.
class _FakeRepository implements ProfileRepository {
  _FakeRepository(this.devices);

  List<PairedDeviceDto> devices;
  final List<String> unpaired = <String>[];

  @override
  Future<List<PairedDeviceDto>> pairedDevices() async => devices;

  @override
  Future<void> unpairDevice(String deviceId) async {
    unpaired.add(deviceId);
    devices = devices.where((PairedDeviceDto d) => d.id != deviceId).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(loadTestTranslations);

  Future<_FakeRepository> pumpCard(
    WidgetTester tester,
    List<PairedDeviceDto> devices,
  ) async {
    final _FakeRepository repository = _FakeRepository(devices);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repository),
          pairedDevicesProvider.overrideWith(
            (ref) => ref.read(profileRepositoryProvider).pairedDevices(),
          ),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: const Scaffold(body: PairedDevicesCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  const PairedDeviceDto karoo = PairedDeviceDto(
    id: 'k1',
    type: 'KAROO',
    pairedAt: '2026-09-01T08:00:00Z',
  );
  const PairedDeviceDto garmin = PairedDeviceDto(
    id: 'g1',
    type: 'GARMIN',
    pairedAt: '2026-08-01T08:00:00Z',
    lastUsedAt: '2026-08-02T08:00:00Z',
  );

  testWidgets('chaque appareil appairé est listé sous son nom', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, <PairedDeviceDto>[karoo, garmin]);

    expect(find.byKey(keys.profile.pairedDevice('k1')), findsOneWidget);
    expect(find.byKey(keys.profile.pairedDevice('g1')), findsOneWidget);
    expect(find.text('Karoo'), findsOneWidget);
    expect(find.text('Garmin'), findsOneWidget);
    expect(find.byKey(keys.profile.noPairedDevice), findsNothing);
  });

  testWidgets('sans appareil, la carte dit comment en appairer un', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, const <PairedDeviceDto>[]);

    expect(find.byKey(keys.profile.noPairedDevice), findsOneWidget);
  });

  testWidgets(
    'la carte dit ce qu\'est un appareil appairé, à côté des services',
    (WidgetTester tester) async {
      await pumpCard(tester, const <PairedDeviceDto>[]);

      expect(find.textContaining('par un code'), findsOneWidget);
    },
  );

  testWidgets('délier ne délie que l\'appareil confirmé', (
    WidgetTester tester,
  ) async {
    final _FakeRepository repository = await pumpCard(tester, <PairedDeviceDto>[
      karoo,
      garmin,
    ]);

    await tester.tap(find.byKey(keys.profile.unpairDevice('g1')));
    await tester.pumpAndSettle();
    expect(repository.unpaired, isEmpty);
    await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
    await tester.pumpAndSettle();

    expect(repository.unpaired, <String>['g1']);
    expect(find.byKey(keys.profile.pairedDevice('g1')), findsNothing);
    expect(find.byKey(keys.profile.pairedDevice('k1')), findsOneWidget);
  });
}
