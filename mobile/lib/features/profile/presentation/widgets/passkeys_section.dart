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
import '../../../auth/data/passkey_management_repository.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../auth/services/passkey_service.dart';
import 'confirm_sheet.dart';

/// Les clés d'accès de l'utilisateur — **toutes**.
final passkeysProvider = FutureProvider<List<PasskeyDto>>((ref) async {
  // Surveillé pour relire la liste à chaque changement de session, pas pour
  // être passé à la main : le client authentifié porte le jeton.
  final String? token = ref.watch(accessTokenHolderProvider);
  if (token == null) return const <PasskeyDto>[];
  return ref.read(passkeyManagementRepositoryProvider).listPasskeys();
});

/// Sécurité : la liste des clés d'accès.
///
/// **Ajouter une clé n'écrase plus les autres.** L'écran précédent enregistrait
/// la nouvelle puis supprimait toutes les précédentes, si bien qu'un compte ne
/// pouvait jamais avoir qu'une seule clé : ajouter son ordinateur retirait son
/// téléphone, sans le dire. Le contrat n'a jamais imposé cela — quatre
/// endpoints existent et la liste en rend autant qu'il y en a.
class PasskeysSection extends ConsumerStatefulWidget {
  const PasskeysSection({super.key});

  @override
  ConsumerState<PasskeysSection> createState() => _PasskeysSectionState();
}

class _PasskeysSectionState extends ConsumerState<PasskeysSection> {
  bool _busy = false;
  String? _error;

  Future<void> _add() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(passkeyServiceProvider).register();
      ref.read(authProvider.notifier).setHasPasskeys(true);
      ref.invalidate(passkeysProvider);
      if (mounted) setState(() => _busy = false);
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = getErrorMessage(error, stackTrace);
      });
    }
  }

  Future<void> _delete(PasskeyDto passkey) async {
    final String name = _name(passkey);
    final bool confirmed = await confirmDestructive(
      context,
      title: 'profile.passkeys.deleteTitle'.tr(
        namedArgs: <String, String>{'device': name},
      ),
      message: 'profile.passkeys.deleteMessage'.tr(),
      confirmLabel: 'common.delete'.tr(),
    );
    if (!confirmed || !mounted) return;

    final String? id = passkey.id;
    if (id == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(passkeyManagementRepositoryProvider).deletePasskey(id);
      ref.invalidate(passkeysProvider);
      if (mounted) setState(() => _busy = false);
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = getErrorMessage(error, stackTrace);
      });
    }
  }

  /// Un appareil sans nom reste une clé : on l'affiche, nommée par défaut,
  /// plutôt que de rendre une ligne vide qu'on ne saurait pas supprimer.
  String _name(PasskeyDto passkey) =>
      (passkey.deviceName?.trim().isNotEmpty ?? false)
      ? passkey.deviceName!.trim()
      : 'profile.passkeys.unnamedDevice'.tr();

  String _subtitle(PasskeyDto passkey) {
    final DateTime? last = passkey.lastUsedAt == null
        ? null
        : AppFormatters.tryParseDisplayTime(passkey.lastUsedAt!);
    if (last != null) {
      return 'profile.passkeys.lastUsed'.tr(
        namedArgs: <String, String>{'date': AppFormatters.formatLongDate(last)},
      );
    }
    // `lastUsedAt` nul veut dire « jamais employée », pas « inconnue » : une
    // clé enregistrée et jamais servie est exactement ce qu'on veut voir.
    return 'profile.passkeys.neverUsed'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors t = context.pdl;
    final PdlTypography ty = context.pdlText;
    final AsyncValue<List<PasskeyDto>> passkeys = ref.watch(passkeysProvider);
    final List<PasskeyDto> list = passkeys.value ?? const <PasskeyDto>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PdlSpacing.section,
        0,
        PdlSpacing.section,
        PdlSpacing.section,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PdlSectionHeader(
            title: 'profile.passkeys.title'.tr(),
            count: passkeys.hasValue
                ? 'profile.passkeys.count'.plural(list.length)
                : null,
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: PdlSpacing.chipGap),
            child: Text('profile.passkeys.hint'.tr(), style: ty.sub),
          ),
          PdlCard(
            padding: PdlCardPadding.none,
            child: Column(
              children: <Widget>[
                if (passkeys.isLoading && list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(PdlSpacing.section),
                    child: PdlSkeleton(height: 44),
                  ),
                for (int i = 0; i < list.length; i++)
                  PdlSettingRow(
                    icon: PdlIcons.passkey,
                    title: _name(list[i]),
                    subtitle: _subtitle(list[i]),
                    showDivider: true,
                    trailing: IconButton(
                      icon: Icon(PdlIcons.close, size: 20, color: t.textDimmed),
                      // Le libellé **nomme la clé** : « Supprimer » répété
                      // trois fois ne permet pas de choisir laquelle.
                      tooltip: 'profile.passkeys.deleteSemantic'.tr(
                        namedArgs: <String, String>{'device': _name(list[i])},
                      ),
                      constraints: const BoxConstraints.tightFor(
                        width: PdlMetrics.tapTarget,
                        height: PdlMetrics.tapTarget,
                      ),
                      onPressed: _busy ? null : () => _delete(list[i]),
                    ),
                  ),
                if (list.isEmpty && !passkeys.isLoading)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      PdlSpacing.section,
                      PdlSpacing.section,
                      PdlSpacing.section,
                      0,
                    ),
                    child: Text('profile.passkeys.none'.tr(), style: ty.sub),
                  ),
                Padding(
                  padding: const EdgeInsets.all(PdlSpacing.section),
                  child: PdlButton(
                    label: 'profile.passkeys.add'.tr(),
                    icon: PdlIcons.add,
                    variant: PdlButtonVariant.outline,
                    fullWidth: true,
                    loading: _busy,
                    loadingLabel: 'profile.passkeys.adding'.tr(),
                    onPressed: _add,
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: PdlSpacing.chipGap),
            PdlBanner(tone: PdlBannerTone.danger, message: _error!),
          ],
        ],
      ),
    );
  }
}
