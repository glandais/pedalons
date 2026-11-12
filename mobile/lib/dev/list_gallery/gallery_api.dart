// Le serveur factice de la galerie des listes — page de DEBUG.
//
// La galerie des listes monte les **vraies pages** : leurs fournisseurs, leurs
// dépôts, leurs clients Retrofit et leur pagination tournent tels quels. Seul
// le Dio est remplacé, par celui-ci, dont l'intercepteur répond à chaque
// requête depuis une table de réponses fixes au lieu de partir sur le réseau.
// C'est le point de remplacement le plus bas : les filtres, les compteurs et
// la pagination de la page sont ceux de production.
//
// Une réponse est une page de résultats, une erreur serveur, ou une attente
// sans fin (la requête ne reçoit jamais de réponse).

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Ce que le serveur factice répond à une requête.
sealed class GalleryReply {
  const GalleryReply();
}

/// Un corps JSON, avec le statut 200 — un DTO généré (`toJson`), une liste ou
/// une table.
final class GalleryJson extends GalleryReply {
  const GalleryJson(this.body);
  final Object? body;
}

/// Une erreur HTTP, 500 par défaut.
final class GalleryError extends GalleryReply {
  const GalleryError([this.status = 500]);
  final int status;
}

/// Aucune réponse, jamais : la page reste en chargement.
final class GalleryPending extends GalleryReply {
  const GalleryPending();
}

/// Une requête, lue par une [GalleryRoute].
@immutable
class GalleryRequest {
  const GalleryRequest(this.method, this.path, this.query, this.params);

  final String method;
  final String path;

  /// Les paramètres de requête, tels que Dio les a reçus (une liste reste une
  /// liste).
  final Map<String, dynamic> query;

  /// Les segments nommés du gabarit (`{teamSlug}`).
  final Map<String, String> params;

  /// Le numéro de page demandé, 0 par défaut.
  int get page => int.tryParse('${query['page'] ?? 0}') ?? 0;

  /// La taille de page demandée, 20 par défaut.
  int get size => int.tryParse('${query['size'] ?? 20}') ?? 20;

  /// Un paramètre de requête en texte, `null` s'il est absent ou vide.
  String? text(String name) {
    final Object? value = query[name];
    if (value == null) return null;
    final String s = value is List ? value.join(',') : '$value';
    return s.trim().isEmpty ? null : s;
  }

  /// Vrai quand l'un des [names] est posé : la requête est filtrée.
  bool any(Iterable<String> names) => names.any((String n) => text(n) != null);

  /// La même requête à la page [page] — ce que lit un compteur.
  GalleryRequest withPage(int page) => GalleryRequest(
    method,
    path,
    <String, dynamic>{...query, 'page': page},
    params,
  );
}

typedef GalleryHandler = GalleryReply Function(GalleryRequest request);

/// Une adresse de l'API et sa réponse. Le gabarit suit le contrat
/// (`/api/teams/{teamSlug}/routes`).
class GalleryRoute {
  GalleryRoute(this.method, this.template, this.handler, {this.when})
    : _pattern = RegExp(
        '^${template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (Match m) => '(?<${m[1]}>[^/]+)')}\$',
      );

  GalleryRoute.get(
    String template,
    GalleryHandler handler, {
    bool Function(GalleryRequest request)? when,
  }) : this('GET', template, handler, when: when);

  final String method;
  final String template;
  final GalleryHandler handler;

  /// Départage deux usages d'une même adresse (`/api/teams` : mes équipes,
  /// ou l'annuaire).
  final bool Function(GalleryRequest request)? when;
  final RegExp _pattern;

  Map<String, String>? match(String method, String path) {
    if (method != this.method) return null;
    final RegExpMatch? m = _pattern.firstMatch(path);
    if (m == null) return null;
    return <String, String>{
      for (final String name in m.groupNames) name: m.namedGroup(name)!,
    };
  }
}

/// La table des réponses d'un cas. La première adresse qui correspond gagne :
/// un cas pose les siennes **devant** celles de sa section.
class GalleryApi {
  GalleryApi(this.routes);

  final List<GalleryRoute> routes;

  /// Les requêtes reçues, dans l'ordre — ce que les tests relisent.
  final List<GalleryRequest> log = <GalleryRequest>[];

  /// Les requêtes sans réponse prévue : elles reçoivent un 404, et le test de
  /// galerie échoue s'il en reste.
  final List<String> unknown = <String>[];

  GalleryReply answer(String method, String path, Map<String, dynamic> query) {
    for (final GalleryRoute route in routes) {
      final Map<String, String>? params = route.match(method, path);
      if (params == null) continue;
      final GalleryRequest request = GalleryRequest(
        method,
        path,
        query,
        params,
      );
      if (route.when != null && !route.when!(request)) continue;
      log.add(request);
      return route.handler(request);
    }
    unknown.add('$method $path ${query.isEmpty ? '' : query}');
    debugPrint('Galerie des listes : pas de réponse pour $method $path $query');
    return const GalleryError(404);
  }

  /// Le Dio de la galerie : rien ne sort, tout est répondu ici.
  Dio dio() => Dio(BaseOptions(baseUrl: 'https://galerie.invalid'))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          final GalleryReply reply = answer(
            options.method.toUpperCase(),
            options.uri.path,
            options.queryParameters,
          );
          switch (reply) {
            case GalleryJson(:final Object? body):
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  // Un aller-retour par le texte : les DTO deviennent
                  // les tables et listes qu'un vrai corps donnerait.
                  data: body == null ? null : jsonDecode(jsonEncode(body)),
                ),
              );
            case GalleryError(:final int status):
              handler.reject(
                DioException.badResponse(
                  statusCode: status,
                  requestOptions: options,
                  response: Response<dynamic>(
                    requestOptions: options,
                    statusCode: status,
                    data: <String, Object>{
                      'status': status,
                      'message': 'Galerie des listes : erreur $status',
                    },
                  ),
                ),
              );
            case GalleryPending():
              // Ni `resolve` ni `reject` : la requête attend toujours.
              break;
          }
        },
      ),
    );
}

/// Une page de [items] : les éléments de la page demandée, le reste vide.
///
/// La page 0 rend tout [items] ; les suivantes, rien — avec le même [total],
/// pour que la page annonce « 3 sur 47 » comme si le reste existait.
List<T> pageOf<T>(GalleryRequest request, List<T> items) =>
    request.page == 0 ? items : <T>[];

/// L'état d'une liste dans un cas du cahier.
enum ListMode {
  /// Une page de résultats, et un total plus grand que la page.
  full,

  /// Aucun élément, filtre ou pas.
  empty,

  /// Des éléments sans filtre, aucun avec : le vide **filtré**.
  emptyFiltered,

  /// Une erreur serveur (500).
  error,

  /// Une attente sans fin.
  loading,
}

/// Les éléments d'une liste et la façon dont le serveur factice les filtre.
///
/// Sans filtre, la page 0 rend [items] et annonce [total]. Avec un filtre
/// ([isFiltered]), elle rend ceux que [matches] retient, et leur nombre pour
/// total : le compteur filtré de la page est alors exact.
class ListFixture<T> {
  const ListFixture({
    required this.items,
    required this.total,
    required this.isFiltered,
    this.matches,
  });

  final List<T> items;
  final int total;
  final bool Function(GalleryRequest request) isFiltered;
  final bool Function(GalleryRequest request, T item)? matches;

  /// Les éléments de la page demandée et le total, selon [mode] ; `null`
  /// quand la réponse n'est pas une page (erreur, attente).
  (List<T>, int)? answer(GalleryRequest request, ListMode mode) {
    final bool filtered = isFiltered(request);
    switch (mode) {
      case ListMode.error:
      case ListMode.loading:
        return null;
      case ListMode.empty:
        return (<T>[], 0);
      case ListMode.emptyFiltered when filtered:
        return (<T>[], 0);
      case ListMode.full:
      case ListMode.emptyFiltered:
        if (!filtered) return (pageOf(request, items), total);
        final List<T> kept = <T>[
          for (final T item in items)
            if (matches?.call(request, item) ?? true) item,
        ];
        return (pageOf(request, kept), kept.length);
    }
  }

  /// La réponse d'une liste : [body] met la page en forme.
  GalleryReply list(
    GalleryRequest request,
    ListMode mode,
    Object Function(List<T> page, int total) body,
  ) => _reply(mode, answer(request, mode), (p) => body(p.$1, p.$2));

  /// La réponse d'un compteur (`…/count`) : `{total}`.
  GalleryReply count(GalleryRequest request, ListMode mode) => _reply(
    mode,
    answer(request.withPage(0), mode),
    (p) => <String, int>{'total': p.$2},
  );

  GalleryReply _reply(
    ListMode mode,
    (List<T>, int)? page,
    Object Function((List<T>, int) page) body,
  ) => switch (mode) {
    ListMode.error => const GalleryError(),
    ListMode.loading => const GalleryPending(),
    _ => GalleryJson(body(page!)),
  };
}

/// Le texte sans casse ni accents, pour une recherche : « Monts » trouve
/// « monts », « Léa » trouve « lea ».
String foldText(String value) {
  const String from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ’';
  const String to = 'aaaaaaceeeeiiiinooooouuuuyyoa\'';
  final StringBuffer out = StringBuffer();
  for (final int rune in value.toLowerCase().runes) {
    final String ch = String.fromCharCode(rune);
    final int i = from.indexOf(ch);
    out.write(i < 0 ? ch : to[i]);
  }
  return out.toString();
}

/// Vrai quand [haystack] contient la recherche [needle] (sans casse ni accents).
bool textMatches(String? needle, Iterable<String?> haystack) {
  if (needle == null || needle.trim().isEmpty) return true;
  final String n = foldText(needle.trim());
  return haystack.any((String? h) => h != null && foldText(h).contains(n));
}
