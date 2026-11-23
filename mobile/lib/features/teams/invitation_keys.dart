import 'package:flutter/widgets.dart';

class _InvitationPageKey extends ValueKey<String> {
  const _InvitationPageKey(String value) : super('invitationPage_$value');
}

/// La page du lien d'un e-mail d'invitation (docs/LEDGER_*.md MOB-179).
class InvitationPageKeys {
  /// « {inviter} vous invite à rejoindre {team} ».
  final title = const _InvitationPageKey('title');

  /// « Se connecter ou créer un compte », hors session.
  final signInButton = const _InvitationPageKey('signIn');

  /// « Rejoindre l'équipe », connecté.
  final joinButton = const _InvitationPageKey('join');

  /// « Utiliser un autre compte », connecté.
  final switchAccountButton = const _InvitationPageKey('switchAccount');

  /// L'échec de l'acceptation (adresse d'un autre compte, invitation expirée…).
  final acceptError = const _InvitationPageKey('acceptError');

  /// L'invitation n'est plus en attente, et la personne n'est pas membre.
  final notRedeemable = const _InvitationPageKey('notRedeemable');

  /// L'invitation est déjà acceptée par ce membre.
  final alreadyMember = const _InvitationPageKey('alreadyMember');

  /// Lien sans jeton, ou jeton inconnu.
  final unavailable = const _InvitationPageKey('unavailable');
}
