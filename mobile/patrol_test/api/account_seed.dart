import 'package:dio/dio.dart';

import 'backend_client.dart';

/// Seeding and checks of the account group: signing in, sessions, participations.
extension AccountSeed on BackendClient {
  /// `POST /api/auth/login` with [email] and [password]: the HTTP status, whatever it is (200
  /// signed in; 400 `INVALID_CREDENTIALS` for a wrong password, an unknown or a deleted account).
  Future<int> loginStatus(String email, String password) async =>
      (await _login(email, password)).statusCode!;

  /// A fresh session of [email] through the password login: the auth response, with its
  /// `accessToken`, `refreshToken` and `user`.
  Future<Json> login(String email, String password) async {
    final response = await _login(email, password);
    if (response.statusCode != 200) {
      throw StateError('login of $email refused: ${response.statusCode}');
    }
    return response.data!;
  }

  /// `POST /api/auth/refresh` with [refreshToken]: 200 while the session lives.
  Future<int> refreshStatus(String refreshToken) async =>
      (await http.post<Json>(
        '/api/auth/refresh',
        options: Options(
          headers: {'X-Refresh-Token': refreshToken},
          validateStatus: (_) => true,
        ),
      )).statusCode!;

  /// `GET /api/teams/{slug}` without a session: 200 for a public team, 404 once it is gone.
  Future<int> anonymousTeamStatus(String teamSlug) async =>
      (await http.get<void>(
        '/api/teams/$teamSlug',
        options: Options(validateStatus: (_) => true),
      )).statusCode!;

  Future<Response<Json>> _login(String email, String password) =>
      http.post<Json>(
        '/api/auth/login',
        data: {'email': email, 'password': password},
        options: Options(validateStatus: (status) => status! < 500),
      );
}
