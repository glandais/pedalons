import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../api/generated/export.dart';
import '../../../../../core/pdl/pdl.dart';
import '../../../../../core/theme/enum_colors.dart';
import '../../../../../core/theme/pdl_colors.dart';
import '../../../../../core/theme/pdl_icons.dart';
import '../../../../../core/theme/pdl_tokens.dart';
import '../../../../../core/theme/pdl_typography.dart';
import '../../../../../keys.dart';
import '../editor/ride_group_editor.dart';
import 'ride_template_summary.dart';

/// Un modèle dans la liste : son nom, le statut des sorties qu'il crée, et
/// « 3 groupes · prochaine sortie #42 » (ledger `MOB-78`). Toucher la carte
/// ouvre la modification ([onTap]) ; le `⋯` ([onMore]) ouvre le menu.
class RideTemplateCard extends StatelessWidget {
  const RideTemplateCard({
    super.key,
    required this.template,
    required this.onTap,
    required this.onMore,
  });

  final RideTemplateDto template;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return PdlCard(
      key: keys.rideTemplates.card(template.slug),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        template.name,
                        style: t.bodyStrong,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: PdlSpacing.chipGap),
                    PdlBadge(
                      label: 'status.${template.status.toLowerCase()}'.tr(),
                      tone: Status.fromJson(template.status).tone(c),
                    ),
                  ],
                ),
                const SizedBox(height: PdlSpacing.badgeGap),
                Text(
                  rideTemplateSummary(template, long: true),
                  style: t.sub.copyWith(color: c.textDimmed),
                ),
              ],
            ),
          ),
          EditorIconButton(
            key: keys.rideTemplates.moreButton(template.slug),
            icon: PdlIcons.more,
            label: 'rides.templates.more'.tr(
              namedArgs: <String, String>{'name': template.name},
            ),
            onTap: onMore,
          ),
        ],
      ),
    );
  }
}
