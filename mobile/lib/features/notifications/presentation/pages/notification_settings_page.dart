import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../keys.dart';
import '../../../profile/presentation/widgets/profile_subpage.dart';
import '../../data/notifications_repository.dart';
import '../../providers/notifications_provider.dart';

/// Une famille de types, dans l'ordre où la page les montre — le même que le
/// site. Un type que cette version de l'app ne connaît pas n'apparaît pas :
/// il n'aurait pas de libellé.
@visibleForTesting
const List<(String, List<NotificationType>)> notificationFamilies =
    <(String, List<NotificationType>)>[
      (
        'rides',
        <NotificationType>[
          NotificationType.ridePublished,
          NotificationType.rideUpdated,
          NotificationType.rideCancelled,
          NotificationType.rideGroupRemoved,
          NotificationType.rideReminder,
          NotificationType.rideJoined,
        ],
      ),
      (
        'trips',
        <NotificationType>[
          NotificationType.tripPublished,
          NotificationType.tripCancelled,
        ],
      ),
      (
        'posts',
        <NotificationType>[
          NotificationType.postPublished,
          NotificationType.commentOnMyPublication,
          NotificationType.commentReply,
        ],
      ),
      (
        'teams',
        <NotificationType>[
          NotificationType.teamInvitation,
          NotificationType.contentReported,
        ],
      ),
    ];

/// Les réglages des notifications (`/profil/notifications`) : une ligne par
/// type, regroupées par famille, avec une **puce à bascule par canal** —
/// E-mail, Push — au lieu d'un interrupteur par case de la matrice (jusqu'à
/// vingt-six). Puis le résumé quotidien et les annonces des équipes.
///
/// **Seuls les canaux que le serveur déclare** (`channels`) ont une puce :
/// `IN_APP` n'est jamais réglable (la boîte reçoit tout, et le `PUT` le
/// refuse), et un serveur sans envoi d'e-mails ne déclare pas `EMAIL` — ni
/// puce E-mail ni résumé quotidien alors. Sans aucun canal, la page ne garde
/// que les équipes et le lien vers la boîte : dessiner des réglages sans effet
/// est ce que le brief §5 interdit.
///
/// Une puce écrit **une seule case** : envoyer la matrice entière
/// transformerait chaque défaut en dérogation explicite jamais choisie. Il en
/// va de même d'une équipe ou du résumé — un appel par geste.
class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  String? _error;
  bool _busy = false;

  /// Un appel, puis la relecture des préférences : c'est la réponse du
  /// serveur qui fait foi, pas l'état local de la puce.
  Future<void> _write(
    Future<void> Function(NotificationsRepository repository) call,
  ) async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await call(ref.read(notificationsRepositoryProvider));
      ref.invalidate(notificationPreferencesProvider);
      await ref.read(notificationPreferencesProvider.future);
    } catch (error, stackTrace) {
      if (mounted) setState(() => _error = getErrorMessage(error, stackTrace));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<NotificationPreferencesDto> async = ref.watch(
      notificationPreferencesProvider,
    );
    final NotificationPreferencesDto? data = async.value;

    // `$unknown` : un canal qu'une version plus ancienne de l'app ne connaît
    // pas. Il n'aurait ni nom traduit ni sens ici, on le laisse de côté.
    final List<NotificationChannel> channels =
        data?.channels
            .where(
              (NotificationChannel channel) =>
                  channel != NotificationChannel.$unknown,
            )
            .toList() ??
        const <NotificationChannel>[];

    return ProfileSubpage(
      title: 'notifications.preferences.title'.tr(),
      intro: data == null
          ? null
          : channels.isEmpty
          ? 'notifications.preferences.introInAppOnly'.tr()
          : 'notifications.preferences.intro'.tr(),
      onRefresh: () => ref.refresh(notificationPreferencesProvider.future),
      slivers: <Widget>[
        const SliverToBoxAdapter(child: ProfileSection(child: _InboxLink())),
        if (data == null)
          SliverToBoxAdapter(
            child: async.hasError
                ? PdlEmptyState(
                    variant: PdlEmptyVariant.error,
                    title: 'common.loadError'.tr(),
                    message: getErrorMessage(async.error!, async.stackTrace),
                    actions: <Widget>[
                      PdlButton(
                        label: 'common.retry'.tr(),
                        onPressed: () =>
                            ref.invalidate(notificationPreferencesProvider),
                      ),
                    ],
                  )
                : const ProfileSection(child: PdlSkeletonCard()),
          )
        else ...<Widget>[
          if (channels.isNotEmpty)
            for (final (String family, List<NotificationType> types)
                in notificationFamilies)
              if (_rowsOf(data, types, channels).isNotEmpty)
                SliverToBoxAdapter(
                  child: ProfileSection(
                    title: 'notifications.preferences.families.$family'.tr(),
                    child: PdlCard(
                      padding: PdlCardPadding.none,
                      child: Column(children: _rowsOf(data, types, channels)),
                    ),
                  ),
                ),
          if (channels.contains(NotificationChannel.email))
            SliverToBoxAdapter(child: ProfileSection(child: _digest(data))),
          if (data.teams.isNotEmpty)
            SliverToBoxAdapter(
              child: ProfileSection(
                title: 'notifications.preferences.teamsTitle'.tr(),
                footnote: 'notifications.preferences.teamsHint'.tr(),
                child: PdlCard(
                  padding: PdlCardPadding.none,
                  child: Column(
                    children: <Widget>[
                      for (int i = 0; i < data.teams.length; i++)
                        _team(data.teams[i], last: i == data.teams.length - 1),
                    ],
                  ),
                ),
              ),
            ),
          if (_error != null)
            SliverToBoxAdapter(
              child: ProfileSection(
                child: PdlBanner(tone: PdlBannerTone.danger, message: _error!),
              ),
            ),
        ],
      ],
    );
  }

  /// Les lignes d'une famille : un type n'a de ligne que si au moins une de
  /// ses cases existe parmi les canaux déclarés.
  List<Widget> _rowsOf(
    NotificationPreferencesDto data,
    List<NotificationType> types,
    List<NotificationChannel> channels,
  ) {
    final List<NotificationType> shown = types
        .where(
          (NotificationType type) => channels.any(
            (NotificationChannel channel) => _cell(data, type, channel) != null,
          ),
        )
        .toList();
    return <Widget>[
      for (int i = 0; i < shown.length; i++)
        _typeRow(data, shown[i], channels, last: i == shown.length - 1),
    ];
  }

  NotificationPreferenceDto? _cell(
    NotificationPreferencesDto data,
    NotificationType type,
    NotificationChannel channel,
  ) => data.preferences
      .where(
        (NotificationPreferenceDto p) =>
            p.type == type.toJson() && p.channel == channel.toJson(),
      )
      .firstOrNull;

  Widget _typeRow(
    NotificationPreferencesDto data,
    NotificationType type,
    List<NotificationChannel> channels, {
    required bool last,
  }) {
    final String typeLabel = 'notifications.typeLabel.${type.toJson()}'.tr();
    return PdlSettingRow(
      key: keys.notifications.typeRow(type.toJson()),
      title: typeLabel,
      showDivider: !last,
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final NotificationChannel channel in channels)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: switch (_cell(data, type, channel)) {
                final NotificationPreferenceDto cell => ChannelChip(
                  key: keys.notifications.channelChip(
                    type.toJson(),
                    channel.toJson(),
                  ),
                  typeLabel: typeLabel,
                  channel: channel,
                  on: cell.enabled,
                  onChanged: _busy
                      ? null
                      : (bool enabled) => _write(
                          (NotificationsRepository r) => r.setPreference(
                            type: type,
                            channel: channel,
                            enabled: enabled,
                          ),
                        ),
                ),
                // Une case que le serveur ne propose pas (un type sans
                // push) : une place vide de la même largeur, pour que les
                // puces restent en colonnes.
                null => ExcludeSemantics(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0,
                      child: ChannelChip(
                        typeLabel: typeLabel,
                        channel: channel,
                        on: false,
                        onChanged: null,
                      ),
                    ),
                  ),
                ),
              },
            ),
        ],
      ),
    );
  }

  /// Le résumé quotidien. Il ne concerne que l'e-mail : la page ne le montre
  /// que lorsque l'e-mail est un canal déclaré.
  Widget _digest(NotificationPreferencesDto data) {
    final String label = 'notifications.preferences.digest'.tr();
    return PdlCard(
      padding: PdlCardPadding.none,
      child: PdlSettingRow(
        title: label,
        subtitle: 'notifications.preferences.digestHint'.tr(),
        trailing: PdlSwitch(
          key: keys.notifications.digestSwitch,
          value: data.emailDigest,
          semanticLabel: label,
          onChanged: _busy
              ? null
              : (bool value) => _write(
                  (NotificationsRepository r) => r.setEmailDigest(value),
                ),
        ),
      ),
    );
  }

  /// Une équipe. L'interrupteur dit « je reçois ses annonces » — allumé par
  /// défaut, comme les puces — plutôt que « coupée », qui inverserait le sens
  /// d'une commande sur deux dans la même page.
  Widget _team(NotificationTeamPreferenceDto team, {required bool last}) {
    return PdlSettingRow(
      title: team.teamName,
      showDivider: !last,
      trailing: PdlSwitch(
        key: keys.notifications.teamSwitch(team.teamSlug),
        value: !team.muted,
        semanticLabel: 'notifications.preferences.teamSwitch'.tr(
          namedArgs: <String, String>{'team': team.teamName},
        ),
        onChanged: _busy
            ? null
            : (bool receive) => _write(
                (NotificationsRepository r) =>
                    r.setTeamMuted(teamSlug: team.teamSlug, muted: !receive),
              ),
      ),
    );
  }
}

/// La puce d'un canal sur la ligne d'un type : allumée, elle porte une coche.
///
/// Pour un lecteur d'écran c'est **un interrupteur nommé** — « Sortie
/// publiée, par e-mail », activé ou non — et non une puce « E-mail » de plus :
/// sur une page qui en compte une vingtaine, le libellé visible seul ne dirait
/// pas laquelle on touche.
class ChannelChip extends StatelessWidget {
  const ChannelChip({
    super.key,
    required this.typeLabel,
    required this.channel,
    required this.on,
    required this.onChanged,
  });

  final String typeLabel;
  final NotificationChannel channel;
  final bool on;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? toggle = onChanged == null
        ? null
        : () => onChanged!(!on);
    return Semantics(
      container: true,
      button: true,
      toggled: on,
      enabled: onChanged != null,
      label: 'notifications.preferences.chipSemantic.${channel.toJson()}'.tr(
        namedArgs: <String, String>{'type': typeLabel},
      ),
      onTap: toggle,
      excludeSemantics: true,
      child: PdlChip(
        label: 'notifications.channel.${channel.toJson()}'.tr(),
        selected: on,
        icon: on ? PdlIcons.check : null,
        onTap: toggle,
      ),
    );
  }
}

/// « Ouvrir mes notifications », avec le nombre de non lues. La boîte vit dans
/// la branche Accueil : on y va par `go`, qui change d'onglet sans empiler une
/// branche sur l'autre.
class _InboxLink extends ConsumerWidget {
  const _InboxLink();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    final int unread = ref.watch(unreadNotificationCountProvider);
    return PdlCard(
      padding: PdlCardPadding.none,
      child: PdlSettingRow(
        key: keys.notifications.openInboxRow,
        icon: PdlIcons.notifications,
        title: 'notifications.preferences.openInbox'.tr(),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (unread > 0)
              PdlBadge(
                label: unread > 99 ? '99+' : '$unread',
                size: PdlBadgeSize.lg,
                tone: PdlTone.pair(c.softRed, c.danger),
              ),
            const SizedBox(width: 4),
            Icon(PdlIcons.chevronRight, size: 20, color: c.textPlaceholder),
          ],
        ),
        onTap: () => context.go(Paths.notifications()),
      ),
    );
  }
}
