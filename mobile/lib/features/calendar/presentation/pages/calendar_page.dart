import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/formatters.dart';
import '../../providers/calendar_month_provider.dart';
import '../widgets/agenda_card.dart';
import '../widgets/calendar_subscription_card.dart';
import '../widgets/calendar_toolbar.dart';
import '../../../feedback/presentation/report_problem_button.dart';

/// Hauteur maximale de la grille de mois, légende comprise. Elle se compresse
/// au défilement jusqu'à disparaître : sans cela, deux cartes d'agenda
/// seulement seraient visibles au premier paint (§3.2).
const double kCalendarGridMaxHeight = 334;

/// Le calendrier : un mois qu'on voit, un agenda qu'on lit.
///
/// L'ancienne page ne rendait qu'une liste par jour et sondait jusqu'à six mois
/// à l'ouverture pour trouver où se poser. Elle ouvre désormais **sur le mois
/// courant**, comme le veut §3.2 ; le sondage sert encore, mais à l'action
/// « Aller au prochain mois avec une sortie » de l'état vide, où il répond à
/// une question que l'utilisateur a posée.
class CalendarPage extends ConsumerStatefulWidget {
  final String? teamSlug;
  final bool embedded;

  /// Le type **piloté par l'appelant**, quand [onTypeChanged] est donné : la
  /// vue Calendrier de l'Agenda d'une équipe, qui garde son type d'une vue à
  /// l'autre (ledger `MOB-60`). Sans lui, `calendarTypeFilterProvider`.
  final CalendarTypeFilter? typeFilter;
  final ValueChanged<CalendarTypeFilter>? onTypeChanged;

  /// « Je participe » : seulement les événements où l'on est inscrit
  /// (`CalendarEventDto.registered`), filtrés en mémoire comme le type — l'API
  /// du calendrier n'a pas de paramètre pour cela.
  final bool registeredOnly;

  /// Lève « Je participe » depuis l'état vide filtré.
  final VoidCallback? onClearRegisteredOnly;

  /// Les types proposés en chips : tous par défaut, ceux des modules de
  /// l'équipe dans son Agenda (`agendaTypeOptions`, comme au site).
  final List<CalendarTypeFilter> typeOptions;

  const CalendarPage({
    super.key,
    this.teamSlug,
    this.embedded = false,
    this.typeFilter,
    this.onTypeChanged,
    this.registeredOnly = false,
    this.onClearRegisteredOnly,
    this.typeOptions = CalendarTypeFilter.values,
  });

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  final ItemScrollController _agendaController = ItemScrollController();

  /// 0 = grille pleine, 1 = grille repliée. Le défilement l'interpole, le
  /// chevron la force.
  double _collapse = 0;
  bool _pinnedCollapsed = false;

  /// Le mois pour lequel l'agenda a déjà été positionné : sans ce garde-fou,
  /// chaque cadre ramènerait la liste sur aujourd'hui.
  CalendarMonthKey? _positionedFor;

  @override
  Widget build(BuildContext context) {
    final CalendarMonthKey monthKey = ref.watch(
      calendarMonthKeyProvider(widget.teamSlug),
    );
    final CalendarTypeFilter typeFilter = widget.onTypeChanged != null
        ? widget.typeFilter ?? CalendarTypeFilter.all
        : ref.watch(calendarTypeFilterProvider);
    final AsyncValue<CalendarMonth> month = ref.watch(
      calendarMonthProvider(monthKey),
    );

    final Widget body = Column(
      children: <Widget>[
        Material(
          color: context.pdl.overlaySolid,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: PdlMetrics.toolbarPadding,
            ),
            child: CalendarToolbar(
              monthKey: monthKey,
              onMonthChanged: _setMonth,
              typeFilter: typeFilter,
              onTypeChanged: _setType,
              showScope: widget.teamSlug == null,
              // Sans app bar à elle, la section d'équipe perdrait le raccourci
              // « Aujourd'hui » : il descend alors dans la barre d'outils.
              onToday: widget.embedded ? _goToToday : null,
              typeOptions: widget.typeOptions,
            ),
          ),
        ),
        Divider(height: 1, color: context.pdl.borderSubtle),
        Expanded(
          child: month.when(
            data: (CalendarMonth loaded) => _content(
              monthKey,
              loaded.filtered(
                typeFilter,
                registeredOnly: widget.registeredOnly,
              ),
              typeFilter,
              monthHasEvents: !loaded.isEmpty,
            ),
            loading: _skeletons,
            error: (Object error, StackTrace stack) => Center(
              child: PdlEmptyState(
                variant: PdlEmptyVariant.error,
                title: 'common.loadError'.tr(),
                message: getErrorMessage(error),
                actions: <Widget>[
                  PdlButton(
                    label: 'common.retry'.tr(),
                    variant: PdlButtonVariant.outline,
                    size: PdlButtonSize.sm,
                    onPressed: () =>
                        ref.invalidate(calendarMonthProvider(monthKey)),
                  ),
                  ReportProblemButton(error: error, stackTrace: stack),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: PdlAppBar(
        title: 'calendar.title'.tr(),
        actions: <Widget>[
          PdlButton(
            variant: PdlButtonVariant.outline,
            size: PdlButtonSize.sm,
            pill: true,
            label: 'calendar.today'.tr(),
            onPressed: _goToToday,
          ),
        ],
      ),
      body: body,
    );
  }

  void _setType(CalendarTypeFilter next) {
    if (widget.onTypeChanged != null) {
      widget.onTypeChanged!(next);
    } else {
      ref.read(calendarTypeFilterProvider.notifier).state = next;
    }
  }

  // ── Contenu ───────────────────────────────────────────────────────────────

  Widget _content(
    CalendarMonthKey monthKey,
    CalendarMonth month,
    CalendarTypeFilter typeFilter, {
    required bool monthHasEvents,
  }) {
    final List<_AgendaEntry> entries = _compose(month);

    return Column(
      children: <Widget>[
        _grid(monthKey, month),
        Expanded(
          child: entries.isEmpty
              ? SingleChildScrollView(
                  child: Column(
                    children: <Widget>[
                      _emptyState(monthKey, typeFilter, monthHasEvents),
                      CalendarSubscriptionCard(teamSlug: widget.teamSlug),
                      const SizedBox(height: 32),
                    ],
                  ),
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: _onAgendaScroll,
                  child: ScrollablePositionedList.builder(
                    itemScrollController: _agendaController,
                    // La liste ne pose **pas** de marge latérale : le bloc
                    // d'abonnement, qui en est la dernière entrée, porte les
                    // siennes et les doublerait.
                    padding: const EdgeInsets.only(bottom: 32),
                    itemCount: entries.length + 1,
                    itemBuilder: (BuildContext context, int index) =>
                        index == entries.length
                        ? CalendarSubscriptionCard(teamSlug: widget.teamSlug)
                        : _entry(entries[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _entry(_AgendaEntry entry) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
    child: _entryBody(entry),
  );

  Widget _entryBody(_AgendaEntry entry) => switch (entry) {
    _DayHeaderEntry(:final DateTime day) => PdlDayHeader(label: _dayLabel(day)),
    _UpcomingSeparatorEntry() => Padding(
      padding: const EdgeInsets.only(top: PdlSpacing.section),
      child: PdlSectionHeader(
        title: 'calendar.upcoming'.tr(),
        padding: EdgeInsets.zero,
      ),
    ),
    _EventEntry(:final CalendarEventDto event) => Padding(
      padding: const EdgeInsets.only(bottom: PdlSpacing.feedGap),
      child: AgendaCard(event: event),
    ),
  };

  Widget _grid(CalendarMonthKey monthKey, CalendarMonth month) {
    final PdlColors c = context.pdl;
    final DateTime? selected = ref.watch(calendarSelectedDayProvider);
    final DateTime today = AppFormatters.displayNow();

    _schedulePositioning(monthKey, month, today);

    final double factor = (1 - _collapse).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: factor,
            child: Opacity(
              opacity: factor,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  PdlSpacing.section,
                  PdlSpacing.chipGap,
                  PdlSpacing.section,
                  0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    GestureDetector(
                      // `onHorizontalDragEnd`, pas `onPanUpdate` : un swipe
                      // est un geste ponctuel qui change de mois, pas un
                      // défilement continu — la grille n'a rien à suivre au
                      // doigt.
                      onHorizontalDragEnd: (DragEndDetails details) {
                        final double? velocity = details.primaryVelocity;
                        if (velocity == null ||
                            velocity.abs() < _swipeVelocityThreshold) {
                          return;
                        }
                        _setMonth(monthKey.shifted(velocity < 0 ? 1 : -1));
                      },
                      child: PdlMonthGrid(
                        year: monthKey.year,
                        month: monthKey.month,
                        weekdayLabels: _weekdayLabels(),
                        today: today,
                        selectedDay: selected,
                        onDayTap: (DateTime day) => _selectDay(day, month),
                        dotsOf: (DateTime day) => _dotsOf(c, month, day),
                        isRegistered: (DateTime day) =>
                            month.byDay[day]?.any(
                              (CalendarEventDto e) => e.registered,
                            ) ??
                            false,
                        daySemanticLabel: (DateTime day) =>
                            _daySemanticLabel(month, day),
                      ),
                    ),
                    const SizedBox(height: PdlSpacing.chipGap),
                    PdlLegendRow(
                      padding: EdgeInsets.zero,
                      entries: <PdlLegendEntry>[
                        PdlLegendEntry(
                          color: calendarEventColor(c, 'RIDE'),
                          label: 'calendar.legend.ride'.tr(),
                        ),
                        PdlLegendEntry(
                          color: calendarEventColor(c, 'TRIP_STAGE'),
                          label: 'calendar.legend.stage'.tr(),
                        ),
                        PdlLegendEntry(
                          color: c.primary,
                          label: 'rides.registered'.tr(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _gridHandle(),
      ],
    );
  }

  /// La poignée de repli — **hors du bloc qui se replie**, et c'est tout le
  /// point : le chevron vivait dans la rangée de légende, donc replier la
  /// grille emportait le seul moyen de la rouvrir.
  ///
  /// Toute la bande est cliquable et non le seul chevron : c'est la cible de
  /// 44 px, et une poignée se saisit là où l'œil la voit.
  Widget _gridHandle() {
    final PdlColors c = context.pdl;
    final bool collapsed = _collapse > 0.5;

    return Semantics(
      button: true,
      label: collapsed
          ? 'calendar.expandGrid'.tr()
          : 'calendar.collapseGrid'.tr(),
      child: InkWell(
        onTap: _toggleGrid,
        child: SizedBox(
          height: PdlMetrics.tapTarget,
          width: double.infinity,
          child: Icon(
            collapsed ? PdlIcons.chevronDown : PdlIcons.chevronUp,
            size: 20,
            color: c.textDimmed,
          ),
        ),
      ),
    );
  }

  Widget _skeletons() => ListView(
    padding: const EdgeInsets.all(PdlSpacing.section),
    children: const <Widget>[
      PdlSkeletonCardList(variant: PdlSkeletonCardVariant.compact, count: 5),
    ],
  );

  Widget _emptyState(
    CalendarMonthKey monthKey,
    CalendarTypeFilter type,
    bool monthHasEvents,
  ) {
    // Deux vides bien distincts : « rien ce mois-ci » et « rien *avec ces
    // filtres* ». Le second se résout en effaçant les filtres, jamais en
    // changeant de mois — et il ne se dit que si le mois a bien des
    // événements, sans quoi sa phrase (« Ce mois contient des événements… »)
    // serait fausse : un mois vide reste le vide du mois, filtre ou non.
    final bool filtered =
        type != CalendarTypeFilter.all || widget.registeredOnly;
    if (filtered && monthHasEvents) {
      return Padding(
        padding: const EdgeInsets.all(PdlSpacing.section),
        child: PdlEmptyState(
          variant: PdlEmptyVariant.filtered,
          icon: PdlIcons.dateBusy,
          title: 'calendar.noEventsFiltered.title'.tr(),
          message: 'calendar.noEventsFiltered.message'.tr(),
          actions: <Widget>[
            PdlButton(
              label: 'common.clearFilters'.tr(),
              variant: PdlButtonVariant.outline,
              size: PdlButtonSize.sm,
              onPressed: () {
                _setType(CalendarTypeFilter.all);
                if (widget.registeredOnly) {
                  widget.onClearRegisteredOnly?.call();
                }
              },
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(PdlSpacing.section),
      child: Consumer(
        builder: (BuildContext context, WidgetRef ref, _) {
          final CalendarMonthKey? next = ref
              .watch(calendarNextMonthWithEventsProvider(monthKey))
              .value;
          return PdlEmptyState(
            variant: PdlEmptyVariant.empty,
            icon: PdlIcons.dateBusy,
            title: 'calendar.noEvents'.tr(),
            // Sur une équipe (son Agenda, ou sa chip au calendrier global),
            // c'est elle qui n'a rien publié — pas « vos équipes ».
            message:
                (monthKey.teamSlug == null
                        ? 'calendar.noEventsIn'
                        : 'calendar.noEventsInTeam')
                    .tr(
                      namedArgs: <String, String>{
                        'month': AppFormatters.formatMonthYear(monthKey.start),
                      },
                    ),
            actions: <Widget>[
              if (next != null)
                PdlButton(
                  label: 'calendar.goToNextMonthWithEvents'.tr(),
                  variant: PdlButtonVariant.outline,
                  size: PdlButtonSize.sm,
                  onPressed: () => _setMonth(next),
                ),
            ],
          );
        },
      ),
    );
  }

  // ── Composition de l'agenda ───────────────────────────────────────────────

  List<_AgendaEntry> _compose(CalendarMonth month) {
    final DateTime now = AppFormatters.displayNow();
    final DateTime todayStart = DateTime(now.year, now.month, now.day);
    final List<_AgendaEntry> entries = <_AgendaEntry>[];
    bool separatorPlaced = false;

    for (final DateTime day in month.days) {
      // « À venir » sépare une fois le passé du reste, et seulement s'il y a un
      // passé à séparer.
      if (!separatorPlaced && !day.isBefore(todayStart) && entries.isNotEmpty) {
        entries.add(const _UpcomingSeparatorEntry());
        separatorPlaced = true;
      }
      entries.add(_DayHeaderEntry(day));
      for (final CalendarEventDto event in month.byDay[day]!) {
        entries.add(_EventEntry(event));
      }
    }
    return entries;
  }

  /// L'index d'agenda d'un jour : son en-tête.
  int? _indexOfDay(CalendarMonth month, DateTime day) {
    final List<_AgendaEntry> entries = _compose(month);
    for (int i = 0; i < entries.length; i++) {
      final _AgendaEntry entry = entries[i];
      if (entry is _DayHeaderEntry && _sameDay(entry.day, day)) return i;
    }
    return null;
  }

  /// À l'ouverture : aujourd'hui s'il est renseigné, sinon le prochain jour
  /// qui l'est. Jamais le 1ᵉʳ du mois, qui n'a aucune raison d'intéresser.
  void _schedulePositioning(
    CalendarMonthKey monthKey,
    CalendarMonth month,
    DateTime today,
  ) {
    if (_positionedFor == monthKey || month.isEmpty) return;
    _positionedFor = monthKey;

    final DateTime todayStart = DateTime(today.year, today.month, today.day);
    final DateTime? target = month.days
        .where((DateTime d) => !d.isBefore(todayStart))
        .firstOrNull;
    if (target == null) return;
    final int? index = _indexOfDay(month, target);
    if (index == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _agendaController.isAttached) {
        _agendaController.jumpTo(index: index);
      }
    });
  }

  // ── Interactions ──────────────────────────────────────────────────────────

  /// En dessous, un doigt qui traîne lentement sur la grille (sélection,
  /// hésitation) ne doit pas changer de mois.
  static const double _swipeVelocityThreshold = 200;

  void _setMonth(CalendarMonthKey next) {
    ref.read(calendarMonthKeyProvider(widget.teamSlug).notifier).state = next;
    ref.read(calendarSelectedDayProvider.notifier).state = null;
    setState(() {
      _positionedFor = null;
      _collapse = 0;
      _pinnedCollapsed = false;
    });
  }

  void _goToToday() {
    final DateTime now = AppFormatters.displayNow();
    _setMonth(
      CalendarMonthKey(
        year: now.year,
        month: now.month,
        teamSlug: widget.teamSlug,
      ),
    );
    ref.read(calendarSelectedDayProvider.notifier).state = DateTime(
      now.year,
      now.month,
      now.day,
    );
  }

  void _selectDay(DateTime day, CalendarMonth month) {
    ref.read(calendarSelectedDayProvider.notifier).state = day;
    final int? index = _indexOfDay(month, day);
    if (index != null && _agendaController.isAttached) {
      _agendaController.scrollTo(
        index: index,
        duration: PdlMotion.stateChange,
        curve: PdlMotion.stateChangeCurve,
      );
    }
  }

  /// La bascule part de l'état **visible**, pas du seul repli épinglé : une
  /// grille déjà repliée par le défilement doit se rouvrir au premier appui,
  /// alors que `_pinnedCollapsed` vaut encore `false`.
  void _toggleGrid() => setState(() {
    _pinnedCollapsed = _collapse <= 0.5;
    _collapse = _pinnedCollapsed ? 1 : 0;
  });

  bool _onAgendaScroll(ScrollNotification notification) {
    if (_pinnedCollapsed || notification.depth != 0) return false;
    final double next = (notification.metrics.pixels / kCalendarGridMaxHeight)
        .clamp(0.0, 1.0);
    if ((next - _collapse).abs() < 0.01) return false;
    setState(() => _collapse = next);
    return false;
  }

  // ── Libellés ──────────────────────────────────────────────────────────────

  List<String> _weekdayLabels() => <String>[
    for (int weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
      AppFormatters.dayAbbrev(weekday, context: context),
  ];

  String _dayLabel(DateTime day) => calendarDayLabel(day);

  String _daySemanticLabel(CalendarMonth month, DateTime day) {
    final List<CalendarEventDto> events =
        month.byDay[day] ?? const <CalendarEventDto>[];
    final String date = AppFormatters.formatFullDate(day);
    if (events.isEmpty) return date;
    final String count = 'calendar.eventCount'.plural(events.length);
    final bool registered = events.any((CalendarEventDto e) => e.registered);
    return registered
        ? '$date, $count, ${'rides.registered'.tr()}'
        : '$date, $count';
  }

  /// Zéro à deux points : un par type présent ce jour-là, dans l'ordre de la
  /// légende. Au-delà de deux la case devient illisible — c'est le contrat de
  /// `PdlMonthGrid`, et c'est ici qu'on tronque.
  List<Color> _dotsOf(PdlColors c, CalendarMonth month, DateTime day) {
    final List<CalendarEventDto> events =
        month.byDay[day] ?? const <CalendarEventDto>[];
    return <Color>[
      if (events.any((CalendarEventDto e) => e.type == 'RIDE'))
        calendarEventColor(c, 'RIDE'),
      if (events.any((CalendarEventDto e) => e.type == 'TRIP_STAGE'))
        calendarEventColor(c, 'TRIP_STAGE'),
    ];
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Entrées d'agenda ────────────────────────────────────────────────────────

sealed class _AgendaEntry {
  const _AgendaEntry();
}

class _DayHeaderEntry extends _AgendaEntry {
  const _DayHeaderEntry(this.day);
  final DateTime day;
}

class _EventEntry extends _AgendaEntry {
  const _EventEntry(this.event);
  final CalendarEventDto event;
}

class _UpcomingSeparatorEntry extends _AgendaEntry {
  const _UpcomingSeparatorEntry();
}
