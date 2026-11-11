import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../../posts/presentation/pages/post_detail_page.dart';
import '../../rides/providers/ride_detail_provider.dart';
import '../../routes/providers/route_detail_provider.dart';
import '../../trips/providers/trip_detail_provider.dart';

/// Les détails d'entité qui portent un bloc `permissions` calculé pour le rôle
/// de l'appelant (docs/LEDGER_*.md MOB-137) : s'inscrire, commenter, voir les
/// noms. Rejoindre ou quitter une équipe, ou accepter une invitation, change ce
/// rôle ; un détail gardé en cache garderait les droits d'avant — un bouton
/// « Rejoindre » que le serveur refuse, ou un membre tout neuf sans composeur.
///
/// Les familles entières : la plupart n'ont personne à l'écoute, et une
/// famille invalidée sans auditeur ne refait son appel qu'à la prochaine
/// lecture.
final List<ProviderOrFamily> kMembershipScopedProviders = <ProviderOrFamily>[
  rideDetailProvider,
  tripDetailProvider,
  postDetailProvider,
  routeDetailProvider,
];

/// Invalide [kMembershipScopedProviders] — `ref.invalidate` d'un `Ref` comme
/// d'un `WidgetRef`.
void invalidateMembershipScopedContent(
  void Function(ProviderOrFamily provider) invalidate,
) {
  for (final ProviderOrFamily provider in kMembershipScopedProviders) {
    invalidate(provider);
  }
}
