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

/// Les briques de la météo d'un leg — un groupe de sortie, une étape de
/// voyage : bandeaux, exposition au vent, frise des passages, bas de section
/// (« Prévision du … » et ⓘ). `WeatherSection` (`weather_section.dart`) les
/// compose en section Météo d'un écran de détail (ledger `MOB-132`) ; le bloc
/// « départ » au point de rendez-vous vit dans `departure_weather_section.dart`.

/// L'état « Météo indisponible » plein écran, avec « Réessayer ».
Widget weatherUnavailableSliver(VoidCallback onRetry) =>
    SliverToBoxAdapter(child: WeatherUnavailableState(onRetry: onRetry));

/// « Météo indisponible » (statut `UNAVAILABLE`, ou échec de l'appel), avec
/// « Réessayer ».
class WeatherUnavailableState extends StatelessWidget {
  const WeatherUnavailableState({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => PdlEmptyState(
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
  );
}

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

/// Le leg a-t-il une frise à dérouler ? Comme le web (`LegWeather`) : une
/// étape prévue (`OK`/`STALE`) avec des points. `UNAVAILABLE`,
/// `NOT_YET_AVAILABLE` (le groupe part au-delà de l'horizon) ou un statut
/// inconnu de cette build : un seul bandeau ([WeatherLegNotice]), plutôt
/// qu'une frise de points sans prévision.
bool weatherLegHasForecast(WeatherLegDto leg) {
  final WeatherStatus status = WeatherStatus.fromJson(leg.status);
  return (status == WeatherStatus.ok || status == WeatherStatus.stale) &&
      leg.checkpoints.isNotEmpty;
}

/// Le bandeau d'un leg sans frise : « pas de parcours » (`NO_LOCATION`) ou
/// « pas encore de prévision le long du parcours ». Rien quand le leg en a
/// une ([weatherLegHasForecast]).
class WeatherLegNotice extends StatelessWidget {
  const WeatherLegNotice({super.key, required this.leg});

  final WeatherLegDto leg;

  /// Le leg se résume-t-il à ce bandeau ?
  static bool shows(WeatherLegDto leg) => !weatherLegHasForecast(leg);

  @override
  Widget build(BuildContext context) {
    if (WeatherStatus.fromJson(leg.status) == WeatherStatus.noLocation) {
      return PdlBanner(
        tone: PdlBannerTone.info,
        icon: PdlIcons.route,
        message: 'rides.weather.legNoRoute'.tr(),
      );
    }
    if (weatherLegHasForecast(leg)) return const SizedBox.shrink();
    return PdlBanner(
      key: keys.ride.weatherLegUnavailable,
      tone: PdlBannerTone.info,
      icon: PdlIcons.weatherUnknown,
      message: 'rides.weather.legUnavailable'.tr(),
    );
  }
}

/// Le corps d'un leg sous son en-tête : alerte pluie, exposition, frise —
/// ou un seul bandeau quand il n'y a rien à dérouler. Les heures se lisent
/// dans le fuseau [timezone] de la sortie ou de l'étape (docs/LEDGER_*.md
/// API-60).
///
/// Avec [onCheckpointTap], chaque point de la frise se touche (la carte d'un
/// groupe y place son réticule, ledger `MOB-93`) ; le point d'`index`
/// [selectedCheckpoint] se marque comme choisi.
///
/// Ne sert plus qu'à la carte météo d'une sortie solo
/// (`RideDepartureWeatherCard`), que le lot 7 du ledger `MOB-132` retire :
/// les écrans passent par `WeatherSection`, qui compose les mêmes briques.
List<Widget> weatherLegBody(
  WeatherLegDto leg,
  Widget Function(Widget) padded,
  String? timezone, {
  ValueChanged<WeatherCheckpointDto>? onCheckpointTap,
  int? selectedCheckpoint,
}) {
  if (WeatherLegNotice.shows(leg)) {
    return <Widget>[padded(WeatherLegNotice(leg: leg))];
  }
  return <Widget>[
    if (leg.rainAlert != null)
      padded(WeatherRainAlertBanner(alert: leg.rainAlert!, timezone: timezone)),
    if (leg.segments.isNotEmpty)
      padded(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            PdlSectionHeader(title: 'rides.weather.exposureTitle'.tr()),
            WeatherExposureCard(leg: leg),
          ],
        ),
      ),
    padded(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PdlSectionHeader(title: 'rides.weather.alongRouteTitle'.tr()),
          WeatherTimeline(
            leg: leg,
            timezone: timezone,
            onTap: onCheckpointTap,
            selected: selectedCheckpoint,
          ),
        ],
      ),
    ),
  ];
}

/// « Passages estimés à 28 km/h », ou la phrase de la vitesse par défaut
/// ([speedDefaultKey] : le groupe, ou l'étape, n'en indique pas).
String weatherLegSpeedLine(
  WeatherLegDto leg,
  UnitSystem units, {
  String speedDefaultKey = 'rides.weather.legSpeedDefault',
}) => (leg.speedIsDefault ? speedDefaultKey : 'rides.weather.legSpeed').tr(
  namedArgs: <String, String>{
    'speed': AppFormatters.formatSpeed(leg.averageSpeed, units),
  },
);

/// « 6 points · de 09:00 à 12:18 » : le nombre de passages de la frise et
/// ses heures de départ et d'arrivée, dans le fuseau [timezone] de l'entité.
String weatherLegPointsLine(WeatherLegDto leg, String? timezone) =>
    'rides.weather.alongRoutePoints'.plural(
      leg.checkpoints.length,
      namedArgs: <String, String>{
        'start': formatWeatherTime(leg.startTime, timezone),
        'arrival': formatWeatherTime(leg.arrivalTime, timezone),
      },
    );

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
          weatherLegSpeedLine(leg, units, speedDefaultKey: speedDefaultKey),
          style: t.xs,
        ),
        if (prevailing != null) ...<Widget>[
          const SizedBox(height: 2),
          WeatherPrevailingWindLine(wind: prevailing, units: units),
        ],
      ],
    );
  }
}

/// L'alerte pluie d'un leg, en bandeau : « Pluie probable (70 %) vers 20:05,
/// à 15,0 km. »
class WeatherRainAlertBanner extends ConsumerWidget {
  const WeatherRainAlertBanner({
    super.key,
    required this.alert,
    required this.timezone,
  });

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

/// La carte « Exposition au vent » (KIT §8) : la barre face / travers / dos,
/// sa légende à pastilles au dixième, puis « Vent dominant : → 18 km/h ».
/// Le titre est à l'appelant.
class WeatherExposureCard extends ConsumerWidget {
  const WeatherExposureCard({super.key, required this.leg});

  final WeatherLegDto leg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UnitSystem units = ref.watch(unitSystemProvider);
    final WindDto? prevailing = leg.prevailingWind;
    return PdlCard(
      key: keys.ride.weatherExposure,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          WeatherWindSegments(leg: leg, units: units),
          if (prevailing != null) ...<Widget>[
            const SizedBox(height: PdlSpacing.chipGap),
            WeatherPrevailingWindLine(wind: prevailing, units: units),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────── frise des passages

/// La frise des passages d'un leg : l'heure et le km à gauche, un rail, puis
/// la météo du point. Seuls « Départ » et « Arrivée » portent un libellé ;
/// un point intermédiaire commence par sa météo (KIT §8). Le titre est à
/// l'appelant.
///
/// Avec [onTap], chaque point se touche (la carte d'un groupe y place son
/// réticule, ledger `MOB-93`) ; le point d'`index` [selected] se marque
/// comme choisi.
class WeatherTimeline extends StatelessWidget {
  const WeatherTimeline({
    super.key,
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
    final String? kind = _kindLabel(p.kind);
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
    // Le lecteur d'écran garde le point cardinal ; à l'écran, la flèche le
    // porte (KIT §8).
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
      units: units,
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
        ?kind,
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
    required String? kind,
    required String? temperature,
    required String? condition,
    required String? rain,
    required String? amount,
    required UnitSystem units,
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
                  Text(time, style: t.statValue),
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
                  if (kind != null) ...<Widget>[
                    Text(kind, style: t.statValue),
                    const SizedBox(height: 2),
                  ],
                  if (w == null)
                    Text('rides.weather.checkpointNoWeather'.tr(), style: t.sub)
                  else ...<Widget>[
                    Row(
                      children: <Widget>[
                        WeatherConditionIcon(
                          condition: w.condition,
                          daylight: w.daylight,
                          size: 16,
                        ),
                        const SizedBox(width: PdlSpacing.badgeGap),
                        Expanded(
                          child: Text(
                            '${temperature!} ${condition!}',
                            style: t.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: PdlSpacing.badgeGap,
                      runSpacing: PdlSpacing.badgeGap,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        if (relative != null) ...<Widget>[
                          if (p.relativeWindAngle != null)
                            PdlWindArrow(
                              angle: p.relativeWindAngle!,
                              color: relativeWindColor(c, relative),
                              size: 14,
                            ),
                          PdlBadge(
                            label: relative.shortLabelKey.tr(),
                            tone: relative.tone(c),
                          ),
                        ],
                        // La flèche du vent relatif dit déjà d'où il vient ;
                        // sans elle, celle du vent absolu, nord en haut.
                        if (relative != null && p.relativeWindAngle != null)
                          Text(
                            formatWind(
                              w.wind,
                              units,
                              gusts: true,
                              compass: false,
                            ),
                            style: t.xs,
                          )
                        else
                          WeatherWindLine(wind: w.wind, units: units),
                      ],
                    ),
                    if (rain != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(rain, style: t.xs),
                    ],
                    if (amount != null) Text(amount, style: t.xs),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// « Départ » et « Arrivée » ; un point intermédiaire n'a pas de libellé
  /// (KIT §8 : plus de « En route »).
  String? _kindLabel(String kind) => switch (WeatherCheckpointKind.fromJson(
    kind,
  )) {
    WeatherCheckpointKind.start => 'rides.weather.checkpointKind.start'.tr(),
    WeatherCheckpointKind.finish => 'rides.weather.checkpointKind.finish'.tr(),
    WeatherCheckpointKind.enRoute || WeatherCheckpointKind.$unknown => null,
  };
}

// ─────────────────────────────────────────────── prévision et attribution

/// Le bas d'une section Météo : « Prévision du mar. 10 nov. · 08:30 »
/// (horodatage, dans le fuseau du lecteur, [AppFormatters.formatTimestamp])
/// et un bouton ⓘ qui ouvre la source des prévisions — le crédit que la
/// licence demande (CC BY 4.0), derrière un bouton comme celui du profil
/// (KIT §8, ledger `MOB-132`).
class WeatherForecastFooter extends StatelessWidget {
  const WeatherForecastFooter({
    super.key,
    required this.attribution,
    required this.fetchedAt,
  });

  /// Le crédit ; `null` : pas de bouton ⓘ.
  final WeatherAttributionDto? attribution;
  final DateTime? fetchedAt;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final WeatherAttributionDto? attribution = this.attribution;
    final PdlTypography t = context.pdlText;
    return Row(
      children: <Widget>[
        Expanded(
          child: fetchedAt == null
              ? const SizedBox.shrink()
              : Text(
                  'rides.weather.forecastOf'.tr(
                    namedArgs: <String, String>{
                      'time': AppFormatters.formatTimestamp(fetchedAt!),
                    },
                  ),
                  key: keys.ride.weatherForecastOf,
                  style: t.xs,
                ),
        ),
        // Le visuel de 18 px, centré dans la cible de 44.
        if (attribution != null)
          Semantics(
            button: true,
            label: 'rides.weather.sourceTitle'.tr(),
            child: ExcludeSemantics(
              child: InkResponse(
                key: keys.ride.weatherSourceButton,
                onTap: () => showWeatherSource(context, attribution),
                radius: PdlMetrics.tapTarget / 2,
                child: SizedBox.square(
                  dimension: PdlMetrics.tapTarget,
                  child: Icon(PdlIcons.info, size: 18, color: c.textDimmed),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// La feuille « Source des prévisions météo » : le crédit, en lien vers le
/// fournisseur.
Future<void> showWeatherSource(
  BuildContext context,
  WeatherAttributionDto attribution,
) => PdlSheet.show<void>(
  context: context,
  builder: (BuildContext sheetContext) => PdlSheet(
    key: keys.ride.weatherSourceSheet,
    title: 'rides.weather.sourceTitle'.tr(),
    footer: const SafeArea(top: false, child: SizedBox(height: 8)),
    children: <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: PdlButton(
            key: keys.ride.weatherAttribution,
            label: weatherAttributionLabel(attribution),
            variant: PdlButtonVariant.text,
            size: PdlButtonSize.sm,
            icon: PdlIcons.openExternal,
            onPressed: () => openLink(sheetContext, attribution.url),
          ),
        ),
      ),
    ],
  ),
);

/// Le crédit que la licence des prévisions demande (CC BY 4.0), et l'heure
/// de la prévision la plus ancienne lue — la carte météo d'une sortie solo
/// (`RideDepartureWeatherCard`, retirée au lot 7 du ledger `MOB-132`) ; les
/// sections Météo passent par [WeatherForecastFooter].
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
