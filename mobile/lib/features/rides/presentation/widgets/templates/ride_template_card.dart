import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../api/generated/export.dart';
import '../../../../../core/material.dart';
import '../../../../../core/pdl/pdl.dart';
import '../../../../../core/preferences/user_preferences_provider.dart';
import '../../../../../core/theme/enum_colors.dart';
import '../../../../../core/theme/pdl_colors.dart';
import '../../../../../core/theme/pdl_icons.dart';
import '../../../../../core/theme/pdl_tokens.dart';
import '../../../../../core/theme/pdl_typography.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../keys.dart';
import '../editor/ride_group_editor.dart';
import 'ride_template_summary.dart';

/// Un modèle dans la liste (règle R12, KIT §9, ledger `MOB-78`) :
///
/// 1. son nom et, seulement par exception, le statut des sorties qu'il crée
///    — « Brouillon » ou « Annulé », jamais « Publié » (règle R1) ;
/// 2. sa description sur deux lignes, si elle existe, en texte ;
/// 3. « 3 groupes · prochaine sortie #12 » ;
/// 4. ses groupes et leur vitesse, « A 28 km/h · B 25 km/h · C 22 km/h ».
///
/// Toucher la carte ouvre la modification ([onTap]) ; le `⋯` ([onMore])
/// ouvre le menu.
class RideTemplateCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);
    final Status status = Status.fromJson(template.status);
    final bool badged = status == Status.draft || status == Status.cancelled;
    final String description = markdownPlainText(template.markdown);
    final String groups = rideTemplateGroupsLine(template, units);
    final String summary = rideTemplateSummary(template, long: true);
    return PdlCard(
      key: keys.rideTemplates.card(template.slug),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    if (badged) ...<Widget>[
                      const SizedBox(width: PdlSpacing.chipGap),
                      PdlBadge(
                        key: keys.rideTemplates.statusBadge(template.slug),
                        label: 'status.${template.status.toLowerCase()}'.tr(),
                        tone: status.tone(c),
                      ),
                    ],
                  ],
                ),
                if (description.isNotEmpty) ...<Widget>[
                  const SizedBox(height: PdlSpacing.badgeGap),
                  Text(
                    description,
                    key: keys.rideTemplates.description(template.slug),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.sub,
                  ),
                ],
                if (summary.isNotEmpty) ...<Widget>[
                  const SizedBox(height: PdlSpacing.badgeGap),
                  Text(summary, style: t.sub.copyWith(color: c.textDimmed)),
                ],
                if (groups.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    groups,
                    key: keys.rideTemplates.groupsLine(template.slug),
                    style: t.sub.copyWith(color: c.textDimmed),
                  ),
                ],
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

/// « A 28 km/h · B 25 km/h · C 22 km/h » : les groupes du modèle dans leur
/// ordre, chacun avec sa vitesse moyenne quand il en a une (règle R12).
String rideTemplateGroupsLine(RideTemplateDto template, UnitSystem units) {
  final List<RideTemplateGroupDto> groups = <RideTemplateGroupDto>[
    ...template.groups,
  ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return <String>[
    for (final RideTemplateGroupDto g in groups)
      g.averageSpeed == null
          ? g.name
          : '${g.name} ${AppFormatters.formatSpeed(g.averageSpeed!, units)}',
  ].join(' · ');
}

/// Le texte d'une description Markdown, pour un aperçu de carte : sans
/// images, les liens réduits à leur texte, sans titres ni marques
/// d'emphase, les lignes jointes par une espace. `''` pour une description
/// vide.
String markdownPlainText(String markdown) {
  String s = markdown;
  s = s.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '');
  s = s.replaceAllMapped(
    RegExp(r'\[([^\]]*)\]\([^)]*\)'),
    (Match m) => m.group(1) ?? '',
  );
  s = s.replaceAll(
    RegExp(r'^\s{0,3}(#{1,6}|>|[-*+]|\d+[.)])\s+', multiLine: true),
    '',
  );
  s = s.replaceAll(RegExp(r'(\*\*|__|\*|~~|`)'), '');
  return s.split(RegExp(r'\s+')).where((String w) => w.isNotEmpty).join(' ');
}
