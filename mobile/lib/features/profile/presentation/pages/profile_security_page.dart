import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
class ProfileSecurityPage extends ConsumerWidget {
  const ProfileSecurityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProfileSubpage(
      title: 'profile.nav.security'.tr(),
      // Une clé créée ou retirée depuis un autre appareil n'arrive ici que si
      // on relit la liste.
      onRefresh: () async {
        ref.invalidate(passkeysProvider);
        try {
          await ref.read(passkeysProvider.future);
        } catch (_) {
          // L'échec se rend par l'état d'erreur de la section.
        }
      },
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
