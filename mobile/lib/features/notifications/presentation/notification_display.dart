import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

import '../../../api/generated/export.dart';
import '../../../config/paths.dart';
import '../../../core/theme/pdl_icons.dart';
import '../../../core/utils/formatters.dart';

/// Ce qu'une notification dit, montre, et où elle mène.
///
/// L'API ne transporte **aucun texte rendu** (`docs/plans/archive/2026-09-18-notifications.md`
/// §3) : une notification est un type et des champs structurés, et c'est le
/// client qui la formule dans la langue du lecteur — même principe que les
/// `ErrorCode`. Le libellé, l'icône et la destination vivent donc ici, et pas
/// sur le serveur.
extension NotificationDisplay on NotificationDto {
  NotificationType get typeEnum => NotificationType.fromJson(type);

  NotificationSubjectType get subjectTypeEnum =>
      NotificationSubjectType.fromJson(subjectType);

  /// La phrase affichée en titre.
  ///
  /// `actorName` manque pour une publication programmée (aucun acteur humain) :
  /// l'équipe prend alors sa place, plutôt que de laisser un trou dans la
  /// phrase.
  ///
  /// Une modification de sortie dit **ce qui** a changé : « une sortie a été
  /// modifiée » obligerait à l'ouvrir pour savoir s'il faut se lever plus tôt
  /// ou aller ailleurs.
  String title() {
    final String key = typeEnum == NotificationType.rideUpdated
        ? 'notifications.rideUpdated.${_rideUpdatedVariant()}'
        : 'notifications.type.$type';
    return key.tr(
      namedArgs: <String, String>{
        'actor': actorName ?? teamName,
        'team': teamName,
      },
    );
  }

  /// La variante du titre d'une modification, selon `changes`. Une liste vide
  /// ou faite de changements qu'une version plus ancienne ne connaît pas
  /// retombe sur la phrase générique plutôt que de ne rien dire.
  String _rideUpdatedVariant() {
    final bool date = changes.contains(NotificationChange.dateTime);
    final bool place = changes.contains(NotificationChange.startPlace);
    if (date && place) return 'both';
    if (date) return 'dateTime';
    if (place) return 'startPlace';
    return 'other';
  }

  /// La date du sujet, quand elle dit quelque chose : « Départ : samedi 11
  /// octobre à 08:00 » pour un rappel, « Nouvelle date : … » pour une sortie
  /// qui en change ; `null` sinon.
  ///
  /// `subjectDateTime` est un **rendez-vous** figé à l'envoi : il se lit dans
  /// le fuseau du sujet (`subjectTimezone`), avec la mention « heure de Tokyo
  /// (ven. 01:00 chez vous) » quand son décalage diffère de celui du lecteur
  /// (docs/LEDGER_*.md API-60). Une notification envoyée avant que le serveur
  /// ne fige ce fuseau n'en porte pas : elle se lit alors chez le lecteur, sans
  /// mention. `createdAt`, lui, reste un horodatage.
  String? subjectDateLine() {
    final String? iso = subjectDateTime;
    if (iso == null) return null;
    final String key;
    if (typeEnum == NotificationType.rideReminder) {
      key = 'notifications.startsAt';
    } else if (typeEnum == NotificationType.rideUpdated &&
        changes.contains(NotificationChange.dateTime)) {
      key = 'notifications.newDate';
    } else {
      return null;
    }
    final DateTime? at = DateTime.tryParse(iso);
    if (at == null) return null;
    return key.tr(
      namedArgs: <String, String>{
        'date': AppFormatters.formatRendezvous(at, subjectTimezone),
      },
    );
  }

  /// La ligne sous le sujet, ou `null` s'il n'y a rien à ajouter.
  ///
  /// L'`excerpt` est une citation — le commentaire — sauf pour une
  /// inscription ou un groupe retiré, où il porte le nom du groupe : le citer
  /// en italique tel quel le ferait passer pour un message.
  String? detail() {
    final String? text = excerpt;
    if (text == null || text.isEmpty) return null;
    if (_namesAGroup) {
      return 'notifications.joinedGroup'.tr(
        namedArgs: <String, String>{'group': text},
      );
    }
    return text;
  }

  /// `true` quand [detail] est une citation, rendue en italique.
  bool get detailIsQuote => !_namesAGroup;

  bool get _namesAGroup =>
      typeEnum == NotificationType.rideJoined ||
      typeEnum == NotificationType.rideGroupRemoved;

  /// L'icône du type. Une annulation se lit comme une annulation d'un coup
  /// d'œil, quel que soit le sujet.
  IconData icon() => switch (typeEnum) {
    NotificationType.ridePublished => PdlIcons.ride,
    NotificationType.rideCancelled => PdlIcons.cancelled,
    NotificationType.tripPublished => PdlIcons.trip,
    NotificationType.tripCancelled => PdlIcons.cancelled,
    NotificationType.postPublished => PdlIcons.post,
    NotificationType.commentReply => PdlIcons.comment,
    NotificationType.rideReminder => PdlIcons.reminder,
    NotificationType.rideUpdated => PdlIcons.edit,
    NotificationType.rideGroupRemoved => PdlIcons.personRemove,
    NotificationType.rideJoined => PdlIcons.personAdd,
    NotificationType.commentOnMyPublication => PdlIcons.comment,
    NotificationType.teamInvitation => PdlIcons.invitation,
    NotificationType.contentReported => PdlIcons.report,
    NotificationType.$unknown => PdlIcons.notifications,
  };

  /// L'écran que la notification ouvre, déduit du **sujet** et jamais du type :
  /// un type de plus sur un sujet existant n'a donc rien à ajouter ici.
  ///
  /// `null` pour un sujet qu'une version plus ancienne de l'app ne connaît pas
  /// — la ligne reste lisible, elle n'est simplement pas cliquable, ce qui vaut
  /// mieux qu'un `go` vers une route inexistante.
  String? path() => switch (subjectTypeEnum) {
    NotificationSubjectType.ride => Paths.ride(teamSlug, subjectSlug),
    NotificationSubjectType.trip => Paths.trip(teamSlug, subjectSlug),
    NotificationSubjectType.post => Paths.post(teamSlug, subjectSlug),
    NotificationSubjectType.route => Paths.route(teamSlug, subjectSlug),
    // Une invitation mène à la liste des équipes : c'est là que les
    // invitations en attente s'acceptent, et la page de l'équipe elle-même
    // peut être fermée à qui n'en est pas encore membre.
    NotificationSubjectType.team => Paths.teams(),
    // Un signalement se décide dans la file de l'équipe, un écran de l'app
    // depuis `MOB-168` : c'est aussi le lien que le serveur met dans le push.
    NotificationSubjectType.report => Paths.teamAdminReports(teamSlug),
    NotificationSubjectType.$unknown => null,
  };
}
