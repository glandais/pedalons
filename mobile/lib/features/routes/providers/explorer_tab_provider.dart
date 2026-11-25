import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Les deux onglets d'Explorer : la parcothèque de toutes les équipes, et les
/// outils GPX, qui ne relèvent d'aucune équipe (docs/LEDGER_*.md MOB-192).
enum ExplorerTab { routes, gpxTools }

/// L'onglet d'Explorer ouvert. Il tient le temps de la session : revenir sur
/// Explorer depuis un autre onglet, ou depuis la fiche d'un fichier, retrouve
/// celui qu'on avait quitté ; l'app relancée rouvre sur les parcours.
final explorerTabProvider = NotifierProvider<ExplorerTabNotifier, ExplorerTab>(
  ExplorerTabNotifier.new,
);

class ExplorerTabNotifier extends Notifier<ExplorerTab> {
  @override
  ExplorerTab build() => ExplorerTab.routes;

  void select(ExplorerTab tab) => state = tab;
}
