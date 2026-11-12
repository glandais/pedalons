import 'package:easy_localization/easy_localization.dart';

import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../keys.dart';
import '../../domain/group_title.dart';
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
      namedArgs: <String, String>{'group': groupLabel(failure.groupName)},
    ),
    RegistrationFailureReason.groupFull => 'rides.failure.full'.tr(
      namedArgs: <String, String>{'group': groupLabel(failure.groupName)},
    ),
    RegistrationFailureReason.notMember => 'rides.failure.notMember'.tr(),
    RegistrationFailureReason.generic => 'rides.failure.generic'.tr(
      namedArgs: <String, String>{'group': groupLabel(failure.groupName)},
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

/// L'échec d'inscription **dans la carte du groupe concerné** (règle R6 des
/// cartes, KIT §9, docs/LEDGER_*.md MOB-139) : sous ses chiffres et ses
/// places, plus en tête de la section « Groupes », où il ne disait pas de quel
/// groupe il parlait sans le nommer.
///
/// Une phrase qui dit le constat puis l'action possible (BRANDING §8.3) :
/// « Ce groupe est complet. Choisissez un autre groupe. » Sans croix : le
/// constat reste vrai tant que rien ne change, et un nouvel appui sur un
/// contrôle d'inscription l'efface (`clearFailure`). « Voir l'équipe » et
/// « Réessayer » restent, là où le bandeau les offrait.
Widget registrationFailureNotice(
  RegistrationFailure failure,
  RideRegistrationController controller, {
  VoidCallback? onViewTeam,
}) {
  final String text = switch (failure.reason) {
    RegistrationFailureReason.groupFull => 'rides.failure.inCard.full'.tr(),
    RegistrationFailureReason.alreadyRegistered =>
      'rides.failure.inCard.exclusive'.tr(
        namedArgs: <String, String>{'group': groupLabel(failure.groupName)},
      ),
    RegistrationFailureReason.notMember =>
      'rides.failure.inCard.notMember'.tr(),
    RegistrationFailureReason.generic => 'rides.failure.inCard.generic'.tr(
      namedArgs: <String, String>{
        // Le message résolu finit parfois par un point : un seul.
        'message': failure.message.trim().replaceFirst(RegExp(r'[.!]+$'), ''),
      },
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
      onPressed: () => failure.leaving
          ? controller.leave(failure.groupId)
          : controller.switchGroup(failure.groupId),
    );
  }

  return PdlBanner(
    key: keys.ride.groupRegistrationFailure(failure.groupId),
    tone: PdlBannerTone.danger,
    icon: PdlIcons.warning,
    message: text,
    action: action,
  );
}
