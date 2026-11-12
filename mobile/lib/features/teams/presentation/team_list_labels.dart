import 'package:easy_localization/easy_localization.dart';

import '../../../api/generated/export.dart';
import '../../../core/lists/list_states.dart';

/// Le compteur d'une liste d'équipes, **suivi de son ordre** (règles RL5 et
/// RL8 des listes, KIT §10) : « 5 équipes · triées par nom » sous la portée
/// « Membre », « 47 équipes · triées par nombre de membres » sur toutes les
/// équipes. Le nombre est formaté.
String teamListCountLabel(int total, TeamSortBy sort) =>
    switch (sort) {
      TeamSortBy.memberCount => 'teams.discovery.countSortedByMembers',
      _ => 'teams.discovery.countSortedByName',
    }.tr(
      namedArgs: <String, String>{
        'count': listCountLabel('teams.discovery.count', total),
      },
    );
