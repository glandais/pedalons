import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../keys.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../providers/route_detail_provider.dart';
import '../../../../core/widgets/detail_section.dart';
import '../../../../core/widgets/zone_mention_line.dart';
import '../../../teams/domain/publication_timing.dart';

/// « Utilisé dans » — les sorties, publications et voyages qui emploient ce
/// parcours.
///
/// `GET …/usages` **existait et n'était pas appelé**. La mention « via les
/// groupes … » / « via l'étape … » vient de `viaChildNames`, qui dit *comment*
/// le parcours est employé : directement, ou à travers les groupes d'une sortie
/// ou une étape de voyage.
///
/// Une section de la fiche (`DetailSection`, ledger `MOB-134`) : son titre et
/// son espace au-dessus ne sont posés que s'il y a un usage à montrer.
class RouteUsagesSection extends ConsumerWidget {
  const RouteUsagesSection({super.key, required this.routeKey});

  final RouteKey routeKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<RouteUsageDto>> usages = ref.watch(
      routeUsagesProvider(routeKey),
    );

    // Un enrichissement : ni son chargement ni son échec ne doivent occuper la
    // fiche. Rien n'est rendu tant qu'il n'y a rien à montrer.
    final List<RouteUsageDto>? data = usages.value;
    if (data == null || data.isEmpty) return const SizedBox.shrink();

    return DetailSection(
      title: 'routes.usedIn'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < data.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: PdlSpacing.feedGap),
            _UsageCard(usage: data[i]),
          ],
        ],
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.usage});

  final RouteUsageDto usage;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    // Deux rendez-vous dans le seul fuseau que porte l'usage
    // (`RouteUsageDto.timezone`, docs/LEDGER_*.md API-60).
    final DateTime? at = AppFormatters.tryParseZoneTime(
      usage.dateTime,
      usage.timezone,
    );
    final DateTime? end = AppFormatters.tryParseZoneTime(
      usage.endDate,
      usage.timezone,
    );

    return PdlCard(
      key: keys.routeDetail.usage(usage.slug),
      padding: PdlCardPadding.tight,
      onTap: () => _open(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  usage.name,
                  style: t.cardTitle.copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (at != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      Icon(PdlIcons.date, size: 16, color: c.textDimmed),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          // Un voyage porte la date de sa dernière étape
                          // (`endDate`, API 5.9.0) : la plage, comme sur sa
                          // carte. Une sortie, ou un voyage sans étape,
                          // garde sa date et son heure, au format unique du
                          // départ (ledger `MOB-115`).
                          end == null
                              ? AppFormatters.formatDeparture(
                                  DateTime.parse(usage.dateTime),
                                  usage.timezone,
                                )
                              : tripDaySpan(
                                      usage.dateTime,
                                      usage.endDate!,
                                      timezone: usage.timezone,
                                    ) ??
                                    AppFormatters.formatDepartureDate(
                                      DateTime.parse(usage.dateTime),
                                      usage.timezone,
                                    ),
                          style: t.sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  ?ZoneMentionLine.maybe(usage.dateTime, usage.timezone),
                ],
                if (usage.viaChildNames.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(_via(), style: t.xs),
                ],
              ],
            ),
          ),
          const SizedBox(width: PdlSpacing.chipGap),
          PdlBadge(label: _typeLabel(), tone: _tone(c)),
        ],
      ),
    );
  }

  /// « via les groupes : A, B » pour une sortie ; pour un voyage, « via
  /// l'étape J3 » ou « via les étapes : J1, J3 », selon le nombre d'étapes
  /// (ledger `MOB-139`, D25).
  String _via() {
    final String names = usage.viaChildNames.join(', ');
    return switch (usage.type) {
      'TRIP' => 'routes.viaStage'.plural(
        usage.viaChildNames.length,
        namedArgs: <String, String>{'names': names},
      ),
      _ => 'routes.viaGroups'.tr(namedArgs: <String, String>{'names': names}),
    };
  }

  String _typeLabel() => switch (usage.type) {
    'RIDE' => 'publicationType.ride'.tr(),
    'TRIP' => 'publicationType.trip'.tr(),
    _ => 'publicationType.post'.tr(),
  };

  PdlTone _tone(PdlColors c) => switch (usage.type) {
    'RIDE' => PublicationType.ride.tone(c),
    'TRIP' => PublicationType.trip.tone(c),
    _ => PublicationType.post.tone(c),
  };

  void _open(BuildContext context) {
    final String path = switch (usage.type) {
      'RIDE' => Paths.ride(usage.teamSlug, usage.slug),
      'TRIP' => Paths.trip(usage.teamSlug, usage.slug),
      _ => Paths.post(usage.teamSlug, usage.slug),
    };
    context.push(path);
  }
}
