import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 리마인더 알림(best-effort). 서명 없는 macOS 빌드에선 권한이 거부될 수 있어
/// [granted] 로 가용 여부를 노출 — 불가하면 호출측이 자동 소환으로 폴백한다.
class ReminderNotifier {
  final FlutterLocalNotificationsPlugin _fln =
      FlutterLocalNotificationsPlugin();
  bool _granted = false;

  /// 알림 권한이 실제로 허용됐는지. false면 알림이 안 뜨므로 폴백 필요.
  bool get granted => _granted;

  /// 초기화 + 권한 요청. onTap(id): 알림 클릭 시 그 스티커 소환 콜백.
  /// 실패해도 throw 하지 않음(best-effort) — granted=false 로 남는다.
  Future<void> init(void Function(String id) onTap) async {
    try {
      await _fln.initialize(
        const InitializationSettings(
          macOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: false,
            requestSoundPermission: true,
          ),
        ),
        onDidReceiveNotificationResponse: (r) {
          final id = r.payload;
          if (id != null && id.isNotEmpty) onTap(id);
        },
      );
      final ok = await _fln
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: false, sound: true);
      _granted = ok ?? false;
    } catch (e) {
      _granted = false;
      debugPrint('[notifier] init failed: $e');
    }
    debugPrint('[notifier] granted=$_granted');
  }

  /// Recheck without requesting permission: users may change Settings while
  /// the app runs. A silent/no-alert configuration uses the memo fallback.
  Future<bool> canShow() async {
    try {
      final permissions = await _fln
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();
      return _granted =
          permissions?.isEnabled == true && permissions?.isAlertEnabled == true;
    } catch (_) {
      return _granted = false;
    }
  }

  /// 알림 표시. payload=스티커 id(클릭 시 소환). granted=false면 호출 안 됨.
  Future<void> show(String id, String title, String body) => _fln.show(
    id.hashCode & 0x7fffffff,
    title,
    body,
    const NotificationDetails(macOS: DarwinNotificationDetails()),
    payload: id,
  );
}
