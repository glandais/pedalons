import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/paths.dart';
import '../../../../core/material.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../keys.dart';
import '../../providers/notifications_provider.dart';

/// La cloche de la barre d'accueil : une icône, et une pastille quand il y a
/// des non lues.
///
/// Elle **ouvre toujours** la boîte de réception, pastille ou pas — le brief §5
/// interdit une icône-action sans effet, et une cloche qui ne réagit qu'au-delà
/// de zéro en serait une la plupart du temps. Le chiffre vient de
/// `unread-count`, sondé au plus une fois par minute
/// ([kUnreadPollInterval]) : la liste, elle, n'est chargée que par l'écran.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final int unread = ref.watch(unreadNotificationCountProvider);

    return Semantics(
      key: keys.notifications.bell,
      button: true,
      label: unread > 0
          ? 'notifications.bellUnread'.plural(unread)
          : 'notifications.title'.tr(),
      excludeSemantics: true,
      child: InkResponse(
        onTap: () => context.push(Paths.notifications()),
        radius: PdlMetrics.tapTarget / 2,
        child: SizedBox(
          width: PdlMetrics.tapTarget,
          height: PdlMetrics.tapTarget,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Icon(PdlIcons.notifications, size: 22, color: c.text),
              if (unread > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    decoration: BoxDecoration(
                      color: c.danger,
                      borderRadius: PdlRadii.pillAll,
                      // Le liseré détache la pastille de l'icône quand les deux
                      // se chevauchent, en clair comme en sombre.
                      border: Border.all(color: c.surface, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        // Au-delà de 99 le chiffre exact n'apprend plus rien et
                        // fait grossir la pastille jusqu'à mordre l'icône.
                        unread > 99 ? '99+' : '$unread',
                        style: t.badge.copyWith(color: c.onPrimary),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
