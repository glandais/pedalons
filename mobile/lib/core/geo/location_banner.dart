import 'package:easy_localization/easy_localization.dart';

import '../material.dart';

import '../pdl/pdl_banner.dart';
import '../pdl/pdl_button.dart';
import 'location_service.dart';

/// Ce que l'écran affiche quand la position n'a pas pu être obtenue.
///
/// Un `PdlBanner` **persistant**, jamais un dialogue système redemandé en
/// boucle : sur iOS, un refus définitif ne rouvre plus aucun dialogue, et
/// insister ne produit qu'un échec silencieux. L'issue est nommée
/// explicitement — « Ouvrir les réglages » quand seuls les réglages peuvent
/// lever le blocage, « Réessayer » quand la demande a encore un sens.
///
/// L'écran reste utilisable : un filtre de proximité est un confort, pas une
/// condition d'accès au contenu.
class LocationFailureBanner extends StatelessWidget {
  const LocationFailureBanner({
    super.key,
    required this.failure,
    required this.service,
    this.onRetry,
    this.onDismiss,
  });

  final LocationFailure failure;
  final LocationService service;

  /// Proposé quand redemander a un sens — c'est-à-dire quand ce n'est pas un
  /// refus définitif ni un service coupé.
  final VoidCallback? onRetry;

  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final bool settings = LocationService.needsSettings(failure);
    return PdlBanner(
      tone: PdlBannerTone.warn,
      title: 'location.title'.tr(),
      message: LocationService.messageKey(failure).tr(),
      onDismiss: onDismiss,
      dismissSemanticLabel: 'common.close'.tr(),
      action: settings
          ? PdlButton(
              variant: PdlButtonVariant.text,
              label: 'location.openSettings'.tr(),
              onPressed: () => failure == LocationFailure.serviceDisabled
                  ? service.openLocationSettings()
                  : service.openAppSettings(),
            )
          : (onRetry == null
                ? null
                : PdlButton(
                    variant: PdlButtonVariant.text,
                    label: 'location.retry'.tr(),
                    onPressed: onRetry,
                  )),
    );
  }
}
