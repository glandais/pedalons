import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../api/generated/export.dart';
import '../../../../../core/pdl/pdl.dart';
import '../../../../../core/theme/pdl_icons.dart';
import '../../../../../core/utils/api_error_handler.dart';
import '../../../../../keys.dart';
import '../../../../teams/providers/team_providers.dart';
import '../../../providers/ride_editor_providers.dart';
import '../../../providers/ride_template_providers.dart';

/// La porte des écrans de modèles de sortie (ledger `MOB-78`) : elle tranche
/// l'accès avant d'afficher quoi que ce soit.
///
/// Même règle que le serveur (`RideTemplateAccessChecker`) : organisateur ou
/// administrateur de l'équipe pour **toutes** les actions, lecture comprise,
/// modules sorties **et** parcours actifs. Quelqu'un d'autre arrivé ici par un
/// lien lit un refus plutôt qu'une erreur 403.
///
/// L'ordre compte : le modèle ([template]) n'est lu qu'**après** le refus
/// tranché — un simple membre qui l'écouterait avant lirait « accès refusé »
/// du serveur au lieu de l'écran de refus.
class RideTemplateAccessGate extends ConsumerWidget {
  const RideTemplateAccessGate({
    super.key,
    required this.teamSlug,
    required this.title,
    required this.builder,
    this.template,
  });

  final String teamSlug;

  /// Le titre de la coquille de repli (attente, erreur, refus).
  final String title;

  /// Le modèle à charger avant de construire (modification), ou `null`.
  final RideTemplateKey? template;

  final Widget Function(
    BuildContext context,
    TeamDetailDto team,
    RideTemplateDto? template,
  )
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget shell(Widget body) => PdlScreenScaffold(
      appBar: PdlAppBar(
        title: title,
        onBack: () => context.pop(),
        backSemanticLabel: 'common.back'.tr(),
      ),
      body: body,
    );

    Widget loadError(Object error, VoidCallback retry) => shell(
      PdlEmptyState(
        key: keys.rideTemplates.loadError,
        variant: PdlEmptyVariant.error,
        title: 'common.loadError'.tr(),
        message: getErrorMessage(error),
        actions: <Widget>[
          PdlButton(label: 'common.retry'.tr(), onPressed: retry),
        ],
      ),
    );

    final AsyncValue<TeamDetailDto> team = ref.watch(
      teamDetailProvider(teamSlug),
    );
    final Object? teamError = team.error;
    if (teamError != null) {
      return loadError(
        teamError,
        () => ref.invalidate(teamDetailProvider(teamSlug)),
      );
    }

    final bool? canManage = ref.watch(canManageRidesProvider(teamSlug));
    final TeamDetailDto? teamValue = team.value;
    if (teamValue == null || canManage == null) {
      return shell(const Center(child: CircularProgressIndicator.adaptive()));
    }

    final bool modulesOn = teamValue.enableRides && teamValue.enableRoutes;
    if (!canManage || !modulesOn) {
      return shell(
        PdlEmptyState(
          key: keys.rideTemplates.forbidden,
          variant: PdlEmptyVariant.empty,
          icon: PdlIcons.admin,
          title: 'rides.editor.forbiddenTitle'.tr(),
          message: canManage
              ? 'rides.editor.modulesOffMessage'.tr()
              : 'rides.templates.forbiddenMessage'.tr(),
          actions: <Widget>[
            PdlButton(
              label: 'common.back'.tr(),
              variant: PdlButtonVariant.outline,
              onPressed: () => context.pop(),
            ),
          ],
        ),
      );
    }

    final RideTemplateKey? key = template;
    if (key == null) return builder(context, teamValue, null);

    final AsyncValue<RideTemplateDto> loaded = ref.watch(
      rideTemplateDetailProvider(key),
    );
    final Object? templateError = loaded.error;
    if (templateError != null) {
      return loadError(templateError, () {
        ref.invalidate(teamDetailProvider(teamSlug));
        ref.invalidate(rideTemplateDetailProvider(key));
      });
    }
    final RideTemplateDto? value = loaded.value;
    if (value == null) {
      return shell(const Center(child: CircularProgressIndicator.adaptive()));
    }
    return builder(context, teamValue, value);
  }
}
