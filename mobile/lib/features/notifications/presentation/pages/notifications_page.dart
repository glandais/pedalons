import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pagination/pagination.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/link_launcher.dart';
import '../../../teams/providers/team_providers.dart';
import '../../providers/notifications_provider.dart';
import '../notification_display.dart';
import '../widgets/notification_tile.dart';
import '../widgets/push_activation_banner.dart';
import '../../../feedback/presentation/report_problem_button.dart';
import '../../../../keys.dart';

/// La boîte de réception : la liste paginée, et un filtre « non lues ».
///
/// Elle vit dans la branche **Accueil** du shell, d'où la cloche l'ouvre :
/// c'est la seule branche pour laquelle `getDestinationIndex` rend le bon
/// onglet sans règle supplémentaire, et l'écran s'atteint depuis l'accueil.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PagedListState<NotificationDto> state = ref.watch(
      notificationsProvider(_unreadOnly),
    );
    final NotificationsNotifier notifier = ref.read(
      notificationsProvider(_unreadOnly).notifier,
    );
    // Le bouton agit sur la boîte entière, donc le compteur global le
    // justifie ; mais une non lue sous les yeux le justifie aussi, et le
    // compteur peut être en retard d'un sondage — ou muet sur un écran monté
    // hors session, comme en test.
    final int unread = ref.watch(unreadNotificationCountProvider);
    final bool hasUnread =
        unread > 0 || state.items.any((NotificationDto item) => !item.read);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: PdlAppBar(
        title: 'notifications.title'.tr(),
        // Ouverte depuis la cloche de l'accueil, la page a une pile derrière
        // elle ; ouverte par un lien froid, elle n'en a pas et la flèche
        // retombe sur l'accueil — même arbitrage que le profil.
        onBack: () =>
            context.canPop() ? context.pop() : context.go(Paths.home()),
        backSemanticLabel: 'common.back'.tr(),
        actions: <Widget>[
          // Les réglages vivent dans le profil (`/profil/notifications`), une
          // autre branche du shell : `go` y change d'onglet, et leur retour
          // retombe sur le profil.
          PdlAppBarAction(
            key: keys.notifications.settingsButton,
            icon: PdlIcons.settings,
            semanticLabel: 'notifications.settings'.tr(),
            onPressed: () => context.go(Paths.profileNotifications()),
          ),
          if (hasUnread)
            PdlAppBarAction(
              key: keys.notifications.markAllReadButton,
              icon: PdlIcons.done,
              semanticLabel: 'notifications.markAllRead'.tr(),
              onPressed: () => _markAllRead(notifier),
            ),
        ],
      ),
      body: PdlRefresh(
        onRefresh: () async {
          await notifier.refresh();
          await ref.read(unreadNotificationCountProvider.notifier).refresh();
        },
        child: CustomScrollView(
          primary: true,
          slivers: <Widget>[
            PdlPinnedToolbar(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: PdlSpacing.section,
                ),
                child: PdlSegmented<bool>(
                  key: keys.notifications.filter,
                  value: _unreadOnly,
                  onChanged: (bool value) =>
                      setState(() => _unreadOnly = value),
                  segments: <PdlSegment<bool>>[
                    PdlSegment<bool>(
                      key: keys.notifications.filterAll,
                      value: false,
                      label: 'notifications.filter.all'.tr(),
                    ),
                    PdlSegment<bool>(
                      key: keys.notifications.filterUnread,
                      value: true,
                      label: 'notifications.filter.unread'.tr(),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: PushActivationBanner()),
            ..._content(state, notifier),
            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
      ),
    );
  }

  Future<void> _markAllRead(NotificationsNotifier notifier) async {
    final bool otherFilter = !_unreadOnly;
    try {
      await notifier.markAllRead();
      if (!mounted) return;
      // L'autre filtre a sa propre instance : s'il vit encore, ses lignes
      // disent « non lue » à tort. Il sera relu à son prochain affichage.
      ref.invalidate(notificationsProvider(otherFilter));
      await ref.read(unreadNotificationCountProvider.notifier).refresh();
    } catch (error, stackTrace) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(getErrorMessage(error, stackTrace))),
      );
    }
  }

  Future<void> _open(
    NotificationsNotifier notifier,
    NotificationDto notification,
  ) async {
    final String? path = notification.path();
    // La lecture d'abord, la navigation ensuite : l'écran suivant se pose
    // par-dessus celui-ci, et une pastille qui ne bouge qu'au retour donne
    // l'impression que le geste n'a rien fait.
    _markReadInBackground(notifier, notification);
    final String? webPath = notification.webPath();
    if (path == null && webPath != null) {
      // Une page que seul le site sait afficher : la file de signalements.
      final bool opened = await openWebPage(webPath);
      if (!opened && mounted) showUnopenableLinkBanner(context, webPath);
      return;
    }
    if (path == null || !mounted) return;
    if (notification.subjectTypeEnum == NotificationSubjectType.team) {
      // Une invitation ouvre la liste des équipes, qui est la racine d'un
      // onglet : on y *va* plutôt que de l'empiler sur l'accueil, ce qui
      // fondrait les deux branches et laisserait l'onglet « Accueil » allumé.
      // Les invitations sont relues, la nouvelle n'y est peut-être pas encore.
      ref.invalidate(myInvitationsProvider);
      context.go(path);
      return;
    }
    context.push(path);
  }

  void _markReadInBackground(
    NotificationsNotifier notifier,
    NotificationDto notification,
  ) {
    if (notification.read) return;
    notifier
        .markRead(notification)
        .then((_) {
          if (mounted) {
            ref.read(unreadNotificationCountProvider.notifier).refresh();
          }
        })
        .catchError((_) {
          // Sans effet visible : la ligne est déjà grisée localement, et le
          // prochain sondage de la pastille rétablira la vérité du serveur.
        });
  }

  List<Widget> _content(
    PagedListState<NotificationDto> state,
    NotificationsNotifier notifier,
  ) {
    if (state.showsSkeletons) {
      return <Widget>[
        const SliverPadding(
          padding: EdgeInsets.only(top: PdlSpacing.chipGap),
          sliver: SliverToBoxAdapter(
            child: PdlSkeletonCardList(
              variant: PdlSkeletonCardVariant.person,
              count: 6,
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
      // Une boîte vide et une boîte filtrée ne disent pas la même chose, et la
      // seconde doit offrir la sortie — sans quoi c'est un cul-de-sac.
      return <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: PdlEmptyState(
              key: _unreadOnly ? keys.notifications.unreadEmptyState : null,
              variant: PdlEmptyVariant.empty,
              icon: PdlIcons.notificationsOff,
              title: _unreadOnly
                  ? 'notifications.empty.unreadTitle'.tr()
                  : 'notifications.empty.title'.tr(),
              message: _unreadOnly
                  ? 'notifications.empty.unreadHint'.tr()
                  : 'notifications.empty.hint'.tr(),
              actions: _unreadOnly
                  ? <Widget>[
                      PdlButton(
                        key: keys.notifications.showAllButton,
                        label: 'notifications.filter.all'.tr(),
                        variant: PdlButtonVariant.outline,
                        size: PdlButtonSize.sm,
                        onPressed: () => setState(() => _unreadOnly = false),
                      ),
                    ]
                  : const <Widget>[],
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
            'notifications.count'.plural(
              total,
              args: <String>[AppFormatters.formatNumber(total)],
            ),
            style: context.pdlText.count,
          ),
        ),
      ),
      SliverList.separated(
        itemCount: state.items.length,
        separatorBuilder: (BuildContext context, int _) =>
            Divider(height: 1, thickness: 1, color: context.pdl.borderSubtle),
        itemBuilder: (BuildContext context, int index) {
          notifier.onItemBuilt(index);
          final NotificationDto notification = state.items[index];
          return NotificationTile(
            key: keys.notifications.tile(notification.id),
            notification: notification,
            onTap: notification.path() == null && notification.webPath() == null
                ? null
                : () => _open(notifier, notification),
          );
        },
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
            progressLabel: pagedProgressNamed(
              'notifications.noun',
              state.items.length,
              total,
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
