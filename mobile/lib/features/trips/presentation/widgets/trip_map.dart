import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/config/config_provider.dart';
import '../../../../core/config/map_style_options.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../keys.dart';
import '../../../rides/presentation/widgets/ride_weather_map_markers.dart';
import '../../../rides/presentation/widgets/ride_wind_map_legend.dart';
import '../../../rides/presentation/widgets/weather_map_layer.dart';
import '../../domain/trip_weather_map.dart';
import '../../providers/trip_detail_provider.dart';
import '../../providers/trip_tracks_provider.dart';

/// Hauteur de la carte interactive du voyage.
const double _kTripMapHeight = 280;

/// La carte multi-étapes, et la moitié cartographique de la sélection croisée.
///
/// **Une couche par étape**, toutes adossées à la même source : `queryLayers`
/// rend le `layerId` sans les propriétés de l'entité touchée, si bien que seul
/// le nom de la couche porte l'identité d'un tracé (§1.0.3-7). Sélectionner ne
/// reconstruit donc pas la carte — `PdlMap` repeint deux couches.
///
/// La carte se **remplit progressivement** : le hero porte la vignette statique
/// pendant ce temps, et les étapes apparaissent dans l'ordre du voyage.
///
/// **Le mode « Météo »** (ledger `MOB-94`) colore chaque étape par **son
/// propre vent**, à son jour, et pose en plein écran les pastilles de toutes
/// les étapes, chacune à l'heure de sa zone. Proposé dès qu'une étape a une
/// prévision ([tripMapWindLegs]) ; une puce sous la carte encastrée,
/// l'interrupteur de la feuille des couches en plein écran, éteint par
/// défaut ([tripMapWindModeProvider]). Une étape sans prévision — déjà
/// partie, trop lointaine — garde sa couleur, jamais le gris du travers ; la
/// légende additionne les parts des étapes colorées et dit lesquelles.
class TripMap extends ConsumerWidget {
  const TripMap({
    super.key,
    required this.tripKey,
    required this.trip,
    required this.selectedStageId,
    required this.onSelect,
    this.fullscreen = false,
  });

  final TripKey tripKey;
  final TripDto trip;
  final String? selectedStageId;
  final ValueChanged<String> onSelect;

  /// Vrai dans la page plein écran, que ce widget construit lui-même : la
  /// carte y prend la page, sans titre ni légende. Le plein écran reconstruit
  /// `TripMap` plutôt que de recopier son hero — voir
  /// `PdlMapHero.fullscreenBuilder`.
  final bool fullscreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final Brightness brightness = Theme.of(context).brightness;
    final AsyncValue<ResolvedMapStyle?> style = ref.watch(
      mapStyleProvider(brightness),
    );
    final TripTracksState tracks = ref.watch(tripTracksProvider(tripKey));
    final List<TripStageDto> stages = trip.orderedStages;

    // Un voyage sans tracé ne rend pas une carte vide : il ne rend pas de
    // carte. Le bloc entier disparaît (§4.1).
    if (stages.every((TripStageDto s) => s.route == null)) {
      return const SizedBox.shrink();
    }

    final ResolvedMapStyle? resolved = style.value;
    // Le vent, étape par étape : une prévision, et le mode choisi.
    final Map<String, WeatherLegDto> windLegs = tripMapWindLegs(
      trip,
      watchTripMapWeather(ref, tripKey, trip),
    );
    final bool windMode =
        windLegs.isNotEmpty && ref.watch(tripMapWindModeProvider(tripKey));
    final List<PdlMapTrack> mapTracks = _tracks(
      stages,
      tracks,
      windMode ? windLegs : const <String, WeatherLegDto>{},
    );
    final TripStageDto? selected = _selectedStage(stages);
    final UnitSystem units = ref.watch(unitSystemProvider);
    final List<PdlMapMarker> weatherMarkers = fullscreen && windMode
        ? _weatherMarkers(stages, tracks, windLegs, units)
        : const <PdlMapMarker>[];

    // Pas de légende tant qu'aucune étape colorée n'est dessinée (géométries
    // encore en vol, ou en échec) : elle n'aurait aucune part à montrer.
    final Widget? legend = windMode
        ? _legend(stages, tracks, windLegs, units, ref)
        : null;

    final Widget? hero = resolved == null
        ? null
        : PdlMapHero(
            height: fullscreen ? null : _kTripMapHeight,
            isFullscreen: fullscreen,
            fullscreenBuilder: fullscreen
                ? null
                : (BuildContext context) => TripMap(
                    tripKey: tripKey,
                    trip: trip,
                    selectedStageId: selectedStageId,
                    onSelect: onSelect,
                    fullscreen: true,
                  ),
            labels: PdlMapHeroLabels(
              enterFullscreen: 'map.fullscreen'.tr(),
              exitFullscreen: 'map.exitFullscreen'.tr(),
              chooseBackground: 'map.chooseBackground'.tr(),
              backgroundSheetTitle: 'map.background'.tr(),
              hillshade: 'map.hillshade'.tr(),
            ),
            styles: servedMapStyleOptions(ref),
            hillshadeEnabled: servedHillshadeEnabled(ref),
            onHillshadeChanged: (bool on) =>
                ref.read(hillshadeEnabledProvider.notifier).set(on),
            selectedStyleId: resolved.style.id,
            onStyleSelected: (String id) =>
                ref.read(mapStyleIdProvider.notifier).select(id),
            // En plein écran, le mode « Météo » se bascule dans la feuille,
            // comme l'ombrage ; la carte encastrée a sa puce sous elle.
            switches: fullscreen && windLegs.isNotEmpty
                ? <PdlMapHeroSwitch>[
                    weatherMapModeSwitch(
                      value: windMode,
                      onChanged: (bool on) =>
                          ref
                                  .read(
                                    tripMapWindModeProvider(tripKey).notifier,
                                  )
                                  .state =
                              on,
                    ),
                  ]
                : const <PdlMapHeroSwitch>[],
            foreground: legend == null
                ? null
                : weatherMapLegendLayer(fullscreen: fullscreen, legend: legend),
            pill: selected == null
                ? null
                : PdlMapPill(
                    label: _pillLabel(selected),
                    leading: PdlColorTrack(
                      color: multiTrackColor(selected.paletteIndex),
                      shape: PdlColorTrackShape.legend,
                    ),
                  ),
            mapBuilder: (BuildContext context) => _native(
              PdlMap(
                markers: weatherMarkers,
                onMarkerTapped: weatherMarkers.isEmpty
                    ? null
                    : (String id) =>
                          _openMarker(context, id, stages, windLegs, units),
                hillshade: servedHillshade(context, ref),
                styleUrl: resolved.url,
                credit: servedMapCredit(resolved),
                // Encastrée dans la page qui défile : ni déplacement ni zoom hors
                // plein écran. Le tap, qui choisit l'étape, reste actif.
                interactive: fullscreen,
                tracks: mapTracks,
                start: _point(stages.first.startPlace),
                end: _point(stages.last.endPlace),
                initialCenter: _defaultCenter(ref),
                // L'emprise servie, jamais une boîte recalculée sur les sommets
                // déjà chargés : elle arrive avec le premier lot et couvre les
                // étapes encore en vol, là où la seconde recadrait la carte à
                // chaque étape qui atterrissait.
                fitBox: _fitBox(tracks.extent) ?? PdlMapBox.ofTracks(mapTracks),
                selectedTrackId: selectedStageId,
                onTrackSelected: (String? id) {
                  if (id != null) onSelect(id);
                },
              ),
            ),
          );

    // La page plein écran n'est que la carte : ni titre de section, ni
    // légende, ni avertissement de troncature — la page qui l'a poussée les
    // porte déjà.
    if (fullscreen) return hero ?? const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('trips.tripTrack'.tr(), style: t.sectionTitle),
        ),
        SizedBox(
          height: _kTripMapHeight,
          child:
              hero ??
              PdlSkeleton(
                height: _kTripMapHeight,
                borderRadius: PdlRadii.mdAll,
              ),
        ),
        if (windLegs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: PdlSpacing.chipGap),
            child: WeatherMapChip(
              chipKey: keys.trip.windMapChip,
              selected: windMode,
              onChanged: (bool on) =>
                  ref.read(tripMapWindModeProvider(tripKey).notifier).state =
                      on,
            ),
          ),
        if (stages.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: PdlLegendRow(
              entries: <PdlLegendEntry>[
                for (final TripStageDto s in stages)
                  PdlLegendEntry(
                    color: multiTrackColor(s.paletteIndex),
                    label: s.name,
                    onTap: () => onSelect(s.id),
                  ),
              ],
              activeIndex: stages.indexWhere(
                (TripStageDto s) => s.id == selectedStageId,
              ),
            ),
          ),
        if (tracks.truncated || tracks.failed.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: <Widget>[
                Icon(PdlIcons.info, size: 15, color: c.textDimmed),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tracks.truncated
                        ? 'trips.partialTrack'.tr(
                            namedArgs: <String, String>{
                              'shown': '${tracks.requested}',
                              'total': '${tracks.total}',
                            },
                          )
                        : 'trips.missingTracks'.tr(
                            namedArgs: <String, String>{
                              'count': '${tracks.failed.length}',
                            },
                          ),
                    style: t.xs,
                  ),
                ),
                if (tracks.failed.isNotEmpty)
                  PdlButton(
                    label: 'common.retry'.tr(),
                    variant: PdlButtonVariant.text,
                    size: PdlButtonSize.sm,
                    onPressed: ref
                        .read(tripTracksProvider(tripKey).notifier)
                        .retryFailed,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// Un tracé par **étape**, pas par parcours : deux étapes qui partagent un
  /// parcours doivent chacune être sélectionnables, et chacune porte la couleur
  /// de son rang.
  ///
  /// En mode « Météo », une étape de [windLegs] est colorée par son propre
  /// vent ; les autres gardent leur couleur.
  List<PdlMapTrack> _tracks(
    List<TripStageDto> stages,
    TripTracksState state,
    Map<String, WeatherLegDto> windLegs,
  ) {
    final List<PdlMapTrack> tracks = <PdlMapTrack>[];
    for (final TripStageDto stage in stages) {
      final String? slug = stage.route?.slug;
      final RouteDetailDto? route = slug == null
          ? null
          : state.geometries[slug];
      if (route == null) continue;
      final Color color = multiTrackColor(stage.paletteIndex);
      final WeatherLegDto? leg = windLegs[stage.id];
      tracks.add(
        PdlMapTrack(
          id: stage.id,
          lines: routeLinesOf(route),
          color: color,
          label: stage.name,
          segmentColors: leg == null
              ? null
              : weatherTrackColors(route, leg, color),
          // Sans sélection, toutes les étapes sont à l'opacité d'un tracé
          // non sélectionné : le vent y ressortirait délavé, loin des teintes
          // de la légende.
          emphasized: leg != null,
        ),
      );
    }
    // L'étape sélectionnée est dessinée **en dernier** : MapLibre n'a pas de
    // `zIndex` sur les lignes, c'est l'ordre d'ajout qui décide.
    final int index = tracks.indexWhere(
      (PdlMapTrack t) => t.id == selectedStageId,
    );
    if (index >= 0) tracks.add(tracks.removeAt(index));
    return tracks;
  }

  /// Le préfixe des marqueurs météo d'une étape : les pastilles de toutes
  /// les étapes partagent la carte, leurs ids doivent rester distincts.
  static String _markerPrefix(TripStageDto stage) => 'stage.${stage.id}/';

  /// Les pastilles de **toutes** les étapes colorées, chacune sur son
  /// parcours et à l'heure de **sa** zone (`TripStageDto.timezone`).
  List<PdlMapMarker> _weatherMarkers(
    List<TripStageDto> stages,
    TripTracksState state,
    Map<String, WeatherLegDto> windLegs,
    UnitSystem units,
  ) => <PdlMapMarker>[
    for (final TripStageDto stage in stages)
      if (windLegs[stage.id] case final WeatherLegDto leg)
        if (state.geometries[stage.route?.slug] case final RouteDetailDto route)
          ...weatherMarkersOnRoute(
            route,
            leg,
            units: units,
            timezone: stage.timezone,
            idPrefix: _markerPrefix(stage),
          ),
  ];

  /// Ouvre le détail d'une pastille : celle de l'étape dont l'id porte le
  /// préfixe, dans la zone de cette étape.
  void _openMarker(
    BuildContext context,
    String id,
    List<TripStageDto> stages,
    Map<String, WeatherLegDto> windLegs,
    UnitSystem units,
  ) {
    for (final TripStageDto stage in stages) {
      final String prefix = _markerPrefix(stage);
      final WeatherLegDto? leg = windLegs[stage.id];
      if (leg == null || !id.startsWith(prefix)) continue;
      openWeatherMapMarker(
        context,
        id,
        leg: leg,
        units: units,
        timezone: stage.timezone,
        idPrefix: prefix,
      );
      return;
    }
  }

  /// La légende des étapes colorées : leurs parts **additionnées**, et ce
  /// qu'elles recouvrent — toutes les étapes tracées, ou seulement celles
  /// qui ont une prévision (une étape partie ou trop lointaine n'en a pas).
  /// `null` quand aucune étape colorée n'est encore dessinée.
  Widget? _legend(
    List<TripStageDto> stages,
    TripTracksState state,
    Map<String, WeatherLegDto> windLegs,
    UnitSystem units,
    WidgetRef ref,
  ) {
    final List<TripStageDto> drawn = <TripStageDto>[
      for (final TripStageDto s in stages)
        if (state.geometries.containsKey(s.route?.slug)) s,
    ];
    final List<TripStageDto> colored = <TripStageDto>[
      for (final TripStageDto s in drawn)
        if (windLegs.containsKey(s.id)) s,
    ];
    if (colored.isEmpty) return null;
    final String? scope = colored.length == drawn.length
        ? (colored.length > 1
              ? 'trips.weather.mapSharesAll'.tr(
                  namedArgs: <String, String>{'count': '${colored.length}'},
                )
              : null)
        : colored.length == 1
        ? 'trips.weather.mapSharesOne'.tr(
            namedArgs: <String, String>{'stage': colored.single.name},
          )
        : 'trips.weather.mapSharesSome'.tr(
            namedArgs: <String, String>{
              'count': '${colored.length}',
              'total': '${drawn.length}',
            },
          );
    return RideWindMapLegend.combined(
      key: keys.trip.windMapLegend,
      legs: <WeatherLegDto>[
        for (final TripStageDto s in colored) windLegs[s.id]!,
      ],
      units: units,
      scopeNote: scope,
      attribution: watchTripMapWeather(ref, tripKey, trip)?.attribution,
    );
  }

  /// Vrai dans un test de widget : MapLibre n'y a pas de vue native, et la
  /// carte y est remplacée par [TripMapProbe], qui garde le `PdlMap`
  /// construit pour qu'on lise ses tracés et ses marqueurs.
  @visibleForTesting
  static bool debugSkipNativeMap = false;

  Widget _native(PdlMap map) =>
      debugSkipNativeMap ? TripMapProbe(map: map) : map;

  /// « J1 · Clermont-Ferrand → Issoire ».
  String _pillLabel(TripStageDto stage) {
    final String? from = stage.startPlace?.name;
    final String? to = stage.endPlace?.name;
    if (from == null || to == null) return stage.name;
    return '${stage.name} · $from → $to';
  }

  TripStageDto? _selectedStage(List<TripStageDto> stages) {
    for (final TripStageDto s in stages) {
      if (s.id == selectedStageId) return s;
    }
    return null;
  }

  PdlMapPoint? _point(PlaceDetailDto? place) {
    final List<double>? c = place?.geometry?.coordinates;
    if (c == null || c.length < 2) return null;
    return PdlMapPoint(lon: c[0], lat: c[1], label: place!.name);
  }

  /// L'emprise servie, convertie pour la carte. `null` tant que le premier lot
  /// n'est pas revenu — le repli sur les tracés tient alors le cadrage.
  PdlMapBox? _fitBox(BoundsDto? extent) => extent == null
      ? null
      : PdlMapBox(
          minLon: extent.minLon,
          minLat: extent.minLat,
          maxLon: extent.maxLon,
          maxLat: extent.maxLat,
        );

  PdlMapPoint? _defaultCenter(WidgetRef ref) {
    final MapCenterDto? center = ref.watch(defaultCenterProvider).value;
    if (center == null) return null;
    return PdlMapPoint(lon: center.lon, lat: center.lat);
  }
}

/// La carte d'un test de widget ([TripMap.debugSkipNativeMap]) : un fond
/// vide qui porte le `PdlMap` que l'écran aurait rendu.
@visibleForTesting
class TripMapProbe extends StatelessWidget {
  const TripMapProbe({super.key, required this.map});

  final PdlMap map;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
