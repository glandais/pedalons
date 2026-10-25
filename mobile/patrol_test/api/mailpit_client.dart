import 'package:dio/dio.dart';

import '../config.dart';

/// Reads the mail the backend sent — on the e2e stack, mailpit is the only way out for mail.
///
/// Messages are told apart by id, not by date: snapshot the mailbox with [mailbox] before the
/// request that sends mail, then [waitForNewMail] returns the first id not seen before. No clock is
/// compared, so an older mail can never be picked up by mistake. Same approach as
/// `frontend/e2e/support/mailpit.ts`.
final class MailpitClient {
  final Dio _dio = Dio(BaseOptions(baseUrl: E2eConfig.mailpitUrl));

  Future<Set<String>> mailbox(String to) async =>
      (await _search(to)).map((m) => m['ID'] as String).toSet();

  /// The plain-text content of the first mail to [to] whose id is not in [seen].
  Future<String> waitForNewMail(
    String to,
    Set<String> seen, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      for (final message in await _search(to)) {
        if (!seen.contains(message['ID'])) {
          return _textOf(message['ID'] as String);
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw StateError('mailpit: no new mail for $to within $timeout');
  }

  /// Every mail to [to], newest first, whole: `From`, `ReplyTo`, `Subject`, `Text`, `HTML`… as
  /// mailpit's `/api/v1/message/{id}` serves them — for a test that checks the envelope, not only
  /// the body.
  Future<List<Map<String, dynamic>>> messagesTo(String to) async => [
    for (final message in await _search(to))
      (await _dio.get<Map<String, dynamic>>('/api/v1/message/${message['ID']}'))
          .data!,
  ];

  /// The 6-digit one-time code in [mail].
  String otpCodeIn(String mail) {
    final match = RegExp(r'\b(\d{6})\b').firstMatch(mail);
    if (match == null) throw StateError('no 6-digit code in mail:\n$mail');
    return match.group(1)!;
  }

  /// The `token` query parameter of the first link in [mail].
  String linkTokenIn(String mail) {
    final match = RegExp(r'[?&]token=([^\s&"<>]+)').firstMatch(mail);
    if (match == null) throw StateError('no ?token= link in mail:\n$mail');
    return match.group(1)!;
  }

  /// Newest first. `to:` matches substrings (a@x also finds ba@x): keep the exact recipient only.
  Future<List<Map<String, dynamic>>> _search(String to) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/search',
      queryParameters: {'query': 'to:"$to"', 'limit': 250},
    );
    final address = to.toLowerCase();
    bool isRecipient(Map<String, dynamic> m) => [
      for (final field in ['To', 'Cc', 'Bcc'])
        ...(m[field] as List?) ?? const [],
    ].any((a) => ((a as Map)['Address'] as String).toLowerCase() == address);
    return ((response.data?['messages'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .where(isRecipient)
        .toList();
  }

  /// Mailpit serves the bodies already MIME-decoded.
  Future<String> _textOf(String id) async {
    final message = (await _dio.get<Map<String, dynamic>>(
      '/api/v1/message/$id',
    )).data!;
    final text = message['Text'] as String? ?? '';
    return text.isNotEmpty ? text : message['HTML'] as String? ?? '';
  }
}
