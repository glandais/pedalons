import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../api/pedalons_api_client.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../keys.dart';
import '../../data/profile_repository.dart';
import 'confirm_sheet.dart';

/// Les appareils appairés au compte par code : Karoo, Garmin
/// (docs/LEDGER_*.md API-64).
final pairedDevicesProvider = FutureProvider<List<PairedDeviceDto>>((
  ref,
) async {
  // Surveillé pour relire la liste à chaque changement de session.
  final String? token = ref.watch(accessTokenHolderProvider);
  if (token == null) return const <PairedDeviceDto>[];
  return ref.read(profileRepositoryProvider).pairedDevices();
});

/// Chaque appareil appairé, avec sa propre déliaison : jusque-là, seul
/// « Déconnecter tous les appareils » pouvait en délier un, et fermait du même
/// coup l'app et le navigateur.
class PairedDevicesCard extends ConsumerStatefulWidget {
  const PairedDevicesCard({super.key});

  @override
  ConsumerState<PairedDevicesCard> createState() => _PairedDevicesCardState();
}

class _PairedDevicesCardState extends ConsumerState<PairedDevicesCard> {
  String? _busy;
  String? _error;

  Future<void> _unpair(PairedDeviceDto device) async {
    final String name = pairedDeviceName(device);
    final bool confirmed = await confirmDestructive(
      context,
      title: 'profile.devices.unpairTitle'.tr(
        namedArgs: <String, String>{'device': name},
      ),
      message: 'profile.devices.unpairMessage'.tr(),
      confirmLabel: 'profile.devices.unpair'.tr(),
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _busy = device.id;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).unpairDevice(device.id);
      ref.invalidate(pairedDevicesProvider);
      if (mounted) setState(() => _busy = null);
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _busy = null;
        _error = getErrorMessage(error, stackTrace);
      });
    }
  }

  String _subtitle(PairedDeviceDto device) {
    final DateTime? paired = AppFormatters.tryParseDisplayTime(device.pairedAt);
    final DateTime? last = device.lastUsedAt == null
        ? null
        : AppFormatters.tryParseDisplayTime(device.lastUsedAt!);
    // « Appairé le 13 octobre 2026 », sans le jour de la semaine, comme le
    // site (KIT §8, docs/LEDGER_*.md MOB-139, N15).
    final String pairedOn = paired == null
        ? ''
        : 'profile.devices.pairedOn'.tr(
            namedArgs: <String, String>{
              'date': AppFormatters.formatLongDateWithoutWeekday(paired),
            },
          );
    if (last == null) return pairedOn;
    return '$pairedOn · ${'profile.devices.lastUsed'.tr(namedArgs: <String, String>{'when': AppFormatters.formatRelative(last)})}';
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final AsyncValue<List<PairedDeviceDto>> devices = ref.watch(
      pairedDevicesProvider,
    );
    final List<PairedDeviceDto> list =
        devices.value ?? const <PairedDeviceDto>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PdlCard(
          padding: PdlCardPadding.none,
          child: Column(
            children: <Widget>[
              if (devices.isLoading && list.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(PdlSpacing.section),
                  child: PdlSkeleton(height: 44),
                ),
              for (int i = 0; i < list.length; i++)
                PdlSettingRow(
                  key: keys.profile.pairedDevice(list[i].id),
                  showDivider: i < list.length - 1,
                  // Décoratif : le nom de l'appareil est juste à côté.
                  leading: _logo(list[i]),
                  icon: _logo(list[i]) == null ? PdlIcons.devices : null,
                  title: pairedDeviceName(list[i]),
                  subtitle: _subtitle(list[i]),
                  trailing: IconButton(
                    key: keys.profile.unpairDevice(list[i].id),
                    icon: Icon(PdlIcons.close, size: 20, color: c.textDimmed),
                    // Le libellé **nomme l'appareil** : « Délier » répété
                    // deux fois ne permet pas de choisir lequel.
                    tooltip: 'profile.devices.unpairSemantic'.tr(
                      namedArgs: <String, String>{
                        'device': pairedDeviceName(list[i]),
                      },
                    ),
                    constraints: const BoxConstraints.tightFor(
                      width: PdlMetrics.tapTarget,
                      height: PdlMetrics.tapTarget,
                    ),
                    onPressed: _busy != null ? null : () => _unpair(list[i]),
                  ),
                ),
              if (list.isEmpty && !devices.isLoading)
                // « Comment appairer » est la section suivante de la page :
                // la ligne vide ne le répète pas.
                PdlSettingRow(
                  key: keys.profile.noPairedDevice,
                  title: 'profile.devices.none'.tr(),
                ),
              // Ce qu'est un appareil appairé, à côté des services connectés
              // juste au-dessus : les mêmes logos y figurent.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  PdlSpacing.section,
                  0,
                  PdlSpacing.section,
                  PdlSpacing.cardTight,
                ),
                child: Text('profile.devices.hint'.tr(), style: t.xs),
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

  Widget? _logo(PairedDeviceDto device) {
    final String? asset = pairedDeviceLogoAsset(device);
    if (asset == null) return null;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: const BorderRadius.all(PdlRadii.sm),
        child: Image.asset(asset, width: 32, height: 32),
      ),
    );
  }
}

/// Le nom d'un appareil appairé : son type, le contrat n'en porte pas d'autre.
String pairedDeviceName(PairedDeviceDto device) =>
    switch (PairedDeviceType.fromJson(device.type)) {
      PairedDeviceType.karoo => 'profile.devices.karoo'.tr(),
      PairedDeviceType.garmin => 'profile.devices.garmin'.tr(),
      PairedDeviceType.other ||
      PairedDeviceType.$unknown => 'profile.devices.other'.tr(),
    };

/// Un Karoo est d'Hammerhead, une Edge de Garmin : les mêmes tuiles que les
/// services GPS (docs/LEDGER_*.md API-14).
String? pairedDeviceLogoAsset(PairedDeviceDto device) =>
    switch (PairedDeviceType.fromJson(device.type)) {
      PairedDeviceType.karoo => 'assets/gps/hammerhead.png',
      PairedDeviceType.garmin => 'assets/gps/garmin.png',
      PairedDeviceType.other || PairedDeviceType.$unknown => null,
    };
