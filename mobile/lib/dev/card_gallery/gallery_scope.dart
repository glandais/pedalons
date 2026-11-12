// Le conteneur Riverpod de la galerie de cartes — page de DEBUG.
//
// Chaque cas est monté dans un `ProviderContainer` **à lui**, sans parent :
// une `ProviderScope` imbriquée sous celle de l'app ne remplacerait que les
// fournisseurs nommés, et un fournisseur dérivé non remplacé (une liste
// paginée qui lit un dépôt) se résoudrait dans le conteneur de l'app, avec sa
// session et son réseau. Ici rien ne remonte : le Dio est coupé, la session est
// celle de Camille Durand, et chaque cas pose ses données.

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/generated/export.dart';
import '../../api/pedalons_api_client.dart';
import '../../core/config/config_provider.dart';
import '../../core/pagination/pagination.dart';
import '../../core/preferences/user_preferences_provider.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/secure_storage.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/comments/data/comment_repository.dart';
import '../../features/participants/data/participant_repository.dart';
import '../../features/participants/domain/participant_query.dart';
import '../../features/rides/providers/participation_changes.dart';
import '../../features/teams/data/team_repository.dart';
import '../../features/teams/domain/member_filters.dart';
import '../../features/teams/providers/my_teams_list_provider.dart';
import 'gallery_data.dart';

/// Un cas de galerie dans son conteneur isolé, avec les [overrides] du cas
/// par-dessus ceux de toute la galerie ([_baseOverrides]).
///
/// Un cas ne remplace jamais un fournisseur déjà remplacé par la base : la
/// base ne contient que ce qu'aucun cas ne fait varier.
class GalleryScope extends StatefulWidget {
  const GalleryScope({
    super.key,
    required this.data,
    this.overrides = const <Override>[],
    required this.child,
  });

  final GalleryData data;
  final List<Override> overrides;
  final Widget child;

  @override
  State<GalleryScope> createState() => _GalleryScopeState();
}

class _GalleryScopeState extends State<GalleryScope> {
  ProviderContainer? _container;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container ??= ProviderContainer(
      // Un appel coupé ne se rejoue pas : il échouerait de nouveau, et chaque
      // essai laisserait un minuteur en vol.
      retry: (int _, Object _) => null,
      overrides: <Override>[
        ..._baseOverrides(
          widget.data,
          ProviderScope.containerOf(
            context,
            listen: false,
          ).read(sharedPreferencesProvider),
        ),
        ...widget.overrides,
      ],
    );
  }

  @override
  void dispose() {
    _container?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      UncontrolledProviderScope(container: _container!, child: widget.child);
}

List<Override> _baseOverrides(
  GalleryData data,
  SharedPreferences preferences,
) => <Override>[
  // Aucun appel ne sort de la galerie : un appui sur « Rejoindre » ou
  // « Accepter » échoue sur place au lieu de partir vers l'API.
  dioProvider.overrideWithValue(_offlineDio()),
  baseDioProvider.overrideWithValue(_offlineDio()),
  sharedPreferencesProvider.overrideWithValue(preferences),
  unitSystemProvider.overrideWithValue(UnitSystem.metric),
  authProvider.overrideWith(
    (Ref ref) => _GalleryAuthNotifier(ref, data.reader),
  ),
  registrationOverridesProvider.overrideWith(
    (Ref ref) => const <String, bool>{},
  ),
  // Un site multi-équipes : « Trouver une équipe » s'affiche.
  appConfigProvider.overrideWith((Ref ref) async => data.config),
];

/// Un Dio qui refuse toute requête.
Dio _offlineDio() => Dio()
  ..interceptors.add(
    InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) =>
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.cancel,
              error: 'Galerie de cartes : aucun appel réseau',
            ),
          ),
    ),
  );

/// La session de la lectrice : Camille Durand, membre, en métrique.
class _GalleryAuthNotifier extends AuthNotifier {
  _GalleryAuthNotifier(Ref ref, UserDto reader)
    : super(_NoAuthRepository(), _NoTokenStorage(), ref) {
    state = AuthState(
      user: reader,
      accessToken: 'galerie',
      isInitialized: true,
    );
  }
}

class _NoAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Galerie de cartes : pas d’authentification');
}

class _NoTokenStorage implements SecureTokenStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Galerie de cartes : pas de stockage');
}

/// Le trombinoscope d'une équipe : une seule page, les [members] donnés.
class GalleryTeamRepository implements TeamRepository {
  const GalleryTeamRepository(this.members);

  final List<MemberDto> members;

  @override
  Future<PageResult<MemberDto>> fetchMembers({
    required MemberFilters filters,
    int page = 0,
    int size = kDefaultPageSize,
  }) async => PageResult<MemberDto>(
    items: page == 0 ? members : const <MemberDto>[],
    total: members.length,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Galerie de cartes : ${invocation.memberName}');
}

/// « Mes équipes » déjà chargée : les [teams] donnés, sans passer par le
/// squelette de chargement (trois cartes qui déborderaient du cadre).
class GalleryMyTeamsNotifier extends MyTeamsListNotifier {
  GalleryMyTeamsNotifier(this.teams)
    : super(const GalleryTeamRepository(<MemberDto>[]), null) {
    state = PagedListState<TeamDetailDto>(
      items: teams,
      total: teams.length,
      loadedPages: 1,
      hasMore: false,
      isLoadingInitial: false,
    );
  }

  final List<TeamDetailDto> teams;

  @override
  Future<PageResult<TeamDetailDto>> fetchPage(int page) async =>
      PageResult<TeamDetailDto>(
        items: page == 0 ? teams : const <TeamDetailDto>[],
        total: teams.length,
      );
}

/// Les personnes inscrites : une seule page, les [people] donnés.
class GalleryParticipantRepository implements ParticipantRepository {
  const GalleryParticipantRepository(this.people);

  final List<PublicUserDto> people;

  @override
  Future<PageResult<PublicUserDto>> fetchPage(
    ParticipantQuery query, {
    required int page,
    required int size,
  }) async => PageResult<PublicUserDto>(
    items: page == 0 ? people : const <PublicUserDto>[],
    total: people.length,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Galerie de cartes : ${invocation.memberName}');
}

/// Un fil de commentaires : une seule page, les [comments] donnés.
class GalleryCommentRepository implements CommentRepository {
  const GalleryCommentRepository(this.comments);

  final List<CommentDto> comments;

  @override
  Future<CommentListResponse> list(
    CommentTarget target, {
    int page = 0,
    int size = 20,
    String? parentId,
    SortDirection? sort,
  }) async {
    final List<CommentDto> items = parentId != null || page > 0
        ? const <CommentDto>[]
        : comments;
    return CommentListResponse(
      items: items,
      total: comments.length,
      itemTotal: comments.length,
      page: page,
      size: size,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Galerie de cartes : ${invocation.memberName}');
}
