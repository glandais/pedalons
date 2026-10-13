import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/pdl/pdl.dart';
import '../../../../keys.dart';
import '../../providers/ride_registration_controller.dart';

/// Le bandeau d'échec — **persistant**, nommant le groupe, et porteur de la
/// seule action qui résout le cas d'exclusivité.
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
  if (failure.canSwitch) {
    action = PdlButton(
      key: keys.ride.switchGroupButton,
      label: 'rides.failure.leaveAndJoin'.tr(
        namedArgs: <String, String>{'group': failure.blockingGroupName ?? ''},
      ),
      variant: PdlButtonVariant.outline,
      size: PdlButtonSize.sm,
      onPressed: () {
        controller.switchGroup(
          leaveGroupId: failure.blockingGroupId!,
          joinGroupId: failure.groupId,
        );
      },
    );
  } else if (failure.reason == RegistrationFailureReason.notMember &&
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
      onPressed: () => controller.join(failure.groupId),
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
