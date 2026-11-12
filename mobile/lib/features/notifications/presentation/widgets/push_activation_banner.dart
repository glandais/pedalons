import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../keys.dart';
import '../../domain/push_message.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/push_provider.dart';

/// Le seul endroit qui demande l'autorisation de notifier, et il la demande
/// depuis la boîte de réception — c'est-à-dire après que le membre a vu ce
/// que l'app lui envoie.
///
/// Deux conditions pour s'afficher, et le bandeau disparaît entièrement sinon,
/// au lieu de proposer un bouton sans effet :
///
/// - **le serveur sait pousser** : `PUSH` figure dans les canaux de la matrice
///   de préférences, ce qui n'arrive que quand `FcmClient` est configuré
///   (`docs/plans/archive/2026-09-18-notifications.md` §5) ;
/// - **l'appareil n'a pas encore dit oui**.
///
/// Refus définitif : la boîte de dialogue du système ne revient pas, donc le
/// bandeau cesse de promettre un bouton et dit où aller.
class PushActivationBanner extends ConsumerWidget {
  const PushActivationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<NotificationChannel> channels =
        ref.watch(notificationPreferencesProvider).value?.channels ??
        const <NotificationChannel>[];
    if (!channels.contains(NotificationChannel.push)) {
      return const SizedBox.shrink();
    }

    final PushAuthorization authorization = ref.watch(
      pushAuthorizationProvider,
    );
    return switch (authorization) {
      PushAuthorization.granted ||
      PushAuthorization.unsupported => const SizedBox.shrink(),
      PushAuthorization.notDetermined => _banner(
        context,
        message: 'notifications.push.hint'.tr(),
        action: PdlButton(
          label: 'notifications.push.enable'.tr(),
          size: PdlButtonSize.sm,
          onPressed: () => ref
              .read(pushAuthorizationProvider.notifier)
              .requestAuthorization(),
        ),
      ),
      PushAuthorization.denied => _banner(
        context,
        message: 'notifications.push.deniedHint'.tr(),
      ),
    };
  }

  Widget _banner(
    BuildContext context, {
    required String message,
    Widget? action,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PdlSpacing.section,
        PdlSpacing.chipGap,
        PdlSpacing.section,
        0,
      ),
      child: PdlBanner(
        key: keys.notifications.pushActivationBanner,
        tone: PdlBannerTone.info,
        icon: PdlIcons.notifications,
        title: 'notifications.push.title'.tr(),
        message: message,
        action: action,
      ),
    );
  }
}
