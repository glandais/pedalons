import 'package:dio/dio.dart' show DioException;
import 'package:flutter/foundation.dart';

import '../../../api/generated/export.dart';

/// Les enregistrements mensuels d'un tracé dessiné sont-ils tous utilisés
/// (docs/LEDGER_*.md BILL-10) ? La règle du site (`isPlannerQuotaSpent`) :
/// `limit` nul est une offre sans limite, un quota absent quelqu'un à qui le
/// serveur n'en a donné aucun, et l'admin de plateforme est exempté côté
/// serveur, dont les chiffres ne le savent pas.
///
/// Seul le cas évident est épargné : le serveur reste l'autorité et refuse
/// avec `PLANNER_QUOTA_REACHED` un enregistrement passé entre-temps.
bool isPlannerQuotaSpent(PlannerQuotaDto? quota, {bool platformAdmin = false}) {
  if (platformAdmin || quota == null) return false;
  final int? limit = quota.limit;
  return limit != null && quota.used >= limit;
}

/// Un refus `PLANNER_QUOTA_REACHED` : de quoi écrire son message.
@immutable
class PlannerQuotaRefusal {
  const PlannerQuotaRefusal({
    required this.team,
    required this.limit,
    required this.resetsOn,
    this.teamName,
  });

  /// Lit les détails d'un refus (`errorDetails` de l'API, ou le message
  /// `quotaRefused` de la page). `null` s'il manque de quoi l'écrire.
  static PlannerQuotaRefusal? fromJson(Object? details) {
    if (details is! Map) return null;
    final Object? scope = details['scope'];
    final Object? limit = details['limit'];
    final Object? resetsOn = details['resetsOn'];
    if (scope is! String || limit is! num || resetsOn is! String) return null;
    return PlannerQuotaRefusal(
      team: scope != PlannerQuotaScope.personal.json,
      limit: limit.toInt(),
      resetsOn: resetsOn,
      teamName: details['teamName'] as String?,
    );
  }

  /// Quota de l'équipe (`TEAM`), sinon quota personnel des outils GPX.
  final bool team;
  final int limit;

  /// Le premier jour du mois où le compteur repart (`AAAA-MM-JJ`).
  final String resetsOn;
  final String? teamName;
}

/// Le refus de quota que porte [error], ou `null` pour tout autre échec.
PlannerQuotaRefusal? plannerQuotaRefusalOf(Object error) {
  if (error is! DioException) return null;
  final Object? data = error.response?.data;
  if (data is! Map || data['code'] != 'PLANNER_QUOTA_REACHED') return null;
  return PlannerQuotaRefusal.fromJson(data['errorDetails']);
}

/// Le mois (1 à 12) d'une date `AAAA-MM-JJ`, ou `null`.
int? monthOfLocalDate(String date) {
  final List<String> parts = date.split('-');
  if (parts.length < 2) return null;
  final int? month = int.tryParse(parts[1]);
  return month != null && month >= 1 && month <= 12 ? month : null;
}
