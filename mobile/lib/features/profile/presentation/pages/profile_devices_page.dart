import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/paths.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../widgets/connected_services_section.dart';
import '../widgets/paired_devices_section.dart';
import '../widgets/profile_subpage.dart';

/// Appareils et services : les comptes GPS connectés (Hammerhead, Garmin
/// Connect, Wahoo), les compteurs appairés par code (Karoo, Garmin), et le
/// chemin pour en appairer un.
class ProfileDevicesPage extends StatelessWidget {
  const ProfileDevicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileSubpage(
      title: 'profile.nav.devices'.tr(),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: ProfileSection(
            title: 'profile.gps.title'.tr(),
            child: const GpsServicesCard(),
          ),
        ),
        SliverToBoxAdapter(
          child: ProfileSection(
            title: 'profile.devices.title'.tr(),
            child: const PairedDevicesCard(),
          ),
        ),
        SliverToBoxAdapter(
          child: ProfileSection(
            title: 'profile.devices.howToPairTitle'.tr(),
            child: PdlCard(
              padding: PdlCardPadding.none,
              child: PdlSettingRow(
                icon: PdlIcons.devices,
                title: 'profile.devices.howToPair'.tr(),
                subtitle: 'profile.devices.hint'.tr(),
                onTap: () => context.push(Paths.apps()),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
