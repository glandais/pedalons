import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/notifications/data/notifications_repository.dart';
import 'package:pedalons/features/notifications/presentation/pages/notification_settings_page.dart';
import 'package:pedalons/features/notifications/providers/notifications_provider.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';

/// La page des réglages de notification : ce qu'elle montre selon ce que le
/// serveur déclare, et l'appel unique que chaque puce ou interrupteur envoie.
class _StubRepository implements NotificationsRepository {
  _StubRepository({
    this.channels = const <NotificationChannel>[],
    List<(NotificationType, NotificationChannel, bool)>? cells,
    this._teams = const <NotificationTeamPreferenceDto>[],
  }) : _cells =
           cells ??
           <(NotificationType, NotificationChannel, bool)>[
             for (final NotificationChannel channel in channels)
               (NotificationType.ridePublished, channel, true),
           ];

  final List<NotificationChannel> channels;
  final List<(NotificationType, NotificationChannel, bool)> _cells;
  List<NotificationTeamPreferenceDto> _teams;
  bool _digest = false;
  final List<String> calls = <String>[];

  @override
  Future<NotificationPreferencesDto> preferences() async =>
      NotificationPreferencesDto(
        channels: channels,
        preferences: <NotificationPreferenceDto>[
          for (final (
                NotificationType type,
                NotificationChannel channel,
                bool enabled,
              )
              in _cells)
            NotificationPreferenceDto(
              type: type.toJson(),
              channel: channel.toJson(),
              enabled: enabled,
              enabledByDefault: true,
            ),
        ],
        teams: _teams,
        emailDigest: _digest,
      );

  @override
  Future<NotificationPreferencesDto> setTeamMuted({
    required String teamSlug,
    required bool muted,
  }) async {
    calls.add('team:$teamSlug:$muted');
    _teams = <NotificationTeamPreferenceDto>[
      for (final NotificationTeamPreferenceDto t in _teams)
        t.teamSlug == teamSlug ? t.copyWith(muted: muted) : t,
    ];
    return preferences();
  }

  @override
  Future<NotificationPreferencesDto> setEmailDigest(bool enabled) async {
    calls.add('digest:$enabled');
    _digest = enabled;
    return preferences();
  }

  @override
  Future<NotificationPreferencesDto> setPreference({
    required NotificationType type,
    required NotificationChannel channel,
    required bool enabled,
  }) async {
    calls.add('cell:${type.toJson()}:${channel.toJson()}:$enabled');
    for (int i = 0; i < _cells.length; i++) {
      if (_cells[i].$1 == type && _cells[i].$2 == channel) {
        _cells[i] = (type, channel, enabled);
      }
    }
    return preferences();
  }

  @override
  Future<PageResult<NotificationDto>> fetchPage({
    int page = 0,
    int size = 20,
    bool unreadOnly = false,
  }) async =>
      const PageResult<NotificationDto>(items: <NotificationDto>[], total: 0);

  @override
  Future<int> unreadCount() async => 0;

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> markAllRead() async {}
}

const NotificationTeamPreferenceDto _gaby = NotificationTeamPreferenceDto(
  teamSlug: 'gaby',
  teamName: 'Gaby Cyclo',
  muted: false,
);

void main() {
  setUpAll(loadTestTranslations);

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  Future<void> pump(WidgetTester tester, _StubRepository repository) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(repository),
          // Sans session dans le test : un compteur qui ne sonde rien.
          unreadNotificationCountProvider.overrideWith(
            (ref) => UnreadCountNotifier(ref),
          ),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: const NotificationSettingsPage(),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets(
    'ni canal ni équipe : le lien vers la boîte, et aucun réglage sans effet',
    (WidgetTester tester) async {
      await pump(tester, _StubRepository());

      expect(find.byKey(keys.notifications.openInboxRow), findsOneWidget);
      expect(
        find.text('Vous recevez toutes vos notifications dans l\'application.'),
        findsOneWidget,
      );
      expect(find.byType(ChannelChip), findsNothing);
      expect(find.byType(PdlSwitch), findsNothing);
    },
  );

  testWidgets(
    'sans canal, les équipes se règlent quand même — et les types restent cachés',
    (WidgetTester tester) async {
      final _StubRepository repository = _StubRepository(
        teams: const <NotificationTeamPreferenceDto>[_gaby],
      );
      await pump(tester, repository);

      expect(find.text('Annonces des équipes'), findsOneWidget);
      expect(find.text('Gaby Cyclo'), findsOneWidget);
      expect(find.text('Sortie publiée'), findsNothing);
      expect(find.text('Résumé quotidien par e-mail'), findsNothing);
      expect(find.byType(PdlSwitch), findsOneWidget);
      // Allumé = je reçois ses annonces.
      expect(tester.widget<PdlSwitch>(find.byType(PdlSwitch)).value, isTrue);

      await tester.tap(find.byType(PdlSwitch));
      await settle(tester);

      expect(repository.calls, <String>['team:gaby:true']);
      expect(tester.widget<PdlSwitch>(find.byType(PdlSwitch)).value, isFalse);
    },
  );

  testWidgets('le résumé quotidien n\'apparaît qu\'avec l\'e-mail', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      _StubRepository(
        channels: const <NotificationChannel>[NotificationChannel.push],
      ),
    );
    expect(find.text('Résumé quotidien par e-mail'), findsNothing);
    // Push seul : aucune puce E-mail.
    expect(
      find.byKey(keys.notifications.channelChip('RIDE_PUBLISHED', 'EMAIL')),
      findsNothing,
    );
    expect(
      find.byKey(keys.notifications.channelChip('RIDE_PUBLISHED', 'PUSH')),
      findsOneWidget,
    );

    final _StubRepository withEmail = _StubRepository(
      channels: const <NotificationChannel>[NotificationChannel.email],
    );
    await pump(tester, withEmail);
    await tester.scrollUntilVisible(
      find.byKey(keys.notifications.digestSwitch),
      200,
    );
    expect(find.text('Résumé quotidien par e-mail'), findsOneWidget);

    await tester.tap(find.byKey(keys.notifications.digestSwitch));
    await settle(tester);
    expect(withEmail.calls, <String>['digest:true']);
  });

  testWidgets(
    'une ligne par type, regroupée par famille, une puce par canal déclaré',
    (WidgetTester tester) async {
      await pump(
        tester,
        _StubRepository(
          channels: const <NotificationChannel>[
            NotificationChannel.email,
            NotificationChannel.push,
          ],
          cells: <(NotificationType, NotificationChannel, bool)>[
            (NotificationType.ridePublished, NotificationChannel.email, true),
            (NotificationType.ridePublished, NotificationChannel.push, false),
            (NotificationType.rideCancelled, NotificationChannel.email, true),
            (NotificationType.rideCancelled, NotificationChannel.push, true),
          ],
        ),
      );

      // Une famille sans ligne n'a pas d'en-tête.
      expect(find.text('Sorties'), findsOneWidget);
      expect(find.text('Voyages'), findsNothing);
      // Deux lignes, pas quatre interrupteurs : le seul est le résumé.
      expect(find.text('Sortie publiée'), findsOneWidget);
      expect(find.text('Sortie annulée'), findsOneWidget);
      expect(find.byType(PdlSwitch), findsOneWidget);
      expect(find.byType(ChannelChip), findsNWidgets(4));
      // Dans l'ordre du site : publiée avant annulée.
      expect(
        tester.getTopLeft(find.text('Sortie publiée')).dy,
        lessThan(tester.getTopLeft(find.text('Sortie annulée')).dy),
      );
    },
  );

  testWidgets('une puce est un interrupteur nommé, et n\'écrit que sa case', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final _StubRepository repository = _StubRepository(
      channels: const <NotificationChannel>[
        NotificationChannel.email,
        NotificationChannel.push,
      ],
      cells: <(NotificationType, NotificationChannel, bool)>[
        (NotificationType.ridePublished, NotificationChannel.email, true),
        (NotificationType.ridePublished, NotificationChannel.push, false),
      ],
    );
    await pump(tester, repository);

    final Finder email = find.byKey(
      keys.notifications.channelChip('RIDE_PUBLISHED', 'EMAIL'),
    );
    expect(
      tester.getSemantics(email),
      matchesSemantics(
        label: 'Sortie publiée, par e-mail',
        isButton: true,
        hasToggledState: true,
        isToggled: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(
        find.byKey(keys.notifications.channelChip('RIDE_PUBLISHED', 'PUSH')),
      ),
      matchesSemantics(
        label: 'Sortie publiée, en push',
        isButton: true,
        hasToggledState: true,
        isToggled: false,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(email);
    await settle(tester);

    expect(repository.calls, <String>['cell:RIDE_PUBLISHED:EMAIL:false']);
    expect(tester.widget<ChannelChip>(email).on, isFalse);
    semantics.dispose();
  });

  testWidgets('une case absente laisse sa place vide, sans puce à toucher', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      _StubRepository(
        channels: const <NotificationChannel>[
          NotificationChannel.email,
          NotificationChannel.push,
        ],
        cells: <(NotificationType, NotificationChannel, bool)>[
          (NotificationType.contentReported, NotificationChannel.email, true),
        ],
      ),
    );

    expect(find.text('Contenu signalé'), findsOneWidget);
    expect(
      find.byKey(keys.notifications.channelChip('CONTENT_REPORTED', 'EMAIL')),
      findsOneWidget,
    );
    expect(
      find.byKey(keys.notifications.channelChip('CONTENT_REPORTED', 'PUSH')),
      findsNothing,
    );
  });
}
