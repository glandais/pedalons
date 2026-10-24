import 'package:easy_localization/easy_localization.dart';
// `Visibility` est à la fois un widget Flutter et un enum du contrat.
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/link_launcher.dart';
import '../../../../keys.dart';
import '../../domain/ride_weather_display.dart';
import 'ride_weather_widgets.dart';

/// Les sections d'un écran « Météo du parcours » qui ne lisent qu'un
/// `WeatherLegDto` : partagées par l'écran d'une sortie (un leg par groupe)
/// et celui d'une étape de voyage (un leg par étape). Côté sortie, elles
/// forment l'onglet Météo de la page d'un groupe (`ride_group_weather_tab.dart`),
/// dont le bloc « départ » au point de rendez-vous vit dans
/// `departure_weather_section.dart` (ledger `MOB-67`).

/// L'état « Météo indisponible » plein écran, avec « Réessayer ».
Widget weatherUnavailableSliver(VoidCallback onRetry) => SliverToBoxAdapter(
  child: PdlEmptyState(
    key: keys.ride.weatherUnavailable,
    variant: PdlEmptyVariant.error,
    icon: PdlIcons.weatherUnknown,
    title: 'rides.weather.unavailableTitle'.tr(),
    message: 'rides.weather.unavailableMessage'.tr(),
    actions: <Widget>[
      PdlButton(
        key: keys.ride.weatherRetryButton,
        label: 'common.retry'.tr(),
        variant: PdlButtonVariant.outline,
        onPressed: onRetry,
      ),
    ],
  ),
);

/// « Prévision ancienne », avec l'heure de la dernière prévision lue.
class WeatherStaleBanner extends StatelessWidget {
  const WeatherStaleBanner({super.key, required this.fetchedAt});

  final DateTime? fetchedAt;

  @override
  Widget build(BuildContext context) => PdlBanner(
    tone: PdlBannerTone.warn,
    icon: PdlIcons.warning,
    title: 'rides.weather.stale'.tr(),
    message: fetchedAt == null
        ? ''
        : 'rides.weather.staleMessage'.tr(
            namedArgs: <String, String>{
              'time': AppFormatters.formatLongDateTime(fetchedAt!),
            },
          ),
  );
}

/// Le corps d'un leg sous son en-tête : alerte pluie, exposition, frise —
/// ou un seul bandeau quand il n'y a rien à dérouler. Les heures se lisent
/// dans le fuseau [timezone] de la sortie ou de l'étape (docs/LEDGER_*.md
/// API-60).
///
/// Avec [onCheckpointTap], chaque point de la frise se touche (l'onglet Météo
/// d'un groupe y place le réticule de sa carte, ledger `MOB-93`) ; le point
/// d'`index` [selectedCheckpoint] se marque comme choisi.
List<Widget> weatherLegBody(
  WeatherLegDto leg,
  Widget Function(Widget) padded,
  String? timezone, {
  ValueChanged<WeatherCheckpointDto>? onCheckpointTap,
  int? selectedCheckpoint,
}) {
  final WeatherStatus legStatus = WeatherStatus.fromJson(leg.status);
  if (legStatus == WeatherStatus.noLocation) {
    return <Widget>[
      padded(
        PdlBanner(
          tone: PdlBannerTone.info,
          icon: PdlIcons.route,
          message: 'rides.weather.legNoRoute'.tr(),
        ),
      ),
    ];
  }
  // Comme le web (`LegWeather`) : la frise ne se déroule que pour une étape
  // prévue (`OK`/`STALE`) avec des points. `UNAVAILABLE`, `NOT_YET_AVAILABLE`
  // (le groupe part au-delà de l'horizon) ou un statut inconnu de cette build :
  // un seul bandeau, plutôt qu'une frise de points sans prévision.
  final bool forecast =
      legStatus == WeatherStatus.ok || legStatus == WeatherStatus.stale;
  if (!forecast || leg.checkpoints.isEmpty) {
    return <Widget>[
      padded(
        PdlBanner(
          key: keys.ride.weatherLegUnavailable,
          tone: PdlBannerTone.info,
          icon: PdlIcons.weatherUnknown,
          message: 'rides.weather.legUnavailable'.tr(),
        ),
      ),
    ];
  }
  return <Widget>[
    if (leg.rainAlert != null)
      padded(_RainAlertBanner(alert: leg.rainAlert!, timezone: timezone)),
    if (leg.segments.isNotEmpty) padded(_WindSection(leg: leg)),
    if (leg.checkpoints.isNotEmpty)
      padded(
        _Timeline(
          leg: leg,
          timezone: timezone,
          onTap: onCheckpointTap,
          selected: selectedCheckpoint,
        ),
      ),
  ];
}

/// L'en-tête d'un leg : son nom (le groupe, l'étape), sa longueur, ses
/// horaires, la vitesse des passages et le vent dominant.
class WeatherLegHeader extends ConsumerWidget {
  const WeatherLegHeader({
    super.key,
    required this.leg,
    required this.title,
    required this.timezone,
    this.speedDefaultKey = 'rides.weather.legSpeedDefault',
  });

  final WeatherLegDto leg;

  /// Le fuseau de la sortie ou de l'étape, où se lisent départ et arrivée.
  final String? timezone;

  /// Le nom du groupe ou de l'étape ; à défaut, « Météo du parcours ».
  final String? title;

  /// La phrase qui dit la vitesse par défaut : c'est le groupe, ou l'étape,
  /// qui n'en indique pas.
  final String speedDefaultKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);
    final String speed = AppFormatters.formatSpeed(leg.averageSpeed, units);
    final WindDto? prevailing = leg.prevailingWind;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PdlSectionHeader(
          title: title ?? 'rides.weather.routeTitle'.tr(),
          count: leg.distance > 0
              ? AppFormatters.formatDistance(leg.distance, units)
              : null,
        ),
        Text(
          'rides.weather.legTimes'.tr(
            namedArgs: <String, String>{
              'start': formatWeatherTime(leg.startTime, timezone),
              'arrival': formatWeatherTime(leg.arrivalTime, timezone),
            },
          ),
          style: t.body,
        ),
        const SizedBox(height: 2),
        Text(
          (leg.speedIsDefault ? speedDefaultKey : 'rides.weather.legSpeed').tr(
            namedArgs: <String, String>{'speed': speed},
          ),
          style: t.xs,
        ),
        if (prevailing != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            'rides.weather.prevailingWind'.tr(
              namedArgs: <String, String>{
                'wind': formatWind(prevailing, units),
              },
            ),
            style: t.xs,
          ),
        ],
      ],
    );
  }
}

class _RainAlertBanner extends ConsumerWidget {
  const _RainAlertBanner({required this.alert, required this.timezone});

  final WeatherRainAlertDto alert;
  final String? timezone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UnitSystem units = ref.watch(unitSystemProvider);
    return PdlBanner(
      tone: PdlBannerTone.warn,
      icon: weatherConditionOf(alert.condition).icon(daylight: true),
      message: formatRainAlert(alert, units, timezone),
    );
  }
}

class _WindSection extends ConsumerWidget {
  const _WindSection({required this.leg});

  final WeatherLegDto leg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PdlSectionHeader(title: 'rides.weather.exposureTitle'.tr()),
        PdlCard(
          flat: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('rides.weather.segmentsTitle'.tr(), style: t.xs),
              const SizedBox(height: PdlSpacing.badgeGap),
              WeatherWindSegments(leg: leg, units: units),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────── frise des passages

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.leg,
    required this.timezone,
    this.onTap,
    this.selected,
  });

  final WeatherLegDto leg;
  final String? timezone;
  final ValueChanged<WeatherCheckpointDto>? onTap;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    final List<WeatherCheckpointDto> points = leg.checkpoints;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PdlSectionHeader(title: 'rides.weather.timelineTitle'.tr()),
        for (int i = 0; i < points.length; i++)
          _CheckpointRow(
            key: keys.ride.weatherCheckpoint(points[i].indexField),
            checkpoint: points[i],
            timezone: timezone,
            first: i == 0,
            last: i == points.length - 1,
            selected: selected == points[i].indexField,
            onTap: onTap == null ? null : () => onTap!(points[i]),
          ),
      ],
    );
  }
}

class _CheckpointRow extends ConsumerWidget {
  const _CheckpointRow({
    super.key,
    required this.checkpoint,
    required this.timezone,
    required this.first,
    required this.last,
    this.selected = false,
    this.onTap,
  });

  final WeatherCheckpointDto checkpoint;
  final String? timezone;
  final bool first;
  final bool last;

  /// Le point choisi : son réticule est sur la carte.
  final bool selected;

  /// Toucher du point ; `null` : la ligne ne se touche pas.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);
    final WeatherCheckpointDto p = checkpoint;
    final WeatherConditionsDto? w = p.weather;
    final RelativeWind? relative = relativeWindOf(p.relativeWind);

    final String time = formatWeatherTime(p.time, timezone);
    final String distance = AppFormatters.formatDistance(p.distance, units);
    final String kind = _kindLabel(p.kind);
    final String? temperature = w == null
        ? null
        : AppFormatters.formatTemperature(w.temperature, units);
    final String? condition = w == null
        ? null
        : weatherConditionOf(w.condition).labelKey.tr();
    final String? rain = w?.precipitationProbability == null
        ? null
        : 'rides.weather.rainChance'.tr(
            namedArgs: <String, String>{
              'probability': AppFormatters.formatPercent(
                w!.precipitationProbability!,
              ),
            },
          );
    final String? amount = w == null || w.precipitation <= 0
        ? null
        : 'rides.weather.precipitation'.tr(
            namedArgs: <String, String>{
              'amount': AppFormatters.formatPrecipitation(w.precipitation),
            },
          );
    final String? relativeLabel = relative?.labelKey.tr();
    final String? wind = w == null
        ? null
        : formatWind(w.wind, units, gusts: true);

    final bool endpoint = first || last;
    final Color dot = endpoint ? c.primary : c.textDimmed;

    final Widget row = _row(
      c,
      t,
      p,
      w,
      relative,
      time: time,
      distance: distance,
      kind: kind,
      temperature: temperature,
      condition: condition,
      rain: rain,
      amount: amount,
      wind: wind,
      dot: dot,
      endpoint: endpoint,
    );

    return Semantics(
      container: true,
      button: onTap != null,
      // Nul, pas `false`, sur une ligne qui ne se touche pas : `false` lui
      // donnerait un état « non sélectionné » qu'elle n'a pas.
      selected: onTap == null ? null : selected,
      onTap: onTap,
      onTapHint: onTap == null ? null : 'rides.weather.mapShowPoint'.tr(),
      label: <String>[
        kind,
        time,
        distance,
        ?temperature,
        ?condition,
        ?relativeLabel,
        ?wind,
        ?rain,
        ?amount,
        if (w == null) 'rides.weather.checkpointNoWeather'.tr(),
      ].join(', '),
      child: ExcludeSemantics(
        child: onTap == null
            ? row
            : Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: PdlRadii.mdAll,
                  child: Ink(
                    decoration: BoxDecoration(
                      color: selected ? c.primarySoft : null,
                      borderRadius: PdlRadii.mdAll,
                    ),
                    child: row,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _row(
    PdlColors c,
    PdlTypography t,
    WeatherCheckpointDto p,
    WeatherConditionsDto? w,
    RelativeWind? relative, {
    required String time,
    required String distance,
    required String kind,
    required String? temperature,
    required String? condition,
    required String? rain,
    required String? amount,
    required String? wind,
    required Color dot,
    required bool endpoint,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 64,
            child: Padding(
              padding: const EdgeInsets.only(top: PdlSpacing.badgeGap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(time, style: t.bodyStrong),
                  Text(distance, style: t.xs),
                ],
              ),
            ),
          ),
          // Le rail : un trait continu, interrompu au premier et au
          // dernier point, et une pastille par point.
          SizedBox(
            width: 24,
            child: Column(
              children: <Widget>[
                Container(width: 2, height: 10, color: first ? null : c.border),
                Container(
                  width: endpoint ? 12 : 8,
                  height: endpoint ? 12 : 8,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                Expanded(
                  child: Container(width: 2, color: last ? null : c.border),
                ),
              ],
            ),
          ),
          const SizedBox(width: PdlSpacing.chipGap),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                top: PdlSpacing.badgeGap,
                bottom: PdlSpacing.section,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(kind, style: t.xs),
                  const SizedBox(height: 2),
                  if (w == null)
                    Text('rides.weather.checkpointNoWeather'.tr(), style: t.sub)
                  else ...<Widget>[
                    Row(
                      children: <Widget>[
                        WeatherConditionIcon(
                          condition: w.condition,
                          daylight: w.daylight,
                        ),
                        const SizedBox(width: PdlSpacing.badgeGap),
                        Text(temperature!, style: t.statValue),
                        const SizedBox(width: PdlSpacing.chipGap),
                        Expanded(
                          child: Text(
                            condition!,
                            style: t.sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: PdlSpacing.badgeGap),
                    Wrap(
                      spacing: PdlSpacing.chipGap,
                      runSpacing: PdlSpacing.badgeGap,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        if (relative != null) ...<Widget>[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (p.relativeWindAngle != null) ...<Widget>[
                                PdlWindArrow(
                                  angle: p.relativeWindAngle!,
                                  color: relativeWindColor(c, relative),
                                ),
                                const SizedBox(width: 2),
                              ],
                              PdlBadge(
                                label: relative.shortLabelKey.tr(),
                                tone: relative.tone(c),
                              ),
                            ],
                          ),
                        ],
                        Text(wind!, style: t.xs),
                        if (rain != null) Text(rain, style: t.xs),
                        if (amount != null) Text(amount, style: t.xs),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _kindLabel(String kind) =>
      switch (WeatherCheckpointKind.fromJson(kind)) {
        WeatherCheckpointKind.start => 'rides.weather.checkpointKind.start',
        WeatherCheckpointKind.finish => 'rides.weather.checkpointKind.finish',
        WeatherCheckpointKind.enRoute || WeatherCheckpointKind.$unknown =>
          'rides.weather.checkpointKind.enRoute',
      }.tr();
}

// ─────────────────────────────────────────────────────────── attribution

/// Le crédit que la licence des prévisions demande (CC BY 4.0), et l'heure
/// de la prévision la plus ancienne lue.
class WeatherAttributionBlock extends StatelessWidget {
  const WeatherAttributionBlock({
    super.key,
    required this.attribution,
    required this.fetchedAt,
  });

  final WeatherAttributionDto attribution;
  final DateTime? fetchedAt;

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (fetchedAt != null)
          Text(
            'rides.weather.updatedAt'.tr(
              namedArgs: <String, String>{
                'time': AppFormatters.formatLongDateTime(fetchedAt!),
              },
            ),
            style: t.xs,
          ),
        PdlButton(
          label: weatherAttributionLabel(attribution),
          variant: PdlButtonVariant.text,
          size: PdlButtonSize.sm,
          icon: PdlIcons.openExternal,
          onPressed: () => openLink(context, attribution.url),
        ),
      ],
    );
  }
}
