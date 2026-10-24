import 'package:flutter/material.dart';

import 'routes_page.dart';

/// Cross-team route library, as a list — the Explorer tab's other view, its
/// root being the map ([AllRoutesMapPage], docs/LEDGER_*.md WEB-114).
///
/// C'est le **même écran** que la section Parcours d'une équipe, à la portée
/// près : ici elle est libre et le sélecteur de portée s'affiche.
class AllRoutesPage extends StatelessWidget {
  const AllRoutesPage({super.key});

  @override
  Widget build(BuildContext context) => const RoutesPage(teamSlug: null);
}
