import 'dart:async';
import 'dart:io';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'upload_service.dart';

const _notifChannelId = 'ai_call_assistant';
const _notifChannelName = 'AI 통화비서';

Future<void> initBackgroundService() async {
  final service = FlutterBackgroundService();

  // 알림 채널 (Android 8+)
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    _notifChannelId,
    _notifChannelName,
    description: '통화 녹음 자동 업로드 서비스',
    importance: Importance.low,
  );
  final notifPlugin = FlutterLocalNotificationsPlugin();
  await notifPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: _onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: _notifChannelId,
      initialNotificationTitle: 'AI 통화비서',
      initialNotificationContent: '통화 녹음 감시 중...',
      foregroundServiceNotificationId: 1001,
    ),
    iosConfiguration: IosConfiguration(autoStart: false),
  );
}

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  final Set<String> uploaded = {};
  final prefs = await SharedPreferences.getInstance();

  // 5초마다 녹음 폴더 스캔
  Timer.periodic(const Duration(seconds: 5), (_) async {
    if (prefs.getBool('auto_upload') != true) return;

    final List<String> folders = [
      '/storage/emulated/0/MIUI/sound_recorder/call_rec',
      '/storage/emulated/0/Recordings/Call',
      '/storage/emulated/0/PhoneRecord',
      '/storage/emulated/0/Record/PhoneRecord',
      '/storage/emulated/0/Music/Recordings',
      '/storage/emulated/0/Call',
      '/storage/emulated/0/Recordings',
      '/storage/emulated/0/Samsung/Recorder',
    ];

    for (final folderPath in folders) {
      final dir = Directory(folderPath);
      if (!await dir.exists()) continue;

      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) =>
              f.path.endsWith('.mp3') ||
              f.path.endsWith('.m4a') ||
              f.path.endsWith('.wav'))
          .toList();

      // 가장 최근 파일만 확인 (5분 이내)
      for (final file in files) {
        final stat = await file.stat();
        final age = DateTime.now().difference(stat.modified);
        if (age.inMinutes > 5) continue;
        if (uploaded.contains(file.path)) continue;

        uploaded.add(file.path);
        final ok = await UploadService.uploadFile(file.path);

        // 업로드 결과 알림
        final notifPlugin = FlutterLocalNotificationsPlugin();
        await notifPlugin.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ok ? '분석 완료' : '업로드 실패',
          ok
              ? '${file.uri.pathSegments.last} 분석이 완료되었습니다.'
              : '${file.uri.pathSegments.last} 업로드에 실패했습니다.',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _notifChannelId,
              _notifChannelName,
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }
    }
  });
}

void startBackgroundService() {
  FlutterBackgroundService().startService();
}

void stopBackgroundService() {
  FlutterBackgroundService().invoke('stopService');
}
