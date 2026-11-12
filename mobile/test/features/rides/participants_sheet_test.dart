import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/auth/data/auth_repository.dart';
import 'package:pedalons/features/auth/data/secure_storage.dart';
import 'package:pedalons/features/auth/domain/auth_state.dart';
import 'package:pedalons/features/auth/providers/auth_provider.dart';
import 'package:pedalons/features/moderation/presentation/moderation_menu.dart';
import 'package:pedalons/features/participants/data/participant_repository.dart';
import 'package:pedalons/features/participants/domain/participant_query.dart';
import 'package:pedalons/features/participants/presentation/widgets/participants_sheet.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';

/// Un serveur en mémoire : pagine et cherche comme `…/participants`, et
/// retient ce qu'on lui a demandé.
class _FakeParticipantRepository implements ParticipantRepository {
  _FakeParticipantRepository(this.people);

  final List<PublicUserDto> people;
  final List<(String search, int page)> calls = <(String, int)>[];

  @override
  Future<PageResult<PublicUserDto>> fetchPage(
    ParticipantQuery query, {
    required int page,
    required int size,
  }) async {
    calls.add((query.search, page));
    final String needle = query.search.toLowerCase();
    final List<PublicUserDto> matching = people
        .where(
          (PublicUserDto p) => p.displayName.toLowerCase().contains(needle),
        )
        .toList();
    return PageResult<PublicUserDto>(
      items: matching.skip(page * size).take(size).toList(),
      total: matching.length,
    );
  }
}

/// S12-7 — la pastille « Organisateur du groupe » est **conditionnelle** ;
/// `API-12` — la liste est lue page par page et cherchée côté serveur.
///
/// Pour la pastille, trois cas, et le premier est le plus fréquent : la
/// plupart des groupes n'ont pas de meneur désigné. `leader` nul ne rend rien
/// — surtout pas un repli sur `createdBy`, qui serait le créateur de la
/// sortie, donc la même personne sur tous ses groupes.
void main() {
  // Le pied paginé accorde son nom au nombre (`.plural`) : il lui faut une
  // locale chargée (docs/LEDGER_*.md MOB-139, N7).
  setUpAll(loadTestTranslations);
  String organizerKey() => 'participants.groupOrganizer'.tr();

  const PublicUserDto antoine = PublicUserDto(
    id: 'u1',
    displayName: 'Antoine Yvon',
  );
  const List<PublicUserDto> three = <PublicUserDto>[
    antoine,
    PublicUserDto(id: 'u2', displayName: 'Hélène Ebrard'),
    PublicUserDto(id: 'u3', displayName: 'Gaby Landais'),
  ];

  const RideParticipantSource source = RideParticipantSource(
    teamSlug: 'team',
    rideSlug: 'ride',
    groupId: 'g1',
  );

  Future<_FakeParticipantRepository> open(
    WidgetTester tester, {
    List<PublicUserDto> people = three,
    String? organizerId,
    TeamPublicationDto? team,
    bool signedInAsU1 = false,
  }) async {
    final _FakeParticipantRepository repository = _FakeParticipantRepository(
      people,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          participantRepositoryProvider.overrideWithValue(repository),
          if (signedInAsU1) authProvider.overrideWith((Ref ref) => _Me(ref)),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Scaffold(
            body: ParticipantsSheet(
              subtitle: 'Chill Route Long',
              source: source,
              count: people.length,
              organizerId: organizerId,
              team: team,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return repository;
  }

  testWidgets('règle R13 : un `⋯` en bout de ligne, sauf sur la sienne', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      signedInAsU1: true,
      team: const TeamPublicationDto(
        accessible: true,
        id: 't1',
        slug: 'team',
        name: 'Équipe',
        visibility: 'TEAM',
      ),
    );
    expect(find.byKey(keys.participants.personMore('u1')), findsNothing);
    expect(find.byKey(keys.participants.personMore('u2')), findsOneWidget);
    expect(find.byKey(keys.participants.personMore('u3')), findsOneWidget);
    final ModerationMoreButton more = tester.widget<ModerationMoreButton>(
      find.byKey(keys.participants.personMore('u2')),
    );
    final PdlPersonRow row = tester.widget<PdlPersonRow>(
      find.byKey(keys.participants.person('u2')),
    );
    expect(row.trailing, same(more));
    expect(row.onTap, isNotNull);
  });

  testWidgets('sans équipe, ni `⋯` ni menu', (WidgetTester tester) async {
    await open(tester);
    expect(find.byType(ModerationMoreButton), findsNothing);
  });

  testWidgets('sans meneur désigné, aucune pastille — le cas courant', (
    WidgetTester tester,
  ) async {
    await open(tester);
    expect(find.text(organizerKey()), findsNothing);
    expect(find.byType(PdlPersonRow), findsNWidgets(3));
  });

  testWidgets('un meneur qui participe porte la pastille, et lui seul', (
    WidgetTester tester,
  ) async {
    await open(tester, organizerId: antoine.id);
    expect(find.text(organizerKey()), findsOneWidget);
  });

  testWidgets('un meneur qui ne participe pas ne crée pas de ligne', (
    WidgetTester tester,
  ) async {
    await open(tester, organizerId: 'u9');
    expect(find.text(organizerKey()), findsNothing);
    // Les trois participants restent rendus : l'absence du meneur n'enlève
    // rien à la liste.
    expect(find.text('Antoine Yvon'), findsOneWidget);
    expect(find.byType(PdlPersonRow), findsNWidgets(3));
  });

  testWidgets('la recherche part au serveur, débattue', (
    WidgetTester tester,
  ) async {
    final _FakeParticipantRepository server = await open(
      tester,
      people: <PublicUserDto>[
        for (int i = 0; i < 12; i++)
          PublicUserDto(id: 'm$i', displayName: 'Membre $i'),
      ],
    );
    expect(server.calls, <(String, int)>[('', 0)]);

    await tester.enterText(find.byType(TextField), 'Membre 7');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    // Une seule requête pour la frappe entière, pas une par caractère.
    expect(server.calls, <(String, int)>[('', 0), ('Membre 7', 0)]);
    // Le champ lui-même porte aussi le texte saisi : on compte les lignes.
    expect(find.byType(PdlPersonRow), findsOneWidget);
    expect(find.text('Membre 0'), findsNothing);
  });

  testWidgets('au-delà d\'une page, « Afficher plus » charge la suivante', (
    WidgetTester tester,
  ) async {
    final _FakeParticipantRepository server = await open(
      tester,
      people: <PublicUserDto>[
        for (int i = 0; i < 60; i++)
          PublicUserDto(id: 'm$i', displayName: 'Membre $i'),
      ],
    );
    // Arriver au bout de la liste ne charge rien : seule la demande explicite
    // le fait.
    final Finder list = find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(keys.participants.loadMore),
      500,
      scrollable: list,
    );
    await tester.pump();
    expect(server.calls, <(String, int)>[('', 0)]);
    expect(find.byKey(keys.participants.progress), findsOneWidget);

    await tester.tap(find.byKey(keys.participants.loadMore));
    await tester.pump();
    await tester.pump();

    expect(server.calls, <(String, int)>[('', 0), ('', 1)]);
    expect(find.byKey(keys.participants.loadMore), findsNothing);
  });
}

class _NoAuth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoStorage implements SecureTokenStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Connecté en Antoine Yvon (`u1`).
class _Me extends AuthNotifier {
  _Me(Ref ref) : super(_NoAuth(), _NoStorage(), ref) {
    state = const AuthState(
      isInitialized: true,
      accessToken: 'token',
      user: UserDto(
        plannerQuota: PlannerQuotaDto(used: 0, resetsOn: '2026-12-01'),
        id: 'u1',
        email: 'moi@example.org',
        displayName: 'Antoine Yvon',
        contactableByMembers: true,
        emailVerified: true,
      ),
    );
  }
}
