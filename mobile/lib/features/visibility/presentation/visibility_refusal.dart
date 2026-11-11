import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../api/generated/export.dart';
import '../../../config/paths.dart';
import '../../../core/pdl/pdl.dart';
import '../../../core/theme/pdl_icons.dart';
import '../../../core/theme/pdl_tokens.dart';
import '../../../core/theme/pdl_typography.dart';
import '../../../keys.dart';

/// Ce qui est enregistré quand ses parcours sont en travers : une sortie ou
/// un voyage.
enum AlignedKind { ride, trip }

/// Le libellé d'une visibilité reçue en chaîne (« Équipe », « Non
/// répertorié », « Public »).
String visibilityLabel(String visibility) =>
    'visibility.${visibility.toLowerCase()}'.tr();

/// Décision D5 (docs/LEDGER_*.md MOB-137) : une sortie enregistrée hors de
/// l'équipe avec des parcours encore « Équipe » est refusée avec leur liste ;
/// cette feuille dit quels parcours changent et vers quelle visibilité, et
/// rend `true` si la personne accepte — l'appelant rejoue alors **la même
/// requête** avec `alignVisibility = true`, son formulaire intact.
Future<bool> confirmVisibilityAlignment(
  BuildContext context, {
  required AlignedKind kind,
  required List<IncompatibleRouteDto> routes,
}) async {
  final bool? confirmed = await PdlSheet.show<bool>(
    context: context,
    builder: (BuildContext sheetContext) {
      final PdlTypography t = sheetContext.pdlText;
      return PdlSheet(
        key: keys.visibility.alignSheet,
        title: 'visibility.align.title'.tr(),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            PdlSpacing.section,
            PdlSpacing.chipGap,
            PdlSpacing.section,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                kind == AlignedKind.ride
                    ? 'visibility.align.messageRide'.tr()
                    : 'visibility.align.messageTrip'.tr(),
                style: t.sub,
              ),
              const SizedBox(height: PdlSpacing.chipGap),
              for (final IncompatibleRouteDto route in routes)
                PdlSettingRow(
                  key: keys.visibility.alignRoute(route.slug),
                  padding: const EdgeInsets.symmetric(
                    vertical: PdlSpacing.chipGap,
                  ),
                  icon: PdlIcons.route,
                  title: 'visibility.align.route'.tr(
                    namedArgs: <String, String>{
                      'name': route.name,
                      'from': visibilityLabel(route.visibility),
                      'to': visibilityLabel(route.proposedVisibility),
                    },
                  ),
                ),
            ],
          ),
        ),
        footer: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(PdlSpacing.section),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                PdlButton(
                  key: keys.visibility.alignConfirm,
                  label: 'visibility.align.confirm'.tr(),
                  fullWidth: true,
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                ),
                const SizedBox(height: PdlSpacing.chipGap),
                PdlButton(
                  key: keys.visibility.alignCancel,
                  label: 'common.cancel'.tr(),
                  variant: PdlButtonVariant.outline,
                  fullWidth: true,
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return confirmed ?? false;
}

/// Décision D6 : un parcours qui sert à des sorties ou des voyages visibles
/// hors de l'équipe ne passe pas en « Équipe » — refusé avec ces usages, que
/// cette feuille liste, chacun ouvrant sa fiche. Rien à aligner dans ce sens.
Future<void> showRouteInUseRefusal(
  BuildContext context, {
  required String teamSlug,
  required List<IncompatibleRouteUsageDto> usages,
}) => _showRefusal(
  context,
  sheetKey: keys.visibility.routeInUseSheet,
  title: 'visibility.routeInUse.title'.tr(),
  message: 'visibility.routeInUse.message'.tr(),
  rows: <_RefusalRow>[
    for (final IncompatibleRouteUsageDto usage in usages)
      _RefusalRow(
        key: keys.visibility.usage(usage.type, usage.slug),
        icon: usage.type == 'TRIP' ? PdlIcons.trip : PdlIcons.ride,
        label: 'visibility.routeInUse.usage'.tr(
          namedArgs: <String, String>{
            'kind': usage.type == 'TRIP'
                ? 'visibility.routeInUse.trip'.tr()
                : 'visibility.routeInUse.ride'.tr(),
            'name': usage.name,
            'visibility': visibilityLabel(usage.visibility),
          },
        ),
        location: usage.type == 'TRIP'
            ? Paths.trip(teamSlug, usage.slug)
            : Paths.ride(teamSlug, usage.slug),
      ),
  ],
);

/// La restauration d'une sortie ou d'un voyage dont des parcours sont passés
/// en « Équipe » entre-temps est refusée avec leur liste (plan §4.4) : pas de
/// corps de requête pour porter `alignVisibility`, les parcours s'ouvrent
/// d'abord. Les liste, chacun ouvrant sa fiche.
Future<void> showRestoreRefusal(
  BuildContext context, {
  required String teamSlug,
  required AlignedKind kind,
  required List<IncompatibleRouteDto> routes,
}) => _showRefusal(
  context,
  sheetKey: keys.visibility.restoreBlockedSheet,
  title: 'visibility.restoreBlocked.title'.tr(),
  message: kind == AlignedKind.ride
      ? 'visibility.restoreBlocked.messageRide'.tr()
      : 'visibility.restoreBlocked.messageTrip'.tr(),
  rows: <_RefusalRow>[
    for (final IncompatibleRouteDto route in routes)
      _RefusalRow(
        key: keys.visibility.restoreRoute(route.slug),
        icon: PdlIcons.route,
        label: route.name,
        location: Paths.route(teamSlug, route.slug),
      ),
  ],
);

class _RefusalRow {
  const _RefusalRow({
    required this.key,
    required this.icon,
    required this.label,
    required this.location,
  });

  final Key key;
  final IconData icon;
  final String label;
  final String location;
}

Future<void> _showRefusal(
  BuildContext context, {
  required Key sheetKey,
  required String title,
  required String message,
  required List<_RefusalRow> rows,
}) async {
  // Le routeur de l'écran qui ouvre la feuille : celui de la feuille, posée
  // sur le navigateur racine, mènerait au même endroit, mais l'écran reste le
  // point de départ de la fiche ouverte.
  final GoRouter router = GoRouter.of(context);
  final String? location = await PdlSheet.show<String>(
    context: context,
    builder: (BuildContext sheetContext) {
      final PdlTypography t = sheetContext.pdlText;
      return PdlSheet(
        key: sheetKey,
        title: title,
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            PdlSpacing.section,
            PdlSpacing.chipGap,
            PdlSpacing.section,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(message, style: t.sub),
              const SizedBox(height: PdlSpacing.chipGap),
              for (final _RefusalRow row in rows)
                PdlSettingRow(
                  key: row.key,
                  padding: const EdgeInsets.symmetric(
                    vertical: PdlSpacing.chipGap,
                  ),
                  icon: row.icon,
                  title: row.label,
                  onTap: () => Navigator.of(sheetContext).pop(row.location),
                ),
            ],
          ),
        ),
        footer: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(PdlSpacing.section),
            child: PdlButton(
              key: keys.visibility.refusalClose,
              label: 'common.close'.tr(),
              variant: PdlButtonVariant.outline,
              fullWidth: true,
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ),
        ),
      );
    },
  );
  if (location != null) router.push(location);
}
