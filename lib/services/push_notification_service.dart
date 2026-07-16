import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../config/firebase_config.dart';

/// Ensures Firebase is initialised, tolerating either native config files or
/// --dart-define credentials.
Future<void> _ensureFirebase() async {
  if (Firebase.apps.isNotEmpty) return;
  final options = FirebaseConfig.options;
  if (options == null) {
    await Firebase.initializeApp();
  } else {
    await Firebase.initializeApp(options: options);
  }
}

/// Handles messages that arrive while the app is backgrounded or terminated.
/// Must be a top-level function annotated with @pragma('vm:entry-point').
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await _ensureFirebase();
  } catch (e) {
    debugPrint('[FCM] background handler error: $e');
  }
}

typedef NotificationTapCallback = void Function(Map<String, dynamic> data);

/// Driver-app push notifications: register the device with the backend, show
/// foreground alerts, and surface taps. Firebase is optional — if it can't
/// initialise (no config), every method becomes a no-op so the app still runs.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  // Lazy: FirebaseMessaging.instance must not be touched before
  // Firebase.initializeApp() runs, so resolve it only when actually used.
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'driver_default',
    'การแจ้งเตือน',
    description: 'แจ้งเตือนงานและเหตุการณ์สำหรับคนขับ',
    importance: Importance.high,
  );

  bool _available = false;
  bool _initialized = false;
  Future<void>? _initFuture;
  NotificationTapCallback? _onTap;
  Map<String, dynamic>? _pendingTap;

  Future<void> initialize({NotificationTapCallback? onNotificationTap}) {
    if (onNotificationTap != null) {
      _onTap = onNotificationTap;
      _flushPendingTap();
    }
    return _initFuture ??= _doInitialize();
  }

  Future<void> _doInitialize() async {
    if (_initialized) return;
    try {
      await _ensureFirebase();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await _initializeLocalNotifications();
      await _requestPermission();

      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => _handleTap(m.data),
      );
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _handleTap(initial.data);

      _available = true;
    } catch (e) {
      // No Firebase config (or unsupported device) — push stays disabled.
      debugPrint('[FCM] initialize skipped: $e');
      _available = false;
    } finally {
      _initialized = true;
    }
  }

  Future<void> _initializeLocalNotifications() async {
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          _handleTap(Map<String, dynamic>.from(json.decode(payload) as Map));
        } catch (_) {}
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission();
    // Show heads-up alerts while the app is in the foreground on iOS.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  void _showForeground(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: json.encode(message.data),
    );
  }

  void _handleTap(Map<String, dynamic> data) {
    if (_onTap == null) {
      _pendingTap = data;
      return;
    }
    _onTap!(data);
  }

  void _flushPendingTap() {
    final pending = _pendingTap;
    if (pending != null && _onTap != null) {
      _pendingTap = null;
      _onTap!(pending);
    }
  }

  /// Register this device's FCM token with the backend so the driver can
  /// receive pushes. Safe to call after every login / session restore.
  Future<void> syncToken({
    required String baseUrl,
    required String authToken,
  }) async {
    await initialize();
    if (!_available) return;
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _registerToken(baseUrl, authToken, token);
      }
      _messaging.onTokenRefresh.listen(
        (t) => _registerToken(baseUrl, authToken, t),
      );
    } catch (e) {
      debugPrint('[FCM] syncToken failed: $e');
    }
  }

  /// Deactivate this device on logout so a signed-out phone stops receiving
  /// notifications for the previous driver.
  Future<void> unregisterToken({
    required String baseUrl,
    required String authToken,
  }) async {
    if (!_available) return;
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await http.delete(
          Uri.parse('$baseUrl/notifications/push-token'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
          body: {'token': token},
        );
      }
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('[FCM] unregisterToken failed: $e');
    }
  }

  Future<void> _registerToken(
    String baseUrl,
    String authToken,
    String token,
  ) async {
    await http.post(
      Uri.parse('$baseUrl/notifications/push-token'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: {
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
      },
    );
  }
}
