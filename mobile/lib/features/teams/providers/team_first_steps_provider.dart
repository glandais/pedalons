import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';
import '../data/team_invitations_repository.dart';
import 'team_dashboard_provider.dart';

/// Ce que les « Premières étapes » d'une équipe ont déjà fait
/// (docs/LEDGER_*.md WEB-195). Une étape vaut `null` quand elle ne s'applique
/// pas : l'invitation quand l'équipe n'invite pas par e-mail, la sortie sans
/// les modules sorties et parcours (une sortie se crée sur un parcours), le
/// parcours sans le module parcours.
class FirstStepsState {
  const FirstStepsState({this.invite, this.ride, this.route});

  final bool? invite;
  final bool? ride;
  final bool? route;
}

/// Les « Premières étapes » de [slug] pour qui l'administre, `null` pour tout
/// autre (le tableau de bord ne porte son bloc `admin` qu'à un administrateur).
///
/// Rien n'est stocké : chaque étape lit l'équipe telle qu'elle est — un second
/// membre ou une invitation en attente, une sortie (même passée ou en
/// brouillon), un parcours. Les deux appels de plus ne partent que si le
/// tableau de bord ne répond pas déjà : une seule personne dans l'équipe,
/// aucune sortie à venir. Même règle que le site (`firstStepsReads`).
final teamFirstStepsProvider = FutureProvider.autoDispose
    .family<FirstStepsState?, String>((Ref ref, String slug) async {
      final TeamDashboardDto dashboard = await ref.watch(
        teamDashboardProvider(slug).future,
      );
      if (dashboard.admin == null) return null;
      final TeamDetailDto team = dashboard.team;

      final bool askInvitations =
          team.addMemberAllowed && team.memberCount <= 1;
      final bool ridesApply = team.enableRides && team.enableRoutes;
      final bool askRides = ridesApply && team.upcomingRideCount == 0;

      final List<Object?> answers = await Future.wait<Object?>(
        <Future<Object?>>[
          askInvitations
              ? ref.read(teamInvitationsRepositoryProvider).listPending(slug)
              : Future<Object?>.value(),
          askRides
              ? ref
                    .read(publicationsClientProvider)
                    .countPublications(
                      teamSlug: slug,
                      type: PublicationType.ride,
                    )
              : Future<Object?>.value(),
        ],
      );
      final List<TeamInvitationDto>? pending =
          answers[0] as List<TeamInvitationDto>?;
      final CountResponse? rides = answers[1] as CountResponse?;

      return FirstStepsState(
        invite: team.addMemberAllowed
            ? team.memberCount > 1 || (pending?.isNotEmpty ?? false)
            : null,
        ride: ridesApply
            ? team.upcomingRideCount > 0 || (rides?.total ?? 0) > 0
            : null,
        route: team.enableRoutes ? team.routeCount > 0 : null,
      );
    });
