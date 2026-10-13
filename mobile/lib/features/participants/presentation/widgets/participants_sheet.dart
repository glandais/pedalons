import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../keys.dart';
import '../../domain/participant_query.dart';
import 'participant_list_view.dart';

/// La feuille « Participants » d'un groupe de sortie, d'une sortie entière ou
/// d'un voyage.
///
/// **Lue et cherchée côté serveur** (ledger `API-12`) : le détail n'embarque
/// que les premiers participants, de quoi dessiner des avatars. La feuille
/// lit la liste complète page par page, la recherche part au serveur, et le
/// pied dit « N participants sur M » — M étant le total que le serveur renvoie
/// avec la page.
class ParticipantsSheet extends ConsumerStatefulWidget {
  const ParticipantsSheet({
    super.key,
    required this.subtitle,
    required this.source,
    required this.count,
    this.organizerId,
    this.emptyMessageKey = 'participants.emptyMessage',
    this.team,
  });

  /// L'équipe de la sortie ou du voyage : c'est elle qui modère un membre
  /// signalé depuis cette liste. Sans elle, les lignes ne s'ouvrent pas.
  final TeamPublicationDto? team;

  /// Ce à quoi ces gens participent : le nom du groupe, ou celui du voyage.
  final String subtitle;

  /// De qui lister les participants.
  final ParticipantSource source;

  /// Le total affiché en pastille, connu du détail avant la première page.
  final int count;

  /// Le meneur **désigné**, quand il y en a un. `null` est le cas courant, et
  /// il n'y a jamais de repli sur `createdBy`.
  final String? organizerId;

  final String emptyMessageKey;

  /// Ouvre la feuille au-dessus de la barre d'onglets.
  ///
  /// `PdlSheet.show` force `useRootNavigator: true` : c'était l'unique cause de
  /// F-DE-8, où les feuilles s'ouvraient *dans* la branche de la coquille et
  /// passaient sous la barre.
  static Future<void> open(
    BuildContext context,
    RideDto ride,
    RideGroupDto group,
  ) {
    return PdlSheet.show<void>(
      context: context,
      builder: (BuildContext _) => ParticipantsSheet(
        subtitle: group.name,
        source: RideParticipantSource(
          teamSlug: ride.team.slug,
          rideSlug: ride.slug,
          groupId: group.id,
        ),
        count: group.countParticipants,
        organizerId: group.leader?.id,
        team: ride.team,
      ),
    );
  }

  /// La même feuille pour une sortie entière, tous groupes confondus.
  ///
  /// Le bouton « voir la liste » affiche le total de la sortie
  /// (`ride.participantCount`) : la feuille liste donc les participants de
  /// **chaque** groupe. `organizerId` reste nul — une sortie n'a pas de meneur
  /// unique, chaque groupe a le sien (ou aucun), et rien ne justifie d'en
  /// mettre un en avant ici.
  static Future<void> openRide(BuildContext context, RideDto ride) {
    return PdlSheet.show<void>(
      context: context,
      builder: (BuildContext _) => ParticipantsSheet(
        subtitle: ride.name,
        source: RideParticipantSource(
          teamSlug: ride.team.slug,
          rideSlug: ride.slug,
        ),
        count: ride.participantCount,
        team: ride.team,
      ),
    );
  }

  /// La même feuille pour un voyage : pas de meneur, pas de groupe.
  static Future<void> openTrip(BuildContext context, TripDto trip) {
    return PdlSheet.show<void>(
      context: context,
      builder: (BuildContext _) => ParticipantsSheet(
        subtitle: trip.name,
        source: TripParticipantSource(
          teamSlug: trip.team.slug,
          tripSlug: trip.slug,
        ),
        count: trip.participantCount,
        emptyMessageKey: 'participants.emptyTripMessage',
        team: trip.team,
      ),
    );
  }

  @override
  ConsumerState<ParticipantsSheet> createState() => _ParticipantsSheetState();
}

class _ParticipantsSheetState extends ConsumerState<ParticipantsSheet> {
  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    return PdlSheet(
      header: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('participants.title'.tr(), style: t.sectionTitle),
                Text(
                  widget.subtitle,
                  style: t.xs,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          PdlBadge(
            key: keys.participants.count,
            label: '${widget.count}',
            tone: PdlDerivedTones.registered(c),
            size: PdlBadgeSize.lg,
          ),
        ],
      ),
      children: <Widget>[
        ParticipantListView(
          source: widget.source,
          count: widget.count,
          organizerId: widget.organizerId,
          emptyMessageKey: widget.emptyMessageKey,
          team: widget.team,
        ),
      ],
    );
  }
}
