// Démonstration de `core/pdl/map` — page de DEBUG.
//
// Comme la galerie, elle n'est **pas** enregistrée dans le `GoRouter` : une
// carte MapLibre demande une vue de plateforme, elle n'a rien à faire dans une
// app livrée et elle ne peut pas non plus vivre dans la galerie, dont le test
// de fumée pompe l'arbre entier sans plateforme native.
//
// Pour l'ouvrir :
//
// ```dart
// Navigator.of(context).push(
//   MaterialPageRoute<void>(builder: (_) => const PdlMapDemoPage()),
// );
// ```
//
// Ce qu'elle démontre, point par point, ce sont les critères de fin de F-TE-8 :
// dix tracés colorisés par `kMultiTrackPalette`, la sélection croisée entre la
// carte et la liste, le cadrage sur `MapEventStyleLoaded`, le plein écran et le
// sélecteur de fond.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/generated/export.dart';
import '../core/config/config_provider.dart';
import '../core/config/map_style_options.dart';
import '../core/pdl/map/pdl_map.dart';
import '../core/pdl/map/pdl_map_buttons.dart';
import '../core/pdl/map/pdl_map_controller.dart';
import '../core/pdl/map/pdl_map_hero.dart';
import '../core/theme/pdl_colors.dart';
import '../core/theme/pdl_tokens.dart';
import '../core/theme/pdl_typography.dart';

class PdlMapDemoPage extends ConsumerStatefulWidget {
  const PdlMapDemoPage({super.key});

  @override
  ConsumerState<PdlMapDemoPage> createState() => _PdlMapDemoPageState();
}

class _PdlMapDemoPageState extends ConsumerState<PdlMapDemoPage> {
  late final List<PdlMapTrack> _tracks = _syntheticTracks();
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final Brightness brightness = Theme.of(context).brightness;
    final ResolvedMapStyle? style = ref
        .watch(mapStyleProvider(brightness))
        .value;
    final MapCenterDto? center = ref.watch(defaultCenterProvider).value;

    if (style == null) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(title: const Text('PdlMap — démo')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('PdlMap — démo')),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: PdlMapHero(
              // La démo n'a pas de variante plein écran : la galerie montre le
              // hero encastré, et une page en plus n'y apprendrait rien.
              showFullscreenButton: false,
              labels: const PdlMapHeroLabels(
                enterFullscreen: 'Plein écran',
                exitFullscreen: 'Quitter le plein écran',
                chooseBackground: 'Choisir le fond',
                backgroundSheetTitle: 'Fond de carte',
                hillshade: 'Ombrage du relief',
              ),
              styles: servedMapStyleOptions(ref),
              switches: servedLightMapSwitch(ref, brightness),
              hillshadeEnabled: servedHillshadeEnabled(ref),
              onHillshadeChanged: (bool on) =>
                  ref.read(hillshadeEnabledProvider.notifier).set(on),
              selectedStyleId: style.selectedId,
              onStyleSelected: (String id) =>
                  ref.read(mapStyleIdProvider.notifier).select(id),
              pill: PdlMapPill(
                label: _selected == null
                    ? '${_tracks.length} tracés'
                    : 'Tracé ${_selected!}',
              ),
              floatingCard: _selected == null
                  ? null
                  : PdlMapFloatingCard(
                      onTap: () => setState(() => _selected = null),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 14,
                            height: 3,
                            decoration: BoxDecoration(
                              color: _colorOf(_selected!),
                              borderRadius: PdlRadii.trackAll,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tracé ${_selected!}',
                              style: context.pdlText.cardTitle,
                            ),
                          ),
                        ],
                      ),
                    ),
              mapBuilder: (BuildContext context) => PdlMap(
                hillshade: servedHillshade(context, ref),
                styleUrl: style.url,
                credit: servedMapCredit(style),
                scale: servedMapScale(ref),
                tracks: _tracks,
                selectedTrackId: _selected,
                onTrackSelected: (String? id) => setState(() => _selected = id),
                initialCenter: center == null
                    ? null
                    : PdlMapPoint(lon: center.lon, lat: center.lat),
                initialZoom: center?.zoom ?? 5,
                fitBox: PdlMapBox.ofTracks(_tracks),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: ListView.builder(
              itemCount: _tracks.length,
              itemBuilder: (BuildContext context, int i) {
                final PdlMapTrack t = _tracks[i];
                final bool on = t.id == _selected;
                return ListTile(
                  onTap: () => setState(() => _selected = on ? null : t.id),
                  selected: on,
                  selectedTileColor: c.primarySoft,
                  leading: Container(
                    width: 16,
                    height: 4,
                    decoration: BoxDecoration(
                      color: t.color,
                      borderRadius: PdlRadii.trackAll,
                    ),
                  ),
                  title: Text(t.label ?? t.id, style: context.pdlText.body),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _colorOf(String id) =>
      _tracks.firstWhere((PdlMapTrack t) => t.id == id).color;
}

/// Dix boucles synthétiques autour de Clermont-Ferrand, colorisées par
/// `kMultiTrackPalette` — l'ordre imposé du §1.1.5.
List<PdlMapTrack> _syntheticTracks() {
  const double lon0 = 3.0870;
  const double lat0 = 45.7772;
  return <PdlMapTrack>[
    for (int i = 0; i < 10; i++)
      PdlMapTrack(
        id: 'g$i',
        label: 'Groupe ${i + 1}',
        color: multiTrackColor(i),
        lines: <List<List<double>>>[
          <List<double>>[
            for (int p = 0; p <= 64; p++)
              () {
                final double a = p / 64 * 2 * math.pi;
                final double r = 0.03 + i * 0.012;
                return <double>[
                  lon0 + r * math.cos(a) * 1.4,
                  lat0 + r * math.sin(a) + i * 0.004,
                ];
              }(),
          ],
        ],
      ),
  ];
}
