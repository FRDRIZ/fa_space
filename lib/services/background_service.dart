import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import '../firebase_options.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'fa_space_service',
    'FA Space Service',
    description: 'Monitoring status for Aura',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      foregroundServiceTypes: [AndroidForegroundType.location],
      notificationChannelId: 'fa_space_service',
      initialNotificationTitle: 'FA Space Active',
      initialNotificationContent: 'Menjaga koneksi untuk Aura... ❤️',
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final battery = Battery();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((_) => service.setAsForegroundService());
    service.on('setAsBackground').listen((_) => service.setAsBackgroundService());
    service.setAsForegroundService();
  }

  service.on('stopService').listen((_) async {
    await _markOffline();
    service.stopSelf();
  });

  service.on('appForegrounded').listen((_) async {
    await _sendUpdate(battery, service, isOnline: true);
  });

  service.on('appBackgrounded').listen((_) async {
    await _markOffline();
  });

  await _sendUpdate(battery, service, isOnline: true);

  battery.onBatteryStateChanged.listen((_) => _sendUpdate(battery, service, isOnline: true));

  Timer.periodic(const Duration(seconds: 30), (_) async {
    await _sendUpdate(battery, service, isOnline: true);
  });
}

Future<void> _markOffline() async {
  try {
    await FirebaseFirestore.instance.collection('status').doc('farid').set({
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  } catch (e) {
    debugPrint('QA Log: Failed to mark offline: $e');
  }
}

Future<void> _sendUpdate(Battery battery, ServiceInstance service, {bool isOnline = true}) async {
  try {
    double? lat, lng;

    int level = await battery.batteryLevel;
    BatteryState state = await battery.batteryState;

    try {
      bool isLocationEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();

      if (isLocationEnabled &&
          (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse)) {
        Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 3),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } catch (e) {
      debugPrint('QA Log: Lokasi gagal, tetap update baterai.');
    }

    await FirebaseFirestore.instance.collection('status').doc('farid').set({
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      'battery': level,
      'isCharging': state == BatteryState.charging,
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint('QA Log: Update success. Baterai: $level%, Online: $isOnline');
  } catch (e) {
    debugPrint('QA Log: Update gagal total: $e');
  }
}