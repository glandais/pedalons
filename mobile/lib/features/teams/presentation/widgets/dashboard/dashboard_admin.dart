import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../api/generated/export.dart';
import '../../../../../core/pdl/pdl.dart';
import '../../../../../core/theme/enum_colors.dart';
import '../../../../../core/theme/pdl_colors.dart';
import '../../../../../core/theme/pdl_icons.dart';
import '../../../../../core/theme/pdl_tokens.dart';
import '../../../../../core/theme/pdl_typography.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../keys.dart';
import '../../../../rides/presentation/ride_editor_location.dart';
import '../../team_web_paths.dart';
import 'dashboard_section.dart';

// ─────────────────────────────────────────────────── créer depuis un modèle

/// « Créer depuis un modèle » : les modèles de sortie de l'équipe et leur
/// nombre de groupes. La création elle-même se fait sur le site.
class DashboardTemplates extends StatelessWidget {
  const DashboardTemplates({
    super.key,
    required this.teamSlug,
    required this.list,
  });

  final String teamSlug;
  final RideTemplateListResponse list;

  @override
  Widget build(BuildContext context) {
    return DashboardSection(
      key: keys.teamDashboard.templates,
      title: 'teams.dashboard.templates.title'.tr(),
      onViewAll: () =>
          openTeamWebPage(context, TeamWebPaths.rideTemplates(teamSlug)),
      child: list.templates.isEmpty
          ? DashboardEmptyLine(message: 'teams.dashboard.templates.empty'.tr())
          : PdlCard(
              padding: PdlCardPadding.none,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (int i = 0; i < list.templates.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: PdlSpacing.cardTight,
                      ),
                      child: PdlSettingRow(
                        title: list.templates[i].name,
                        icon: PdlIcons.template,
                        subtitle: 'rides.groupCount'.plural(
                          list.templates[i].groupCount,
                        ),
                        onTap: () => context.push(
                          rideNewLocation(
                            teamSlug,
                            templateSlug: list.templates[i].slug,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

// ──────────────────────────────────────────────────────────── administration

/// « Administration » : membres par rôle, nouveaux membres, fonctionnalités
/// activées, état du webhook, et les gestes d'un administrateur.
///
/// La répartition par rôle est `team.memberCountByRole` et les fonctionnalités
/// sont les `enable*` de l'équipe : l'API ne les répète pas dans le bloc
/// `admin`, l'écran les lit là où elles sont.
class DashboardAdmin extends StatelessWidget {
  const DashboardAdmin({super.key, required this.team, required this.data});

  final TeamDetailDto team;
  final TeamDashboardAdminDto data;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final MemberCountByRoleDto? split = team.memberCountByRole;
    final List<String> features = <String>[
      if (team.enableRides) 'rides',
      if (team.enableRoutes) 'routes',
      if (team.enableTrips) 'trips',
      if (team.enablePosts) 'posts',
      if (team.enableAds) 'ads',
      if (team.enableMemberDirectory) 'directory',
    ];

    return DashboardSection(
      key: keys.teamDashboard.admin,
      title: 'teams.dashboard.admin.title'.tr(),
      child: PdlCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'teams.membersList.count'.plural(team.memberCount),
              style: t.sectionTitle,
            ),
            if (split != null) ...<Widget>[
              const SizedBox(height: PdlSpacing.chipGap),
              _RoleSplit(split: split),
            ],
            const SizedBox(height: PdlSpacing.section),
            _Label('teams.dashboard.admin.newestMembers'.tr()),
            if (data.newestMembers.members.isEmpty)
              Text('teams.dashboard.admin.noNewMembers'.tr(), style: t.sub)
            else
              for (final MemberDto m in data.newestMembers.members)
                PdlPersonRow(
                  name: m.user.displayName,
                  imageUrl: m.user.avatarUrl,
                  avatarSize: 32,
                  subtitle: _joined(m.joinedAt),
                ),
            const SizedBox(height: PdlSpacing.section),
            _Label('teams.dashboard.admin.features'.tr()),
            if (features.isEmpty)
              Text('teams.dashboard.admin.noFeature'.tr(), style: t.sub)
            else
              Wrap(
                spacing: PdlSpacing.badgeGap,
                runSpacing: PdlSpacing.badgeGap,
                children: <Widget>[
                  for (final String f in features)
                    PdlBadge(
                      label: 'teams.dashboard.admin.feature.$f'.tr(),
                      tone: PdlFamily.indigo.soft(c),
                      icon: PdlIcons.check,
                    ),
                ],
              ),
            const SizedBox(height: PdlSpacing.section),
            _Webhook(webhook: data.webhook),
            const SizedBox(height: PdlSpacing.section),
            Wrap(
              spacing: PdlSpacing.chipGap,
              runSpacing: PdlSpacing.chipGap,
              children: <Widget>[
                if (team.addMemberAllowed)
                  PdlButton(
                    label: 'teams.dashboard.admin.invite'.tr(),
                    icon: PdlIcons.personAdd,
                    size: PdlButtonSize.sm,
                    onPressed: () => openTeamWebPage(
                      context,
                      TeamWebPaths.adminMembersInvite(team.slug),
                    ),
                  ),
                PdlButton(
                  label: 'teams.dashboard.admin.manageMembers'.tr(),
                  icon: PdlIcons.people,
                  variant: PdlButtonVariant.outline,
                  size: PdlButtonSize.sm,
                  onPressed: () => openTeamWebPage(
                    context,
                    TeamWebPaths.adminMembers(team.slug),
                  ),
                ),
                PdlButton(
                  label: 'teams.dashboard.admin.settings'.tr(),
                  icon: PdlIcons.settings,
                  variant: PdlButtonVariant.text,
                  size: PdlButtonSize.sm,
                  onPressed: () => openTeamWebPage(
                    context,
                    TeamWebPaths.settings(team.slug),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String? _joined(String? joinedAt) {
    final DateTime? at = AppFormatters.tryParseDisplayTime(joinedAt);
    return at == null ? null : AppFormatters.formatRelative(at);
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PdlSpacing.badgeGap),
      child: Text(text, style: context.pdlText.bodyStrong),
    );
  }
}

/// La barre empilée administrateurs / organisateurs / membres, et sa légende.
///
/// Les teintes sont celles des rôles (`TeamRoleTone`, issu de
/// `contracts/brand-colors.yaml`) : un rôle a la même couleur ici que sur son
/// badge.
class _RoleSplit extends StatelessWidget {
  const _RoleSplit({required this.split});

  final MemberCountByRoleDto split;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final List<(int, Color, String)> parts = <(int, Color, String)>[
      (
        split.admins,
        TeamRole.admin.tone(c).fill,
        'teams.dashboard.admin.roles.admins'.plural(split.admins),
      ),
      (
        split.organizers,
        TeamRole.organizer.tone(c).fill,
        'teams.dashboard.admin.roles.organizers'.plural(split.organizers),
      ),
      (
        split.members,
        TeamRole.member.tone(c).fill,
        'teams.dashboard.admin.roles.members'.plural(split.members),
      ),
    ];
    final int total = split.admins + split.organizers + split.members;

    return Semantics(
      label:
          '${'teams.dashboard.admin.roleSplit'.tr()} : '
          '${parts.map(((int, Color, String) p) => p.$3).join(', ')}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ClipRRect(
            borderRadius: PdlRadii.pillAll,
            child: SizedBox(
              height: PdlMetrics.seatsBar,
              child: total == 0
                  ? ColoredBox(color: c.neutralSoft)
                  : Row(
                      children: <Widget>[
                        for (final (int, Color, String) p in parts)
                          if (p.$1 > 0)
                            Expanded(
                              flex: p.$1,
                              child: ColoredBox(color: p.$2),
                            ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: PdlSpacing.chipGap),
          PdlLegendRow(
            padding: EdgeInsets.zero,
            entries: <PdlLegendEntry>[
              for (final (int, Color, String) p in parts)
                PdlLegendEntry(color: p.$2, label: p.$3),
            ],
          ),
        ],
      ),
    );
  }
}

/// « Webhook Discord · dernier envoi le 2 oct. », et son état.
class _Webhook extends StatelessWidget {
  const _Webhook({required this.webhook});

  final TeamWebhookDto webhook;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    if (!webhook.configured) {
      return Row(
        children: <Widget>[
          Icon(PdlIcons.webhook, size: 20, color: c.textDimmed),
          const SizedBox(width: PdlSpacing.chipGap),
          Expanded(
            child: Text(
              'teams.dashboard.admin.webhook.notConfigured'.tr(),
              style: t.sub,
            ),
          ),
        ],
      );
    }

    final DateTime? last = AppFormatters.tryParseDisplayTime(
      webhook.lastAttemptAt,
    );
    final String kind = webhook.kind == null
        ? ''
        : 'teams.dashboard.admin.webhook.kind.${webhook.kind}'.tr();
    final bool failed = webhook.lastStatus == 'FAILED';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(PdlIcons.webhook, size: 20, color: c.textDimmed),
        const SizedBox(width: PdlSpacing.chipGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'teams.dashboard.admin.webhook.title'
                    .tr(namedArgs: <String, String>{'kind': kind})
                    .trim(),
                style: t.bodyStrong,
              ),
              Text(
                last == null
                    ? 'teams.dashboard.admin.webhook.never'.tr()
                    : 'teams.dashboard.admin.webhook.lastAttempt'.tr(
                        namedArgs: <String, String>{
                          'date': AppFormatters.formatDayMonth(last),
                        },
                      ),
                style: t.xs,
              ),
            ],
          ),
        ),
        const SizedBox(width: PdlSpacing.chipGap),
        PdlBadgeStack(
          badges: <Widget>[
            PdlBadge(
              label: webhook.enabled
                  ? 'teams.dashboard.admin.webhook.enabled'.tr()
                  : 'teams.dashboard.admin.webhook.disabled'.tr(),
              tone: webhook.enabled
                  ? PdlFamily.green.soft(c)
                  : PdlFamily.gray.soft(c),
            ),
            if (webhook.lastStatus != null)
              PdlBadge(
                label:
                    'teams.dashboard.admin.webhook.status.${webhook.lastStatus}'
                        .tr(),
                tone: failed ? PdlFamily.red.soft(c) : PdlFamily.gray.soft(c),
              ),
          ],
        ),
      ],
    );
  }
}
