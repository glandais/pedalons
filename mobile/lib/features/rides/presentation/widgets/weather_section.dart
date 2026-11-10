import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/widgets/detail_section.dart';
import '../../../../keys.dart';
import '../../domain/group_start.dart';
import '../../domain/ride_weather_display.dart';
import 'departure_weather_section.dart';
import 'ride_weather_widgets.dart';
import 'weather_leg_sections.dart';

/// D'où viennent l'heure et les conditions de « Météo au départ de … ».
enum WeatherDepartureOf {
  /// Celles du leg fourni, quand il en porte (`WeatherLegDto.departure` :
  /// le point de rendez-vous à l'heure **du groupe**, API 13.4.0) ; sinon
  /// celles de la sortie.
  leg,

  /// Celles de la sortie (ou de l'étape) : [WeatherSection.departure] à
  /// [WeatherSection.departureAt], quoi que porte le leg.
  ride,
}

/// La section Météo d'un écran de détail (ledger `MOB-134`, KIT §8,
/// maquettes `groupe-mobile-cible`, `sortie-solo-mobile-cible`,
/// `etape-mobile-cible`, `sortie-groupes-heures-differentes-mobile-cible`).
///
/// Titre « Météo », puis, pour une prévision (`OK` / `STALE`) :
///
/// 1. le bandeau « Prévision ancienne » (`STALE`) ;
/// 2. « Météo au départ de 09:00 » et la carte des conditions
///    ([DepartureConditionsBlock]) — l'heure et les conditions du leg quand
///    il en porte, sinon celles de la sortie ([departureOf]) ;
/// 3. l'alerte pluie du leg ;
/// 4. « Exposition au vent » et sa carte ([WeatherExposureCard]) ;
/// 5. « Météo le long du parcours » ([WeatherTimeline]) : repliée dans un
///    [PdlDisclosure] quand du contenu suit ([collapsed]), dépliée avec son
///    sous-titre quand la section est le dernier bloc de la page ;
/// 6. « Prévision du mar. 10 nov. · 08:30 » et le bouton ⓘ de la source
///    ([WeatherForecastFooter]).
///
/// [departureOnly] — sorties à plusieurs groupes — ne garde que 1, 2 et 6.
/// Un leg sans frise (`NO_LOCATION`, `UNAVAILABLE`, `NOT_YET_AVAILABLE`…) se
/// résume à son bandeau ([WeatherLegNotice]) à la place de 3 à 5.
///
/// Les autres statuts de [view] : `unavailable` rend « Météo indisponible »
/// et « Réessayer » ([onRetry]), `notYetAvailable` la date d'ouverture
/// ([availableFrom]), `noLocation` le mot aux organisateurs
/// ([noLocationMessage]). `hidden` (`OUT_OF_RANGE`, `NO_LOCATION` pour qui
/// n'organise pas, statut inconnu) garde le titre « Météo » et une ligne
/// d'explication ([emptyMessage]) : la section ne disparaît plus (décision
/// du 2026-11-10, docs/LEDGER_*.md MOB-134). [shows] dit encore si la
/// section a autre chose que cette ligne à montrer.
///
/// Une `Column` au rythme de [DetailSection] (marges latérales comprises) ;
/// [WeatherSection.sliver] la pose dans un `CustomScrollView`. Aucune
/// requête : l'écran lit la météo et passe ce qu'il faut.
class WeatherSection extends ConsumerWidget {
  const WeatherSection({
    super.key,
    required this.view,
    required this.timezone,
    this.departure,
    this.departureAt,
    this.leg,
    this.departureOf = WeatherDepartureOf.leg,
    this.groupStartAt,
    this.attribution,
    this.fetchedAt,
    this.availableFrom,
    this.collapsed = false,
    this.departureOnly = false,
    this.speedDefaultKey = 'rides.weather.legSpeedDefault',
    this.noLocationMessage,
    this.emptyMessage,
    this.onRetry,
    this.onCheckpointTap,
    this.selectedCheckpoint,
  });

  /// La même section, dans un `SliverToBoxAdapter`.
  static Widget sliver({
    Key? key,
    required RideWeatherView view,
    required String? timezone,
    DepartureWeatherDto? departure,
    String? departureAt,
    WeatherLegDto? leg,
    WeatherDepartureOf departureOf = WeatherDepartureOf.leg,
    String? groupStartAt,
    WeatherAttributionDto? attribution,
    DateTime? fetchedAt,
    DateTime? availableFrom,
    bool collapsed = false,
    bool departureOnly = false,
    String speedDefaultKey = 'rides.weather.legSpeedDefault',
    String? noLocationMessage,
    String? emptyMessage,
    VoidCallback? onRetry,
    ValueChanged<WeatherCheckpointDto>? onCheckpointTap,
    int? selectedCheckpoint,
  }) => SliverToBoxAdapter(
    child: WeatherSection(
      key: key,
      view: view,
      timezone: timezone,
      departure: departure,
      departureAt: departureAt,
      leg: leg,
      departureOf: departureOf,
      groupStartAt: groupStartAt,
      attribution: attribution,
      fetchedAt: fetchedAt,
      availableFrom: availableFrom,
      collapsed: collapsed,
      departureOnly: departureOnly,
      speedDefaultKey: speedDefaultKey,
      noLocationMessage: noLocationMessage,
      emptyMessage: emptyMessage,
      onRetry: onRetry,
      onCheckpointTap: onCheckpointTap,
      selectedCheckpoint: selectedCheckpoint,
    ),
  );

  /// Le rendu du statut (`rideWeatherViewOf`), calculé par l'écran.
  final RideWeatherView view;

  /// Le fuseau de la sortie ou de l'étape : heure du départ, lever et
  /// coucher du soleil, passages et alerte s'y lisent, sans mention
  /// (docs/LEDGER_*.md API-60).
  final String? timezone;

  /// Les conditions au départ de la sortie ou de l'étape
  /// (`RideWeatherDto.departure`, `TripStageWeatherDto.departure`).
  final DepartureWeatherDto? departure;

  /// L'instant que [departure] décrit (`RideDto.dateTime`, ou le départ de
  /// l'étape).
  final String? departureAt;

  /// Le leg du groupe ou de l'étape ; `null` : le départ seul.
  final WeatherLegDto? leg;

  final WeatherDepartureOf departureOf;

  /// Le départ du groupe (`RideGroupDto.startAt`) quand la section est celle
  /// d'un groupe : s'il diffère de [departureAt] et que le leg ne porte pas
  /// son propre départ, le titre dit « Météo au départ de la sortie, 21:30 »
  /// — la prévision est à l'heure de la sortie (ledger `BRAND-8`).
  final String? groupStartAt;

  /// Le crédit des prévisions, derrière le bouton ⓘ ; `null` : pas de bouton.
  final WeatherAttributionDto? attribution;

  /// L'émission de la prévision lue — « Prévision du … ».
  final DateTime? fetchedAt;

  /// L'ouverture de la prévision, pour `notYetAvailable`.
  final DateTime? availableFrom;

  /// Replier « Météo le long du parcours » : du contenu suit la section.
  final bool collapsed;

  /// Les conditions au départ seulement : ni vent ni frise.
  final bool departureOnly;

  /// La phrase de la vitesse par défaut (« le groupe », « l'étape »).
  final String speedDefaultKey;

  /// Le mot aux organisateurs de `noLocation` ; celui d'une sortie par
  /// défaut.
  final String? noLocationMessage;

  /// La ligne de `hidden` ; celle d'une sortie par défaut
  /// (`rides.weather.emptyMessage`).
  final String? emptyMessage;

  /// « Réessayer » de `unavailable`.
  final VoidCallback? onRetry;

  /// Toucher d'un point de la frise (le réticule de la carte, ledger
  /// `MOB-93`) ; `null` : les points ne se touchent pas.
  final ValueChanged<WeatherCheckpointDto>? onCheckpointTap;

  /// L'`index` du point dont le réticule est sur la carte.
  final int? selectedCheckpoint;

  /// La section a-t-elle, pour [view], autre chose à montrer que la ligne
  /// « Aucune prévision… » de `hidden` ?
  static bool shows(RideWeatherView view) => view != RideWeatherView.hidden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlTypography t = context.pdlText;
    final List<Widget> body = switch (view) {
      RideWeatherView.hidden => <Widget>[
        Text(
          emptyMessage ?? 'rides.weather.emptyMessage'.tr(),
          key: keys.ride.weatherEmpty,
          style: t.sub,
        ),
      ],
      RideWeatherView.unavailable => <Widget>[
        WeatherUnavailableState(onRetry: onRetry ?? () {}),
      ],
      RideWeatherView.noLocation => <Widget>[
        PdlBanner(
          key: keys.ride.weatherNoLocation,
          tone: PdlBannerTone.info,
          icon: PdlIcons.weatherUnknown,
          message: noLocationMessage ?? 'rides.weather.noLocation'.tr(),
        ),
      ],
      RideWeatherView.notYetAvailable => <Widget>[
        PdlBanner(
          key: keys.ride.weatherNotYetAvailable,
          tone: PdlBannerTone.info,
          icon: PdlIcons.date,
          message: notYetAvailableMessage(availableFrom),
        ),
      ],
      RideWeatherView.forecast ||
      RideWeatherView.stale => _forecast(context, ref),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DetailSection(
          key: keys.ride.weatherSection,
          title: 'rides.weather.title'.tr(),
        ),
        for (final Widget w in body)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
            child: w,
          ),
      ],
    );
  }

  List<Widget> _forecast(BuildContext context, WidgetRef ref) {
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);
    final WeatherLegDto? leg = departureOnly ? null : this.leg;
    final ({DepartureWeatherDto? dto, String? at, bool ofRide}) start =
        _departure();

    const Widget subsectionGap = SizedBox(
      height: PdlSpacing.detailSubsectionGap,
    );
    Widget subsection(
      String title, {
      Key? key,
      EdgeInsetsGeometry padding = const EdgeInsets.only(
        bottom: PdlSpacing.chipGap,
      ),
    }) => Semantics(
      header: true,
      child: PdlSectionHeader(
        key: key,
        title: title,
        subsection: true,
        padding: padding,
      ),
    );

    return <Widget>[
      if (view == RideWeatherView.stale) ...<Widget>[
        const SizedBox(height: PdlSpacing.chipGap),
        WeatherStaleBanner(fetchedAt: fetchedAt),
      ],
      if (_showsDeparture(start.dto)) ...<Widget>[
        const SizedBox(height: PdlSpacing.badgeGap),
        subsection(
          departureWeatherTitle(start.at, timezone, ofRide: start.ofRide),
          key: keys.rideGroup.departureWeatherTitle,
        ),
        PdlCard(
          child: start.dto!.conditions == null
              ? Text('rides.weather.unavailableTitle'.tr(), style: t.sub)
              : DepartureConditionsBlock(
                  conditions: start.dto!.conditions!,
                  units: units,
                  sunrise: start.dto!.sunrise,
                  sunset: start.dto!.sunset,
                  timezone: timezone,
                ),
        ),
      ],
      if (leg != null) ..._leg(t, units, leg, subsection, subsectionGap),
      if (attribution != null || fetchedAt != null) ...<Widget>[
        const SizedBox(height: PdlSpacing.chipGap),
        WeatherForecastFooter(attribution: attribution, fetchedAt: fetchedAt),
      ],
    ];
  }

  List<Widget> _leg(
    PdlTypography t,
    UnitSystem units,
    WeatherLegDto leg,
    Widget Function(String, {Key? key, EdgeInsetsGeometry padding}) subsection,
    Widget subsectionGap,
  ) {
    if (WeatherLegNotice.shows(leg)) {
      return <Widget>[subsectionGap, WeatherLegNotice(leg: leg)];
    }
    final String speed = weatherLegSpeedLine(
      leg,
      units,
      speedDefaultKey: speedDefaultKey,
    );
    final Widget timeline = WeatherTimeline(
      leg: leg,
      timezone: timezone,
      onTap: onCheckpointTap,
      selected: selectedCheckpoint,
    );
    return <Widget>[
      if (leg.rainAlert != null) ...<Widget>[
        subsectionGap,
        WeatherRainAlertBanner(alert: leg.rainAlert!, timezone: timezone),
      ],
      if (leg.segments.isNotEmpty) ...<Widget>[
        subsectionGap,
        subsection('rides.weather.exposureTitle'.tr()),
        WeatherExposureCard(leg: leg),
      ],
      subsectionGap,
      if (collapsed)
        PdlDisclosure(
          key: keys.ride.weatherAlongRoute,
          title: 'rides.weather.alongRouteTitle'.tr(),
          subtitles: <String>[weatherLegPointsLine(leg, timezone), speed],
          child: timeline,
        )
      else ...<Widget>[
        subsection(
          'rides.weather.alongRouteTitle'.tr(),
          key: keys.ride.weatherAlongRoute,
          padding: EdgeInsets.zero,
        ),
        Text(speed, style: t.xs),
        const SizedBox(height: PdlSpacing.chipGap),
        timeline,
      ],
    ];
  }

  /// Un départ se montre avec ses conditions ; sans elles, « Météo
  /// indisponible » dans la carte pour un départ prévu (`OK` / `STALE`), et
  /// rien pour les autres statuts.
  static bool _showsDeparture(DepartureWeatherDto? dto) {
    if (dto == null) return false;
    if (dto.conditions != null) return true;
    final WeatherStatus status = WeatherStatus.fromJson(dto.status);
    return status == WeatherStatus.ok || status == WeatherStatus.stale;
  }

  /// Les conditions et l'heure du départ, et si le titre doit dire « de la
  /// sortie » : un groupe qui part à son heure sans leg qui la porte garde
  /// l'heure de la sortie, celle de la prévision (ledger `BRAND-8`).
  ({DepartureWeatherDto? dto, String? at, bool ofRide}) _departure() {
    final WeatherLegDto? leg = this.leg;
    if (departureOf == WeatherDepartureOf.leg && leg?.departure != null) {
      return (dto: leg!.departure, at: leg.startTime, ofRide: false);
    }
    final bool ofRide =
        departureOf == WeatherDepartureOf.leg &&
        groupStartAt != null &&
        departureAt != null &&
        groupLeavesAtOwnTime(groupStartAt!, departureAt!);
    return (dto: departure, at: departureAt, ofRide: ofRide);
  }
}
