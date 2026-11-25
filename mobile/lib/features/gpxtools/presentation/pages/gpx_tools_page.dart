import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../widgets/gpx_tools_hub.dart';

/// L'accueil des outils GPX sous sa propre barre, pour l'adresse
/// `/outils-gpx` qu'ouvre un lien (docs/LEDGER_*.md MOB-178). Dans l'app, on
/// l'atteint par l'onglet « Outils GPX » d'Explorer, qui pose le même
/// [GpxToolsHub] sous son sélecteur.
class GpxToolsPage extends StatelessWidget {
  const GpxToolsPage({super.key});

  @override
  Widget build(BuildContext context) => PdlScreenScaffold(
    appBar: PdlAppBar(
      title: 'gpxTools.title'.tr(),
      onBack: () => context.pop(),
      backSemanticLabel: 'common.back'.tr(),
    ),
    body: const GpxToolsHub(),
  );
}
