import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';
import '../domain/track_key.dart';

/// Ce que la retouche offre pour un parcours (docs/LEDGER_*.md MOB-185) :
/// `GET …/retouch`, demandé seulement à qui peut modifier le parcours.
/// Un échec ne montre rien — l'action est un plus, jamais une raison de
/// déranger la fiche : `null`.
final routeRetouchOfferProvider = FutureProvider.autoDispose
    .family<RouteRetouchOfferDto?, RouteKey>((Ref ref, RouteKey key) async {
      try {
        return await ref
            .watch(routeGeneratorClientProvider)
            .getRouteRetouchOffer(
              teamSlug: key.teamSlug,
              routeSlug: key.routeSlug,
            );
      } on Object {
        return null;
      }
    });
