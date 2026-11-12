import 'package:flutter/widgets.dart';

class _ParticipantsSheetKey extends ValueKey<String> {
  const _ParticipantsSheetKey(String value) : super('participantsSheet_$value');
}

class ParticipantsSheetKeys {
  /// La pastille du total, dans l'en-tête de la feuille.
  final count = const _ParticipantsSheetKey('count');

  /// Le bouton qui charge la page suivante.
  final loadMore = const _ParticipantsSheetKey('loadMore');

  /// « N participants sur M », au-dessus du bouton.
  final progress = const _ParticipantsSheetKey('progress');

  /// Le pied « N participants sur M ».
  final footer = const _ParticipantsSheetKey('footer');

  /// La ligne d'un participant, par son identifiant.
  ValueKey<String> person(String userId) =>
      _ParticipantsSheetKey('person_$userId');

  /// Le `⋯` en bout de ligne d'un participant : Signaler, Bloquer (règle
  /// R13).
  ValueKey<String> personMore(String userId) =>
      _ParticipantsSheetKey('personMore_$userId');
}
