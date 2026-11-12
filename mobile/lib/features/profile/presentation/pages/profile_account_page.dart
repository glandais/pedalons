import 'package:easy_localization/easy_localization.dart';

import '../../../../core/material.dart';

import '../widgets/data_and_account_section.dart';
import '../widgets/profile_identity_section.dart';
import '../widgets/profile_subpage.dart';

/// Mon compte : photo, nom affiché (toujours éditable), adresse e-mail en
/// lecture seule, puis la zone de danger. On y arrive par la carte d'identité
/// de la vue d'ensemble.
class ProfileAccountPage extends StatelessWidget {
  const ProfileAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileSubpage(
      title: 'profile.nav.account'.tr(),
      slivers: const <Widget>[
        SliverToBoxAdapter(child: ProfileIdentitySection()),
        SliverToBoxAdapter(child: DeleteAccountSection()),
      ],
    );
  }
}
