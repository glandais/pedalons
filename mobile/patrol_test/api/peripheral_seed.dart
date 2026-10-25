import 'backend_client.dart';

/// Reads for the peripheral screens: the notification channels.
extension PeripheralSeed on BackendClient {
  /// The channels the server can deliver to [who] on — `PUSH` only once FCM is configured.
  Future<List<String>> notificationChannels(TestUser who) async {
    final preferences = await get(who, '/api/notifications/preferences');
    return (preferences['channels'] as List).cast<String>();
  }
}
