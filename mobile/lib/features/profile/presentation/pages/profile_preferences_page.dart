import 'package:easy_localization/easy_localization.dart';

import '../../../../core/material.dart';

import '../widgets/preferences_section.dart';
import '../widgets/profile_subpage.dart';

/// Préférences : système d'unités, fuseau horaire, thème, langue.
class ProfilePreferencesPage extends StatelessWidget {
  const ProfilePreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileSubpage(
      title: 'profile.nav.preferences'.tr(),
      slivers: const <Widget>[
        SliverToBoxAdapter(child: ProfileSection(child: PreferencesSection())),
      ],
    );
  }
}
