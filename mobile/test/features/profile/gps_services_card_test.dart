import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/api/pedalons_api_client.dart';
import 'package:pedalons/core/config/config_provider.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/auth/data/auth_repository.dart';
import 'package:pedalons/features/auth/data/secure_storage.dart';
import 'package:pedalons/features/auth/domain/auth_state.dart';
import 'package:pedalons/features/auth/providers/auth_provider.dart';
import 'package:pedalons/features/profile/data/profile_repository.dart';
import 'package:pedalons/features/profile/presentation/widgets/connected_services_section.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';

/// docs/LEDGER_*.md MOB-71 — l'interrupteur « Envoi automatique » d'un service
/// GPS connecté : présent seulement pour un service connecté, mise à jour
/// optimiste, retour arrière sur échec, l'état du serveur en sous-titre.
GpsServiceConnectionDto _connection({
  String serviceType = 'GARMIN',
  bool autoSync = false,
  String state = 'OFF',
  int count = 0,
}) => GpsServiceConnectionDto(
  serviceType: serviceType,
  displayName: serviceType == 'GARMIN' ? 'Garmin Connect' : 'Wahoo',
  connectedAt: '2026-09-01T10:00:00Z',
  autoSync: autoSync,
  autoSyncState: state,
  autoSyncRouteCount: count,
);

UserDto _user(List<GpsServiceConnectionDto> services) => UserDto(
  id: 'u-me',
  email: 'moi@example.org',
  displayName: 'Moi',
  contactableByMembers: true,
  emailVerified: true,
  connectedServices: services,
);

ConfigDto _config({required bool gpsAutoSyncEnabled}) => ConfigDto(
  webAuthnRpId: 'localhost',
  appName: 'Pédalons',
  singleTeam: false,
  enableGpxPlanner: false,
  mapStyles: const <MapStyleDto>[],
  tileServerBaseUrl: '',
  defaultCenter: const MapCenterDto(lat: 45.7, lon: 4.8, zoom: 9),
  gpsAutoSyncEnabled: gpsAutoSyncEnabled,
);

class _FakeAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSecureStorage implements SecureTokenStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubAuthNotifier extends AuthNotifier {
  _StubAuthNotifier(Ref ref, AuthRepository repository, UserDto user)
    : super(repository, _FakeSecureStorage(), ref) {
    state = AuthState(user: user, accessToken: 'token');
  }
}

class _RecordingProfileRepository implements ProfileRepository {
  final List<(GpsServiceType, bool)> autoSyncCalls = <(GpsServiceType, bool)>[];
  final List<GpsServiceType> connectCalls = <GpsServiceType>[];
  Completer<GpsServiceConnectionDto>? pending;

  @override
  Future<List<GpsServiceType>> availableGpsServices() async => <GpsServiceType>[
    GpsServiceType.garmin,
    GpsServiceType.wahoo,
  ];

  @override
  Future<GpsServiceConnectionDto> setGpsAutoSync(
    GpsServiceType service, {
    required bool enabled,
  }) {
    autoSyncCalls.add((service, enabled));
    pending = Completer<GpsServiceConnectionDto>();
    return pending!.future;
  }

  /// Le navigateur n'a pas à s'ouvrir ici : l'appel suffit à la preuve.
  @override
  Future<String> gpsConnectUrl(
    GpsServiceType service, {
    GpsConnectReturn returnTo = GpsConnectReturn.profile,
  }) async {
    connectCalls.add(service);
    throw Exception('pas de navigateur en test');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestTranslations);

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<(_RecordingProfileRepository, ProviderContainer)> pump(
    WidgetTester tester,
    List<GpsServiceConnectionDto> services, {
    bool gpsAutoSyncEnabled = true,
  }) async {
    final _RecordingProfileRepository repository =
        _RecordingProfileRepository();
    final _FakeAuthRepository auth = _FakeAuthRepository();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          accessTokenHolderProvider.overrideWith((ref) => 'token'),
          authProvider.overrideWith(
            (ref) => _StubAuthNotifier(ref, auth, _user(services)),
          ),
          profileRepositoryProvider.overrideWithValue(repository),
          appConfigProvider.overrideWith(
            (ref) async => _config(gpsAutoSyncEnabled: gpsAutoSyncEnabled),
          ),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: GpsServicesCard()),
          ),
        ),
      ),
    );
    await settle(tester);
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(GpsServicesCard)),
    );
    return (repository, container);
  }

  PdlSwitch switchOf(WidgetTester tester, GpsServiceType service) => tester
      .widget<PdlSwitch>(find.byKey(keys.profile.gpsAutoSyncSwitch(service)));

  Finder rowText(GpsServiceType service, String text) => find.descendant(
    of: find.byKey(keys.profile.gpsAutoSyncRow(service)),
    matching: find.text(text),
  );

  testWidgets('un interrupteur pour le service connecté, aucun pour l\'autre', (
    WidgetTester tester,
  ) async {
    await pump(tester, <GpsServiceConnectionDto>[_connection()]);

    expect(
      find.byKey(keys.profile.gpsAutoSyncSwitch(GpsServiceType.garmin)),
      findsOneWidget,
    );
    expect(
      find.byKey(keys.profile.gpsAutoSyncSwitch(GpsServiceType.wahoo)),
      findsNothing,
    );
    expect(switchOf(tester, GpsServiceType.garmin).value, isFalse);
    expect(find.text('Envoi automatique des parcours'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(keys.profile.gpsAutoSyncRow(GpsServiceType.garmin)),
        matching: find.textContaining('dès 7 jours avant le départ'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'activer : la valeur bascule tout de suite, puis l\'état du serveur la remplace',
    (WidgetTester tester) async {
      final (
        _RecordingProfileRepository repository,
        ProviderContainer container,
      ) = await pump(tester, <GpsServiceConnectionDto>[
        _connection(),
      ]);

      await tester.tap(
        find.byKey(keys.profile.gpsAutoSyncSwitch(GpsServiceType.garmin)),
      );
      await settle(tester);

      expect(repository.autoSyncCalls, <(GpsServiceType, bool)>[
        (GpsServiceType.garmin, true),
      ]);
      // Optimiste : l'interrupteur montre la demande, et se bloque le temps
      // de la réponse.
      expect(switchOf(tester, GpsServiceType.garmin).value, isTrue);
      expect(switchOf(tester, GpsServiceType.garmin).onChanged, isNull);
      expect(rowText(GpsServiceType.garmin, 'Enregistrement…'), findsOneWidget);

      repository.pending!.complete(
        _connection(autoSync: true, state: 'UP_TO_DATE', count: 2),
      );
      await settle(tester);

      expect(switchOf(tester, GpsServiceType.garmin).value, isTrue);
      expect(switchOf(tester, GpsServiceType.garmin).onChanged, isNotNull);
      expect(
        rowText(GpsServiceType.garmin, 'À jour · 2 parcours envoyés'),
        findsOneWidget,
      );
      // La seule copie est celle de l'utilisateur courant, mise à jour avec
      // la connexion rendue.
      final GpsServiceConnectionDto stored = container
          .read(authProvider)
          .user!
          .connectedServices!
          .single;
      expect(stored.autoSync, isTrue);
      expect(stored.autoSyncRouteCount, 2);
    },
  );

  testWidgets('un échec remet l\'interrupteur et affiche l\'erreur', (
    WidgetTester tester,
  ) async {
    final (
      _RecordingProfileRepository repository,
      ProviderContainer _,
    ) = await pump(tester, <GpsServiceConnectionDto>[
      _connection(autoSync: true, state: 'UP_TO_DATE', count: 1),
    ]);

    await tester.tap(
      find.byKey(keys.profile.gpsAutoSyncSwitch(GpsServiceType.garmin)),
    );
    await settle(tester);
    expect(switchOf(tester, GpsServiceType.garmin).value, isFalse);

    repository.pending!.completeError(Exception('réseau'));
    await settle(tester);

    expect(repository.autoSyncCalls.single, (GpsServiceType.garmin, false));
    expect(switchOf(tester, GpsServiceType.garmin).value, isTrue);
    expect(
      rowText(GpsServiceType.garmin, 'À jour · 1 parcours envoyé'),
      findsOneWidget,
    );
    expect(find.byType(PdlBanner), findsOneWidget);
  });

  testWidgets(
    'aucun interrupteur quand le déploiement n\'envoie rien de lui-même',
    (WidgetTester tester) async {
      await pump(tester, <GpsServiceConnectionDto>[
        _connection(autoSync: true, state: 'UP_TO_DATE'),
      ], gpsAutoSyncEnabled: false);

      expect(
        find.byKey(keys.profile.gpsAutoSyncSwitch(GpsServiceType.garmin)),
        findsNothing,
      );
      expect(find.text('Envoi automatique des parcours'), findsNothing);
      // Le service reste connecté, et déconnectable.
      expect(find.text('Déconnecter'), findsOneWidget);
    },
  );

  testWidgets(
    'accès refusé : « Reconnecter » relance l\'autorisation sans déconnecter',
    (WidgetTester tester) async {
      final (
        _RecordingProfileRepository repository,
        ProviderContainer _,
      ) = await pump(tester, <GpsServiceConnectionDto>[
        _connection(autoSync: true, state: 'RECONNECT_REQUIRED'),
      ]);

      expect(
        rowText(
          GpsServiceType.garmin,
          'Garmin Connect refuse l\'accès : reconnectez le service pour reprendre l\'envoi.',
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(keys.profile.gpsReconnect(GpsServiceType.garmin)),
      );
      await settle(tester);

      expect(repository.connectCalls, <GpsServiceType>[GpsServiceType.garmin]);
      expect(switchOf(tester, GpsServiceType.garmin).value, isTrue);
    },
  );

  testWidgets('pas de « Reconnecter » tant que le service accepte l\'accès', (
    WidgetTester tester,
  ) async {
    await pump(tester, <GpsServiceConnectionDto>[
      _connection(autoSync: true, state: 'FAILING'),
    ]);

    expect(
      find.byKey(keys.profile.gpsReconnect(GpsServiceType.garmin)),
      findsNothing,
    );
  });

  testWidgets('la déconnexion annonce le retrait des parcours envoyés', (
    WidgetTester tester,
  ) async {
    await pump(tester, <GpsServiceConnectionDto>[
      _connection(autoSync: true, state: 'UP_TO_DATE', count: 3),
    ]);

    await tester.tap(find.text('Déconnecter'));
    await settle(tester);

    expect(
      tester
          .widget<Text>(find.byKey(keys.profile.confirmDestructiveMessage))
          .data,
      endsWith(
        'Les 3 parcours envoyés automatiquement seront retirés de Garmin Connect.',
      ),
    );
  });

  group('gpsAutoSyncStatus', () {
    String status(bool autoSync, String state, {int count = 0}) =>
        gpsAutoSyncStatus(
          _connection(autoSync: autoSync, state: state, count: count),
          serviceLabel: 'Wahoo',
        );

    test('chaque état a sa phrase', () {
      expect(status(false, 'OFF'), contains('dès 7 jours avant le départ'));
      expect(status(true, 'UP_TO_DATE'), 'À jour · aucun parcours à venir');
      expect(
        status(true, 'UP_TO_DATE', count: 1),
        'À jour · 1 parcours envoyé',
      );
      expect(status(true, 'PENDING'), 'Envoi en cours…');
      // Pas de nouvel essai promis : au-delà de quelques heures, la ligne
      // attend un changement du parcours ou une réactivation.
      expect(
        status(true, 'FAILING'),
        startsWith('Échec du dernier envoi ; Pédalons réessaie pendant'),
      );
      expect(status(true, 'RECONNECT_REQUIRED'), startsWith('Wahoo refuse'));
    });

    test('un état inconnu de ce build ne s\'affiche pas brut', () {
      expect(status(true, 'SOMETHING_NEW'), status(false, 'OFF'));
    });
  });
}
