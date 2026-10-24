import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/ads/data/ad_repository.dart';
import 'package:pedalons/features/ads/domain/ad_filters.dart';
import 'package:pedalons/features/ads/presentation/pages/ad_detail_page.dart';
import 'package:pedalons/features/ads/presentation/widgets/ad_location_map.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/features/auth/domain/auth_state.dart';
import 'package:pedalons/features/auth/data/auth_repository.dart';
import 'package:pedalons/features/auth/data/secure_storage.dart';
import 'package:pedalons/features/auth/providers/auth_provider.dart';

import '../../support/localization.dart';
import 'ad_fixtures.dart';

/// S32-5 à S32-7 — le détail d'une annonce.
///
/// Trois choses s'y vérifient, et ce sont les trois que le plan tranche contre
/// l'évidence : la localisation est un **secteur** et le dit, le bouton de
/// contact n'existe pas sur sa propre annonce, et aucune issue d'envoi n'est
/// annoncée comme un succès sans que le serveur l'ait confirmée.
class _StubAdRepository implements AdRepository {
  _StubAdRepository(this.ad, {this.contactError});

  final AdDto ad;
  final Object? contactError;

  int contacts = 0;
  String? lastMessage;

  @override
  Future<AdDto> getAd(String teamSlug, String adSlug) async => ad;

  @override
  Future<void> contactSeller({
    required String teamSlug,
    required String adSlug,
    required String message,
  }) async {
    contacts++;
    lastMessage = message;
    if (contactError != null) throw contactError!;
  }

  @override
  Future<PageResult<AdDto>> fetchAds({
    required AdFilters filters,
    int page = 0,
    int size = kDefaultPageSize,
    ListViewMode? view,
  }) async => const PageResult<AdDto>(items: <AdDto>[], total: 0);
}

DioException _apiError(
  String code, {
  int status = 400,
  Map<String, List<String>> headers = const <String, List<String>>{},
}) => DioException(
  requestOptions: RequestOptions(path: '/'),
  type: DioExceptionType.badResponse,
  response: Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: '/'),
    statusCode: status,
    headers: Headers.fromMap(headers),
    data: <String, dynamic>{'code': code},
  ),
);

const AuthState _signedIn = AuthState(
  user: UserDto(
    id: 'u-me',
    email: 'moi@example.org',
    displayName: 'Moi',
    emailVerified: true,
    contactableByMembers: true,
  ),
  accessToken: 'token',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestTranslations);

  Future<_StubAdRepository> openAd(
    WidgetTester tester,
    AdDto ad, {
    Object? contactError,
    Brightness brightness = Brightness.light,
  }) async {
    final _StubAdRepository repository = _StubAdRepository(
      ad,
      contactError: contactError,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adRepositoryProvider.overrideWithValue(repository),
          authProvider.overrideWith((ref) => _StubAuthNotifier(ref)),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(brightness),
          home: AdDetailPage(teamSlug: ad.team.slug, adSlug: ad.slug),
        ),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    return repository;
  }

  group('localisation', () {
    testWidgets('une annonce géolocalisée rend un secteur et le dit', (
      WidgetTester tester,
    ) async {
      await openAd(
        tester,
        fixtureAd(
          locationDescription: 'Lille',
          locationGeometry: const AdDtoLocationGeometry(
            type: AdDtoLocationGeometryTypeType.point,
            coordinates: <double>[3.0573, 50.6292],
          ),
        ),
      );

      expect(find.byType(AdLocationMap), findsOneWidget);
      expect(find.textContaining('Localisation approximative'), findsOneWidget);
    });

    testWidgets('sans géométrie, aucune carte — et le lieu écrit reste', (
      WidgetTester tester,
    ) async {
      await openAd(tester, fixtureAd(locationDescription: 'Lille'));

      expect(find.byType(AdLocationMap), findsNothing);
      expect(find.textContaining('Localisation approximative'), findsNothing);
      expect(find.text('Lille'), findsOneWidget);
    });
  });

  group('contacter le vendeur', () {
    testWidgets('le bouton est absent de sa propre annonce', (
      WidgetTester tester,
    ) async {
      await openAd(tester, fixtureAd(createdById: 'u-me'));
      expect(find.text('Répondre à l\'annonce'), findsNothing);
    });

    testWidgets('le bouton est là sur l\'annonce d\'un autre', (
      WidgetTester tester,
    ) async {
      await openAd(tester, fixtureAd(createdById: 'u-autre'));
      expect(find.text('Répondre à l\'annonce'), findsOneWidget);
    });

    testWidgets('l\'envoi est coupé sous dix caractères, ouvert au-delà', (
      WidgetTester tester,
    ) async {
      await openAd(tester, fixtureAd(createdById: 'u-autre'));
      await tester.tap(find.text('Répondre à l\'annonce'));
      await tester.pumpAndSettle();

      expect(find.textContaining('elle lui sera donc visible'), findsOneWidget);
      PdlButton send() =>
          tester.widget<PdlButton>(find.widgetWithText(PdlButton, 'Envoyer'));
      expect(send().enabled, isFalse);

      await tester.enterText(find.byType(TextField), 'court');
      await tester.pump();
      expect(send().enabled, isFalse);

      await tester.enterText(find.byType(TextField), 'Bonjour, votre vélo ?');
      await tester.pump();
      expect(send().enabled, isTrue);
      expect(find.textContaining('/ 2000'), findsOneWidget);
    });

    testWidgets('un 500 est un échec franc, et le brouillon survit', (
      WidgetTester tester,
    ) async {
      final _StubAdRepository repository = await openAd(
        tester,
        fixtureAd(createdById: 'u-autre'),
        contactError: _apiError('AD_CONTACT_DELIVERY_FAILED', status: 500),
      );
      await tester.tap(find.text('Répondre à l\'annonce'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Bonjour, votre vélo ?');
      await tester.pump();
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();

      expect(repository.contacts, 1);
      // Ni fermeture, ni confirmation : l'échec est nommé, la feuille reste.
      expect(find.textContaining('n\'est pas parti'), findsOneWidget);
      expect(
        find.text(
          'Message envoyé, la réponse vous arrivera directement par e-mail.',
        ),
        findsNothing,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'Bonjour, votre vélo ?',
      );
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('un 429 traduit le Retry-After en délai lisible', (
      WidgetTester tester,
    ) async {
      await openAd(
        tester,
        fixtureAd(createdById: 'u-autre'),
        contactError: _apiError(
          'AD_CONTACT_RATE_LIMITED',
          status: 429,
          headers: <String, List<String>>{
            'retry-after': <String>['2700'],
          },
        ),
      );
      await tester.tap(find.text('Répondre à l\'annonce'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Bonjour, votre vélo ?');
      await tester.pump();
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('45 minutes'), findsOneWidget);
    });

    testWidgets('un opt-out ferme la feuille et retire le bouton', (
      WidgetTester tester,
    ) async {
      await openAd(
        tester,
        fixtureAd(createdById: 'u-autre'),
        contactError: _apiError('AD_CONTACT_OPTED_OUT'),
      );
      await tester.tap(find.text('Répondre à l\'annonce'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Bonjour, votre vélo ?');
      await tester.pump();
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.text('Répondre à l\'annonce'), findsNothing);
      expect(
        find.text('Cette annonce ne reçoit pas de messages.'),
        findsOneWidget,
      );
    });

    testWidgets('un 204 confirme, et ne le fait qu\'après le serveur', (
      WidgetTester tester,
    ) async {
      final _StubAdRepository repository = await openAd(
        tester,
        fixtureAd(createdById: 'u-autre'),
      );
      await tester.tap(find.text('Répondre à l\'annonce'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Bonjour, votre vélo ?');
      await tester.pump();
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();

      expect(repository.lastMessage, 'Bonjour, votre vélo ?');
      expect(
        find.text(
          'Message envoyé, la réponse vous arrivera directement par e-mail.',
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('le mode sombre rend le même écran', (WidgetTester tester) async {
    await openAd(
      tester,
      fixtureAd(createdById: 'u-autre'),
      brightness: Brightness.dark,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Vélo à vendre'), findsOneWidget);
  });
}

/// Un utilisateur connecté, sans toucher au stockage sécurisé ni au réseau.
///
/// `AuthNotifier` exige un dépôt, un stockage et un `Ref` ; aucun n'est
/// sollicité par ce que l'écran lit — l'identifiant de l'utilisateur courant.
class _FakeAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSecureStorage implements SecureTokenStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubAuthNotifier extends AuthNotifier {
  _StubAuthNotifier(Ref ref)
    : super(_FakeAuthRepository(), _FakeSecureStorage(), ref) {
    state = _signedIn;
  }
}
