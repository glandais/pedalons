import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../material.dart';
import '../pdl/pdl_banner.dart';
import 'config_provider.dart';

/// Le bandeau d'obsolescence, posé sous la barre de la coquille.
///
/// `ConfigDto.minSupportedAppVersion` est le plus ancien build que le serveur
/// sert encore. En deçà, prévenir est la seule chose utile : l'app continue de
/// fonctionner pour ce que le serveur accepte encore, et rien ne justifie de
/// la bloquer.
///
/// Le bandeau **ne se ferme pas** : la cause persiste jusqu'à la mise à jour,
/// et une croix laisserait croire l'inverse. Tant que la configuration ou la
/// version locale n'est pas connue, il ne rend rien — on ne prévient pas d'une
/// obsolescence qu'on n'a pas constatée.
class AppOutdatedBanner extends ConsumerWidget {
  const AppOutdatedBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool outdated = ref.watch(appOutdatedProvider).value ?? false;
    if (!outdated) return const SizedBox.shrink();
    return PdlBanner(
      tone: PdlBannerTone.warn,
      fullBleed: true,
      title: 'errors.outdated.title'.tr(),
      message: 'errors.outdated.message'.tr(),
    );
  }
}
