import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/paths.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/error_reports_preference.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/push_location.dart';
import '../../../../keys.dart';
import '../../providers/profile_summary_provider.dart';
import '../widgets/data_and_account_section.dart';
import '../widgets/profile_subpage.dart';

/// Confidentialité : être contacté par les membres, les utilisateurs bloqués,
/// les rapports d'erreur, et l'export de mes données.
class ProfilePrivacyPage extends ConsumerStatefulWidget {
  const ProfilePrivacyPage({super.key});

  @override
  ConsumerState<ProfilePrivacyPage> createState() => _ProfilePrivacyPageState();
}

class _ProfilePrivacyPageState extends ConsumerState<ProfilePrivacyPage> {
  String? _error;

  /// L'interrupteur passe par `userPreferencesProvider`, qui applique en
  /// optimiste et revient en arrière sur un échec : l'écran ne fait que dire
  /// l'échec, sous la carte concernée.
  Future<void> _setContactable(bool value) async {
    setState(() => _error = null);
    try {
      await ref
          .read(userPreferencesProvider.notifier)
          .setContactableByMembers(value);
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() => _error = getErrorMessage(error, stackTrace));
    }
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final bool contactable = ref.watch(
      userPreferencesProvider.select(
        (UserPreferences p) => p.contactableByMembers,
      ),
    );
    // Le compteur du résumé : la page ne charge pas toute la liste pour un
    // nombre. Un blocage ou un déblocage l'invalide (`refreshAfterBlockChange`).
    final int? blocked = ref
        .watch(profileSummaryProvider)
        .value
        ?.blockedUserCount;

    return ProfileSubpage(
      title: 'profile.nav.privacy'.tr(),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: ProfileSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                PdlCard(
                  padding: PdlCardPadding.none,
                  child: PdlSettingRow(
                    icon: PdlIcons.email,
                    title: 'profile.contactable.title'.tr(),
                    subtitle: 'profile.contactable.hint'.tr(),
                    trailing: PdlSwitch(
                      key: keys.profile.contactableSwitch,
                      value: contactable,
                      onChanged: _setContactable,
                      semanticLabel: 'profile.contactable.title'.tr(),
                    ),
                  ),
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: PdlSpacing.chipGap),
                  PdlBanner(tone: PdlBannerTone.danger, message: _error!),
                ],
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: ProfileSection(
            title: 'profile.privacyPage.blockedTitle'.tr(),
            footnote: 'moderation.blockedUsers.hint'.tr(),
            child: PdlCard(
              padding: PdlCardPadding.none,
              child: PdlSettingRow(
                key: keys.moderation.blockedUsersRow,
                icon: PdlIcons.block,
                title: 'moderation.blockedUsers.title'.tr(),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (blocked != null && blocked > 0)
                      PdlBadge(
                        label: '$blocked',
                        size: PdlBadgeSize.lg,
                        tone: PdlTone.pair(c.softGray, c.neutral),
                      ),
                    const SizedBox(width: 4),
                    Icon(
                      PdlIcons.chevronRight,
                      size: 20,
                      color: c.textPlaceholder,
                    ),
                  ],
                ),
                onTap: () => pushLocation(context, Paths.blockedUsers()),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: ProfileSection(
            title: 'profile.privacyPage.reportsTitle'.tr(),
            // Réglage d'appareil, sans aller-retour serveur : il ne peut pas
            // échouer, donc pas de bandeau.
            child: PdlCard(
              padding: PdlCardPadding.none,
              child: PdlSettingRow(
                icon: PdlIcons.bug,
                title: 'feedback.autoReports.title'.tr(),
                subtitle: 'feedback.autoReports.hint'.tr(),
                trailing: PdlSwitch(
                  value: ref.watch(autoErrorReportsProvider),
                  onChanged: (bool value) =>
                      ref.read(autoErrorReportsProvider.notifier).set(value),
                  semanticLabel: 'feedback.autoReports.title'.tr(),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: ProfileSection(
            title: 'profile.data.title'.tr(),
            child: const DataExportCard(),
          ),
        ),
      ],
    );
  }
}
