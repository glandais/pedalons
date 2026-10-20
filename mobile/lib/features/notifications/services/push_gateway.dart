import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/push_message.dart';

/// Tout ce que l'app demande à la plateforme pour recevoir un push.
///
/// L'interface existe pour que rien au-dessus (le contrôleur, l'écran, leurs
/// tests) ne touche Firebase : un test de widget qui instancierait
/// `FirebaseMessaging` échouerait sur les canaux de plateforme, et le push
/// n'existe ni sur le bureau ni en test.
abstract class PushGateway {
  /// Prépare la plateforme : Firebase, le canal Android, l'affichage au
  /// premier plan. Idempotent — appelée à chaque ouverture de session.
  Future<void> ensureInitialized();

  Future<PushAuthorization> authorization();

  /// Demande l'autorisation — la boîte de dialogue du système, une seule fois
  /// dans la vie de l'installation.
  Future<PushAuthorization> requestAuthorization();

  /// Le jeton d'inscription FCM, `null` si la plateforme n'en donne pas encore
  /// (iOS sans autorisation, par exemple).
  Future<String?> token();

  /// Les rotations du jeton. FCM peut en changer sans prévenir : l'ancien
  /// cesse alors de livrer, et seul ce flux dit lequel prend sa place.
  Stream<String> tokenRefreshes();

  /// Les messages reçus **application ouverte**.
  Stream<PushMessage> foregroundMessages();

  /// Les messages **tapés** par le membre, quelle que soit la façon dont l'app
  /// était endormie.
  Stream<PushMessage> taps();

  /// Le message qui a réveillé une application **tuée**, s'il y en a un. Il
  /// n'arrive pas par [taps] : il a été tapé avant que l'app n'existe.
  Future<PushMessage?> initialMessage();

  /// Affiche une bannière pour un message reçu au premier plan.
  Future<void> showForeground(PushMessage message);
}

/// L'implémentation réelle : FCM pour la réception,
/// `flutter_local_notifications` pour le canal Android et l'affichage au
/// premier plan.
class FirebasePushGateway implements PushGateway {
  FirebasePushGateway({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? local,
  }) : _injectedMessaging = messaging,
       _local = local ?? FlutterLocalNotificationsPlugin();

  /// Le `channel_id` que `FcmClient` met dans chaque message Android. Le créer
  /// ici est ce qui lui donne un nom lisible dans les réglages du téléphone :
  /// un identifiant sans canal déclaré retombe sur « Divers ».
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'pedalons_default',
    'Pédalons',
    description:
        'Sorties, voyages, publications et réponses à vos commentaires',
    importance: Importance.high,
  );

  final FirebaseMessaging? _injectedMessaging;

  /// Paresseux, et lu seulement quand [_supported] le permet :
  /// `FirebaseMessaging.instance` lève `[core/no-app]` si `initializeApp` a
  /// échoué au démarrage — ce que `main.dart` tolère —, et le lire dans le
  /// constructeur mettait `pushGatewayProvider` en erreur à la connexion.
  late final FirebaseMessaging _messaging =
      _injectedMessaging ?? FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local;

  /// Faux quand Firebase n'a pas pu démarrer : plus de push sur cette
  /// installation, mais une app qui marche.
  bool _firebaseReady = true;

  final StreamController<PushMessage> _taps =
      StreamController<PushMessage>.broadcast();
  StreamSubscription<RemoteMessage>? _openedSubscription;
  AppLifecycleListener? _resumeListener;
  bool _initialized = false;

  @override
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;

    if (_injectedMessaging == null && Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp();
      } catch (error) {
        log('Firebase could not start, push disabled: $error', name: 'push');
        _firebaseReady = false;
        return;
      }
    }

    await _local.initialize(
      settings: const InitializationSettings(
        // L'icône de la barre d'état, la silhouette blanche du P : le lanceur
        // s'y afficherait en carré blanc.
        android: AndroidInitializationSettings('ic_stat_notification'),
        // Les autorisations sont demandées par FCM, pas ici : deux demandes
        // successives, c'est deux boîtes de dialogue pour la même chose.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final String? payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        _taps.add(PushMessage(data: _decodeData(payload)));
      },
    );

    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);
    } else {
      // Sur iOS, FCM sait présenter la bannière au premier plan ; sans ceci
      // elle est simplement avalée.
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      // Une app tuée n'est pas lancée par le tap : le `content-available` du
      // message la réveille en arrière-plan dès son arrivée, et le plugin le
      // retient alors comme « message initial ». `getInitialMessage()`, appelé
      // à ce réveil, répond `null` — personne n'a encore tapé. Au tap, le
      // plugin reconnaît le même message, n'émet **pas** `onMessageOpenedApp`
      // et le garde pour un *second* `getInitialMessage()`. On le fait donc à
      // chaque retour au premier plan ; le plugin ne le rend qu'une fois.
      _resumeListener ??= AppLifecycleListener(
        onResume: () => unawaited(_collectTappedInitialMessage()),
      );
    }

    _openedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) => _taps.add(_toPushMessage(message)),
    );
  }

  Future<void> _collectTappedInitialMessage() async {
    final RemoteMessage? message = await _messaging.getInitialMessage();
    if (message != null) _taps.add(_toPushMessage(message));
  }

  @override
  Future<PushAuthorization> authorization() async {
    if (!_supported) return PushAuthorization.unsupported;
    return _map(await _messaging.getNotificationSettings());
  }

  @override
  Future<PushAuthorization> requestAuthorization() async {
    if (!_supported) return PushAuthorization.unsupported;
    return _map(await _messaging.requestPermission());
  }

  @override
  Future<String?> token() async {
    if (!_supported) return null;
    try {
      // Déprécié depuis firebase_messaging 17, mais `register()` rend un FID,
      // que le backend ne sait pas encore cibler — ledger NOTIF-12.
      // ignore: deprecated_member_use
      return await _messaging.getToken();
    } catch (error) {
      // Un appareil sans Google Play Services, un simulateur iOS sans APNs :
      // pas de jeton, pas de push, et surtout pas d'app qui refuse de démarrer.
      log('No FCM token: $error', name: 'push');
      return null;
    }
  }

  @override
  Stream<String> tokenRefreshes() => _supported
      // Même raison que `token()` — ledger NOTIF-12.
      // ignore: deprecated_member_use
      ? _messaging.onTokenRefresh
      : const Stream<String>.empty();

  @override
  Stream<PushMessage> foregroundMessages() => _supported
      ? FirebaseMessaging.onMessage.map(_toPushMessage)
      : const Stream<PushMessage>.empty();

  @override
  Stream<PushMessage> taps() => _taps.stream;

  @override
  Future<PushMessage?> initialMessage() async {
    if (!_supported) return null;
    final RemoteMessage? message = await _messaging.getInitialMessage();
    return message == null ? null : _toPushMessage(message);
  }

  @override
  Future<void> showForeground(PushMessage message) async {
    // iOS présente lui-même la bannière (voir `ensureInitialized`) ; Android,
    // non : au premier plan, un message FCM n'affiche rien du tout.
    if (!Platform.isAndroid) return;
    if (message.title == null && message.body == null) return;
    await _local.show(
      id: message.notificationId.hashCode,
      title: message.title,
      body: message.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  bool get _supported =>
      _firebaseReady && (Platform.isAndroid || Platform.isIOS);

  static PushMessage _toPushMessage(RemoteMessage message) {
    return PushMessage(
      title: message.notification?.title,
      body: message.notification?.body,
      data: <String, String>{
        for (final MapEntry<String, dynamic> entry in message.data.entries)
          entry.key: '${entry.value}',
      },
    );
  }

  static Map<String, String> _decodeData(String payload) {
    try {
      final Object? decoded = jsonDecode(payload);
      if (decoded is! Map) return const <String, String>{};
      return <String, String>{
        for (final MapEntry<Object?, Object?> entry in decoded.entries)
          '${entry.key}': '${entry.value}',
      };
    } catch (_) {
      return const <String, String>{};
    }
  }

  static PushAuthorization _map(NotificationSettings settings) {
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional => PushAuthorization.granted,
      AuthorizationStatus.denied ||
      AuthorizationStatus.deniedPermanently => PushAuthorization.denied,
      AuthorizationStatus.notDetermined => PushAuthorization.notDetermined,
    };
  }
}
