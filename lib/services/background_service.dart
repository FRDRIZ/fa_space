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

DateTime? _lastUpdateTime;

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
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
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
    service.on('setAsForeground').listen((event) => service.setAsForegroundService());
    service.on('setAsBackground').listen((event) => service.setAsBackgroundService());
    
    service.setAsForegroundService();
  }

  service.on('stopService').listen((event) => service.stopSelf());

  // Set waktu awal mula service berjalan
  _lastUpdateTime = DateTime.now();

  // Jalankan update pertama kali
  await _sendUpdate(battery, service);

  battery.onBatteryStateChanged.listen((_) => _sendUpdate(battery, service));

  // Timer interval update rutin setiap 15 detik
  Timer.periodic(const Duration(seconds: 15), (timer) async {
    await _sendUpdate(battery, service);
  });
}

Future<void> _sendUpdate(Battery battery, ServiceInstance service) async {
  try {
    double? lat, lng;
    DateTime now = DateTime.now();
    bool shouldUpdateLastSeen = true;

    // --- LOGIKA DETERMINASI TIMING LAYAR (FIXED) ---
    if (_lastUpdateTime != null) {
      int differenceInSeconds = now.difference(_lastUpdateTime!).inSeconds;
      
      if (differenceInSeconds > 25) {
        shouldUpdateLastSeen = false;
        debugPrint("QA Log: Android Background tersendat ($differenceInSeconds detik), layar terindikasi MATI.");
      }
    }
    
    // PERBAIKAN: Hanya update tracker waktu jika eksekusinya lancar (artinya layar beneran aktif)
    if (shouldUpdateLastSeen) {
      _lastUpdateTime = now;
    }

    int level = await battery.batteryLevel;
    BatteryState state = await battery.batteryState;

    try {
      bool isLocationEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();

      if (isLocationEnabled && (permission == LocationPermission.always || permission == LocationPermission.whileInUse)) {
        Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 3), 
        );
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } catch (e) {
      debugPrint("QA Log: Lokasi gagal diambil.");
    }

    // KIRIM KE FIREBASE
    await FirebaseFirestore.instance.collection('status').doc('farid').set({
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      'battery': level,
      'isCharging': state == BatteryState.charging,
      if (shouldUpdateLastSeen) 'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint("QA Log: Update Berhasil. Update LastSeen = $shouldUpdateLastSeen");
  } catch (e) {
    debugPrint("QA Log: Update Gagal: $e");
  }
}