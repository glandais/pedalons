import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/config/config_provider.dart';
import '../../../../core/config/map_style_options.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/map/pdl_map.dart';
import '../../../../core/pdl/map/pdl_map_buttons.dart';
import '../../../../core/pdl/map/pdl_map_camera.dart';
import '../../../../core/pdl/map/pdl_map_controller.dart';
import '../../../../core/pdl/map/pdl_map_hero.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../keys.dart';
import '../../../geocoding/presentation/geocoded_place_picker.dart';

/// Un lieu choisi : la carte s'y cadre à peu près à l'échelle d'une ville
/// (±0,02° autour du point).
const double _kPlaceSpan = 0.02;

/// La carte sans tracé des outils GPX (`gpxToolsBlankMap`, docs/LEDGER_*.md
/// MOB-178), la page `GpxBlankMapPage` du site : plein écran d'emblée, les
/// fonds de carte servis, l'ombrage du relief, et la recherche d'un lieu —
/// celle des formulaires (`pickGeocodedPlace`, `GET /api/geocode/search`), qui
/// recadre la carte sur l'adresse choisie. « Fermer » revient à l'accueil des
/// outils.
///
/// **Pas de « Me localiser »** (décision D4 du plan) : l'usage déclaré de la
/// position n'en couvre pas l'affichage sur une carte (ledgers `MOB-131`,
/// `MOB-170`, la règle de `kPlannerLocate`).
class GpxBlankMapPage extends ConsumerStatefulWidget {
  const GpxBlankMapPage({super.key, this.initialView});

  /// La caméra de `?map=z/lat/lon` (un lien du site), à la place du centre par
  /// défaut ; `null` : le centre par défaut.
  final PdlMapCamera? initialView;

  @override
  ConsumerState<GpxBlankMapPage> createState() => _GpxBlankMapPageState();
}

class _GpxBlankMapPageState extends ConsumerState<GpxBlankMapPage> {
  final PdlMapController _controller = PdlMapController();

  /// Le cadre du dernier lieu choisi ; `null` : le centre par défaut.
  PdlMapBox? _place;
  bool _searching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_searching) return;
    setState(() => _searching = true);
    try {
      final GeocodedPick? pick = await pickGeocodedPlace(
        context,
        ref,
        title: 'map.searchPlace'.tr(),
      );
      if (!mounted) return;
      if (pick case GeocodedPlace(:final double lat, :final double lon)) {
        setState(
          () => _place = PdlMapBox.ofPoints(<PdlMapPoint>[
            PdlMapPoint(lon: lon - _kPlaceSpan, lat: lat - _kPlaceSpan),
            PdlMapPoint(lon: lon + _kPlaceSpan, lat: lat + _kPlaceSpan),
          ]),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final AsyncValue<ResolvedMapStyle?> style = ref.watch(
      mapStyleProvider(brightness),
    );
    final MapCenterDto? center = ref.watch(defaultCenterProvider).value;
    final ResolvedMapStyle? resolved = style.value;

    final Widget body;
    if (resolved == null || center == null) {
      // Ni style servi ni centre : pas de carte à une position inventée.
      body = ColoredBox(
        color: context.pdl.surfaceAlt,
        child: Center(
          child: style.hasError
              ? Text('map.unavailable'.tr())
              : const CircularProgressIndicator(),
        ),
      );
    } else {
      body = PdlMapHero(
        labels: PdlMapHeroLabels(
          enterFullscreen: 'map.fullscreen'.tr(),
          exitFullscreen: 'map.exitFullscreen'.tr(),
          chooseBackground: 'map.chooseBackground'.tr(),
          backgroundSheetTitle: 'map.background'.tr(),
          hillshade: 'map.hillshade'.tr(),
        ),
        // Déjà plein écran : « Fermer » quitte la page.
        isFullscreen: true,
        switches: servedLightMapSwitch(ref, brightness),
        styles: servedMapStyleOptions(ref),
        hillshadeEnabled: servedHillshadeEnabled(ref),
        onHillshadeChanged: (bool on) =>
            ref.read(hillshadeEnabledProvider.notifier).set(on),
        selectedStyleId: resolved.selectedId,
        onStyleSelected: (String id) =>
            ref.read(mapStyleIdProvider.notifier).select(id),
        extraButtons: <Widget>[
          PdlMapButton(
            icon: PdlIcons.search,
            semanticLabel: 'map.searchPlace'.tr(),
            onPressed: _search,
          ),
        ],
        mapBuilder: (BuildContext context) => PdlMap(
          controller: _controller,
          styleUrl: resolved.url,
          credit: servedMapCredit(resolved),
          scale: servedMapScale(ref),
          hillshade: servedHillshade(context, ref),
          initialCenter: PdlMapPoint(
            lon: widget.initialView?.lon ?? center.lon,
            lat: widget.initialView?.lat ?? center.lat,
          ),
          initialZoom: widget.initialView?.zoom ?? center.zoom,
          fitBox: _place,
          fitPadding: EdgeInsets.zero,
        ),
      );
    }

    return Scaffold(
      key: keys.gpxTools.blankMap,
      body: SafeArea(bottom: false, child: body),
    );
  }
}
