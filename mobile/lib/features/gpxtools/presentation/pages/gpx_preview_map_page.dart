import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../keys.dart';
import '../../../routes/domain/shown_route.dart';
import '../../../routes/presentation/widgets/route_map.dart';
import '../../providers/gpx_preview_provider.dart';
import '../widgets/gpx_preview_map_layer.dart';

/// La carte plein écran d'un aperçu (`gpxToolsMap`, docs/LEDGER_*.md
/// MOB-178) : le lien `…/carte` du site. La même page que le plein écran de
/// la fiche (`PdlMapHero`), ouverte directement : « Fermer » revient à la
/// fiche, que le lien profond a posée dessous. Le mode Pente | Revêtement |
/// Météo est celui de la fiche ([gpxPreviewColorModeProvider]).
class GpxPreviewMapPage extends ConsumerWidget {
  const GpxPreviewMapPage({super.key, required this.previewId});

  final String previewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<GpxPreviewDto> preview = ref.watch(
      gpxPreviewProvider(previewId),
    );
    return Scaffold(
      key: keys.gpxTools.previewMap,
      body: SafeArea(
        bottom: false,
        child: preview.when(
          data: (GpxPreviewDto p) => RouteMap(
            route: p.shown,
            fullscreen: true,
            colorBy: watchGpxPreviewColorMode(ref, p).colorBy,
            layer: gpxPreviewMapLayer(p),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace _) => PdlEmptyState(
            variant: PdlEmptyVariant.error,
            icon: PdlIcons.gpx,
            title: 'gpxTools.preview.loadErrorTitle'.tr(),
            actions: <Widget>[
              PdlButton(
                label: 'common.back'.tr(),
                variant: PdlButtonVariant.outline,
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
