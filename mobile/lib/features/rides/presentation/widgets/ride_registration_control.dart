import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../keys.dart';
import '../../../teams/domain/publication_timing.dart';
import '../../../teams/providers/team_providers.dart';
import '../../domain/ride_group_action.dart';
import '../../providers/ride_detail_provider.dart';
import '../../providers/ride_registration_controller.dart';

/// Ce que le contrôle d'inscription montre pour [group] (ledger `MOB-134`,
/// KIT §8, maquettes `groupe-mobile-cible`, `groupe-inscrit-mobile-cible`).
///
/// Sur [rideGroupAction], avec trois écarts que la page d'un groupe demande :
///
/// * le groupe se juge sur **son** départ ([rideGroupPhase], ledger
///   `API-170`), pas sur celui de la sortie (`RideDto.finished`) : un groupe
///   parti — en cours ou terminé — n'offre plus ni « Rejoindre » ni
///   « Changer pour » ; un groupe plus tardif reste ouvert quand le premier
///   est parti. **La personne inscrite garde « J'y vais »**, et donc
///   « Quitter le groupe » ([rideGroupCanLeave]) : le serveur l'autorise
///   après le départ, pour corriger qui est vraiment venu (décision du
///   2026-11-10, docs/LEDGER_*.md MOB-134). Une sortie annulée n'offre rien,
///   pas même cela ;
/// * l'appartenance **inconnue** ([isMember] `null`, « Mes équipes » pas encore
///   là ou en échec) ne propose rien, pas même « Rejoindre » : rien tant
///   qu'on ne sait pas. Une inscription dans ce groupe, elle, se sait sans
///   l'appartenance (`registered` vient du serveur) ;
/// * [RideGroupAction.leave] se rend en badge « J'y vais » : se désinscrire
///   est le lien « Quitter le groupe », en bas de « Personnes inscrites ».
///
/// [now] ne sert qu'aux tests.
RideGroupAction rideRegistrationControlAction({
  required RideDto ride,
  required RideGroupDto group,
  required bool? isMember,
  DateTime? now,
}) {
  if (ride.isCancelled) return RideGroupAction.none;
  // Inscrit ici : « J'y vais », parti ou non.
  if (group.registered) return RideGroupAction.leave;
  if (rideGroupPhase(ride, group, now: now).hasStarted) {
    return RideGroupAction.none;
  }
  if (isMember != true) return RideGroupAction.none;
  // Le départ de la sortie ne compte plus : celui du groupe vient d'être lu.
  return rideGroupAction(
    ride: ride.copyWith(finished: false),
    group: group,
    isMember: true,
    now: now,
  );
}

/// Peut-on quitter [group] ? Inscrit et sortie maintenue, que le groupe soit
/// parti ou non — le lien « Quitter le groupe » de « Personnes inscrites ».
bool rideGroupCanLeave(RideDto ride, RideGroupDto group, {DateTime? now}) =>
    rideRegistrationControlAction(
      ride: ride,
      group: group,
      isMember: null,
      now: now,
    ) ==
    RideGroupAction.leave;

/// Le contrôle d'inscription à droite de l'heure de départ (ledger
/// `MOB-134`) — la page d'un groupe et le détail d'une sortie solo (lot 7),
/// les cartes de groupe ensuite (lot 8) :
///
/// * « Rejoindre » — bouton plein ;
/// * inscrit ici — badge « J'y vais » ;
/// * complet — « Complet » désactivé ;
/// * inscrit dans un autre groupe, celui-ci ouvert — « Changer pour A », un
///   seul appel (`RideRegistrationController.switchGroup`, ledger `API-171`) ;
/// * parti (sans y être inscrit), annulé, non-membre, appartenance inconnue —
///   rien.
///
/// **Aucune confirmation**, ni pour rejoindre ni pour changer (plan
/// `MOB-134`). Un échec garde le bandeau de l'écran
/// (`registrationFailureBanner`), que ce contrôle ne pose pas.
///
/// [shows] dit à l'appelant s'il y a quelque chose à rendre, pour ne pas
/// réserver de place à droite de l'heure.
class RideRegistrationControl extends ConsumerWidget {
  const RideRegistrationControl({
    super.key,
    required this.rideKey,
    required this.ride,
    required this.group,
    this.now,
  });

  final RideKey rideKey;
  final RideDto ride;
  final RideGroupDto group;

  /// Un instant, pour les tests ; maintenant sinon.
  final DateTime? now;

  /// L'action du contrôle, l'appartenance lue au même provider que lui.
  static RideGroupAction actionOf(
    WidgetRef ref,
    RideDto ride,
    RideGroupDto group, {
    DateTime? now,
  }) => rideRegistrationControlAction(
    ride: ride,
    group: group,
    isMember: ref.watch(teamMembershipProvider(ride.team.slug)),
    now: now,
  );

  /// Le contrôle rend-il quelque chose ?
  static bool shows(
    WidgetRef ref,
    RideDto ride,
    RideGroupDto group, {
    DateTime? now,
  }) => actionOf(ref, ride, group, now: now) != RideGroupAction.none;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RideGroupAction action = actionOf(ref, ride, group, now: now);
    final bool pending =
        ref.watch(rideRegistrationProvider(rideKey)).pendingGroupId == group.id;
    RideRegistrationController controller() =>
        ref.read(rideRegistrationProvider(rideKey).notifier);

    return switch (action) {
      RideGroupAction.none => const SizedBox.shrink(),
      RideGroupAction.join => PdlButton(
        key: keys.rideGroup.joinButton,
        label: 'rides.groupJoin'.tr(),
        loadingLabel: 'rides.joining'.tr(),
        loading: pending,
        onPressed: () => controller().join(group.id),
      ),
      RideGroupAction.switchTo => PdlButton(
        key: keys.rideGroup.switchButton,
        label: 'rides.groupSwitchTo'.tr(
          namedArgs: <String, String>{'group': group.name},
        ),
        loadingLabel: 'rides.joining'.tr(),
        variant: PdlButtonVariant.outline,
        loading: pending,
        onPressed: () => controller().switchGroup(group.id),
      ),
      RideGroupAction.full => PdlButton(
        key: keys.rideGroup.fullBadge,
        label: 'rides.groupFull'.tr(),
        variant: PdlButtonVariant.outline,
        enabled: false,
      ),
      RideGroupAction.leave => PdlBadge(
        key: keys.rideGroup.goingBadge,
        label: 'rides.registered'.tr(),
        tone: PdlDerivedTones.registered(context.pdl),
        size: PdlBadgeSize.lg,
      ),
    };
  }
}
