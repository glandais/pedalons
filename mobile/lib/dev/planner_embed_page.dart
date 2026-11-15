// Page de DEBUG : le planificateur de parcours embarqué, hors de tout
// formulaire — sur **le vrai pont** (`PlannerBridge`) et le vrai écran
// (`RoutePlannerScreen`) de l'éditeur de parcours (docs/LEDGER_*.md MOB-170,
// WEB-183).
//
// Elle sert à recetter le bundle (`assets/planner/`, construit par
// `pnpm build:mobile-planner` dans `frontend/`) sur un appareil sans passer
// par une équipe où le planificateur est ouvert : premier affichage, fonds de
// carte, gestes. Ce que la page rend à « Terminer » part dans le journal,
// préfixé `[planner-embed]`.
//
//   flutter run --dart-define=DEV_ROUTE=/dev/planificateur \
//     --dart-define=PLANNER_TEAM=<slug d'équipe>
//
// Sans session, les appels au routeur reviennent en 401 : la carte, les fonds
// et les gestes se recettent quand même.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/generated/export.dart';
import '../api/pedalons_api_client.dart';
import '../config/app_config.dart';
import '../config/locale_context.dart';
import '../core/geo/location_service.dart';
import '../core/material.dart';
import '../features/routes/data/gpx_file_source.dart';
import '../features/routes/data/planner_bridge.dart';
import '../features/routes/data/planner_load.dart';
import '../features/routes/data/planner_web_view.dart';
import '../features/routes/domain/planner_result.dart';
import '../features/routes/presentation/pages/route_planner_screen.dart';

const String kPlannerEmbedPath = '/dev/planificateur';

const String _team = String.fromEnvironment('PLANNER_TEAM');

class PlannerEmbedPage extends ConsumerStatefulWidget {
  const PlannerEmbedPage({super.key});

  @override
  ConsumerState<PlannerEmbedPage> createState() => _PlannerEmbedPageState();
}

class _PlannerEmbedPageState extends ConsumerState<PlannerEmbedPage> {
  late final PlannerBridge _bridge;

  @override
  void initState() {
    super.initState();
    _bridge = PlannerBridge(
      dio: ref.read(dioProvider),
      picker: () => ref.read(gpxFilePickerProvider),
      location: ref.read(locationServiceProvider),
      webViewFactory: ref.read(plannerWebViewFactoryProvider),
      load: _load,
      onDone: _done,
    );
  }

  /// Une création, dans l'équipe donnée au lancement : la configuration est
  /// lue sans session, comme les documents de style.
  Future<PlannerLoad> _load() async {
    final ConfigDto config = await ref
        .read(baseApiClientProvider)
        .configuration
        .getConfig();
    return PlannerLoad(
      withoutNulls(<String, dynamic>{
          'teamSlug': _team,
          'routeName': 'Essai',
          'create': true,
          'terrain': config.terrain?.toJson(),
          'defaultCenter': config.defaultCenter.toJson(),
          'theme': 'light',
          'locale': getCurrentLocale(),
          'units': 'METRIC',
        })
        ..['styles'] = await plannerMapStyles(
          config.mapStyles,
          dio: ref.read(baseDioProvider),
          apiBaseUrl: AppConfig.apiBaseUrl,
        ),
    );
  }

  void _done(PlannerResult result) {
    debugPrint(
      '[planner-embed] done '
      'state=${result.plannerState != null} points=${result.points?.length} '
      'file=${result.file} waypoints=${result.waypoints?.length} '
      'distance=${result.stats.distance} ascend=${result.stats.ascend} '
      'pointCount=${result.stats.pointCount} line=${result.stats.line.length} '
      'name=${result.nameSuggestion} tooLarge=${result.tooLarge}',
    );
  }

  @override
  void dispose() {
    _bridge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RoutePlannerScreen(bridge: _bridge);
}
