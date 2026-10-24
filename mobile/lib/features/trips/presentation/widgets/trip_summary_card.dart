import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../providers/trip_detail_provider.dart';
import '../../../../core/widgets/zone_mention_line.dart';

/// Le bloc de synthèse d'un voyage : quatre chiffres et les participants.
///
/// Il n'existe que depuis la 1.5.0 : `endDate`, `stageCount`, `totalDistance` et
/// `totalElevationGain` sont tous nouveaux. Avant, l'écran affichait une date de
/// départ et rien d'autre — ni la durée, ni la distance, ni le dénivelé d'une
/// traversée de sept jours.
///
/// **`null` se rend « — », jamais « 0 ».** Un voyage dont aucune étape n'a de
/// parcours n'a pas une distance nulle : il n'en a pas. Écrire « 0 km » serait
/// une mesure inventée, et le contrat distingue explicitement les deux cas.
class TripSummaryCard extends ConsumerWidget {
  const TripSummaryCard({
    super.key,
    required this.trip,
    required this.onShowParticipants,
  });

  final TripDto trip;
  final VoidCallback onShowParticipants;

  static const String _dash = '—';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    final UnitSystem units = ref.watch(unitSystemProvider);

    return PdlCard(
      flat: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _cells(context, units),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: PdlSpacing.cardTight),
            child: Divider(height: 1, color: c.borderSubtle),
          ),
          _participants(context),
        ],
      ),
    );
  }

  // ── Les quatre cellules ─────────────────────────────────────────────────
  Widget _cells(BuildContext context, UnitSystem units) {
    final List<Widget> cells = <Widget>[
      _cell(
        context,
        label: 'trips.summary.dates'.tr(),
        value: _dates(),
        extra: _duration(),
        // Le départ vu d'ailleurs : « heure de Tokyo (ven. 01:00 chez
        // vous) » (docs/LEDGER_*.md API-60).
        note: ZoneMentionLine.maybe(trip.dateTime, trip.timezone),
      ),
      _cell(
        context,
        label: 'trips.stages'.tr(),
        value: trip.stageCount == 0
            ? _dash
            : 'trips.stageCount'.plural(trip.stageCount),
        extra: trip.stageCount == 0
            ? null
            : 'trips.summary.dayRange'.tr(
                namedArgs: <String, String>{'last': '${trip.stageCount}'},
              ),
      ),
      _cell(
        context,
        label: 'trips.summary.totalDistance'.tr(),
        value: trip.totalDistance == null
            ? _dash
            : AppFormatters.formatDistance(trip.totalDistance!, units),
        icon: PdlIcons.distance,
      ),
      _cell(
        context,
        label: 'trips.summary.totalElevation'.tr(),
        value: trip.totalElevationGain == null
            ? _dash
            : AppFormatters.formatElevationGain(
                trip.totalElevationGain!,
                units,
              ),
        icon: PdlIcons.elevationUp,
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Même règle que le bloc méta de la sortie : deux colonnes tant qu'une
        // colonne reste lisible, une seule au-delà — quatre cellules écrasées
        // à `textScaleFactor` élevé ne se lisent plus.
        final bool twoColumns =
            constraints.maxWidth >= 320 &&
            MediaQuery.textScalerOf(context).scale(14) <= 18;
        if (!twoColumns) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int i = 0; i < cells.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: PdlSpacing.meta2V),
                cells[i],
              ],
            ],
          );
        }
        return Wrap(
          spacing: PdlSpacing.meta2H,
          runSpacing: PdlSpacing.meta2V,
          children: <Widget>[
            for (final Widget cell in cells)
              SizedBox(
                width: (constraints.maxWidth - PdlSpacing.meta2H) / 2,
                child: cell,
              ),
          ],
        );
      },
    );
  }

  Widget _cell(
    BuildContext context, {
    required String label,
    required String value,
    String? extra,
    Widget? note,
    IconData? icon,
  }) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: t.xs),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 15, color: c.textDimmed),
              const SizedBox(width: 5),
            ],
            Flexible(child: Text(value, style: t.statBigValue)),
          ],
        ),
        if (extra != null) Text(extra, style: t.xs),
        ?note,
      ],
    );
  }

  /// « 12 → 18 août 2026 », ou la seule date de départ quand le voyage tient
  /// en un jour — `endDate` nul signifie exactement cela, par contrat. Le
  /// départ se lit dans le fuseau de la première étape, la fin dans celui de
  /// la dernière ([TripTiming.endsAt]) : la durée compte les jours vécus.
  String _dates() {
    final DateTime? start = trip.startsAt;
    if (start == null) return _dash;
    final DateTime? end = trip.endsAt;
    if (end == null || _sameDay(start, end)) {
      return AppFormatters.formatLongDate(start);
    }
    return 'trips.summary.dateRange'.tr(
      namedArgs: <String, String>{
        'start': AppFormatters.formatDayMonth(start),
        'end': AppFormatters.formatLongDate(end),
      },
    );
  }

  String? _duration() {
    final DateTime? start = trip.startsAt;
    final DateTime? end = trip.endsAt;
    if (start == null || end == null) return null;
    final int days =
        DateTime(
          end.year,
          end.month,
          end.day,
        ).difference(DateTime(start.year, start.month, start.day)).inDays +
        1;
    if (days <= 1) return null;
    return 'trips.summary.days'.plural(days);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── La rangée participants ──────────────────────────────────────────────
  Widget _participants(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final String label = 'trips.participants'.plural(
      trip.participantCount,
      namedArgs: <String, String>{'count': '${trip.participantCount}'},
    );

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onShowParticipants,
        borderRadius: PdlRadii.smAll,
        child: SizedBox(
          height: PdlMetrics.tapTarget,
          child: Row(
            children: <Widget>[
              if (trip.participants.isNotEmpty) ...<Widget>[
                PdlAvatarStack(
                  people: <PdlAvatarEntry>[
                    for (final PublicUserDto p in trip.participants)
                      PdlAvatarEntry(
                        name: p.displayName,
                        imageUrl: p.avatarUrl,
                      ),
                  ],
                  max: 3,
                  total: trip.participantCount,
                ),
                const SizedBox(width: PdlSpacing.chipGap),
              ],
              Expanded(
                child: Text(
                  label,
                  style: t.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(PdlIcons.chevronRight, size: 20, color: c.textDimmed),
            ],
          ),
        ),
      ),
    );
  }
}
