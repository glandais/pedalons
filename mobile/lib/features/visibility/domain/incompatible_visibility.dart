import 'package:dio/dio.dart';

import '../../../api/generated/export.dart';

/// Le code du refus d'une visibilité incompatible (plan
/// 2026-11-11-visibilite-contenu-equipe-privee §4.4).
const String kIncompatibleVisibilityCode = 'INCOMPATIBLE_VISIBILITY';

/// Ce que dit un refus `INCOMPATIBLE_VISIBILITY` : les parcours « Équipe »
/// d'une sortie ou d'un voyage enregistré hors de l'équipe ([routes]), ou les
/// sorties et voyages visibles hors de l'équipe qui utilisent un parcours
/// qu'on voulait passer en « Équipe » ([usages]). L'autre liste est vide.
typedef IncompatibleVisibility = ({
  List<IncompatibleRouteDto> routes,
  List<IncompatibleRouteUsageDto> usages,
});

/// Lit un refus `INCOMPATIBLE_VISIBILITY` dans [error], nul pour tout autre
/// échec. Un refus sans détail lisible (un backend plus ancien, un corps
/// tronqué) rend deux listes vides : le refus reste reconnu, et l'écran dit au
/// moins son message.
IncompatibleVisibility? incompatibleVisibilityOf(Object error) {
  if (error is! DioException) return null;
  final Object? data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;
  if (data['code'] != kIncompatibleVisibilityCode) return null;
  final Object? details = data['errorDetails'];
  if (details is Map<String, dynamic>) {
    try {
      final ErrorDetails parsed = ErrorDetails.fromJson(details);
      if (parsed is ErrorDetailsIncompatibleVisibility) {
        return (routes: parsed.routes, usages: parsed.usages);
      }
    } catch (_) {
      // Un détail illisible ne masque pas le refus lui-même.
    }
  }
  return (
    routes: const <IncompatibleRouteDto>[],
    usages: const <IncompatibleRouteUsageDto>[],
  );
}
