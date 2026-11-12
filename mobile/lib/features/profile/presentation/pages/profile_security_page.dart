import 'package:easy_localization/easy_localization.dart';

import '../../../../config/paths.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/utils/push_location.dart';
import '../widgets/data_and_account_section.dart';
import '../widgets/passkeys_section.dart';
import '../widgets/profile_subpage.dart';

/// Connexion et sécurité : les clés d'accès, et « Déconnecter tous les
/// appareils ». La suppression du compte n'est pas ici mais dans « Mon
/// compte », vers lequel la page renvoie : une action rare et sans retour
/// descend d'un niveau, dans la page qui la concerne.
class ProfileSecurityPage extends StatelessWidget {
  const ProfileSecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileSubpage(
      title: 'profile.nav.security'.tr(),
      slivers: <Widget>[
        const SliverToBoxAdapter(child: PasskeysSection()),
        SliverToBoxAdapter(
          child: ProfileSection(
            title: 'profile.sessions.title'.tr(),
            child: const LogoutAllCard(),
          ),
        ),
        SliverToBoxAdapter(
          child: ProfileSection(
            child: PdlCard(
              padding: PdlCardPadding.none,
              child: PdlSettingRow(
                title: 'profile.sessions.deleteAccount'.tr(),
                onTap: () => pushLocation(context, Paths.profileAccount()),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
