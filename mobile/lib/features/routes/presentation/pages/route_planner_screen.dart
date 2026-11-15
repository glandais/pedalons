import 'package:easy_localization/easy_localization.dart';

import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../keys.dart';
import '../../data/planner_bridge.dart';
import '../../domain/gpx_check.dart';
import '../widgets/editor/gpx_refused_banner.dart';

/// Ouvre le planificateur en plein écran, au-dessus de tout (navigateur
/// racine). L'écran n'a pas de route déclarée : il n'existe que le temps d'un
/// formulaire de parcours, qui possède [bridge].
Future<void> openRoutePlanner(BuildContext context, PlannerBridge bridge) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(builder: (_) => RoutePlannerScreen(bridge: bridge)),
  );
}

/// Le planificateur de parcours du site, embarqué : une WebView qui est **tout
/// le corps** de l'écran et prend tous les gestes (docs/LEDGER_*.md MOB-170).
/// Jamais dans le formulaire qui défile — la décision de l'éditeur riche
/// (`MOB-160`).
///
/// L'écran ne possède rien : la page vit dans [bridge], au-delà de lui. Le
/// quitter — « Terminer », la flèche de la page, le retour du système — la
/// détache sans la détruire ; le rouvrir la retrouve telle quelle. Aucune
/// confirmation ici : rien n'est perdu tant que le formulaire est là, et
/// c'est lui qui demande avant de partir.
class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key, required this.bridge});

  final PlannerBridge bridge;

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  PlannerBridge get _bridge => widget.bridge;

  @override
  void initState() {
    super.initState();
    _bridge
      ..onLeave = _leave
      ..onGpxRefused = _gpxRefused;
    _bridge.stateReadFailed.addListener(_stateReadFailed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _stateReadFailed());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bridge.webView.setBackgroundColor(context.pdl.surface);
  }

  @override
  void dispose() {
    _bridge
      ..onLeave = null
      ..onGpxRefused = null;
    _bridge.stateReadFailed.removeListener(_stateReadFailed);
    super.dispose();
  }

  void _leave() {
    final ModalRoute<Object?>? route = ModalRoute.of(context);
    if (route == null) return;
    // Une feuille par-dessus (le refus de quota) ne doit pas partir à la
    // place de l'écran.
    final NavigatorState navigator = Navigator.of(context);
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
      _bridge.screenLeft();
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  void _gpxRefused(GpxRefused refused) => _say(gpxRefusalMessage(refused));

  bool _saidStateReadFailed = false;

  /// L'avertissement du site (`planner.state.readFailed`), une fois : le
  /// formulaire le garde en bandeau.
  void _stateReadFailed() {
    if (_saidStateReadFailed || !_bridge.stateReadFailed.value) return;
    _saidStateReadFailed = true;
    _say('routes.planner.stateReadFailed'.tr());
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    return PopScope(
      // Le retour du système n'atteint jamais la page : l'écran part, la page
      // reste, et le pont note ce qu'elle laisse en suspens.
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (didPop) _bridge.screenLeft();
      },
      child: _body(c),
    );
  }

  Widget _body(PdlColors c) {
    return Scaffold(
      key: keys.routeEditor.plannerScreen,
      backgroundColor: c.surface,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _bridge.webView.build(context),
            ListenableBuilder(
              listenable: Listenable.merge(<Listenable>[
                _bridge.loaded,
                _bridge.loadError,
              ]),
              builder: (BuildContext context, Widget? _) {
                final Object? error = _bridge.loadError.value;
                if (error != null) {
                  return ColoredBox(
                    color: c.surface,
                    child: PdlEmptyState(
                      variant: PdlEmptyVariant.error,
                      title: 'routes.planner.loadError'.tr(),
                      message: getErrorMessage(error),
                      actions: <Widget>[
                        PdlButton(
                          label: 'common.retry'.tr(),
                          onPressed: _bridge.retryLoad,
                        ),
                        PdlButton(
                          label: 'common.back'.tr(),
                          variant: PdlButtonVariant.outline,
                          onPressed: _leave,
                        ),
                      ],
                    ),
                  );
                }
                if (_bridge.loaded.value) return const SizedBox.shrink();
                // La page n'a rien peint tant que `load` n'est pas parti.
                return ColoredBox(
                  color: c.surface,
                  child: const Center(
                    child: CircularProgressIndicator.adaptive(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
