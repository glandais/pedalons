import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/router.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/notifications/data/notifications_repository.dart';
import 'package:pedalons/features/notifications/data/push_device_repository.dart';
import 'package:pedalons/features/notifications/domain/push_message.dart';
import 'package:pedalons/features/notifications/presentation/widgets/push_activation_banner.dart';
import 'package:pedalons/features/notifications/providers/notifications_provider.dart';
import 'package:pedalons/features/notifications/providers/push_provider.dart';
import 'package:pedalons/features/notifications/services/push_gateway.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';

import '../../support/localization.dart';

/// Le canal push côté appareil : le jeton, et ce qu'un message déclenche.
///
/// Rien ici ne touche Firebase — [_FakeGateway] tient la place de la
/// plateforme, qui n'existe ni sur une machine de test ni sur le bureau. Ce
/// qui est vérifié est donc bien ce que l'app décide : *quand* elle enregistre
/// un jeton, et *ce qu'elle fait* d'un message reçu ou tapé.
class _FakeGateway implements PushGateway {
  // Tout se règle après coup, cas par cas : chaque test part du même appareil
  // neuf — jamais interrogé sur l'autorisation — et ne change que ce qu'il
  // raconte.
  PushAuthorization initial = PushAuthorization.notDetermined;
  PushAuthorization granted = PushAuthorization.granted;
  String? currentToken = 'tok-1';
  PushMessage? initialMessageValue;

  final StreamController<String> tokens = StreamController<String>.broadcast();
  final StreamController<PushMessage> foreground =
      StreamController<PushMessage>.broadcast();
  final StreamController<PushMessage> tapped =
      StreamController<PushMessage>.broadcast();

  final List<PushMessage> shown = <PushMessage>[];
  int initializations = 0;
  int authorizationRequests = 0;

  @override
  Future<void> ensureInitialized() async => initializations++;

  @override
  Future<PushAuthorization> authorization() async => initial;

  @override
  Future<PushAuthorization> requestAuthorization() async {
    authorizationRequests++;
    return initial = granted;
  }

  @override
  Future<String?> token() async => currentToken;

  @override
  Stream<String> tokenRefreshes() => tokens.stream;

  @override
  Stream<PushMessage> foregroundMessages() => foreground.stream;

  @override
  Stream<PushMessage> taps() => tapped.stream;

  @override
  Future<PushMessage?> initialMessage() async => initialMessageValue;

  @override
  Future<void> showForeground(PushMessage message) async => shown.add(message);
}

class _FakeDeviceRepository implements PushDeviceRepository {
  final List<String> registered = <String>[];
  final List<String> unregistered = <String>[];
  bool failNext = false;

  @override
  Future<void> register(String token) async {
    if (failNext) {
      failNext = false;
      throw StateError('network');
    }
    registered.add(token);
  }

  @override
  Future<void> unregister(String token) async => unregistered.add(token);
}

class _FakeNotificationsRepository implements NotificationsRepository {
  _FakeNotificationsRepository({this.channels = const <NotificationChannel>[]});

  final List<NotificationChannel> channels;
  final List<String> markedRead = <String>[];
  int unread = 3;

  @override
  Future<void> markRead(String id) async {
    markedRead.add(id);
    unread = unread > 0 ? unread - 1 : 0;
  }

  @override
  Future<int> unreadCount() async => unread;

  @override
  Future<PageResult<NotificationDto>> fetchPage({
    int page = 0,
    int size = 20,
    bool unreadOnly = false,
  }) async =>
      const PageResult<NotificationDto>(items: <NotificationDto>[], total: 0);

  @override
  Future<void> markAllRead() async {}

  @override
  Future<NotificationPreferencesDto> preferences() async =>
      NotificationPreferencesDto(
        channels: channels,
        preferences: const <NotificationPreferenceDto>[],
        teams: const <NotificationTeamPreferenceDto>[],
        emailDigest: false,
      );

  @override
  Future<NotificationPreferencesDto> setPreference({
    required NotificationType type,
    required NotificationChannel channel,
    required bool enabled,
  }) async => preferences();

  @override
  Future<NotificationPreferencesDto> setTeamMuted({
    required String teamSlug,
    required bool muted,
  }) async => preferences();

  @override
  Future<NotificationPreferencesDto> setEmailDigest(bool enabled) async =>
      preferences();
}

/// Le contrôleur, monté sans passer par `authProvider` : celui-ci ouvrirait
/// une session, du stockage sécurisé et un Dio, dont rien ici n'a besoin.
final _controllerProvider =
    StateNotifierProvider<PushController, PushAuthorization>(
      (Ref ref) => PushController(ref),
    );

void main() {
  late _FakeGateway gateway;
  late _FakeDeviceRepository devices;
  late _FakeNotificationsRepository notifications;
  late ProviderContainer container;
  late int invitationLoads;

  setUp(() {
    invitationLoads = 0;
    gateway = _FakeGateway();
    devices = _FakeDeviceRepository();
    notifications = _FakeNotificationsRepository();
    container = ProviderContainer(
      overrides: [
        pushGatewayProvider.overrideWithValue(gateway),
        pushDeviceRepositoryProvider.overrideWithValue(devices),
        notificationsRepositoryProvider.overrideWithValue(notifications),
        myInvitationsProvider.overrideWith((Ref ref) async {
          invitationLoads++;
          return const <MyInvitationDto>[];
        }),
      ],
    );
    addTearDown(container.dispose);
  });

  PushController start() {
    final PushController controller = container.read(
      _controllerProvider.notifier,
    );
    return controller;
  }

  test('sans autorisation, aucun jeton n\'est envoyé au serveur', () async {
    final PushController controller = start();
    await controller.onAuthChanged(true);

    expect(
      container.read(_controllerProvider),
      PushAuthorization.notDetermined,
    );
    expect(devices.registered, isEmpty);
    expect(container.read(registeredPushTokenProvider), isNull);
  });

  test('autorisation accordée : le jeton part, et une seule fois', () async {
    gateway.initial = PushAuthorization.granted;
    final PushController controller = start();

    await controller.onAuthChanged(true);
    await controller.onAuthChanged(true);

    expect(devices.registered, <String>['tok-1']);
    expect(container.read(registeredPushTokenProvider), 'tok-1');
  });

  test('le bouton d\'activation enregistre le jeton dans la foulée', () async {
    final PushController controller = start();
    await controller.onAuthChanged(true);
    expect(devices.registered, isEmpty);

    final PushAuthorization result = await controller.requestAuthorization();

    expect(result, PushAuthorization.granted);
    expect(gateway.authorizationRequests, 1);
    expect(devices.registered, <String>['tok-1']);
  });

  test('un refus laisse l\'appareil non inscrit, sans erreur', () async {
    gateway.granted = PushAuthorization.denied;
    final PushController controller = start();
    await controller.onAuthChanged(true);

    expect(await controller.requestAuthorization(), PushAuthorization.denied);
    expect(devices.registered, isEmpty);
  });

  test('une rotation de jeton réenregistre l\'appareil', () async {
    gateway.initial = PushAuthorization.granted;
    final PushController controller = start();
    await controller.onAuthChanged(true);

    gateway.currentToken = 'tok-2';
    gateway.tokens.add('tok-2');
    await Future<void>.delayed(Duration.zero);

    expect(devices.registered, <String>['tok-1', 'tok-2']);
    expect(container.read(registeredPushTokenProvider), 'tok-2');
  });

  test(
    'une inscription qui échoue ne retient pas le jeton — la suivante réessaie',
    () async {
      gateway.initial = PushAuthorization.granted;
      devices.failNext = true;
      final PushController controller = start();

      await controller.onAuthChanged(true);
      expect(container.read(registeredPushTokenProvider), isNull);

      await controller.onAuthChanged(true);
      expect(devices.registered, <String>['tok-1']);
    },
  );

  test('la déconnexion oublie le jeton côté app', () async {
    gateway.initial = PushAuthorization.granted;
    final PushController controller = start();
    await controller.onAuthChanged(true);
    expect(container.read(registeredPushTokenProvider), 'tok-1');

    await controller.onAuthChanged(false);

    // C'est `AuthNotifier` qui appelle `POST /api/push-devices/unregister`
    // avant d'effacer la session ; ici, seul l'état côté app est vérifié.
    expect(container.read(registeredPushTokenProvider), isNull);
  });

  test(
    'un message reçu app ouverte affiche une bannière et bouge la pastille',
    () async {
      gateway.initial = PushAuthorization.granted;
      final PushController controller = start();
      await controller.onAuthChanged(true);
      // La pastille commence par ce que dit le serveur.
      await container.read(unreadNotificationCountProvider.notifier).refresh();
      expect(container.read(unreadNotificationCountProvider), 3);

      notifications.unread = 4;
      gateway.foreground.add(
        const PushMessage(title: 'Sortie publiée', body: 'Dimanche'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(gateway.shown, hasLength(1));
      expect(container.read(unreadNotificationCountProvider), 4);
    },
  );

  test('taper une notification la marque lue et dépose sa route', () async {
    gateway.initial = PushAuthorization.granted;
    final PushController controller = start();
    await controller.onAuthChanged(true);

    gateway.tapped.add(
      const PushMessage(
        data: <String, String>{
          'notificationId': 'n-42',
          'path': '/equipes/gaby/sorties/dimanche',
        },
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(notifications.markedRead, <String>['n-42']);
    expect(
      container.read(pendingPushRouteProvider),
      '/equipes/gaby/sorties/dimanche',
    );
  });

  test(
    'une app tuée puis réveillée par un tap ouvre quand même la page',
    () async {
      gateway.initial = PushAuthorization.granted;
      gateway.initialMessageValue = const PushMessage(
        data: <String, String>{
          'notificationId': 'n-7',
          'path': '/equipes/gaby/articles/bilan',
        },
      );
      final PushController controller = start();

      await controller.onAuthChanged(true);
      await Future<void>.delayed(Duration.zero);

      expect(notifications.markedRead, <String>['n-7']);
      expect(
        container.read(pendingPushRouteProvider),
        '/equipes/gaby/articles/bilan',
      );
    },
  );

  test(
    'une invitation ouvre la liste des équipes et relit les invitations',
    () async {
      gateway.initial = PushAuthorization.granted;
      final PushController controller = start();
      await controller.onAuthChanged(true);
      await container.read(myInvitationsProvider.future);
      expect(invitationLoads, 1);

      gateway.tapped.add(
        const PushMessage(
          data: <String, String>{
            'notificationId': 'n-11',
            'type': 'TEAM_INVITATION',
            'subjectType': 'TEAM',
            'path': '/teams',
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(container.read(pendingPushRouteProvider), '/teams');
      // La liste des équipes est la racine d'un onglet : aucun ancêtre à
      // empiler, `main.dart` y va directement.
      expect(ancestorsForDeepLink('/teams'), isEmpty);
      await container.read(myInvitationsProvider.future);
      expect(invitationLoads, 2);
    },
  );

  test(
    'un message sans route n\'envoie nulle part, et reste marqué lu',
    () async {
      gateway.initial = PushAuthorization.granted;
      final PushController controller = start();
      await controller.onAuthChanged(true);

      gateway.tapped.add(
        const PushMessage(data: <String, String>{'notificationId': 'n-9'}),
      );
      await Future<void>.delayed(Duration.zero);

      expect(notifications.markedRead, <String>['n-9']);
      expect(container.read(pendingPushRouteProvider), isNull);
    },
  );

  group('le bandeau d\'activation', () {
    setUpAll(loadTestTranslations);

    Future<void> pumpBanner(
      WidgetTester tester, {
      required List<NotificationChannel> channels,
      required PushAuthorization authorization,
    }) async {
      final _FakeNotificationsRepository repository =
          _FakeNotificationsRepository(channels: channels);
      gateway.initial = authorization;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pushGatewayProvider.overrideWithValue(gateway),
            pushDeviceRepositoryProvider.overrideWithValue(devices),
            notificationsRepositoryProvider.overrideWithValue(repository),
            pushAuthorizationProvider.overrideWith((Ref ref) {
              final PushController controller = PushController(ref);
              unawaited(controller.onAuthChanged(true));
              return controller;
            }),
          ],
          child: MaterialApp(
            theme: PedalonsTheme.build(Brightness.light),
            home: const Scaffold(body: PushActivationBanner()),
          ),
        ),
      );
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
    }

    testWidgets('reste invisible quand le serveur ne sait pas pousser', (
      WidgetTester tester,
    ) async {
      await pumpBanner(
        tester,
        channels: const <NotificationChannel>[NotificationChannel.email],
        authorization: PushAuthorization.notDetermined,
      );

      expect(find.text('Activer'), findsNothing);
      expect(
        find.textContaining('Notifications sur cet appareil'),
        findsNothing,
      );
    });

    testWidgets('propose l\'activation quand le push est disponible', (
      WidgetTester tester,
    ) async {
      await pumpBanner(
        tester,
        channels: const <NotificationChannel>[NotificationChannel.push],
        authorization: PushAuthorization.notDetermined,
      );

      expect(find.text('Activer'), findsOneWidget);

      await tester.tap(find.text('Activer'));
      await tester.pump(const Duration(milliseconds: 10));
      expect(gateway.authorizationRequests, 1);
      expect(devices.registered, <String>['tok-1']);
    });

    testWidgets('après un refus, renvoie aux réglages plutôt qu\'à un bouton', (
      WidgetTester tester,
    ) async {
      await pumpBanner(
        tester,
        channels: const <NotificationChannel>[NotificationChannel.push],
        authorization: PushAuthorization.denied,
      );

      expect(find.text('Activer'), findsNothing);
      expect(
        find.textContaining('réglages de votre téléphone'),
        findsOneWidget,
      );
    });

    testWidgets('disparaît une fois l\'autorisation accordée', (
      WidgetTester tester,
    ) async {
      await pumpBanner(
        tester,
        channels: const <NotificationChannel>[NotificationChannel.push],
        authorization: PushAuthorization.granted,
      );

      expect(find.text('Activer'), findsNothing);
    });
  });
}
