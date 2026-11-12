import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/day_box.dart';
import '../../../../core/widgets/zone_mention_line.dart';
import '../../../../keys.dart';
import '../../../calendar/presentation/widgets/agenda_card.dart';
import '../../../rides/presentation/widgets/ride_meta_line.dart';
import '../../providers/next_ride_provider.dart';
import '../../providers/week_events_provider.dart';

/// Combien de lignes « Cette semaine » montre au plus ; le reste est au
/// calendrier.
const int kWeekAgendaLimit = 5;

/// « Cette semaine » — l'agenda des sept prochains jours, toutes équipes.
///
/// La sortie que « Ma prochaine sortie » montre déjà en grand n'est **pas**
/// répétée ici : la maquette la retire, et deux fois la même ligne l'une sous
/// l'autre ne dit rien de plus.
///
/// Un échec masque le bloc ; une semaine vide le réduit à une carte compacte
/// qui mène au calendrier.
class WeekAgendaSection extends ConsumerWidget {
  const WeekAgendaSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<CalendarEventDto>> week = ref.watch(
      weekEventsProvider,
    );
    final RideDto? nextRide = ref.watch(nextRideProvider).value?.ride;

    return week.when(
      loading: () => _frame(
        context,
        const PdlSkeletonCard(variant: PdlSkeletonCardVariant.compact),
      ),
      error: (Object error, StackTrace stack) => const SizedBox.shrink(),
      data: (List<CalendarEventDto> all) {
        final List<CalendarEventDto> events = <CalendarEventDto>[
          for (final CalendarEventDto e in all)
            if (!_isNextRide(e, nextRide)) e,
        ];
        if (events.isEmpty) {
          // Only the next ride this week: it sits right above, so « nothing else ».
          return _frame(context, _WeekEmpty(nothingElse: all.isNotEmpty));
        }

        final List<CalendarEventDto> shown = events
            .take(kWeekAgendaLimit)
            .toList();
        final int hidden = events.length - shown.length;
        return _frame(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final CalendarEventDto e in shown) ...<Widget>[
                WeekAgendaRow(key: keys.home.weekEvent(e.entitySlug), event: e),
                const SizedBox(height: PdlSpacing.feedGap),
              ],
              if (hidden > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: PdlButton(
                    label: 'home.week.more'.plural(hidden),
                    variant: PdlButtonVariant.text,
                    size: PdlButtonSize.sm,
                    onPressed: () => context.go(Paths.calendar()),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static bool _isNextRide(CalendarEventDto e, RideDto? ride) =>
      ride != null &&
      e.type == 'RIDE' &&
      e.teamSlug == ride.team.slug &&
      e.entitySlug == ride.slug;

  Widget _frame(BuildContext context, Widget body) => Padding(
    key: keys.home.weekSection,
    padding: const EdgeInsets.fromLTRB(
      PdlSpacing.section,
      0,
      PdlSpacing.section,
      PdlSpacing.section,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PdlSectionHeader(
          title: 'home.week.title'.tr(),
          action: PdlButton(
            label: 'home.week.calendar'.tr(),
            variant: PdlButtonVariant.text,
            size: PdlButtonSize.sm,
            onPressed: () => context.go(Paths.calendar()),
          ),
        ),
        body,
      ],
    ),
  );
}

class _WeekEmpty extends StatelessWidget {
  const _WeekEmpty({required this.nothingElse});

  final bool nothingElse;

  @override
  Widget build(BuildContext context) {
    return PdlCard(
      key: keys.home.weekEmpty,
      flat: true,
      child: Row(
        children: <Widget>[
          Icon(PdlIcons.date, size: 24, color: context.pdl.textDimmed),
          const SizedBox(width: PdlSpacing.cardTight),
          Expanded(
            child: Text(
              (nothingElse ? 'home.week.nothingElse' : 'home.week.empty').tr(),
              style: context.pdlText.body,
            ),
          ),
        ],
      ),
    );
  }
}

/// Une ligne de « Cette semaine » : le jour en vignette, le titre, l'heure et
/// l'équipe. Tout vient de l'événement de calendrier, **sans appel**.
class WeekAgendaRow extends StatelessWidget {
  const WeekAgendaRow({super.key, required this.event});

  final CalendarEventDto event;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    // Le jour et l'heure de l'événement dans le fuseau de son entité, pour
    // que la vignette et l'heure disent le même jour ; la mention porte celui
    // du lecteur quand il diffère (docs/LEDGER_*.md API-60). La semaine
    // elle-même reste celle du lecteur (`weekEventsProvider`).
    final DateTime start = AppFormatters.toZoneTime(
      DateTime.parse(event.start),
      event.timezone,
    );
    final PublicationType type = event.type == 'TRIP_STAGE'
        ? PublicationType.trip
        : PublicationType.ride;
    final PdlTone tone = type.tone(c);
    final bool cancelled = event.status == 'CANCELLED';
    // Un brouillon le dit, comme dans le fil (docs/LEDGER_*.md MOB-139, N6).
    final bool draft = event.status == 'DRAFT';

    // L'heure est celle du groupe rejoint (BRANDING §7.8) : la ligne le
    // nomme, comme le site (ledger `MOB-139`, D8) — « Groupe B » par
    // `groupLabel`, et c'est l'équipe qui cède (décision du 2026-11-12).
    final Widget meta = RideMetaLine(
      key: keys.home.weekMeta(event.entitySlug),
      time: event.allDay ? null : AppFormatters.formatTime(start),
      teamName: event.teamName,
      groupName: event.groupName,
      style: t.sub,
    );

    return PdlCard(
      padding: PdlCardPadding.tight,
      onTap: calendarEventTap(context, event),
      child: Row(
        children: <Widget>[
          // Le jour en vignette compacte, dans la teinte de son type (sortie ou
          // étape), la même que le calendrier.
          dayBoxFor(start, tone: tone, size: PdlDayBoxSize.compact),
          const SizedBox(width: PdlSpacing.cardTight),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.cardTitle.copyWith(color: c.text),
                ),
                const SizedBox(height: 2),
                meta,
                if (!event.allDay)
                  ?ZoneMentionLine.maybe(event.start, event.timezone),
                if (event.registered || cancelled || draft) ...<Widget>[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: PdlSpacing.badgeGap,
                    runSpacing: PdlSpacing.badgeGap,
                    // L'ordre des cartes (règle R1, KIT §9) : un état,
                    // puis J'y vais.
                    children: <Widget>[
                      if (cancelled)
                        PdlBadge(
                          label: 'calendar.cancelled'.tr(),
                          icon: PdlIcons.cancelled,
                          tone: Status.cancelled.tone(c),
                        )
                      else if (draft)
                        PdlBadge(
                          key: keys.home.weekDraftBadge(event.entitySlug),
                          label: 'status.draft'.tr(),
                          tone: Status.draft.tone(c),
                        ),
                      if (event.registered)
                        PdlBadge(
                          key: keys.home.weekRegisteredBadge(event.entitySlug),
                          label: 'rides.registered'.tr(),
                          icon: PdlIcons.check,
                          tone: PdlDerivedTones.registered(c),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Icon(PdlIcons.chevronRight, size: 18, color: c.textDimmed),
        ],
      ),
    );
  }
}
