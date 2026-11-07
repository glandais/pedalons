import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/day_box.dart';
import '../../../../core/widgets/zone_mention_line.dart';
import '../../domain/group_start.dart';
import '../../providers/ride_detail_provider.dart';

/// Le bloc de départ d'une sortie ou d'un de ses groupes (BRANDING §7.8,
/// ledgers `BRAND-8`, `MOB-113`), juste sous l'identité.
///
/// * **Sortie** ([group] nul) — le détail d'une sortie donne l'heure **de la
///   sortie** (décision `BRAND-8` ; ses cartes de groupe se situent par
///   rapport à elle), « sam. 12 avr. · retour vers 14:10 » d'après
///   `endDateTime`, et dessous « Votre groupe : B · 09:30 » quand la personne
///   est inscrite dans un groupe qui part à son heure propre.
/// * **Groupe** — la page d'un groupe donne l'heure **du groupe**, sa relation
///   à la sortie (« après la sortie de 09:00 ») quand elle en diffère, et
///   l'arrivée estimée de son leg météo ([arrival]) quand il y en a une :
///   `endDateTime` est la fin de la sortie entière, pas celle du groupe.
///
/// La mention de fuseau porte sur l'heure affichée.
class RideDepartureBlock extends StatelessWidget {
  const RideDepartureBlock({
    super.key,
    required this.ride,
    this.group,
    this.arrival,
    this.now,
  });

  final RideDto ride;

  /// Le groupe de la page ; nul sur le détail de la sortie.
  final RideGroupDto? group;

  /// « Arrivée estimée 13:10 », déjà formatée, pour un groupe.
  final String? arrival;

  /// Un instant, pour les tests ; maintenant sinon.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final String zone = ride.timezone;
    final RideGroupDto? group = this.group;
    final String iso = group?.startAt ?? ride.dateTime;
    final DateTime? instant = DateTime.tryParse(iso);
    if (instant == null) return const SizedBox.shrink();
    final DateTime wall = AppFormatters.toZoneTime(instant, zone);

    final String time = AppFormatters.formatTime(wall);
    final String headline = 'rides.departureBlock.departs'.tr(
      namedArgs: <String, String>{'time': time},
    );
    final String? relative = AppFormatters.formatDepartureRelative(
      instant,
      zone,
      now: now,
    );
    final String date = AppFormatters.formatDepartureDate(
      instant,
      zone,
      now: now,
    );

    final List<String> details;
    String? groupLine;
    if (group == null) {
      final DateTime? end = AppFormatters.tryParseZoneTime(
        ride.endDateTime,
        zone,
      );
      details = <String>[
        <String>[
          date,
          if (end != null)
            'rides.departureBlock.returnAround'.tr(
              namedArgs: <String, String>{
                'time': AppFormatters.formatTime(end),
              },
            ),
        ].join(' · '),
      ];
      final RideGroupDto? mine = ride.joinedGroup;
      if (mine != null && groupLeavesAtOwnTime(mine.startAt, ride.dateTime)) {
        groupLine = 'rides.departureBlock.yourGroup'.tr(
          namedArgs: <String, String>{
            'group': mine.name,
            'time': formatGroupStart(mine.startAt, zone),
          },
        );
      }
    } else {
      final GroupStartRelation relation = groupStartRelation(
        group.startAt,
        ride.dateTime,
      );
      details = <String>[
        <String>[date, ?arrival].join(' · '),
        if (relation != GroupStartRelation.same)
          'rides.departureBlock.relativeToRide'.tr(
            namedArgs: <String, String>{
              'relation': relation.labelKey.tr(),
              'rideTime': formatGroupStart(ride.dateTime, zone),
            },
          ),
      ];
    }

    final String? mention = AppFormatters.formatZoneMention(instant, zone);
    final String semanticLabel = <String>[
      headline,
      ?relative,
      ...details,
      ?mention,
      ?groupLine,
    ].join(', ');

    return PdlDepartureBlock(
      dayBox: dayBoxFor(wall),
      headline: headline,
      relativeLabel: relative,
      details: details,
      zoneMention: mention == null
          ? null
          : ZoneMentionLine(instant: instant, zone: zone),
      groupLine: groupLine,
      semanticLabel: semanticLabel,
    );
  }
}
