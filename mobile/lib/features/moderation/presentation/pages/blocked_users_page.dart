import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../data/moderation_repository.dart';
import '../../providers/moderation_refresh.dart';
import '../../../feedback/presentation/report_problem_button.dart';
import '../../../../keys.dart';
import '../../../profile/presentation/widgets/profile_subpage.dart';

/// « Personnes bloquées » — ouverte depuis le profil, mobile seulement.
///
/// Une liste courte et non paginée : on bloque une poignée de personnes, pas
/// un annuaire. Chaque ligne porte **son** bouton « Débloquer », sans
/// confirmation : le geste se défait en rebloquant, et il ne révèle rien à la
/// personne concernée.
class BlockedUsersPage extends ConsumerStatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  ConsumerState<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends ConsumerState<BlockedUsersPage> {
  /// Les lignes dont le déblocage est en cours : leur bouton tourne, les
  /// autres restent actifs.
  final Set<String> _pending = <String>{};

  Future<void> _unblock(PublicUserDto user) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ProviderContainer container = ProviderScope.containerOf(
      context,
      listen: false,
    );
    setState(() => _pending.add(user.id));
    String message;
    try {
      await ref.read(moderationRepositoryProvider).unblock(user.id);
      refreshAfterBlockChange(container);
      message = 'moderation.unblocked'.tr(
        namedArgs: <String, String>{'name': user.displayName},
      );
    } catch (error, stackTrace) {
      message = getErrorMessage(error, stackTrace);
    }
    if (mounted) setState(() => _pending.remove(user.id));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final AsyncValue<List<PublicUserDto>> blocked = ref.watch(
      blockedUsersProvider,
    );

    return ProfileSummaryRefreshOnLeave(
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: PdlAppBar(
          title: 'moderation.blockedUsers.title'.tr(),
          // Sous-route de « Confidentialité » : même ouverte par `go`, la page
          // la trouve dessous, le retour par défaut suffit.
          onBack: () => leaveProfileSubpage(context),
          backSemanticLabel: 'common.back'.tr(),
          backKey: keys.profile.backButton,
        ),
        body: PdlRefresh(
          onRefresh: () => ref.refresh(blockedUsersProvider.future),
          child: CustomScrollView(
            primary: true,
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.all(PdlSpacing.section),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'moderation.blockedUsers.hint'.tr(),
                    style: context.pdlText.sub,
                  ),
                ),
              ),
              ...blocked.when(
                // Le premier chargement seulement : une relecture après un
                // déblocage garde la liste affichée.
                skipLoadingOnRefresh: true,
                skipLoadingOnReload: true,
                data: _list,
                loading: () => const <Widget>[
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: PdlSpacing.section,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: PdlSkeletonCardList(
                        variant: PdlSkeletonCardVariant.person,
                        count: 3,
                      ),
                    ),
                  ),
                ],
                error: (Object error, StackTrace stack) => <Widget>[
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: PdlEmptyState(
                        variant: PdlEmptyVariant.error,
                        title: 'common.loadError'.tr(),
                        message: getErrorMessage(error, stack),
                        actions: <Widget>[
                          PdlButton(
                            label: 'common.retry'.tr(),
                            variant: PdlButtonVariant.outline,
                            size: PdlButtonSize.sm,
                            onPressed: () =>
                                ref.invalidate(blockedUsersProvider),
                          ),
                          ReportProblemButton(error: error, stackTrace: stack),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _list(List<PublicUserDto> users) {
    if (users.isEmpty) {
      return <Widget>[
        SliverToBoxAdapter(
          child: PdlEmptyState(
            variant: PdlEmptyVariant.empty,
            title: 'moderation.blockedUsers.emptyTitle'.tr(),
            message: 'moderation.blockedUsers.emptyMessage'.tr(),
          ),
        ),
      ];
    }
    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
        sliver: SliverToBoxAdapter(
          child: PdlCard(
            padding: PdlCardPadding.none,
            child: Column(
              children: <Widget>[
                for (int i = 0; i < users.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PdlSpacing.card,
                    ),
                    child: PdlPersonRow(
                      name: users[i].displayName,
                      imageUrl: users[i].avatarUrl,
                      showDivider: i < users.length - 1,
                      // « Débloquer » répété sur chaque ligne ne dit pas qui :
                      // le libellé lu nomme la personne.
                      trailing: Semantics(
                        label: 'moderation.unblockSemantic'.tr(
                          namedArgs: <String, String>{
                            'name': users[i].displayName,
                          },
                        ),
                        button: true,
                        excludeSemantics: true,
                        onTap: _pending.contains(users[i].id)
                            ? null
                            : () => _unblock(users[i]),
                        child: PdlButton(
                          key: keys.moderation.unblockButton(users[i].id),
                          label: 'moderation.unblock'.tr(),
                          variant: PdlButtonVariant.outline,
                          size: PdlButtonSize.sm,
                          loading: _pending.contains(users[i].id),
                          onPressed: () => _unblock(users[i]),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ];
  }
}
