import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../keys.dart';
import '../../../../core/widgets/zone_mention_line.dart';

/// La couleur d'un événement de calendrier.
///
/// **Une seule couleur d'étape** (§3.2) : celle de `PublicationType.trip`
/// (`#12b886` clair / `#099268` sombre). Le `#40c057` que la maquette employait
/// aussi reste réservé au marqueur de départ cartographique — deux verts
/// voisins sur deux plans différents ne se distinguent pas.
Color calendarEventColor(PdlColors c, String type) => switch (type) {
  'RIDE' => PublicationType.ride.tone(c).fill,
  'TRIP_STAGE' => PublicationType.trip.tone(c).fill,
  _ => c.neutral,
};

IconData calendarEventIcon(String type) => switch (type) {
  'RIDE' => PdlIcons.ride,
  'TRIP_STAGE' => PdlIcons.trip,
  _ => PdlIcons.date,
};

/// Où mène un événement de calendrier : la sortie, ou l'étape de son voyage.
///
/// `null` pour un type inconnu, ou une étape sans `tripSlug` — la ligne n'est
/// alors pas tapable plutôt que de pousser une route qui n'existe pas. Partagé
/// par l'agenda du calendrier et « Cette semaine » de l'accueil.
VoidCallback? calendarEventTap(BuildContext context, CalendarEventDto event) {
  switch (event.type) {
    case 'RIDE':
      return () => context.push(Paths.ride(event.teamSlug, event.entitySlug));
    case 'TRIP_STAGE':
      final String? tripSlug = event.tripSlug;
      if (tripSlug == null) return null;
      return () =>
          context.push(Paths.stage(event.teamSlug, tripSlug, event.entitySlug));
    default:
      return null;
  }
}

/// L'en-tête d'un jour de l'agenda (ledger `MOB-115`) : « Aujourd'hui ·
/// samedi 12 avril », « Demain · dimanche 13 avril », « lundi 14 avril » —
/// le jour de semaine toujours, le relatif seulement pour aujourd'hui et
/// demain (BRANDING §8.3).
///
/// [day] est un jour **du lecteur** — la grille et le regroupement le sont —,
/// comparé à [now] (maintenant, dans le fuseau du lecteur, par défaut).
String calendarDayLabel(DateTime day, {DateTime? now}) {
  final DateTime today = now ?? AppFormatters.displayNow();
  final int gap = DateTime.utc(
    day.year,
    day.month,
    day.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  final String date = AppFormatters.formatFullDate(day);
  return switch (gap) {
    0 => '${AppFormatters.today} · $date',
    1 => '${AppFormatters.tomorrow} · $date',
    _ => date,
  };
}

/// Une ligne d'agenda — la carte de ~92 px de l'écran 22.
///
/// **Elle ne déclenche aucun appel.** Tout ce qu'elle rend — le lieu, la
/// distance, le D+, le groupe rejoint, le statut — vient de l'unique
/// `GET /api/calendar/events` du mois. C'est le gain principal de l'écran, et
/// il se perd à la première lecture qui rappellerait l'API depuis ici.
class AgendaCard extends ConsumerWidget {
  const AgendaCard({super.key, required this.event});

  final CalendarEventDto event;

  /// L'heure de l'événement dans le fuseau de son entité — un rendez-vous
  /// (docs/LEDGER_*.md API-60). La grille et le regroupement par jour, eux,
  /// restent au fuseau du lecteur (`CalendarMonth.dayOf`), sauf la date
  /// d'une journée entière, qui reste celle de son fuseau.
  DateTime get _start =>
      AppFormatters.toZoneTime(DateTime.parse(event.start), event.timezone);

  /// Dit par le serveur (`docs/LEDGER_*.md API-16`) : fin de l'événement, ou
  /// son début quand il n'a pas de fin.
  bool get _isPast => event.finished;

  bool get _isCancelled => event.status == 'CANCELLED';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);
    final Color accent = calendarEventColor(c, event.type);

    // L'heure en tête et en gras (ledger `MOB-115`, BRANDING §7.8) : au
    // milieu de « Équipe · 08:30 · Lieu », c'était elle que l'ellipse
    // mangeait. Elle n'est plus jamais tronquée ; l'équipe et le lieu, si.
    final String? time = event.allDay ? null : AppFormatters.formatTime(_start);
    final String meta = <String>[
      event.teamName,
      if (event.startPlaceName != null && event.startPlaceName!.isNotEmpty)
        event.startPlaceName!,
    ].join(' · ');

    final List<PdlStat> stats = <PdlStat>[
      if (event.distance != null)
        PdlStat(
          icon: PdlIcons.distance,
          value: AppFormatters.formatDistance(event.distance!, units),
        ),
      if (event.elevationGain != null)
        PdlStat(
          icon: PdlIcons.elevationUp,
          value: AppFormatters.formatElevation(event.elevationGain!, units),
        ),
    ];

    final Widget card = PdlCard(
      key: keys.calendar.agendaCard(event.entitySlug),
      padding: PdlCardPadding.none,
      onTap: calendarEventTap(context, event),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Le filet porte la couleur du type : c'est lui qui relie la carte
            // au point de la grille, et à la légende.
            Container(width: 4, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(PdlSpacing.cardTight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          calendarEventIcon(event.type),
                          size: 16,
                          color: accent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.cardTitle.copyWith(color: c.text),
                          ),
                        ),
                        Icon(
                          PdlIcons.chevronRight,
                          size: 18,
                          color: c.textDimmed,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        if (time != null) ...<Widget>[
                          Text(
                            time,
                            maxLines: 1,
                            softWrap: false,
                            style: t.sub.copyWith(
                              fontWeight: FontWeight.w700,
                              color: c.text,
                            ),
                          ),
                          if (meta.isNotEmpty) Text(' · ', style: t.sub),
                        ],
                        Expanded(
                          child: Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.sub,
                          ),
                        ),
                      ],
                    ),
                    if (!event.allDay)
                      ?ZoneMentionLine.maybe(event.start, event.timezone),
                    if (stats.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      PdlStatRow(stats: stats),
                    ],
                    if (_badges(c).isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: PdlSpacing.badgeGap,
                        runSpacing: PdlSpacing.badgeGap,
                        children: _badges(c),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Le passé s'efface sans disparaître : un mois se lit d'un bloc, et une
    // sortie d'avant-hier reste une information.
    return _isPast ? Opacity(opacity: 0.55, child: card) : card;
  }

  List<Widget> _badges(PdlColors c) => <Widget>[
    if (event.registered)
      PdlBadge(
        key: keys.calendar.agendaRegisteredBadge(event.entitySlug),
        // « Inscrit · Chill route long » : le groupe rejoint est la moitié
        // utile de l'information, et `groupName` la porte depuis la 1.5.0.
        label: event.groupName == null
            ? 'rides.registered'.tr()
            : 'rides.registeredIn'.tr(
                namedArgs: <String, String>{'group': event.groupName!},
              ),
        icon: PdlIcons.check,
        tone: PdlDerivedTones.registered(c),
      ),
    // Oublié par la maquette, ajouté depuis `CalendarEventDto.status` (§3.2) :
    // une sortie annulée qui se rend comme les autres est un rendez-vous
    // manqué.
    if (_isCancelled)
      PdlBadge(
        label: 'calendar.cancelled'.tr(),
        icon: PdlIcons.cancelled,
        tone: Status.cancelled.tone(c),
      ),
  ];
}
