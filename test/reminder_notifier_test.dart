import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteez/reminder/notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'delivery rechecks permission changes and treats query failure as unavailable',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      MacOSFlutterLocalNotificationsPlugin.registerWith();
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var allowed = true;
      var failed = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (failed) throw PlatformException(code: 'unavailable');
        return {'isEnabled': allowed, 'isAlertEnabled': allowed};
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final notifier = ReminderNotifier();
      expect(await notifier.canShow(), isTrue);
      allowed = false;
      expect(await notifier.canShow(), isFalse);
      allowed = true;
      expect(await notifier.canShow(), isTrue);
      failed = true;
      expect(await notifier.canShow(), isFalse);
    },
  );
}
