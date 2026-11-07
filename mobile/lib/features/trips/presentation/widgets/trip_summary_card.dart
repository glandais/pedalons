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
import '../../../../keys.dart';

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
    this.onShowParticipants,
  });

  final TripDto trip;

  /// Nul pour qui n'est pas membre de l'équipe : la liste lui est refusée, la
  /// rangée n'affiche alors que le nombre, sans chevron.
  final VoidCallback? onShowParticipants;

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
    final PdlTypography t = context.pdlText;
    final String? dayRange = trip.stageCount == 0
        ? null
        : 'trips.summary.dayRange'.tr(
            namedArgs: <String, String>{'last': '${trip.stageCount}'},
          );
    // Même règle que le bloc méta de la sortie : deux colonnes tant qu'une
    // colonne reste lisible, une seule au-delà — quatre cellules écrasées à
    // `textScaleFactor` élevé ne se lisent plus.
    return PdlMetaGrid(
      cells: <Widget>[
        // La durée seule : les dates, l'heure de départ et la mention de
        // fuseau sont montées dans le bloc de départ, sous le titre (BRANDING
        // §7.8, ledger `BRAND-8`) — les redire ici, dans un autre format, les
        // disait deux fois.
        PdlMetaCell(
          key: keys.trip.summaryDuration,
          label: 'trips.summary.duration'.tr(),
          value: _duration() ?? _dash,
          icon: PdlIcons.date,
        ),
        PdlMetaCell(
          label: 'trips.stages'.tr(),
          value: trip.stageCount == 0
              ? _dash
              : 'trips.stageCount'.plural(trip.stageCount),
          extra: <Widget>[if (dayRange != null) Text(dayRange, style: t.xs)],
        ),
        PdlMetaCell(
          label: 'trips.summary.totalDistance'.tr(),
          value: trip.totalDistance == null
              ? _dash
              : AppFormatters.formatDistance(trip.totalDistance!, units),
          icon: PdlIcons.distance,
        ),
        PdlMetaCell(
          label: 'trips.summary.totalElevation'.tr(),
          value: trip.totalElevationGain == null
              ? _dash
              : AppFormatters.formatElevationGain(
                  trip.totalElevationGain!,
                  units,
                ),
          icon: PdlIcons.elevationUp,
        ),
      ],
    );
  }

  /// « 7 jours », « 1 jour » — `endDate` nul signifie un voyage d'un jour, par
  /// contrat. Le départ se lit dans le fuseau de la première étape, la fin
  /// dans celui de la dernière ([TripTiming.endsAt]) : la durée compte les
  /// jours vécus. `null` sans date de départ lisible.
  String? _duration() {
    final DateTime? start = trip.startsAt;
    if (start == null) return null;
    final DateTime end = trip.endsAt ?? start;
    // Comptés sur des dates UTC : un écart de minuits locaux perd une heure
    // au passage à l'heure d'été, et `inDays` tomberait d'un jour.
    final int days =
        DateTime.utc(
          end.year,
          end.month,
          end.day,
        ).difference(DateTime.utc(start.year, start.month, start.day)).inDays +
        1;
    return 'trips.summary.days'.plural(days < 1 ? 1 : days);
  }

  // ── La rangée participants ──────────────────────────────────────────────
  Widget _participants(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final String label = 'trips.participants'.plural(
      trip.participantCount,
      namedArgs: <String, String>{'count': '${trip.participantCount}'},
    );

    return Semantics(
      button: onShowParticipants != null,
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
              if (onShowParticipants != null)
                Icon(PdlIcons.chevronRight, size: 20, color: c.textDimmed),
            ],
          ),
        ),
      ),
    );
  }
}
