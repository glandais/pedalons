import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';

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
