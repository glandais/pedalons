import '../../../../api/generated/export.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../notification_display.dart';

/// Une entrée de la boîte de réception.
///
/// Une non lue se signale par un **point** et un titre en graisse 600, pas par
/// un fond teinté : la ligne entière est une cible tactile, et un fond de
/// couleur entrerait en concurrence avec son état pressé.
///
/// La ligne fait au moins [PdlSettingRow.minHeight] de haut comme toutes les
/// lignes tapables de l'app, et reste tapable même sans destination — c'est
/// alors [onTap] qui vaut `null`, jamais un `go` vers une route inconnue.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

  final NotificationDto notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final bool unread = !notification.read;

    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: PdlSettingRow.minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PdlSpacing.section,
              vertical: 10,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    notification.icon(),
                    size: 20,
                    color: unread ? c.primary : c.textDimmed,
                  ),
                ),
                const SizedBox(width: PdlSpacing.chipGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        notification.title(),
                        style: unread ? t.bodyStrong : t.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        notification.subjectName,
                        style: t.sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (notification.subjectDateLine() case final String date)
                        Text(
                          date,
                          style: t.xs,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (notification.detail() case final String detail)
                        Text(
                          detail,
                          style: notification.detailIsQuote
                              ? t.xs.copyWith(fontStyle: FontStyle.italic)
                              : t.xs,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        '${notification.teamName} · '
                        '${AppFormatters.formatRelative(DateTime.parse(notification.createdAt))}',
                        style: t.xs.copyWith(color: c.textPlaceholder),
                      ),
                    ],
                  ),
                ),
                if (unread)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: PdlSpacing.chipGap,
                      top: 6,
                    ),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: c.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
