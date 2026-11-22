import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/day_box.dart';
import '../../../../core/widgets/zone_mention_line.dart';
import '../../../../keys.dart';

/// Le départ d'un aperçu daté (docs/LEDGER_*.md MOB-178), le bloc de départ
/// des fiches (BRANDING §7.8, `BRAND-8`) : la boîte du jour, « Départ
/// 09:00 » en gros, « Aujourd'hui » ou « Demain », la vitesse moyenne
/// donnée, et la mention du fuseau quand celui du tracé n'est pas celui du
/// lecteur. L'heure se lit dans `departureTimezone`, le fuseau du premier
/// point : c'est un rendez-vous, pas un horodatage.
///
/// Rien sans date.
class GpxPreviewDeparture extends ConsumerWidget {
  const GpxPreviewDeparture({super.key, required this.preview, this.now});

  final GpxPreviewDto preview;

  /// Un instant, pour les tests ; maintenant sinon.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime? instant = DateTime.tryParse(preview.departureTime ?? '');
    if (instant == null) return const SizedBox.shrink();
    final String? zone = preview.departureTimezone;
    final UnitSystem units = ref.watch(unitSystemProvider);
    final DateTime wall = AppFormatters.toZoneTime(instant, zone);
    final String headline = 'rides.departureBlock.departs'.tr(
      namedArgs: <String, String>{'time': AppFormatters.formatTime(wall)},
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
    final double? speed = preview.averageSpeed;
    final List<String> details = <String>[
      if (speed != null)
        'gpxTools.departure.speedLine'.tr(
          namedArgs: <String, String>{
            'speed': AppFormatters.formatSpeed(speed, units),
          },
        ),
    ];
    final String? mention = AppFormatters.formatZoneMention(instant, zone);

    return PdlDepartureBlock(
      key: keys.gpxTools.previewDeparture,
      dayBox: dayBoxFor(wall, now: now),
      headline: headline,
      relativeLabel: relative,
      details: details,
      zoneMention: mention == null
          ? null
          : ZoneMentionLine(instant: instant, zone: zone),
      semanticLabel: <String>[
        headline,
        ?relative,
        date,
        ...details,
        ?mention,
      ].join(', '),
    );
  }
}
