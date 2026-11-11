// Les routes des pages de DEBUG : la galerie des composants et celle des
// cartes.
//
// `router.dart` ne les déclare que sous `kDebugMode`, une constante : en
// profil et en release la branche est éliminée à la compilation, et avec elle
// tout ce que ce fichier importe. Aucune n'est dans `contracts/routes.yaml` :
// elles n'ont ni variante de langue, ni lien universel, ni entrée de manifeste.
//
// - `/dev/composants` : `PdlGalleryPage` ;
// - `/dev/cartes`, `/dev/cartes/<section>` : `CardGalleryPage`.
//
// Elles s'ouvrent sans session (`isDevLocation`, lu par `isAuthAdjacent`), et
// au lancement avec `--dart-define=DEV_ROUTE=/dev/cartes/fil`.

import 'package:go_router/go_router.dart';

import 'card_gallery_page.dart';
import 'pdl_gallery_page.dart';

const String kDevComponentsPath = '/dev/composants';

/// Une adresse des pages de debug.
bool isDevLocation(String location) {
  final String path = Uri.tryParse(location)?.path ?? location;
  return path == '/dev' || path.startsWith('/dev/');
}

/// L'adresse à ouvrir au lancement, donnée par `--dart-define=DEV_ROUTE=…`.
String? devInitialPath() {
  const String path = String.fromEnvironment('DEV_ROUTE');
  return path.isEmpty ? null : path;
}

List<RouteBase> devRoutes() => <RouteBase>[
  GoRoute(path: kDevComponentsPath, builder: (_, _) => const PdlGalleryPage()),
  GoRoute(
    path: kCardGalleryPath,
    builder: (_, _) => const CardGalleryPage(),
    routes: <RouteBase>[
      GoRoute(
        path: ':section',
        builder: (_, GoRouterState state) =>
            CardGalleryPage(sectionId: state.pathParameters['section']),
      ),
    ],
  ),
];
