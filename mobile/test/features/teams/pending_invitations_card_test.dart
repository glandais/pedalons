import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/teams/data/invitations_repository.dart';
import 'package:pedalons/features/teams/presentation/widgets/pending_invitations_card.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';

import '../../support/localization.dart';
import 'team_fixtures.dart';

/// La carte des invitations en attente, en tête de « Mes équipes » : ce
/// qu'elle affiche, ce qu'une acceptation déclenche, et comment elle échoue.
class _FakeInvitations implements InvitationsRepository {
  _FakeInvitations(this.pending, {this.acceptError});

  List<MyInvitationDto> pending;
  final Object? acceptError;
  final List<String> accepted = <String>[];

  @override
  Future<List<MyInvitationDto>> listMine() async => pending;

  @override
  Future<void> accept(String invitationId) async {
    if (acceptError != null) throw acceptError!;
    accepted.add(invitationId);
    pending = pending
        .where((MyInvitationDto i) => i.id != invitationId)
        .toList();
  }
}

const MyInvitationDto _invitation = MyInvitationDto(
  id: 'inv-1',
  team: kMemberTeam,
  inviterName: 'Gaby Landais',
  role: 'MEMBER',
  expiresAt: '2026-10-01T00:00:00Z',
);

DioException _apiError(String code) => DioException(
  requestOptions: RequestOptions(path: '/'),
  type: DioExceptionType.badResponse,
  response: Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: '/'),
    statusCode: 403,
    data: <String, dynamic>{'code': code},
  ),
);

void main() {
  setUpAll(loadTestTranslations);

  late int teamLoads;

  Future<ProviderContainer> pump(
    WidgetTester tester,
    _FakeInvitations invitations,
  ) async {
    teamLoads = 0;
    final ProviderContainer container = ProviderContainer(
      overrides: [
        invitationsRepositoryProvider.overrideWithValue(invitations),
        myTeamsProvider.overrideWith((Ref ref) async {
          teamLoads++;
          return const <TeamDetailDto>[];
        }),
      ],
    );
    addTearDown(container.dispose);
    // La liste des équipes est affichée à côté : on la tient ouverte comme
    // l'écran le ferait, pour voir l'acceptation la recharger.
    container.listen(myTeamsProvider, (_, _) {});
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: const Scaffold(body: PendingInvitationsCard()),
        ),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    return container;
  }

  testWidgets('sans invitation, la carte ne prend aucune place', (
    WidgetTester tester,
  ) async {
    await pump(tester, _FakeInvitations(<MyInvitationDto>[]));

    expect(find.text('Accepter'), findsNothing);
    expect(find.textContaining('invitation'), findsNothing);
  });

  testWidgets(
    'accepter rejoint l\'équipe, retire l\'invitation et recharge les équipes',
    (WidgetTester tester) async {
      final _FakeInvitations invitations = _FakeInvitations(<MyInvitationDto>[
        _invitation,
      ]);
      await pump(tester, invitations);

      expect(find.text('Vous avez une invitation en attente'), findsOneWidget);
      expect(
        find.text('Gaby Landais vous invite à rejoindre N-Peloton.'),
        findsOneWidget,
      );
      expect(teamLoads, 1);

      await tester.tap(find.text('Accepter'));
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(invitations.accepted, <String>['inv-1']);
      expect(find.text('Accepter'), findsNothing);
      expect(teamLoads, 2);
    },
  );

  testWidgets('un refus du serveur reste affiché, avec sa cause', (
    WidgetTester tester,
  ) async {
    final _FakeInvitations invitations = _FakeInvitations(<MyInvitationDto>[
      _invitation,
    ], acceptError: _apiError('EMAIL_NOT_VERIFIED'));
    await pump(tester, invitations);

    await tester.tap(find.text('Accepter'));
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(
      find.text('Veuillez vérifier votre adresse e-mail avant de continuer'),
      findsOneWidget,
    );
    // L'invitation reste là : on peut réessayer une fois l'adresse vérifiée.
    expect(find.text('Accepter'), findsOneWidget);
    expect(teamLoads, 1);
  });
}
