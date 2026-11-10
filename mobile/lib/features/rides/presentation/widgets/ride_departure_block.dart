import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/utils/directions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/day_box.dart';
import '../../../../core/widgets/zone_mention_line.dart';
import '../../../../keys.dart';
import '../../domain/group_start.dart';
import '../../providers/ride_detail_provider.dart';

/// Le bloc de départ d'une sortie ou d'un de ses groupes (BRANDING §7.8,
/// ledgers `BRAND-8`, `MOB-113`), juste sous l'identité.
///
/// * **Sortie** ([group] nul) — le détail d'une sortie à plusieurs groupes ou
///   sans groupe donne l'heure **de la sortie** (décision `BRAND-8`), « sam.
///   12 avr. », et dessous « Votre groupe : B · 09:30 » quand la personne est
///   inscrite dans un groupe qui part à son heure propre.
/// * **Groupe** — la page d'un groupe, et le détail d'une sortie solo
///   (SYNTHESE §6.1 : une seule heure sur l'écran, celle du groupe), donnent
///   l'heure **du groupe** et son arrivée estimée ([arrival],
///   `rideGroupArrivalLine`) quand il y en a une : `endDateTime` est la fin
///   de la sortie entière, pas celle du groupe.
///
/// La mention de fuseau porte sur l'heure affichée.
class RideDepartureBlock extends StatelessWidget {
  const RideDepartureBlock({
    super.key,
    required this.ride,
    this.group,
    this.arrival,
    this.trailing,
    this.places = const <Widget>[],
    this.footnote,
    this.now,
  });

  final RideDto ride;

  /// Le groupe de la page ; nul sur le détail de la sortie.
  final RideGroupDto? group;

  /// « Arrivée estimée 13:10 », déjà formatée, pour un groupe.
  final String? arrival;

  /// À droite de l'heure : le contrôle d'inscription
  /// (`RideRegistrationControl`, ledger `MOB-134`).
  final Widget? trailing;

  /// Les lieux de départ et d'arrivée, sous l'heure ([ridePlaceLinks]).
  final List<Widget> places;

  /// Une note atténuée au pied du bloc : « Sortie sans groupe, inscription
  /// impossible » (KIT §8, maquette `sortie-sans-groupe-mobile-cible`).
  final String? footnote;

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

    // La boîte du jour dit déjà la date, l'année comprise hors de l'année en
    // cours (BRANDING §7.8) : la ligne atténuée ne la répète pas. Le lecteur
    // d'écran, lui, la lit, la boîte étant muette.
    final List<String> details;
    String? groupLine;
    if (group == null) {
      details = const <String>[];
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
      details = <String>[?arrival];
    }

    final String? mention = AppFormatters.formatZoneMention(instant, zone);
    final String semanticLabel = <String>[
      headline,
      ?relative,
      date,
      ...details,
      ?mention,
      ?groupLine,
    ].join(', ');

    return PdlDepartureBlock(
      dayBox: dayBoxFor(wall, now: now),
      headline: headline,
      relativeLabel: relative,
      details: details,
      zoneMention: mention == null
          ? null
          : ZoneMentionLine(instant: instant, zone: zone),
      groupLine: groupLine,
      semanticLabel: semanticLabel,
      trailing: trailing,
      places: places,
      footnote: footnote,
    );
  }
}

/// Les lieux de départ (drapeau vert) et d'arrivée (drapeau rouge, s'il y en
/// a un) d'une sortie, en liens d'itinéraire (ledger `MOB-134`, KIT §8 :
/// « liens noirs soulignés qui ouvrent l'itinéraire »). Un lieu sans
/// coordonnées ni adresse reste un texte simple.
List<Widget> ridePlaceLinks(BuildContext context, RideDto ride) {
  Widget row(PlaceDetailDto place, PdlPlaceKind kind, Key key) {
    final bool opens = placeDirectionsUri(place) != null;
    return PdlPlaceRow.link(
      key: key,
      kind: kind,
      name: place.name,
      semanticLabel: 'common.directionsTo'.tr(
        namedArgs: <String, String>{'place': place.name},
      ),
      onTap: opens ? () => openPlaceDirections(context, place) : null,
    );
  }

  return <Widget>[
    if (ride.startPlace case final PlaceDetailDto start)
      row(start, PdlPlaceKind.start, keys.ride.startPlaceLink),
    if (ride.endPlace case final PlaceDetailDto end)
      row(end, PdlPlaceKind.end, keys.ride.endPlaceLink),
  ];
}
