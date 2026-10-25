import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../api/generated/export.dart';
import '../../../core/pagination/pagination.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/notifications_repository.dart';

/// Le rythme du sondage de la pastille.
///
/// Phase 1 n'a pas de canal temps réel (`docs/plans/archive/2026-09-18-notifications.md`
/// §9) : les clients interrogent `unread-count`, qui est fait pour ça, au plus
/// une fois par minute. Descendre sous cette barre coûte une requête par minute
/// et par appareil pour un chiffre qui bouge quelques fois par jour.
const Duration kUnreadPollInterval = Duration(minutes: 1);

/// Le nombre de non lues, rafraîchi périodiquement et à la demande.
///
/// Il se remet à zéro et cesse de sonder dès que la session tombe : l'endpoint
/// répond 401 sans jeton, et l'intervalle continuerait sinon à produire une
/// erreur par minute sur l'écran de connexion.
final unreadNotificationCountProvider =
    StateNotifierProvider<UnreadCountNotifier, int>((ref) {
      final UnreadCountNotifier notifier = UnreadCountNotifier(ref);
      ref.listen<bool>(
        authProvider.select((AuthState s) => s.isAuthenticated),
        (bool? previous, bool next) => notifier.onAuthChanged(next),
        fireImmediately: true,
      );
      return notifier;
    });

class UnreadCountNotifier extends StateNotifier<int> {
  UnreadCountNotifier(this._ref) : super(0);

  final Ref _ref;
  Timer? _timer;

  void onAuthChanged(bool isAuthenticated) {
    _timer?.cancel();
    _timer = null;
    if (!isAuthenticated) {
      state = 0;
      return;
    }
    unawaited(refresh());
    _timer = Timer.periodic(kUnreadPollInterval, (_) => unawaited(refresh()));
  }

  /// Un échec laisse la pastille telle quelle : une boîte momentanément
  /// injoignable n'est pas une boîte vide, et la remettre à zéro ferait
  /// disparaître une pastille légitime à la première coupure réseau.
  Future<void> refresh() async {
    try {
      final int count = await _ref
          .read(notificationsRepositoryProvider)
          .unreadCount();
      if (mounted) state = count;
    } catch (_) {
      // Ignoré volontairement — voir ci-dessus.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// La liste paginée, filtrée ou non sur les non lues.
final notificationsProvider = StateNotifierProvider.autoDispose
    .family<NotificationsNotifier, PagedListState<NotificationDto>, bool>((
      ref,
      unreadOnly,
    ) {
      return NotificationsNotifier(
        ref.watch(notificationsRepositoryProvider),
        unreadOnly: unreadOnly,
      );
    });

class NotificationsNotifier extends PagedListNotifier<NotificationDto> {
  NotificationsNotifier(this._repository, {required this._unreadOnly});

  final NotificationsRepository _repository;
  final bool _unreadOnly;

  @override
  Future<PageResult<NotificationDto>> fetchPage(int page) {
    return _repository.fetchPage(
      page: page,
      size: pageSize,
      unreadOnly: _unreadOnly,
    );
  }

  @override
  Object? itemKey(NotificationDto item) => item.id;

  /// Marque une notification lue et la reflète **sur place**, sans recharger :
  /// on vient de toucher la ligne, elle doit changer d'état avant que l'écran
  /// suivant ne s'ouvre par-dessus.
  ///
  /// Déjà lue, rien n'est envoyé : l'endpoint est idempotent, mais un aller-
  /// retour par ouverture d'une notification ancienne ne sert à rien.
  Future<void> markRead(NotificationDto notification) async {
    if (notification.read) return;
    state = state.copyWith(
      items: <NotificationDto>[
        for (final NotificationDto item in state.items)
          if (item.id == notification.id) item.copyWith(read: true) else item,
      ],
    );
    await _repository.markRead(notification.id);
  }

  /// Marque toute la boîte lue.
  ///
  /// La liste complète garde ses lignes, grisées sur place. La liste des non
  /// lues, elle, n'a plus rien à montrer : garder ses lignes marquées lues
  /// contredirait le filtre, et l'état vide « aucune non lue » n'apparaîtrait
  /// qu'au prochain rafraîchissement. On la relit donc depuis le serveur, qui
  /// fait foi — une notification arrivée entre-temps y reste.
  ///
  /// L'autre filtre est une autre instance de la famille : c'est à l'écran de
  /// l'invalider (`NotificationsPage`), comme la pastille.
  Future<void> markAllRead() async {
    await _repository.markAllRead();
    if (!mounted) return;
    if (_unreadOnly) {
      await loadFirstPage(refreshing: true);
      return;
    }
    state = state.copyWith(
      items: <NotificationDto>[
        for (final NotificationDto item in state.items)
          item.copyWith(read: true),
      ],
    );
  }
}

/// La matrice type × canal. `channels` vide = rien à régler sur ce serveur.
final notificationPreferencesProvider =
    FutureProvider<NotificationPreferencesDto>((ref) {
      return ref.watch(notificationsRepositoryProvider).preferences();
    });
