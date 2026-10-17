import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../api/generated/export.dart';
import '../../../core/pagination/pagination.dart';
import '../../teams/providers/team_dashboard_provider.dart';
import '../data/ride_template_repository.dart';

/// La clé d'une liste de modèles : l'équipe et la recherche en cours.
typedef RideTemplateListKey = ({String teamSlug, String? search});

/// La clé du détail d'un modèle.
typedef RideTemplateKey = ({String teamSlug, String templateSlug});

/// Les modèles de sortie d'une équipe, page par page, pour une recherche
/// donnée (ledger `MOB-78`). Changer la recherche change la clé : un nouveau
/// notifier, jamais deux résultats mêlés.
final rideTemplateListProvider = StateNotifierProvider.autoDispose
    .family<
      RideTemplateListNotifier,
      PagedListState<RideTemplateDto>,
      RideTemplateListKey
    >((ref, key) {
      return RideTemplateListNotifier(
        ref.watch(rideTemplateRepositoryProvider),
        key,
      );
    });

class RideTemplateListNotifier extends PagedListNotifier<RideTemplateDto> {
  RideTemplateListNotifier(this._repository, this._key);

  final RideTemplateRepository _repository;
  final RideTemplateListKey _key;

  @override
  Future<PageResult<RideTemplateDto>> fetchPage(int page) {
    return _repository.list(
      _key.teamSlug,
      search: _key.search,
      page: page,
      size: pageSize,
    );
  }

  @override
  Object? itemKey(RideTemplateDto item) => item.id;
}

/// Un modèle, lu pour l'éditer. Le serveur ne le sert qu'aux organisateurs :
/// l'écran tranche le refus **avant** de l'écouter.
final rideTemplateDetailProvider = FutureProvider.autoDispose
    .family<RideTemplateDto, RideTemplateKey>((ref, key) {
      return ref
          .watch(rideTemplateRepositoryProvider)
          .get(key.teamSlug, key.templateSlug);
    });

/// **Le** point où l'app dit « un modèle de sortie vient de changer » — créé,
/// réécrit ou supprimé (docs/LEDGER_*.md MOB-78).
///
/// Les listes (toutes les recherches), les détails et le tableau de bord, qui
/// porte « Créer depuis un modèle », sont invalidés ici. Invalider un provider
/// que personne n'écoute ne coûte rien. Le sens inverse — une sortie créée
/// depuis un modèle en avance le numéro — est dans `notifyRideChanged`.
///
/// Prend le **conteneur**, pas un `WidgetRef` : l'écriture est une requête, et
/// l'écran qui l'a lancée peut être quitté avant sa réponse. Le `WidgetRef`
/// d'un widget démonté lève une `StateError` ; le conteneur, pris avant le
/// premier `await` (`ProviderScope.containerOf(context, listen: false)`),
/// survit à l'écran et l'invalidation n'est jamais perdue.
void notifyRideTemplatesChanged(ProviderContainer container) {
  container.invalidate(rideTemplateListProvider);
  container.invalidate(rideTemplateDetailProvider);
  container.invalidate(teamDashboardProvider);
}
