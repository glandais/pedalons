import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/formatters.dart';
import 'package:pedalons/features/notifications/data/notifications_repository.dart';
import 'package:pedalons/features/notifications/presentation/notification_display.dart';
import 'package:pedalons/features/notifications/presentation/pages/notifications_page.dart';

import '../../support/localization.dart';

/// La boîte de réception : ce qu'elle rend, et surtout ce qu'elle formule
/// elle-même.
///
/// Le point de tout l'étage client est là : l'API n'envoie **aucun texte
/// rendu** (`docs/plans/archive/2026-09-18-notifications.md` §3), donc un écran qui
/// afficherait `RIDE_PUBLISHED` tel quel serait passé à côté. Les cas ci-dessous
/// vérifient la phrase, la destination et la distinction lu / non lu.
class _StubRepository implements NotificationsRepository {
  _StubRepository(this.items, {this.unread = 0});

  final List<NotificationDto> items;
  int unread;
  final List<String> markedRead = <String>[];
  bool markedAll = false;

  @override
  Future<PageResult<NotificationDto>> fetchPage({
    int page = 0,
    int size = 20,
    bool unreadOnly = false,
  }) async {
    final List<NotificationDto> visible = unreadOnly
        ? items.where((NotificationDto n) => !n.read).toList()
        : items;
    return PageResult<NotificationDto>(
      items: page == 0 ? visible : <NotificationDto>[],
      total: visible.length,
    );
  }

  @override
  Future<int> unreadCount() async => unread;

  @override
  Future<void> markRead(String id) async => markedRead.add(id);

  @override
  Future<void> markAllRead() async {
    markedAll = true;
    for (int i = 0; i < items.length; i++) {
      items[i] = items[i].copyWith(read: true);
    }
    unread = 0;
  }

  @override
  Future<NotificationPreferencesDto> preferences() async =>
      const NotificationPreferencesDto(
        channels: <NotificationChannel>[],
        preferences: <NotificationPreferenceDto>[],
        teams: <NotificationTeamPreferenceDto>[],
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

NotificationDto _notification({
  String id = 'n1',
  NotificationType type = NotificationType.ridePublished,
  NotificationSubjectType subject = NotificationSubjectType.ride,
  bool read = false,
  String? actorName = 'Gaby Landais',
  List<NotificationChange> changes = const <NotificationChange>[],
  String? excerpt,
  String subjectName = 'Sortie du dimanche',
  String? subjectDateTime,
  String? subjectTimezone,
}) {
  return NotificationDto(
    id: id,
    type: type.toJson(),
    read: read,
    createdAt: DateTime.now()
        .subtract(const Duration(minutes: 5))
        .toUtc()
        .toIso8601String(),
    actorName: actorName,
    teamSlug: 'gaby',
    teamName: 'Gaby',
    subjectType: subject.toJson(),
    subjectSlug: 'sortie-du-dimanche',
    subjectName: subjectName,
    changes: changes,
    excerpt: excerpt,
    subjectDateTime: subjectDateTime,
    subjectTimezone: subjectTimezone,
  );
}

void main() {
  setUpAll(() async {
    // L'écran affiche un compteur : `.plural()` exige une locale chargée.
    await loadTestTranslations();
  });

  Widget app(_StubRepository repository) {
    return ProviderScope(
      overrides: [
        notificationsRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: PedalonsTheme.build(Brightness.light),
        home: const NotificationsPage(),
      ),
    );
  }

  Future<void> open(WidgetTester tester, _StubRepository repository) async {
    await tester.pumpWidget(app(repository));
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  testWidgets('une notification est formulée par le client, pas par l\'API', (
    WidgetTester tester,
  ) async {
    await open(tester, _StubRepository(<NotificationDto>[_notification()]));

    expect(find.text('Gaby Landais a publié une sortie'), findsOneWidget);
    expect(find.text('Sortie du dimanche'), findsOneWidget);
    // Le type brut ne doit jamais atteindre l'écran.
    expect(find.textContaining('RIDE_PUBLISHED'), findsNothing);
  });

  testWidgets(
    'une publication sans acteur nomme l\'équipe plutôt qu\'un trou',
    (WidgetTester tester) async {
      await open(
        tester,
        _StubRepository(<NotificationDto>[_notification(actorName: null)]),
      );

      expect(find.text('Gaby a publié une sortie'), findsOneWidget);
      expect(find.textContaining('null'), findsNothing);
    },
  );

  testWidgets('la boîte vide le dit, et ne propose pas de sortie de filtre', (
    WidgetTester tester,
  ) async {
    await open(tester, _StubRepository(<NotificationDto>[]));

    expect(find.text('Aucune notification'), findsOneWidget);
    expect(find.text('Toutes'), findsOneWidget); // le segmenté, pas un bouton
  });

  testWidgets('« Tout marquer lu » n\'apparaît qu\'avec des non lues', (
    WidgetTester tester,
  ) async {
    final _StubRepository withUnread = _StubRepository(<NotificationDto>[
      _notification(),
    ], unread: 1);
    await open(tester, withUnread);
    expect(find.bySemanticsLabel('Tout marquer lu'), findsOneWidget);

    await open(
      tester,
      _StubRepository(<NotificationDto>[_notification(read: true)]),
    );
    expect(find.bySemanticsLabel('Tout marquer lu'), findsNothing);
  });

  testWidgets('un sujet inconnu reste lisible, mais n\'est pas tapable', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      _StubRepository(<NotificationDto>[
        _notification(subject: NotificationSubjectType.$unknown),
      ]),
    );

    expect(find.text('Gaby Landais a publié une sortie'), findsOneWidget);
  });

  test('la destination vient du sujet, jamais du type', () {
    expect(_notification().path(), '/equipes/gaby/sorties/sortie-du-dimanche');
    expect(
      _notification(subject: NotificationSubjectType.post).path(),
      '/equipes/gaby/articles/sortie-du-dimanche',
    );
    // Un sujet qu'une version plus ancienne ne connaît pas n'invente pas de
    // route : la ligne se rend, elle ne mène nulle part.
    expect(
      _notification(subject: NotificationSubjectType.$unknown).path(),
      isNull,
    );
  });

  test('un signalement nomme l\'équipe et mène à la file du site', () {
    final NotificationDto reported = _notification(
      type: NotificationType.contentReported,
      subject: NotificationSubjectType.report,
      actorName: null,
      subjectName: 'Gaby',
    );
    // Aucun acteur : le signaleur est anonyme pour l'équipe.
    expect(reported.title(), 'Nouveau signalement dans Gaby');
    // La file n'existe que sur le web : pas de route interne, une page du
    // site — celle que le serveur met dans le push.
    expect(reported.path(), isNull);
    // Dans la langue de l'app (route `teamAdminReports`, MOB-54).
    expect(reported.webPath(), '/equipes/gaby/admin/signalements');
    expect(_notification().webPath(), isNull);
  });

  testWidgets('les types de la phase 5 ont leur phrase, pas leur code', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      _StubRepository(<NotificationDto>[
        _notification(
          id: 'c',
          type: NotificationType.commentOnMyPublication,
          excerpt: 'Superbe parcours !',
        ),
        _notification(
          id: 'j',
          type: NotificationType.rideJoined,
          actorName: 'Léa',
          excerpt: 'Groupe rapide',
        ),
        _notification(
          id: 'r',
          type: NotificationType.rideReminder,
          actorName: null,
        ),
      ]),
    );

    expect(
      find.text('Gaby Landais a commenté votre publication'),
      findsOneWidget,
    );
    expect(find.text('Superbe parcours !'), findsOneWidget);
    // Le nom du groupe n'est pas une citation : il est présenté comme tel.
    expect(find.text('Léa a rejoint une sortie'), findsOneWidget);
    expect(find.text('Groupe « Groupe rapide »'), findsOneWidget);
    expect(find.text('Rappel : votre sortie part demain'), findsOneWidget);
    expect(find.textContaining('COMMENT_ON_MY_PUBLICATION'), findsNothing);
  });

  test('une modification de sortie dit ce qui a changé', () {
    String title(List<NotificationChange> changes) => _notification(
      type: NotificationType.rideUpdated,
      changes: changes,
    ).title();

    expect(
      title(<NotificationChange>[NotificationChange.dateTime]),
      'Une sortie change de date',
    );
    expect(
      title(<NotificationChange>[NotificationChange.startPlace]),
      'Une sortie change de point de départ',
    );
    expect(
      title(<NotificationChange>[
        NotificationChange.dateTime,
        NotificationChange.startPlace,
      ]),
      'Une sortie change de date et de point de départ',
    );
    // Rien de connu : la phrase générique, jamais un trou.
    expect(
      title(<NotificationChange>[NotificationChange.$unknown]),
      'Une sortie a été modifiée',
    );
  });

  group('la date du sujet, un rendez-vous (docs/LEDGER_*.md API-60)', () {
    // 2026-10-11T23:00Z : lundi 12 octobre, 08:00 à Tokyo, 01:00 à Paris.
    const String at = '2026-10-11T23:00:00Z';

    setUp(() => AppFormatters.setDisplayTimezone('Europe/Paris'));
    tearDown(() => AppFormatters.setDisplayTimezone(null));

    test('un rappel se lit dans le fuseau de la sortie, avec la mention', () {
      expect(
        _notification(
          type: NotificationType.rideReminder,
          subjectDateTime: at,
          subjectTimezone: 'Asia/Tokyo',
        ).subjectDateLine(),
        'Départ : lundi 12 octobre à 08:00 · heure de Tokyo '
        '(01:00 chez vous)',
      );
    });

    test('le même décalage ne dit rien de plus', () {
      expect(
        _notification(
          type: NotificationType.rideReminder,
          subjectDateTime: at,
          subjectTimezone: 'Europe/Brussels',
        ).subjectDateLine(),
        'Départ : lundi 12 octobre à 01:00',
      );
    });

    test('une notification sans fuseau figé se lit chez le lecteur', () {
      expect(
        _notification(
          type: NotificationType.rideReminder,
          subjectDateTime: at,
        ).subjectDateLine(),
        'Départ : lundi 12 octobre à 01:00',
      );
    });

    test('une nouvelle date se dit, un autre changement non', () {
      expect(
        _notification(
          type: NotificationType.rideUpdated,
          changes: <NotificationChange>[NotificationChange.dateTime],
          subjectDateTime: at,
          subjectTimezone: 'Asia/Tokyo',
        ).subjectDateLine(),
        startsWith('Nouvelle date : lundi 12 octobre à 08:00 · '),
      );
      expect(
        _notification(
          type: NotificationType.rideUpdated,
          changes: <NotificationChange>[NotificationChange.startPlace],
          subjectDateTime: at,
          subjectTimezone: 'Asia/Tokyo',
        ).subjectDateLine(),
        isNull,
      );
      expect(
        _notification(
          subjectDateTime: at,
          subjectTimezone: 'Asia/Tokyo',
        ).subjectDateLine(),
        isNull,
      );
    });

    testWidgets('la ligne apparaît dans la boîte', (WidgetTester tester) async {
      await open(
        tester,
        _StubRepository(<NotificationDto>[
          _notification(
            type: NotificationType.rideReminder,
            subjectDateTime: at,
            subjectTimezone: 'Asia/Tokyo',
          ),
        ]),
      );

      expect(find.textContaining('heure de Tokyo'), findsOneWidget);
    });
  });

  testWidgets('une invitation nomme l\'invitant et l\'équipe', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      _StubRepository(<NotificationDto>[
        _notification(
          type: NotificationType.teamInvitation,
          subject: NotificationSubjectType.team,
          subjectName: 'Gaby',
        ),
      ]),
    );

    expect(
      find.text('Gaby Landais vous invite à rejoindre Gaby'),
      findsOneWidget,
    );
  });

  test('un sujet TEAM mène à la liste des équipes', () {
    expect(
      _notification(
        type: NotificationType.teamInvitation,
        subject: NotificationSubjectType.team,
      ).path(),
      '/equipes',
    );
  });

  testWidgets('« Tout marquer lu » sous « Non lues » vide la liste', (
    WidgetTester tester,
  ) async {
    final _StubRepository repository = _StubRepository(<NotificationDto>[
      _notification(id: 'a', subjectName: 'Sortie A'),
      _notification(id: 'b', subjectName: 'Sortie B', read: true),
    ], unread: 1);
    await open(tester, repository);
    expect(find.text('Sortie A'), findsOneWidget);
    expect(find.text('Sortie B'), findsOneWidget);

    await tester.tap(find.text('Non lues'));
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(find.text('Sortie A'), findsOneWidget);
    expect(find.text('Sortie B'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Tout marquer lu'));
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(repository.markedAll, isTrue);
    expect(find.text('Sortie A'), findsNothing);
    expect(find.text('Aucune notification non lue'), findsOneWidget);
    expect(find.bySemanticsLabel('Tout marquer lu'), findsNothing);
  });
}
