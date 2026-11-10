import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/pdl/pdl.dart';
import '../../../../keys.dart';
import '../../providers/ride_registration_controller.dart';

/// Le bandeau d'échec — **persistant** et nommant le groupe.
///
/// Plus d'action « Quitter {groupe} » d'exclusivité : inscrit ailleurs,
/// rejoindre est un changement de groupe direct (« Changer pour A »,
/// docs/LEDGER_*.md MOB-134, lot 8). Le motif « déjà inscrit » reste, filet
/// d'une inscription faite sur un autre appareil : le détail est redemandé, et
/// les cartes offrent alors « Changer pour ».
Widget registrationFailureBanner(
  RegistrationFailure failure,
  RideRegistrationController controller, {
  VoidCallback? onViewTeam,
}) {
  final String title = switch (failure.reason) {
    RegistrationFailureReason.alreadyRegistered => 'rides.failure.exclusive'.tr(
      namedArgs: <String, String>{'group': failure.groupName},
    ),
    RegistrationFailureReason.groupFull => 'rides.failure.full'.tr(
      namedArgs: <String, String>{'group': failure.groupName},
    ),
    RegistrationFailureReason.notMember => 'rides.failure.notMember'.tr(),
    RegistrationFailureReason.generic => 'rides.failure.generic'.tr(
      namedArgs: <String, String>{'group': failure.groupName},
    ),
  };

  Widget? action;
  if (failure.reason == RegistrationFailureReason.notMember &&
      onViewTeam != null) {
    action = PdlButton(
      label: 'teams.viewTeam'.tr(),
      variant: PdlButtonVariant.outline,
      size: PdlButtonSize.sm,
      onPressed: onViewTeam,
    );
  } else if (failure.reason == RegistrationFailureReason.generic) {
    action = PdlButton(
      label: 'common.retry'.tr(),
      variant: PdlButtonVariant.outline,
      size: PdlButtonSize.sm,
      // Le même geste : quitter à nouveau, ou rejoindre — un changement de
      // groupe si l'on est inscrit ailleurs (`switchGroup` rejoint sinon).
      onPressed: () => failure.leaving
          ? controller.leave(failure.groupId)
          : controller.switchGroup(failure.groupId),
    );
  }

  return PdlBanner(
    key: keys.ride.registrationFailure,
    tone: PdlBannerTone.danger,
    title: title,
    message: failure.message,
    action: action,
    onDismiss: controller.dismissFailure,
    dismissSemanticLabel: 'common.close'.tr(),
  );
}
