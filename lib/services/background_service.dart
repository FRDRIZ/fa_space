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
import 'package:screen_state/screen_state.dart'; // Import package baru
import '../firebase_options.dart';

// Variabel global di dalam isolate background untuk menyimpan status layar
bool _isScreenOn = true; 
StreamSubscription<ScreenStateEvent>? _screenSubscription;

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

  service.on('stopService').listen((event) {
    _screenSubscription?.cancel(); // Bersihkan listener saat service mati
    service.stopSelf();
  });

  // --- LOGIKA DETEKSI LAYAR HP (FIXED) ---
  try {
    Screen _screen = Screen();
    _screenSubscription = _screen.screenStateStream?.listen((ScreenStateEvent event) {
      // Menggunakan properti bawaan enum atau konversi ke string untuk mencocokkan nilainya
      String eventString = event.toString();
      
      if (eventString.contains('SCREEN_ON') || eventString.contains('SCREEN_UNLOCKED')) {
        _isScreenOn = true;
        debugPrint("QA Log: Layar HP Menyala / Unlocked");
      } else if (eventString.contains('SCREEN_OFF')) {
        _isScreenOn = false;
        debugPrint("QA Log: Layar HP Mati / Locked");
      }
    });
  } catch (e) {
    debugPrint("QA Log: Gagal menginisialisasi Screen State Sensor: $e");
  }

  // Jalankan update pertama kali
  await _sendUpdate(battery, service);

  // Listener baterai dicolok
  battery.onBatteryStateChanged.listen((_) => _sendUpdate(battery, service));

  // Timer interval update rutin (ganti ke 10 atau 15 detik agar responsif)
  Timer.periodic(const Duration(seconds: 15), (timer) async {
    await _sendUpdate(battery, service);
  });
}

Future<void> _sendUpdate(Battery battery, ServiceInstance service) async {
  try {
    double? lat, lng;

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
      // Cek di sini: Jika _isScreenOn true, kirim serverTimestamp. Jika false, field lastSeen tidak akan ikut di-update (mempertahankan data lama)
      if (_isScreenOn) 'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint("QA Log: Update berhasil. Status Layar Aktif = $_isScreenOn");
  } catch (e) {
    debugPrint("QA Log: Update Gagal: $e");
  }
}