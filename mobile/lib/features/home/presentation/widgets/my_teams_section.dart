import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/config/config_provider.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/push_location.dart';
import '../../../../keys.dart';
import '../../../teams/providers/team_providers.dart';

/// Combien d'équipes « Mes équipes » montre au plus ; l'onglet Équipes a le
/// reste.
const int kHomeTeamsLimit = 5;

/// L'annuaire de toutes les équipes, à la même adresse que sur le web
/// (`redirectTeamsDirectory` l'ouvre dans l'application).
String _findTeamLocation() => '${Paths.teams()}?role=all';

/// La ligne d'activité d'une équipe — « 2 sorties à venir · 1 nouvelle
/// publication » —, ou `null` quand il n'y a rien à dire.
///
/// Les trois compteurs viennent de la liste des équipes elle-même
/// (`TeamDetailDto`, API 10.6.0), calculés par page côté serveur : **aucun
/// appel par équipe**. Les zéros sont omis ; une équipe sans activité retombe
/// sur son nombre de membres plutôt que sur une ligne vide.
String teamActivityLine(TeamDetailDto team) {
  final List<String> parts = <String>[
    if (team.upcomingRideCount > 0)
      'home.teams.upcomingRides'.plural(team.upcomingRideCount),
    if (team.upcomingTripCount > 0)
      'home.teams.upcomingTrips'.plural(team.upcomingTripCount),
    if (team.recentPostCount > 0)
      'home.teams.recentPosts'.plural(team.recentPostCount),
  ];
  if (parts.isEmpty) {
    return 'teams.membersList.count'.plural(team.memberCount);
  }
  return parts.join(' · ');
}

/// « Mes équipes » — logo, nom, rôle et activité de chaque équipe dont
/// l'utilisateur est membre.
///
/// Lit [myTeamsProvider], la liste que l'onglet Équipes affiche déjà : le
/// cache est partagé, un pull-to-refresh d'un côté profite à l'autre. Un échec
/// masque le bloc.
class MyTeamsSection extends ConsumerWidget {
  const MyTeamsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<TeamDetailDto>> teams = ref.watch(myTeamsProvider);
    final bool canBrowse =
        ref.watch(appConfigProvider).value?.singleTeam == false;

    return teams.when(
      loading: () => _frame(
        context,
        const PdlSkeletonCardList(
          variant: PdlSkeletonCardVariant.person,
          count: 2,
        ),
      ),
      error: (Object error, StackTrace stack) => const SizedBox.shrink(),
      data: (List<TeamDetailDto> all) {
        if (all.isEmpty) return _frame(context, const _NoTeam());
        final List<TeamDetailDto> shown = all.take(kHomeTeamsLimit).toList();
        return _frame(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final TeamDetailDto team in shown) ...<Widget>[
                HomeTeamRow(key: keys.home.teamRow(team.slug), team: team),
                const SizedBox(height: PdlSpacing.feedGap),
              ],
              if (all.length > kHomeTeamsLimit)
                Align(
                  alignment: Alignment.centerLeft,
                  child: PdlButton(
                    label: 'home.teams.all'.tr(),
                    variant: PdlButtonVariant.text,
                    size: PdlButtonSize.sm,
                    onPressed: () => context.go(Paths.teams()),
                  ),
                ),
            ],
          ),
          showFind: canBrowse,
        );
      },
    );
  }

  Widget _frame(BuildContext context, Widget body, {bool showFind = false}) =>
      Padding(
        key: keys.home.teamsSection,
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
              title: 'home.teams.title'.tr(),
              action: showFind
                  ? PdlButton(
                      key: keys.home.findTeamButton,
                      label: 'home.teams.find'.tr(),
                      variant: PdlButtonVariant.text,
                      size: PdlButtonSize.sm,
                      onPressed: () => context.push(_findTeamLocation()),
                    )
                  : null,
            ),
            body,
          ],
        ),
      );
}

/// Aucune équipe : une carte compacte, et « Trouver une équipe » **sauf** sur
/// un site mono-équipe, où il n'y a rien à parcourir (`ConfigDto.singleTeam`).
/// Tant que la configuration n'est pas connue, le bouton reste caché : mieux
/// vaut l'absence d'un raccourci qu'une porte vers une liste qui n'existe pas.
class _NoTeam extends ConsumerWidget {
  const _NoTeam();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool canBrowse =
        ref.watch(appConfigProvider).value?.singleTeam == false;
    return PdlCard(
      flat: true,
      child: Row(
        children: <Widget>[
          Icon(PdlIcons.team, size: 24, color: context.pdl.textDimmed),
          const SizedBox(width: PdlSpacing.cardTight),
          Expanded(
            child: Text('home.teams.empty'.tr(), style: context.pdlText.body),
          ),
          if (canBrowse)
            PdlButton(
              key: keys.home.findTeamButton,
              label: 'home.teams.find'.tr(),
              variant: PdlButtonVariant.text,
              size: PdlButtonSize.sm,
              onPressed: () => context.push(_findTeamLocation()),
            ),
        ],
      ),
    );
  }
}

/// Une équipe de « Mes équipes ». Le rôle porte la couleur métier de
/// `contracts/brand-colors.yaml` (`TeamRoleTone`).
class HomeTeamRow extends StatelessWidget {
  const HomeTeamRow({super.key, required this.team});

  final TeamDetailDto team;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final String? role = team.role;

    return PdlCard(
      padding: PdlCardPadding.tight,
      onTap: () => pushLocation(context, Paths.team(team.slug)),
      child: Row(
        children: <Widget>[
          PdlAvatar(name: team.name, imageUrl: team.logoUrl, size: 40),
          const SizedBox(width: PdlSpacing.cardTight),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        team.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.cardTitle.copyWith(color: c.text),
                      ),
                    ),
                    if (role != null) ...<Widget>[
                      const SizedBox(width: PdlSpacing.badgeGap * 2),
                      PdlBadge(
                        label: AppFormatters.roleName(role),
                        tone: TeamRole.fromJson(role).tone(c),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  teamActivityLine(team),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.sub,
                ),
              ],
            ),
          ),
          Icon(PdlIcons.chevronRight, size: 18, color: c.textDimmed),
        ],
      ),
    );
  }
}
