import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../data/moderation_repository.dart';

/// Une file de modération : l'équipe, et l'onglet — à traiter, ou traités.
typedef TeamReportsKey = ({String teamSlug, ReportQueueStatus status});

/// La file de modération d'une équipe (docs/LEDGER_*.md MOB-168) : une entrée
/// par cible signalée, tous ses signalements regroupés. Le serveur la rend
/// d'un seul tenant, sans pagination.
///
/// Elle n'est lue que par l'écran « Signalements », une fois le droit
/// établi ; elle est relue après chaque décision
/// (`refreshAfterModerationDecision`).
final teamReportsProvider = FutureProvider.autoDispose
    .family<List<ModerationItemDto>, TeamReportsKey>(
      (Ref ref, TeamReportsKey key) => ref
          .watch(moderationRepositoryProvider)
          .listTeamReports(key.teamSlug, status: key.status),
    );
