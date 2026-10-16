import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/config/config_provider.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../api/pedalons_api_client.dart';
import '../../../../core/utils/link_launcher.dart';
import '../../../../keys.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../data/profile_repository.dart';
import 'confirm_sheet.dart';

/// Relit l'utilisateur pour que l'écran reflète la connexion qui vient de
/// changer : `UserDto.connectedServices` en est la seule
/// source, et rien ne la pousse.
Future<void> refreshCurrentUser(WidgetRef ref) async {
  if (ref.read(accessTokenHolderProvider) == null) return;
  // Le client authentifié : un jeton expiré y est rafraîchi, pas refusé.
  final UserDto user = await ref.read(usersClientProvider).getMe();
  ref.read(authProvider.notifier).setUser(user);
}

/// Les services GPS que **le serveur** propose.
///
/// Jamais une liste codée en dur : `GET /api/gps/available` existe précisément
/// pour qu'un service ajouté au backend apparaisse sans nouvelle version de
/// l'app, et pour qu'un service retiré cesse d'être proposé.
final availableGpsProvider = FutureProvider<List<GpsServiceType>>((ref) async {
  return ref.watch(profileRepositoryProvider).availableGpsServices();
});

/// Services GPS : Hammerhead, Garmin Connect, Wahoo, et ce que le serveur
/// ajoutera — chacun avec son logo embarqué ([gpsServiceLogoAsset]). Les
/// appareils appairés par code sont dans `PairedDevicesCard`.
class GpsServicesCard extends ConsumerStatefulWidget {
  const GpsServicesCard({super.key});

  @override
  ConsumerState<GpsServicesCard> createState() => _GpsServicesCardState();
}

class _GpsServicesCardState extends ConsumerState<GpsServicesCard> {
  GpsServiceType? _busy;
  String? _error;

  /// La valeur demandée d'un interrupteur « Envoi automatique » dont la
  /// requête est en vol : la mise à jour optimiste. Elle n'est jamais gardée
  /// au-delà de la réponse — succès, la connexion rendue la remplace ; échec,
  /// elle disparaît et l'interrupteur revient à la valeur du serveur.
  final Map<GpsServiceType, bool> _autoSyncInFlight = <GpsServiceType, bool>{};

  /// L'OAuth se termine dans le navigateur, et son retour n'y ramène pas
  /// l'app (sur iOS, une redirection sur le même domaine reste dans Safari) :
  /// c'est le retour au premier plan qui relit les connexions.
  late final AppLifecycleListener _resumeListener = AppLifecycleListener(
    onResume: () => unawaited(refreshCurrentUser(ref).catchError((_) {})),
  );

  @override
  void initState() {
    super.initState();
    _resumeListener;
  }

  @override
  void dispose() {
    _resumeListener.dispose();
    super.dispose();
  }

  Future<void> _connect(GpsServiceType service) async {
    setState(() {
      _busy = service;
      _error = null;
    });
    try {
      final String url = await ref
          .read(profileRepositoryProvider)
          .gpsConnectUrl(service);
      if (!mounted) return;
      // L'autorisation se donne chez le fournisseur, dans son navigateur : la
      // rejouer dans une webvue embarquée est ce que les fournisseurs OAuth
      // refusent, et ce que les magasins d'applications sanctionnent.
      await openLink(context, url);
      if (mounted) setState(() => _busy = null);
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _busy = null;
        _error = getErrorMessage(error, stackTrace);
      });
    }
  }

  Future<void> _disconnect(
    GpsServiceType service,
    String label,
    GpsServiceConnectionDto connection,
  ) async {
    final int synced = connection.autoSyncRouteCount;
    final String message = synced > 0
        ? '${'profile.gps.disconnectMessage'.tr()} ${'profile.gps.autoSync.disconnectRemoves'.plural(synced, namedArgs: <String, String>{'service': label})}'
        : 'profile.gps.disconnectMessage'.tr();
    final bool confirmed = await confirmDestructive(
      context,
      title: 'profile.gps.disconnectTitle'.tr(
        namedArgs: <String, String>{'service': label},
      ),
      message: message,
      confirmLabel: 'profile.gps.disconnect'.tr(),
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _busy = service;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).disconnectGps(service);
      await refreshCurrentUser(ref);
      if (mounted) setState(() => _busy = null);
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _busy = null;
        _error = getErrorMessage(error, stackTrace);
      });
    }
  }

  /// L'interrupteur est le seul endroit qui écrit `autoSync` : la valeur
  /// affichée vient de `UserDto.connectedServices`, et rien n'en garde de
  /// copie locale (docs/LEDGER_*.md MOB-71).
  Future<void> _setAutoSync(GpsServiceType service, bool enabled) async {
    if (_autoSyncInFlight.containsKey(service)) return;
    setState(() {
      _autoSyncInFlight[service] = enabled;
      _error = null;
    });
    try {
      final GpsServiceConnectionDto updated = await ref
          .read(profileRepositoryProvider)
          .setGpsAutoSync(service, enabled: enabled);
      final UserDto? user = ref.read(authProvider).user;
      if (user != null) {
        ref
            .read(authProvider.notifier)
            .setUser(
              user.copyWith(
                connectedServices: <GpsServiceConnectionDto>[
                  for (final GpsServiceConnectionDto c
                      in user.connectedServices ??
                          const <GpsServiceConnectionDto>[])
                    c.serviceType == updated.serviceType ? updated : c,
                ],
              ),
            );
      }
      if (mounted) setState(() => _autoSyncInFlight.remove(service));
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _autoSyncInFlight.remove(service);
        _error = getErrorMessage(error, stackTrace);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    final List<GpsServiceType> available =
        ref.watch(availableGpsProvider).value ?? const <GpsServiceType>[];
    final List<GpsServiceConnectionDto> connected =
        ref.watch(
          authProvider.select((AuthState s) => s.user?.connectedServices),
        ) ??
        const <GpsServiceConnectionDto>[];

    // Coupé sur ce déploiement (`ConfigDto.gpsAutoSyncEnabled`, docs/LEDGER_*.md
    // API-120) : aucun interrupteur, plutôt qu'un qui promet un envoi.
    final bool autoSyncAvailable =
        ref.watch(appConfigProvider).value?.gpsAutoSyncEnabled ?? false;

    if (available.isEmpty) {
      return PdlCard(child: Text('profile.gps.none'.tr(), style: t.sub));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PdlCard(
          padding: PdlCardPadding.none,
          child: Column(
            children: <Widget>[
              for (int i = 0; i < available.length; i++)
                _serviceRow(
                  context,
                  service: available[i],
                  connection: connected
                      .where(
                        (GpsServiceConnectionDto s) =>
                            s.serviceType == available[i].json,
                      )
                      .firstOrNull,
                  showDivider: i < available.length - 1,
                  autoSyncAvailable: autoSyncAvailable,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  PdlSpacing.section,
                  0,
                  PdlSpacing.section,
                  PdlSpacing.cardTight,
                ),
                child: Text('profile.gps.hint'.tr(), style: t.xs),
              ),
            ],
          ),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: PdlSpacing.chipGap),
          PdlBanner(tone: PdlBannerTone.danger, message: _error!),
        ],
      ],
    );
  }

  Widget _serviceRow(
    BuildContext context, {
    required GpsServiceType service,
    required GpsServiceConnectionDto? connection,
    required bool showDivider,
    required bool autoSyncAvailable,
  }) {
    final String label = connection?.displayName ?? 'gps.${service.json}'.tr();
    final DateTime? since = connection == null
        ? null
        : AppFormatters.tryParseDisplayTime(connection.connectedAt);

    final String? logo = gpsServiceLogoAsset(service);
    final Widget row = PdlSettingRow(
      showDivider: showDivider && connection == null,
      // Décoratif : le nom du service est juste à côté.
      leading: logo == null
          ? null
          : ExcludeSemantics(
              child: ClipRRect(
                borderRadius: const BorderRadius.all(PdlRadii.sm),
                child: Image.asset(logo, width: _logoSize, height: _logoSize),
              ),
            ),
      title: label,
      subtitle: since == null
          ? 'profile.gps.notConnected'.tr()
          : 'profile.gps.connectedOn'.tr(
              namedArgs: <String, String>{
                'date': AppFormatters.formatLongDate(since),
              },
            ),
      trailing: PdlButton(
        label: connection == null
            ? 'profile.gps.connect'.tr()
            : 'profile.gps.disconnect'.tr(),
        variant: PdlButtonVariant.outline,
        size: PdlButtonSize.sm,
        loading: _busy == service,
        loadingLabel: 'common.loading'.tr(),
        onPressed: connection == null
            ? () => _connect(service)
            : () => _disconnect(service, label, connection),
      ),
    );
    if (connection == null) return row;
    if (!autoSyncAvailable) {
      return showDivider
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[row, const Divider(height: 1)],
            )
          : row;
    }

    final bool? inFlight = _autoSyncInFlight[service];
    final bool enabled = inFlight ?? connection.autoSync;
    // Le service refuse nos jetons : seule une nouvelle autorisation, sur la
    // même connexion, reprend l'envoi — l'interrupteur reste tel quel, ce
    // qu'une déconnexion ne ferait pas.
    final bool reconnectRequired =
        inFlight == null &&
        connection.autoSync &&
        GpsAutoSyncState.fromJson(connection.autoSyncState) ==
            GpsAutoSyncState.reconnectRequired;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        row,
        PdlSettingRow(
          key: keys.profile.gpsAutoSyncRow(service),
          showDivider: showDivider && !reconnectRequired,
          // Aligné sous le nom du service, dont il est un réglage.
          padding: const EdgeInsetsDirectional.fromSTEB(
            _autoSyncIndent,
            0,
            PdlSpacing.section,
            PdlSpacing.chipGap,
          ),
          title: 'profile.gps.autoSync.title'.tr(),
          subtitle: inFlight != null
              ? 'profile.gps.autoSync.saving'.tr()
              : gpsAutoSyncStatus(connection, serviceLabel: label),
          trailing: PdlSwitch(
            key: keys.profile.gpsAutoSyncSwitch(service),
            value: enabled,
            onChanged: inFlight != null
                ? null
                : (bool value) => _setAutoSync(service, value),
            semanticLabel: 'profile.gps.autoSync.semantic'.tr(
              namedArgs: <String, String>{'service': label},
            ),
          ),
        ),
        if (reconnectRequired) ...<Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              _autoSyncIndent,
              0,
              PdlSpacing.section,
              PdlSpacing.cardTight,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: PdlButton(
                key: keys.profile.gpsReconnect(service),
                label: 'profile.gps.autoSync.reconnect'.tr(),
                variant: PdlButtonVariant.outline,
                size: PdlButtonSize.sm,
                loading: _busy == service,
                loadingLabel: 'common.loading'.tr(),
                onPressed: () => _connect(service),
              ),
            ),
          ),
          if (showDivider) const Divider(height: 1),
        ],
      ],
    );
  }

  static const double _logoSize = 32;

  /// Le retrait de la ligne « Envoi automatique » : la marge de la ligne, le
  /// logo et l'écart qui le suit dans [PdlSettingRow].
  static const double _autoSyncIndent = PdlSpacing.section + _logoSize + 12;
}

/// L'état de l'envoi automatique vers un service connecté, tel que le serveur
/// le calcule (`autoSyncState`, docs/LEDGER_*.md API-120). Coupé, la ligne dit
/// ce que l'interrupteur ferait ; un état inconnu de ce build retombe sur la
/// même phrase plutôt que d'afficher une valeur brute.
String gpsAutoSyncStatus(
  GpsServiceConnectionDto connection, {
  required String serviceLabel,
}) {
  if (!connection.autoSync) return 'profile.gps.autoSync.off'.tr();
  return switch (GpsAutoSyncState.fromJson(connection.autoSyncState)) {
    // Pas de clé `zero` : en français, la règle de pluriel range 0 avec 1.
    GpsAutoSyncState.upToDate when connection.autoSyncRouteCount == 0 =>
      'profile.gps.autoSync.upToDateNone'.tr(),
    GpsAutoSyncState.upToDate => 'profile.gps.autoSync.upToDate'.plural(
      connection.autoSyncRouteCount,
    ),
    GpsAutoSyncState.pending => 'profile.gps.autoSync.pending'.tr(),
    GpsAutoSyncState.failing => 'profile.gps.autoSync.failing'.tr(),
    GpsAutoSyncState.reconnectRequired =>
      'profile.gps.autoSync.reconnectRequired'.tr(
        namedArgs: <String, String>{'service': serviceLabel},
      ),
    GpsAutoSyncState.off ||
    GpsAutoSyncState.$unknown => 'profile.gps.autoSync.off'.tr(),
  };
}

/// Le logo d'un service, embarqué : `GpsServiceType` est un enum fermé, le
/// contrat ne porte pas d'URL de logo (docs/LEDGER_*.md API-14). Chaque logo est
/// une tuile carrée à fond sombre, lisible dans les deux thèmes — les mêmes que
/// le web. Un service inconnu de ce build n'en a pas.
String? gpsServiceLogoAsset(GpsServiceType service) => switch (service) {
  GpsServiceType.garmin => 'assets/gps/garmin.png',
  GpsServiceType.wahoo => 'assets/gps/wahoo.png',
  GpsServiceType.hammerhead => 'assets/gps/hammerhead.png',
  GpsServiceType.$unknown => null,
};
