import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/push_location.dart';
import '../../../../keys.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/profile_summary_provider.dart';
import '../widgets/connected_services_section.dart';
import '../widgets/paired_devices_section.dart';
import '../widgets/profile_subpage.dart';
import 'profile_help_page.dart';

/// Le profil : une **vue d'ensemble** courte, et une sous-page par sujet.
///
/// La carte d'identité mène à « Mon compte », que Réglages nomme aussi, en tête,
/// en toutes lettres ; viennent ensuite des raccourcis groupés — Réglages,
/// Sécurité et confidentialité, Compte —,
/// chacun avec **une ligne d'état** : on sait ce qu'on va trouver avant
/// d'ouvrir. « Se déconnecter » ferme la liste, une seule fois dans le profil.
///
/// Les mêmes libellés et les mêmes routes que le site (`/profil/preferences`,
/// `/profil/notifications`…). L'onglet Profil est une **racine** : pas de
/// flèche de retour ici ; chaque sous-page, elle, revient vers « Profil ».
///
/// Les lignes d'état viennent de deux sources, sans doublon : l'utilisateur
/// connecté (préférences d'affichage, services GPS connectés) et
/// `GET /api/users/me/profile-summary` (le reste, en un appel). Le résumé est
/// relu quand une sous-page se ferme, où l'un de ses compteurs a pu changer ;
/// tirer pour rafraîchir relit les deux sources.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserDto? user = ref.watch(
      authProvider.select((AuthState s) => s.user),
    );
    final ProfileSummaryDto? summary = ref.watch(profileSummaryProvider).value;

    // Le résumé est relu quand la sous-page se ferme
    // (`ProfileSummaryRefreshOnLeave`), quelle que soit la façon dont on y
    // est arrivé : rien à faire au retour du `push`.
    void open(String path) => pushLocation(context, path);

    return PdlScreenScaffold(
      appBar: PdlAppBar(title: 'profile.title'.tr()),
      // Les deux sources des lignes d'état : le résumé, et `/me` (préférences
      // d'affichage, services connectés), qu'un autre appareil a pu changer.
      onRefresh: () => Future.wait(<Future<void>>[
        ref.refresh(profileSummaryProvider.future),
        refreshCurrentUser(ref).catchError((Object _) {}),
      ]),
      slivers: <Widget>[
        const SliverToBoxAdapter(child: SizedBox(height: PdlSpacing.section)),
        SliverToBoxAdapter(
          child: ProfileSection(
            child: user == null
                ? const PdlSkeletonCard()
                : _IdentityCard(
                    user: user,
                    onTap: () => open(Paths.profileAccount()),
                  ),
          ),
        ),
        // Plus de groupe « Mon activité » (« Mes sorties », « Mes équipes ») :
        // l'accueil, « Je participe » de l'Agenda et l'onglet Équipes en
        // montrent déjà tout.
        SliverToBoxAdapter(
          child: _Group(
            title: 'profile.groups.settings'.tr(),
            rows: <Widget>[
              // En tête des réglages, même si la carte d'identité y mène déjà.
              _ShortcutRow(
                key: keys.profile.accountRow,
                icon: PdlIcons.person,
                title: 'profile.nav.account'.tr(),
                status: 'profile.status.account'.tr(),
                onTap: () => open(Paths.profileAccount()),
              ),
              _ShortcutRow(
                key: keys.profile.preferencesRow,
                icon: PdlIcons.units,
                title: 'profile.nav.preferences'.tr(),
                status: _preferencesStatus(context, ref, user),
                onTap: () => open(Paths.profilePreferences()),
              ),
              _ShortcutRow(
                key: keys.profile.notificationsRow,
                icon: PdlIcons.notifications,
                title: 'profile.nav.notifications'.tr(),
                status: summary == null
                    ? null
                    : _notificationsStatus(summary.notifications),
                onTap: () => open(Paths.profileNotifications()),
              ),
              _ShortcutRow(
                key: keys.profile.devicesRow,
                icon: PdlIcons.devices,
                title: 'profile.nav.devices'.tr(),
                status: summary == null ? null : _devicesStatus(user, summary),
                onTap: () => open(Paths.profileDevices()),
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: _Group(
            title: 'profile.groups.security'.tr(),
            rows: <Widget>[
              _ShortcutRow(
                key: keys.profile.securityRow,
                icon: PdlIcons.passkey,
                title: 'profile.nav.security'.tr(),
                status: summary == null
                    ? null
                    : 'profile.passkeys.count'.plural(summary.passkeyCount),
                onTap: () => open(Paths.profileSecurity()),
              ),
              _ShortcutRow(
                key: keys.profile.privacyRow,
                icon: PdlIcons.privacy,
                title: 'profile.nav.privacy'.tr(),
                status: summary == null
                    ? null
                    : '${'profile.status.blocked'.plural(summary.blockedUserCount)} · ${'profile.status.myData'.tr()}',
                onTap: () => open(Paths.profilePrivacy()),
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: _Group(
            title: 'profile.groups.account'.tr(),
            rows: <Widget>[
              _ShortcutRow(
                key: keys.profile.helpRow,
                icon: PdlIcons.info,
                title: 'profile.nav.help'.tr(),
                neutral: true,
                status: switch (appVersionLabel(ref)) {
                  '' => null,
                  final String version => 'profile.status.version'.tr(
                    namedArgs: <String, String>{'version': version},
                  ),
                },
                onTap: () => open(Paths.profileHelp()),
              ),
              const _LogoutRow(),
            ],
          ),
        ),
      ],
    );
  }

  String _preferencesStatus(
    BuildContext context,
    WidgetRef ref,
    UserDto? user,
  ) {
    final UserPreferences prefs = ref.watch(userPreferencesProvider);
    final String units = prefs.unitSystem == UnitSystem.imperial
        ? 'profile.unitOptions.imperial'.tr()
        : 'profile.unitOptions.metric'.tr();
    final String theme = switch (prefs.theme) {
      ThemePreference.light => 'profile.themeOptions.light'.tr(),
      ThemePreference.dark => 'profile.themeOptions.dark'.tr(),
      ThemePreference.system ||
      ThemePreference.$unknown => 'profile.themeOptions.system'.tr(),
    };
    final String language =
        'languages.${prefs.language ?? Localizations.localeOf(context).languageCode}'
            .tr();
    final String timezone =
        user?.timezone ?? 'profile.status.deviceTimezone'.tr();
    return <String>[units, timezone, theme, language].join(' · ');
  }

  /// Où vont les notifications : les canaux où au moins un type est allumé,
  /// et le résumé quotidien. Sans canal, elles restent dans l'application.
  String _notificationsStatus(ProfileNotificationSummaryDto n) {
    final bool email = n.enabledChannels.contains(NotificationChannel.email);
    final bool push = n.enabledChannels.contains(NotificationChannel.push);
    final String channels = switch ((email, push)) {
      (true, true) => 'profile.status.emailAndPush'.tr(),
      (true, false) => 'profile.status.emailOnly'.tr(),
      (false, true) => 'profile.status.pushOnly'.tr(),
      (false, false) => 'profile.status.inAppOnly'.tr(),
    };
    if (!n.emailDigest) return channels;
    return '$channels · ${'profile.status.digest'.tr()}';
  }

  /// Les services GPS connectés par leur nom, puis les compteurs appairés par
  /// type : « Garmin Connect · 1 Karoo ».
  String _devicesStatus(UserDto? user, ProfileSummaryDto summary) {
    final List<String> parts = <String>[
      for (final GpsServiceConnectionDto s
          in user?.connectedServices ?? const <GpsServiceConnectionDto>[])
        s.displayName,
    ];
    final Map<String, int> paired = <String, int>{};
    for (final PairedDeviceDto device in summary.pairedDevices) {
      final String name = pairedDeviceName(device);
      paired[name] = (paired[name] ?? 0) + 1;
    }
    paired.forEach((String device, int count) {
      parts.add(
        'profile.status.paired'.tr(
          namedArgs: <String, String>{'count': '$count', 'device': device},
        ),
      );
    });
    if (parts.isEmpty) return 'profile.status.noDevice'.tr();
    return parts.join(' · ');
  }
}

/// La carte d'identité : avatar, nom affiché, adresse e-mail, et le chemin
/// vers « Mon compte » — toute la carte est la cible.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.user, required this.onTap});

  final UserDto user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return Semantics(
      button: true,
      child: PdlCard(
        key: keys.profile.identityCard,
        onTap: onTap,
        child: Row(
          children: <Widget>[
            PdlAvatar(
              name: user.displayName,
              imageUrl: user.avatarUrl,
              size: 60,
              isCurrentUser: true,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.cardTitle,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.sub,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'profile.overview.identityLink'.tr(),
                    style: t.sub.copyWith(
                      color: c.link,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(PdlIcons.chevronRight, size: 20, color: c.textPlaceholder),
          ],
        ),
      ),
    );
  }
}

/// Un groupe de raccourcis : un en-tête, une carte, des lignes séparées.
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    return ProfileSection(
      title: title,
      child: PdlCard(
        padding: PdlCardPadding.none,
        child: Column(
          children: <Widget>[
            for (int i = 0; i < rows.length; i++)
              if (i < rows.length - 1)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: c.borderSubtle)),
                  ),
                  child: rows[i],
                )
              else
                rows[i],
          ],
        ),
      ),
    );
  }
}

/// Un raccourci : pastille d'icône, titre, ligne d'état, chevron. La ligne d'état est absente tant que sa donnée n'est pas arrivée,
/// plutôt qu'un « Chargement… » sur chaque ligne.
class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.status,
    this.neutral = false,
  });

  final IconData icon;
  final String title;
  final String? status;
  final VoidCallback onTap;

  /// Pastille grise plutôt qu'indigo : le groupe « Compte ».
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    return PdlSettingRow(
      leading: _IconTile(icon: icon, neutral: neutral),
      title: title,
      subtitle: status,
      trailing: Icon(PdlIcons.chevronRight, size: 20, color: c.textPlaceholder),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      onTap: onTap,
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, this.neutral = false});

  final IconData icon;
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    return ExcludeSemantics(
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: neutral ? c.neutralSoft : c.primarySoft,
          borderRadius: PdlRadii.mdAll,
        ),
        child: Icon(
          icon,
          size: 18,
          color: neutral ? c.neutralOnSoft : c.primaryOnSoft,
        ),
      ),
    );
  }
}

/// « Se déconnecter » : la seule occurrence du profil, en bas de la liste.
class _LogoutRow extends ConsumerStatefulWidget {
  const _LogoutRow();

  @override
  ConsumerState<_LogoutRow> createState() => _LogoutRowState();
}

class _LogoutRowState extends ConsumerState<_LogoutRow> {
  bool _busy = false;

  Future<void> _logout() async {
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).logout();
      if (mounted) context.go(Paths.login());
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(getErrorMessage(error, stackTrace))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PdlSettingRow(
      key: keys.profile.logoutButton,
      leading: const _IconTile(icon: PdlIcons.logout, neutral: true),
      title: 'profile.account.logout'.tr(),
      trailing: const SizedBox.shrink(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      onTap: _busy ? null : _logout,
    );
  }
}
