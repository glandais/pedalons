import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';
import '../../../core/pagination/pagination.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/gpx_preview_repository.dart';

/// Un aperçu des outils GPX, pour sa fiche (docs/LEDGER_*.md MOB-178).
///
/// Comme `routeDetailProvider` pour un parcours, **la seule source de la
/// fiche** : tracé, profil, points du parcours, départ. La carte et le profil
/// le lisent à travers `shownRouteProvider(GpxPreviewKey(id))`.
final gpxPreviewProvider = FutureProvider.family<GpxPreviewDto, String>((
  Ref ref,
  String previewId,
) {
  return ref.watch(gpxPreviewsClientProvider).getPreview(previewId: previewId);
});

/// La météo d'un aperçu daté : le cache du serveur seulement (le point
/// d'accès n'appelle jamais le fournisseur), que le planificateur remplit en
/// arrière-plan. `autoDispose` comme celle d'une sortie : une prévision
/// vieillit.
final gpxPreviewWeatherProvider = FutureProvider.autoDispose
    .family<RideWeatherDto, String>(
      (Ref ref, String previewId) =>
          ref.watch(gpxPreviewRepositoryProvider).weather(previewId),
    );

/// « Mes fichiers » : les aperçus encore disponibles de la personne, du plus
/// récent au plus ancien, page après page.
final myGpxPreviewsProvider =
    StateNotifierProvider.autoDispose<
      MyGpxPreviewsNotifier,
      PagedListState<GpxPreviewSummaryDto>
    >(
      (Ref ref) =>
          MyGpxPreviewsNotifier(ref.watch(gpxPreviewRepositoryProvider)),
    );

class MyGpxPreviewsNotifier extends PagedListNotifier<GpxPreviewSummaryDto> {
  MyGpxPreviewsNotifier(this._repository);

  final GpxPreviewRepository _repository;

  @override
  Future<PageResult<GpxPreviewSummaryDto>> fetchPage(int page) =>
      _repository.listMine(page: page, size: pageSize);

  @override
  Object? itemKey(GpxPreviewSummaryDto item) => item.id;
}

/// **Le** point où l'app dit « un aperçu vient de changer » — créé,
/// dupliqué, modifié ou supprimé : « Mes fichiers » se relit, et la fiche de
/// [previewId] et sa météo si elle est nommée. Le pendant de
/// `notifyRouteChanged`.
void notifyGpxPreviewChanged(WidgetRef ref, {String? previewId}) {
  ref.invalidate(myGpxPreviewsProvider);
  if (previewId != null) {
    ref.invalidate(gpxPreviewProvider(previewId));
    ref.invalidate(gpxPreviewWeatherProvider(previewId));
  }
}

/// Relit la personne connectée : son quota personnel des outils GPX
/// (`UserDto.plannerQuota`, `BILL-10`) vient de `/api/users/me`, et un tracé
/// dessiné enregistré l'a entamé. Un échec garde l'ancien : le serveur reste
/// l'autorité, et refuse un enregistrement de trop.
Future<void> refreshPlannerQuota(WidgetRef ref) async {
  try {
    final UserDto user = await ref.read(usersClientProvider).getMe();
    ref.read(authProvider.notifier).setUser(user);
  } catch (_) {}
}
