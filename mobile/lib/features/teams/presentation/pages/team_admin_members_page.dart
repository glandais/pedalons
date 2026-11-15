import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/lists/list_states.dart';
import '../../../../core/material.dart';
import '../../../../core/pagination/pagination.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../keys.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../moderation/presentation/moderation_menu.dart';
import '../../../profile/presentation/widgets/confirm_sheet.dart';
import '../../data/team_invitations_repository.dart';
import '../../data/team_repository.dart';
import '../../domain/member_filters.dart';
import '../../domain/team_member_limit.dart';
import '../../providers/team_access_probe.dart';
import '../../providers/team_change.dart';
import '../../providers/team_invitations_provider.dart';
import '../../providers/team_members_provider.dart';
import '../../providers/team_permission_providers.dart';
import '../../providers/team_providers.dart';
import '../widgets/dashboard/dashboard_section.dart' show openTeamWebPage;
import '../widgets/team_invite_sheet.dart';
import '../widgets/team_role_sheet.dart';

/// L'écran « Gestion des membres », feuille d'invitation ouverte : là où mène
/// « Inviter » du tableau de bord. Le site lit le même `?invite=1`.
String teamAdminMembersInviteLocation(String teamSlug) =>
    '${Paths.teamAdminMembers(teamSlug)}?invite=1';

/// « Gestion des membres » — le pendant mobile de `TeamMembersPage` du site
/// (docs/LEDGER_*.md MOB-167) : la liste des membres avec leur rôle, les
/// invitations en attente, et les gestes d'une personne qui administre
/// l'équipe (changer un rôle, retirer quelqu'un, inviter par e-mail).
///
/// **Réservé à l'administration de l'équipe** (et à l'admin de plateforme).
/// Cet écran montre des noms et sa recherche trouve des adresses e-mail : le
/// refus est tranché **avant** que la moindre requête de membres ou
/// d'invitations ne parte — les deux listes ne sont écoutées que par le corps
/// rendu une fois le droit établi (invariant « les noms des membres
/// n'atteignent jamais un non-membre », ledger `API-144`).
///
/// Le trombinoscope (`team_members_page.dart`), lui, ne change pas.
class TeamAdminMembersPage extends ConsumerWidget {
  const TeamAdminMembersPage({
    super.key,
    required this.teamSlug,
    this.openInvite = false,
  });

  final String teamSlug;

  /// `?invite=1` : la feuille d'invitation s'ouvre avec l'écran, si l'équipe
  /// peut inviter.
  final bool openInvite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // [teamReadable] faux : l'équipe elle-même s'est refusée, sa page ne
    // dirait qu'« Équipe indisponible » — le retour mène à « Mes équipes ».
    void back({bool teamReadable = true}) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(teamReadable ? Paths.team(teamSlug) : Paths.teams());
      }
    }

    PdlAppBar appBar() => PdlAppBar(
      title: 'teams.adminMembers.title'.tr(),
      onBack: back,
      backSemanticLabel: 'common.back'.tr(),
    );

    Widget shell(Widget body) =>
        PdlScreenScaffold(appBar: appBar(), body: body);

    Widget forbidden({required bool teamReadable}) => shell(
      PdlEmptyState(
        key: keys.teamAdminMembers.forbidden,
        variant: PdlEmptyVariant.empty,
        icon: PdlIcons.admin,
        title: 'teams.adminMembers.forbiddenTitle'.tr(),
        message: 'teams.adminMembers.forbiddenMessage'.tr(),
        actions: <Widget>[
          PdlButton(
            key: keys.teamAdminMembers.forbiddenBack,
            label: 'common.back'.tr(),
            variant: PdlButtonVariant.outline,
            onPressed: () => back(teamReadable: teamReadable),
          ),
        ],
      ),
    );

    final AsyncValue<TeamDetailDto> team = ref.watch(
      teamDetailProvider(teamSlug),
    );
    final TeamDetailDto? teamValue = team.value;
    final Object? error = team.error;
    // Une fiche déjà lue reste l'écran en cours : chaque écriture la relit
    // (`notifyTeamChanged`), et une relecture en échec ne le remplace pas par
    // une erreur.
    if (teamValue == null && error != null) {
      // Une équipe que le serveur refuse (403, ou 404 pour une équipe privée
      // dont on n'est pas membre) : un refus, pas une panne à réessayer.
      if (isTeamAccessRefusal(error)) return forbidden(teamReadable: false);
      return shell(
        PdlEmptyState(
          key: keys.teamAdminMembers.loadError,
          variant: PdlEmptyVariant.error,
          title: 'common.loadError'.tr(),
          message: getErrorMessage(error),
          actions: <Widget>[
            PdlButton(
              label: 'common.retry'.tr(),
              onPressed: () => ref.invalidate(teamDetailProvider(teamSlug)),
            ),
          ],
        ),
      );
    }

    // `null` tant que la fiche charge : ni liste, ni refus.
    final bool? admin = ref.watch(isTeamAdminProvider(teamSlug));
    if (teamValue == null || admin == null) {
      return shell(const Center(child: CircularProgressIndicator.adaptive()));
    }
    if (!admin) return forbidden(teamReadable: true);

    return _AdminMembers(
      key: ValueKey<String>('${teamValue.id}@$teamSlug'),
      team: teamValue,
      appBar: appBar(),
      platformAdmin: ref.watch(isPlatformAdminProvider),
      openInvite: openInvite,
    );
  }
}

/// Le corps de l'écran, rendu à qui administre l'équipe — et à lui seul :
/// c'est lui qui écoute les membres et les invitations.
class _AdminMembers extends ConsumerStatefulWidget {
  const _AdminMembers({
    super.key,
    required this.team,
    required this.appBar,
    required this.platformAdmin,
    required this.openInvite,
  });

  final TeamDetailDto team;
  final PdlAppBar appBar;
  final bool platformAdmin;
  final bool openInvite;

  @override
  ConsumerState<_AdminMembers> createState() => _AdminMembersState();
}

class _AdminMembersState extends ConsumerState<_AdminMembers> {
  /// Une écriture est en cours : les autres attendent.
  bool _writing = false;

  /// Ce que le serveur a refusé (`LAST_ADMIN`…), dans la barre épinglée :
  /// visible où que soit la liste.
  String? _error;

  String get _slug => widget.team.slug;

  /// L'équipe ne prend plus d'invitation : pleine, et l'appelant n'est pas
  /// de l'administration de la plateforme, que le serveur exempte du plafond.
  bool get _inviteBlockedByLimit =>
      isTeamFull(widget.team) && !widget.platformAdmin;

  bool get _canInvite => widget.team.addMemberAllowed && !_inviteBlockedByLimit;

  @override
  void initState() {
    super.initState();
    if (widget.openInvite) {
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (mounted && _canInvite) _openInvite();
      });
    }
  }

  void _setFilters(MemberFilters next) {
    ref.read(adminMemberFiltersProvider(_slug).notifier).state = next;
  }

  void _snack(ScaffoldMessengerState messenger, String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  /// Les membres ont changé : la liste (toutes ses variantes de filtres, et
  /// le trombinoscope avec elles), puis la fiche et le tableau de bord —
  /// nombre de membres, répartition par rôle, nouveaux membres.
  void _membersChanged(ProviderContainer container) {
    container.invalidate(teamMembersProvider);
    notifyTeamChanged(container, _slug);
  }

  Future<void> _openInvite() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String? email = await showTeamInviteSheet(context, _slug);
    if (email == null) return;
    _snack(
      messenger,
      'teams.adminMembers.invite.sent'.tr(
        namedArgs: <String, String>{'email': email},
      ),
    );
  }

  /// Une écriture, une à la fois. `true` si elle a réussi ; son échec se lit
  /// dans le bandeau.
  Future<bool> _write(Future<void> Function() action) async {
    if (_writing) return false;
    setState(() {
      _writing = true;
      _error = null;
    });
    try {
      await action();
      return true;
    } catch (error, stackTrace) {
      if (mounted) {
        setState(() => _error = getErrorMessage(error, stackTrace));
      }
      return false;
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  Future<void> _changeRole(MemberDto member) async {
    final String? currentJson = member.role;
    if (currentJson == null) return;
    final TeamRole current = TeamRole.fromJson(currentJson);
    final TeamRole? picked = await showTeamRoleSheet(
      context,
      title: 'teams.adminMembers.roleOf'.tr(
        namedArgs: <String, String>{'name': member.user.displayName},
      ),
      current: current,
    );
    if (picked == null || picked == current || !mounted) return;

    final TeamRepository repository = ref.read(teamRepositoryProvider);
    // Pris avant l'`await` : l'écran peut être quitté avant la réponse.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ProviderContainer container = ProviderScope.containerOf(
      context,
      listen: false,
    );
    final bool done = await _write(() async {
      // L'identifiant de la **personne**, pas celui de l'adhésion.
      await repository.updateMemberRole(
        _slug,
        userId: member.user.id,
        role: picked,
      );
      _membersChanged(container);
    });
    if (done) _snack(messenger, 'teams.adminMembers.roleUpdated'.tr());
  }

  Future<void> _remove(MemberDto member) async {
    final bool confirmed = await confirmDestructive(
      context,
      title: 'teams.adminMembers.remove'.tr(),
      message: 'teams.adminMembers.removeConfirm'.tr(
        namedArgs: <String, String>{'name': member.user.displayName},
      ),
      confirmLabel: 'teams.adminMembers.removeAction'.tr(),
    );
    if (!confirmed || !mounted) return;

    final TeamRepository repository = ref.read(teamRepositoryProvider);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ProviderContainer container = ProviderScope.containerOf(
      context,
      listen: false,
    );
    final bool done = await _write(() async {
      // L'identifiant de la **personne**, pas celui de l'adhésion.
      await repository.removeMember(_slug, userId: member.user.id);
      _membersChanged(container);
    });
    if (done) _snack(messenger, 'teams.adminMembers.removed'.tr());
  }

  /// « Renvoyer » : réinviter la même adresse avec le même rôle — le serveur
  /// révoque l'invitation en attente et en émet une neuve.
  Future<void> _resend(TeamInvitationDto invitation) async {
    final TeamInvitationsRepository repository = ref.read(
      teamInvitationsRepositoryProvider,
    );
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ProviderContainer container = ProviderScope.containerOf(
      context,
      listen: false,
    );
    final bool done = await _write(() async {
      await repository.invite(
        _slug,
        email: invitation.email,
        role: invitation.role,
      );
      container.invalidate(teamInvitationsProvider(_slug));
    });
    if (done) {
      _snack(
        messenger,
        'teams.adminMembers.invite.sent'.tr(
          namedArgs: <String, String>{'email': invitation.email},
        ),
      );
    }
  }

  Future<void> _revoke(TeamInvitationDto invitation) async {
    final bool confirmed = await confirmDestructive(
      context,
      title: 'teams.adminMembers.pending.revoke'.tr(),
      message: 'teams.adminMembers.pending.revokeConfirm'.tr(
        namedArgs: <String, String>{'email': invitation.email},
      ),
      confirmLabel: 'teams.adminMembers.pending.revoke'.tr(),
    );
    if (!confirmed || !mounted) return;

    final TeamInvitationsRepository repository = ref.read(
      teamInvitationsRepositoryProvider,
    );
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ProviderContainer container = ProviderScope.containerOf(
      context,
      listen: false,
    );
    final bool done = await _write(() async {
      try {
        await repository.revoke(_slug, invitation.id);
      } on DioException catch (error) {
        // 409 : l'invitation n'est plus en attente — acceptée, déjà annulée
        // ou expirée. La liste affichée est périmée ; si elle a été acceptée,
        // l'équipe compte une personne de plus.
        if (error.response?.statusCode == 409) {
          container.invalidate(teamInvitationsProvider(_slug));
          _membersChanged(container);
        }
        rethrow;
      }
      container.invalidate(teamInvitationsProvider(_slug));
    });
    if (done) _snack(messenger, 'teams.adminMembers.pending.revoked'.tr());
  }

  Future<void> _openMemberMenu(MemberDto member) async {
    final PublicUserDto user = member.user;
    final String? role = member.role;
    // Parité stricte avec le site (décision D8) : le rôle d'une personne qui
    // administre l'équipe ne se modifie pas ici — la retirer reste possible.
    final bool canEditRole = role != null && role != TeamRole.admin.json;
    await showModerationMenu(
      context,
      title: user.displayName,
      leading: <ModerationMenuEntry>[
        if (canEditRole)
          ModerationMenuEntry(
            key: keys.teamAdminMembers.changeRoleAction,
            icon: PdlIcons.admin,
            title: 'teams.adminMembers.changeRole'.tr(),
            onSelected: () => _changeRole(member),
          ),
        ModerationMenuEntry(
          key: keys.teamAdminMembers.removeAction,
          icon: PdlIcons.personRemove,
          title: 'teams.adminMembers.remove'.tr(),
          destructive: true,
          onSelected: () => _remove(member),
        ),
      ],
      subject: ModerationSubject(
        teamSlug: _slug,
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
    final MemberFilters filters = ref.watch(adminMemberFiltersProvider(_slug));
    final PagedListState<MemberDto> state = ref.watch(
      teamMembersProvider(filters),
    );
    final TeamMembersNotifier notifier = ref.read(
      teamMembersProvider(filters).notifier,
    );
    // Une liste d'invitations qui n'a pas pu être lue ne se montre pas, comme
    // au site : la section est masquée quand elle est vide.
    final List<TeamInvitationDto> invitations =
        ref.watch(teamInvitationsProvider(_slug)).value ??
        const <TeamInvitationDto>[];

    return PdlScreenScaffold(
      appBar: widget.appBar,
      onRefresh: () async {
        ref.invalidate(teamInvitationsProvider(_slug));
        ref.invalidate(teamDetailProvider(_slug));
        await notifier.refresh();
      },
      slivers: <Widget>[
        SliverToBoxAdapter(child: _header(context)),
        if (invitations.isNotEmpty)
          SliverToBoxAdapter(child: _pending(context, invitations)),
        PdlPinnedToolbar(child: _toolbar(filters)),
        ..._memberSlivers(state, notifier, filters),
        const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
      ],
    );
  }

  /// Le compteur « n / limite membres », « Inviter par e-mail », et la notice
  /// d'une équipe pleine.
  Widget _header(BuildContext context) {
    final PdlTypography t = context.pdlText;
    final TeamDetailDto team = widget.team;
    final int? limit = team.memberLimit;
    final bool showNotice =
        team.addMemberAllowed && _inviteBlockedByLimit && limit != null;
    if (limit == null && !team.addMemberAllowed) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PdlSpacing.section,
        PdlSpacing.section,
        PdlSpacing.section,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: PdlSpacing.chipGap,
            runSpacing: PdlSpacing.chipGap,
            children: <Widget>[
              if (limit != null)
                Text(
                  'teams.dashboard.admin.memberCountOfLimit'.tr(
                    namedArgs: <String, String>{
                      'count': '${team.memberCount}',
                      'limit': '$limit',
                    },
                  ),
                  key: keys.teamAdminMembers.counter,
                  style: t.sectionTitle,
                ),
              if (team.addMemberAllowed)
                PdlButton(
                  key: keys.teamAdminMembers.inviteButton,
                  label: 'teams.adminMembers.invite.open'.tr(),
                  icon: PdlIcons.personAdd,
                  size: PdlButtonSize.sm,
                  enabled: !_inviteBlockedByLimit,
                  onPressed: _openInvite,
                ),
            ],
          ),
          if (showNotice) ...<Widget>[
            const SizedBox(height: PdlSpacing.chipGap),
            PdlBanner(
              key: keys.teamAdminMembers.fullNotice,
              tone: PdlBannerTone.warn,
              message: 'teams.adminMembers.full'.tr(
                namedArgs: <String, String>{'limit': '$limit'},
              ),
              // La page d'assistance du site : l'app n'en a pas l'écran.
              action: PdlButton(
                key: keys.teamAdminMembers.contactLink,
                label: 'teams.adminMembers.contact'.tr(),
                variant: PdlButtonVariant.text,
                size: PdlButtonSize.sm,
                onPressed: () => openTeamWebPage(context, Paths.support()),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Les invitations en attente : une carte par invitation, à la place du
  /// tableau large du site. C'est ici qu'une adresse mal saisie se voit.
  Widget _pending(BuildContext context, List<TeamInvitationDto> invitations) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return Padding(
      key: keys.teamAdminMembers.pendingSection,
      padding: const EdgeInsets.fromLTRB(
        PdlSpacing.section,
        PdlSpacing.section,
        PdlSpacing.section,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PdlSectionHeader(title: 'teams.adminMembers.pending.title'.tr()),
          Text(
            'teams.adminMembers.pending.help'.tr(),
            style: t.xs.copyWith(color: c.textDimmed),
          ),
          for (final TeamInvitationDto invitation in invitations) ...<Widget>[
            const SizedBox(height: PdlSpacing.chipGap),
            _InvitationCard(
              key: keys.teamAdminMembers.invitation(invitation.id),
              invitation: invitation,
              enabled: !_writing,
              onResend: () => _resend(invitation),
              onRevoke: () => _revoke(invitation),
            ),
          ],
        ],
      ),
    );
  }

  /// La barre épinglée : le bandeau d'erreur, la recherche par nom ou e-mail,
  /// et les puces de rôle — **exclusives**, `role` étant un paramètre unique
  /// au contrat. Pas de tri, comme le site.
  Widget _toolbar(MemberFilters filters) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PdlSpacing.section,
              0,
              PdlSpacing.section,
              PdlSpacing.chipGap,
            ),
            child: PdlBanner(
              key: keys.teamAdminMembers.errorBanner,
              tone: PdlBannerTone.danger,
              icon: PdlIcons.error,
              message: _error!,
              onDismiss: () => setState(() => _error = null),
              dismissSemanticLabel: 'common.close'.tr(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
          child: PdlSearchField(
            key: keys.teamAdminMembers.searchField,
            value: filters.search,
            hintText: 'teams.membersList.searchPlaceholderAdmin'.tr(),
            clearTooltip: 'common.clearSearch'.tr(),
            onChanged: (String? value) => _setFilters(
              value == null
                  ? filters.copyWith(clearSearch: true)
                  : filters.copyWith(search: value),
            ),
          ),
        ),
        const SizedBox(height: PdlSpacing.chipGap),
        PdlChipRow(
          children: <Widget>[
            PdlChip(
              key: keys.teamAdminMembers.roleChip('all'),
              label: 'teams.membersList.allRoles'.tr(),
              selected: filters.role == null,
              onTap: () => _setFilters(filters.copyWith(clearRole: true)),
            ),
            for (final TeamRole role in TeamRole.$valuesDefined)
              PdlChip(
                key: keys.teamAdminMembers.roleChip(role.json!),
                label: AppFormatters.roleName(role.json!),
                selected: filters.role == role,
                onTap: () => _setFilters(filters.copyWith(role: role)),
              ),
          ],
        ),
      ],
    );
  }

  List<Widget> _memberSlivers(
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
        ListStateSliver(
          child: ListLoadError(
            error: state.initialError!,
            onRetry: notifier.loadFirstPage,
          ),
        ),
      ];
    }

    if (state.isEmpty) {
      final String? search = filters.search?.trim();
      return <Widget>[
        ListStateSliver(
          child: filters.isFiltered
              ? ListFilteredEmpty(
                  key: keys.teamAdminMembers.filteredEmpty,
                  title: 'lists.emptyFiltered.members'.tr(),
                  filters: <String>[
                    if (search != null && search.isNotEmpty)
                      quotedSearch(search),
                    if (filters.role != null)
                      AppFormatters.roleName(filters.role!.json ?? ''),
                  ],
                  onClear: () => _setFilters(filters.cleared),
                )
              : PdlEmptyState(
                  key: keys.teamAdminMembers.empty,
                  variant: PdlEmptyVariant.empty,
                  icon: PdlIcons.people,
                  title: 'teams.membersList.none'.tr(),
                ),
        ),
      ];
    }

    final int total = state.total ?? state.items.length;
    return <Widget>[
      SliverToBoxAdapter(
        child: ListResultCount(
          listCountLabel('teams.membersList.count', total),
          textKey: keys.teamAdminMembers.resultCount,
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
        sliver: SliverList.builder(
          itemCount: state.items.length,
          itemBuilder: (BuildContext context, int index) {
            notifier.onItemBuilt(index);
            final MemberDto member = state.items[index];
            final bool isCurrentUser = member.user.id == currentUserId;
            return _AdminMemberRow(
              key: ValueKey<String>(member.id),
              member: member,
              isCurrentUser: isCurrentUser,
              showDivider: index < state.items.length - 1,
              // Sa propre ligne ne s'ouvre pas : on ne change pas son rôle,
              // on ne se retire pas, on ne se signale pas.
              onTap: isCurrentUser ? null : () => _openMemberMenu(member),
            );
          },
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
        sliver: SliverToBoxAdapter(
          child: PagedListFooter(
            state: state,
            onRetry: notifier.retryNextPage,
            itemNounKey: 'teams.membersList.noun',
          ),
        ),
      ),
    ];
  }
}

/// Une ligne de la gestion des membres : avatar, nom, « (vous) » sur la
/// sienne, ancienneté, badge de rôle.
class _AdminMemberRow extends StatelessWidget {
  const _AdminMemberRow({
    super.key,
    required this.member,
    required this.isCurrentUser,
    this.showDivider = true,
    this.onTap,
  });

  final MemberDto member;
  final bool isCurrentUser;
  final bool showDivider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PublicUserDto user = member.user;
    final DateTime? joined = AppFormatters.tryParseDisplayTime(member.joinedAt);
    final String? role = member.role;

    return PdlPersonRow(
      key: keys.teamAdminMembers.row(user.id),
      name: isCurrentUser
          ? 'teams.adminMembers.youName'.tr(
              namedArgs: <String, String>{'name': user.displayName},
            )
          : user.displayName,
      imageUrl: user.avatarUrl,
      isCurrentUser: isCurrentUser,
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
              key: keys.teamAdminMembers.rowRole(user.id),
              label: AppFormatters.roleName(role),
              tone: TeamRole.fromJson(role).tone(c),
            ),
      trailing: onTap == null
          ? null
          : ModerationMoreButton(
              key: keys.teamAdminMembers.rowMore(user.id),
              onPressed: onTap!,
            ),
      showDivider: showDivider,
    );
  }
}

/// Une invitation en attente : l'adresse, le rôle promis, qui l'a envoyée,
/// quand elle expire, et ses deux gestes.
class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    super.key,
    required this.invitation,
    required this.enabled,
    required this.onResend,
    required this.onRevoke,
  });

  final TeamInvitationDto invitation;
  final bool enabled;
  final VoidCallback onResend;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final DateTime? expires = AppFormatters.tryParseDisplayTime(
      invitation.expiresAt,
    );

    return PdlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Wrap(
            spacing: PdlSpacing.chipGap,
            runSpacing: PdlSpacing.badgeGap,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(invitation.email, style: t.bodyStrong),
              PdlBadge(
                label: AppFormatters.roleName(invitation.role),
                tone: TeamRole.fromJson(invitation.role).tone(c),
              ),
            ],
          ),
          const SizedBox(height: PdlSpacing.badgeGap),
          Text(
            'teams.adminMembers.pending.sentBy'.tr(
              namedArgs: <String, String>{
                'name': invitation.invitedBy.displayName,
              },
            ),
            style: t.xs.copyWith(color: c.textDimmed),
          ),
          if (expires != null)
            Text(
              'teams.adminMembers.pending.expiresAt'.tr(
                namedArgs: <String, String>{
                  'date': AppFormatters.formatLongDateWithoutWeekday(expires),
                },
              ),
              style: t.xs.copyWith(color: c.textDimmed),
            ),
          const SizedBox(height: PdlSpacing.chipGap),
          Wrap(
            spacing: PdlSpacing.chipGap,
            runSpacing: PdlSpacing.chipGap,
            children: <Widget>[
              PdlButton(
                key: keys.teamAdminMembers.invitationResend(invitation.id),
                label: 'teams.adminMembers.pending.resend'.tr(),
                icon: PdlIcons.email,
                variant: PdlButtonVariant.outline,
                size: PdlButtonSize.sm,
                enabled: enabled,
                onPressed: onResend,
              ),
              PdlButton(
                key: keys.teamAdminMembers.invitationRevoke(invitation.id),
                label: 'teams.adminMembers.pending.revoke'.tr(),
                icon: PdlIcons.delete,
                variant: PdlButtonVariant.danger,
                size: PdlButtonSize.sm,
                enabled: enabled,
                onPressed: onRevoke,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
