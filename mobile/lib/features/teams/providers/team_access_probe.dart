import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import 'team_providers.dart';

/// L'appelant peut-il consulter l'équipe [teamSlug] (`GET team` lui
/// répondrait-il) ? La question que `openDeepLink` pose avant d'empiler une
/// équipe sous la page d'une de ses entités.
typedef TeamAccessProbe = Future<bool> Function(String teamSlug);

/// Le plus long qu'un lien profond attend pour savoir si l'équipe se consulte.
/// Au-delà, la pile complète : un réseau lent ne retarde pas l'ouverture plus
/// que cela, et l'écran de détail reste juste.
const Duration kTeamAccessProbeTimeout = Duration(seconds: 4);

/// `GET team` a **refusé** l'équipe à l'appelant : 403, ou 404 — une équipe
/// privée dont il n'est pas membre répond comme une équipe qui n'existe pas.
/// Un refus, pas une panne : l'écran qui le lit dit « réservé » plutôt
/// qu'« Erreur de chargement » et un « Réessayer » qui rendrait le même refus
/// (docs/LEDGER_*.md MOB-166).
bool isTeamAccessRefusal(Object error) {
  if (error is! DioException) return false;
  final int? status = error.response?.statusCode;
  return status == 404 || status == 403;
}

/// L'appelant peut-il consulter l'équipe [teamSlug] — `GET team` lui
/// répondrait-il ? La question que pose un lien profond avant de reconstruire
/// la page de l'équipe sous celle d'une de ses entités (docs/LEDGER_*.md
/// MOB-137) : c'est la définition même de `TeamPublicationDto.accessible`,
/// que l'entité n'apporte qu'une fois la pile construite.
///
/// Membre d'après « Mes équipes » : oui, sans appel. Sinon `GET team` par
/// [teamDetailProvider] — la page de l'équipe, reconstruite dessous, en
/// reprend la réponse sans second appel. 404 ou 403 : non. Tout autre échec
/// (hors ligne, délai dépassé) : oui, la pile d'avant ce lot — le doute ne
/// retire pas une page à qui pourrait la lire.
final teamAccessProbeProvider = Provider<TeamAccessProbe>(
  (Ref ref) => (String teamSlug) async {
    // Une liste **réglée** seulement : pendant un rechargement ou après un
    // échec, Riverpod garde la valeur précédente, celle de la session d'avant
    // un changement de compte. Dans le doute, la question part au serveur.
    final AsyncValue<List<TeamDetailDto>> myTeams = ref.read(myTeamsProvider);
    final List<TeamDetailDto>? mine = myTeams.isLoading || myTeams.hasError
        ? null
        : myTeams.value;
    if (mine != null && mine.any((TeamDetailDto t) => t.slug == teamSlug)) {
      return true;
    }
    try {
      await ref
          .read(teamDetailProvider(teamSlug).future)
          .timeout(kTeamAccessProbeTimeout);
      return true;
    } catch (error) {
      return !isTeamAccessRefusal(error);
    }
  },
);
