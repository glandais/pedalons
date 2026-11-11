import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pagination/pagination.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../keys.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../moderation/presentation/moderation_menu.dart';
import '../../domain/member_filters.dart';
import '../../providers/team_members_provider.dart';
import '../../../feedback/presentation/report_problem_button.dart';

/// Le trombinoscope d'une équipe.
///
/// **Le défaut corrigé est purement client** : `TeamRepository.getTeamMembers`
/// existait et aucun écran ne l'appelait, si bien que le mobile n'affichait
/// aucun membre — et que l'appel, sans `page` ni `size`, en aurait montré vingt
/// sur mille neuf cent quatre-vingt-dix-neuf sans le dire. Tout est au contrat
/// depuis le début : `role`, `search`, `page`, `size` et surtout `total`.
///
/// **Une ligne ouvre le menu de modération**, pas un profil : il n'existe pas
/// d'écran de profil public, et en inventer un derrière une ligne serait
/// promettre une porte qui n'existe pas. Toucher un membre propose de le
/// signaler ou de le bloquer — sauf sa propre ligne, qui ne s'ouvre pas.
///
/// C'est un **corps de section** : l'en-tête d'équipe et la rangée de sections
/// appartiennent à `TeamHomePage`.
class TeamMembersPage extends ConsumerStatefulWidget {
  final String teamSlug;

  /// Si l'équipe rend les rôles à ce lecteur : admin de l'équipe, ou
  /// trombinoscope ouvert. Sinon — un organisateur sur un trombinoscope
  /// fermé — pas de chips de rôle : le serveur refuse ce filtre (403), qui
  /// révélerait les rôles qu'il masque (docs/LEDGER_*.md SEC-18). Un admin
  /// plateforme les voit toujours.
  final bool rolesShown;

  const TeamMembersPage({
    super.key,
    required this.teamSlug,
    required this.rolesShown,
  });

  @override
  ConsumerState<TeamMembersPage> createState() => _TeamMembersPageState();
}

class _TeamMembersPageState extends ConsumerState<TeamMembersPage> {
  void _setFilters(MemberFilters next) {
    ref.read(memberFiltersProvider(widget.teamSlug).notifier).state = next;
  }

  void _scrollToTop() {
    final ScrollController? controller = PrimaryScrollController.maybeOf(
      context,
    );
    if (controller != null && controller.hasClients) controller.jumpTo(0);
  }

  Future<void> _openMemberMenu(MemberDto member) {
    final PublicUserDto user = member.user;
    return showModerationMenu(
      context,
      title: user.displayName,
      subject: ModerationSubject(
        teamSlug: widget.teamSlug,
        type: ReportTargetType.member,
        id: user.id,
        teamName: member.team.name,
        memberName: user.displayName,
      ),
      blockUserId: user.id,
      blockUserName: user.displayName,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(memberFiltersProvider(widget.teamSlug), (
      MemberFilters? previous,
      MemberFilters next,
    ) {
      if (previous != next) _scrollToTop();
    });

    final MemberFilters filters = ref.watch(
      memberFiltersProvider(widget.teamSlug),
    );
    final bool platformAdmin = ref.watch(
      authProvider.select(
        (AuthState s) => s.user?.platformRole == 'PLATFORM_ADMIN',
      ),
    );
    final PagedListState<MemberDto> state = ref.watch(
      teamMembersProvider(filters),
    );
    final TeamMembersNotifier notifier = ref.read(
      teamMembersProvider(filters).notifier,
    );

    return PdlRefresh(
      onRefresh: notifier.refresh,
      child: CustomScrollView(
        key: PageStorageKey<String>('members-${widget.teamSlug}'),
        primary: true,
        slivers: <Widget>[
          PdlPinnedToolbar(
            child: _MembersToolbar(
              filters: filters,
              onChanged: _setFilters,
              showRoles: widget.rolesShown || platformAdmin,
            ),
          ),
          ..._contentSlivers(state, notifier, filters),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  List<Widget> _contentSlivers(
    PagedListState<MemberDto> state,
    TeamMembersNotifier notifier,
    MemberFilters filters,
  ) {
    final String? currentUserId = ref.watch(
      authProvider.select((AuthState s) => s.user?.id),
    );
    if (state.showsSkeletons) {
      return <Widget>[
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(
            PdlSpacing.section,
            PdlSpacing.chipGap,
            PdlSpacing.section,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: PdlSkeletonCardList(
              variant: PdlSkeletonCardVariant.compact,
              count: 5,
            ),
          ),
        ),
      ];
    }

    if (state.initialError != null) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: PdlEmptyState(
              variant: PdlEmptyVariant.error,
              title: 'common.loadError'.tr(),
              message: getErrorMessage(state.initialError!),
              actions: <Widget>[
                PdlButton(
                  label: 'common.retry'.tr(),
                  variant: PdlButtonVariant.outline,
                  size: PdlButtonSize.sm,
                  onPressed: notifier.loadFirstPage,
                ),
                ReportProblemButton(error: state.initialError!),
              ],
            ),
          ),
        ),
      ];
    }

    if (state.isEmpty) {
      return <Widget>[
        SliverToBoxAdapter(
          child: filters.isFiltered
              ? PdlDeadEndEmpty(
                  title: 'teams.membersList.empty.title'.tr(),
                  message: 'teams.membersList.empty.description'.tr(),
                  resetAllLabel: 'teams.membersList.empty.resetAll'.tr(),
                  onResetAll: () => _setFilters(filters.cleared),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: PdlEmptyState(
                    variant: PdlEmptyVariant.empty,
                    icon: Icons.people_outline,
                    title: 'teams.membersList.none'.tr(),
                    message: 'teams.membersList.noneHint'.tr(),
                  ),
                ),
        ),
      ];
    }

    final int total = state.total ?? state.items.length;

    return <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PdlSpacing.section,
            PdlSpacing.chipGap,
            PdlSpacing.section,
            4,
          ),
          child: Text(
            'teams.membersList.count'.plural(total),
            style: context.pdlText.count,
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
        sliver: SliverList.builder(
          itemCount: state.items.length,
          itemBuilder: (BuildContext context, int index) {
            notifier.onItemBuilt(index);
            final MemberDto member = state.items[index];
            return _MemberRow(
              key: ValueKey<String>(member.id),
              member: member,
              showDivider: index < state.items.length - 1,
              onTap: member.user.id == currentUserId
                  ? null
                  : () => _openMemberMenu(member),
            );
          },
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
        sliver: SliverToBoxAdapter(
          child: PdlPagedListFooter(
            isLoadingNext: state.isLoadingNext,
            hasMore: state.hasMore,
            isEmpty: state.items.isEmpty,
            hasError: state.nextError != null,
            onRetry: notifier.retryNextPage,
            // « 60 membres sur 1 999 » : l'exemple de référence du pied
            // paginé, et il ne coûte aucun endpoint `count`.
            progressLabel: 'pagination.progressNamed'.tr(
              namedArgs: <String, String>{
                'loaded': '${state.items.length}',
                'noun': 'teams.membersList.noun'.tr(),
                'total': '$total',
              },
            ),
            loadingLabel: 'pagination.loadingMore'.tr(),
            endLabel: 'pagination.endOfList'.tr(),
            errorLabel: 'pagination.nextPageError'.tr(),
            retryLabel: 'common.retry'.tr(),
          ),
        ),
      ),
    ];
  }
}

/// Recherche débouncée et chips de rôle **exclusives** — `role` est un
/// paramètre unique au contrat.
class _MembersToolbar extends StatelessWidget {
  const _MembersToolbar({
    required this.filters,
    required this.onChanged,
    required this.showRoles,
  });

  final MemberFilters filters;
  final ValueChanged<MemberFilters> onChanged;
  final bool showRoles;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
          child: PdlSearchField(
            key: keys.team.membersSearchField,
            value: filters.search,
            hintText: 'teams.membersList.searchPlaceholder'.tr(),
            clearTooltip: 'common.clearSearch'.tr(),
            onChanged: (String? value) => onChanged(
              value == null
                  ? filters.copyWith(clearSearch: true)
                  : filters.copyWith(search: value),
            ),
          ),
        ),
        if (showRoles) ...<Widget>[
          const SizedBox(height: PdlSpacing.chipGap),
          PdlChipRow(
            children: <Widget>[
              PdlChip(
                label: 'teams.membersList.allRoles'.tr(),
                selected: filters.role == null,
                onTap: () => onChanged(filters.copyWith(clearRole: true)),
              ),
              for (final TeamRole role in TeamRole.$valuesDefined)
                PdlChip(
                  label: AppFormatters.roleName(role.json ?? ''),
                  selected: filters.role == role,
                  onTap: () => onChanged(
                    filters.role == role
                        ? filters.copyWith(clearRole: true)
                        : filters.copyWith(role: role),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Une ligne du trombinoscope : avatar, nom, badge de rôle, ancienneté.
class _MemberRow extends StatelessWidget {
  const _MemberRow({
    super.key,
    required this.member,
    this.showDivider = true,
    this.onTap,
  });

  final MemberDto member;
  final bool showDivider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final DateTime? joined = member.joinedAt == null
        ? null
        : AppFormatters.tryParseDisplayTime(member.joinedAt!);

    // `role` est nul quand l'appelant n'y a pas droit : un organisateur qui lit
    // une équipe dont le trombinoscope n'est pas ouvert obtient les noms, et
    // rien d'autre. On ne devine pas un rôle — on n'affiche pas de badge.
    final String? role = member.role;

    return PdlPersonRow(
      key: keys.team.memberRow(member.user.id),
      name: member.user.displayName,
      imageUrl: member.user.avatarUrl,
      // Le menu de modération, et non un profil public, qui n'existe pas.
      onTap: onTap,
      subtitle: joined == null
          ? null
          : 'teams.membersList.since'.tr(
              namedArgs: <String, String>{
                'date': AppFormatters.formatMonthAndYear(joined),
              },
            ),
      roleBadge: role == null
          ? null
          : PdlBadge(
              label: AppFormatters.roleName(role),
              tone: TeamRole.fromJson(role).tone(c),
            ),
      showDivider: showDivider,
    );
  }
}
