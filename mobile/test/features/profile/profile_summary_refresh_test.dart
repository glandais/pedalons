import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/features/profile/presentation/widgets/profile_subpage.dart';
import 'package:pedalons/features/profile/providers/profile_summary_provider.dart';

/// Le résumé du profil est relu quand une sous-page se ferme — y compris une
/// sous-page ouverte par un lien froid, que la vue d'ensemble n'a pas poussée.
void main() {
  testWidgets(
    'une sous-page ouverte par lien froid puis fermée par pop relit le résumé',
    (WidgetTester tester) async {
      int loads = 0;
      final GoRouter router = GoRouter(
        initialLocation: '/profil/securite',
        routes: <RouteBase>[
          GoRoute(
            path: '/profil',
            builder: (BuildContext context, GoRouterState state) => Consumer(
              builder: (BuildContext context, WidgetRef ref, _) {
                ref.watch(profileSummaryProvider);
                return const Text('vue d\'ensemble');
              },
            ),
            routes: <RouteBase>[
              GoRoute(
                path: 'securite',
                builder: (BuildContext context, GoRouterState state) =>
                    const ProfileSummaryRefreshOnLeave(
                      child: Text('sous-page'),
                    ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileSummaryProvider.overrideWith((ref) async {
              loads++;
              return null as ProfileSummaryDto?;
            }),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Le lien froid a posé la vue d'ensemble dessous : elle a lu le résumé.
      expect(find.text('sous-page'), findsOneWidget);
      expect(loads, 1);

      router.pop();
      await tester.pumpAndSettle();

      expect(find.text('vue d\'ensemble'), findsOneWidget);
      expect(loads, 2);
    },
  );
}
