import 'dart:async';
import 'package:flutter/foundation.dart'; // Wajib untuk debugPrint
import 'package:flutter/material.dart';    // Wajib untuk WidgetsFlutterBinding
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
  // Inisialisasi awal untuk isolate terpisah
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final battery = Battery();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) => service.setAsForegroundService());
    service.on('setAsBackground').listen((event) => service.setAsBackgroundService());
    
    // Set awal agar service langsung terlihat aktif
    service.setAsForegroundService();
  }

  service.on('stopService').listen((event) => service.stopSelf());

  // Jalankan update pertama kali
  await _sendUpdate(battery, service);

  // Listener: Update otomatis setiap status charger berubah (misal: dicolok)
  battery.onBatteryStateChanged.listen((_) => _sendUpdate(battery, service));

  // Timer: Update rutin setiap 5 menit agar data Last Seen tetap segar
  Timer.periodic(const Duration(seconds: 5), (timer) async {
    await _sendUpdate(battery, service);
  });
}

Future<void> _sendUpdate(Battery battery, ServiceInstance service) async {
  try {
    double? lat, lng;

    // Ambil data baterai dulu (pasti berhasil tanpa izin khusus)
    int level = await battery.batteryLevel;
    BatteryState state = await battery.batteryState;

    // Coba ambil lokasi, kalau gagal ya sudah, lanjut update baterai
    try {
      bool isLocationEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();

      if (isLocationEnabled && (permission == LocationPermission.always || permission == LocationPermission.whileInUse)) {
        Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 3), // Jangan kelamaan nunggu GPS
        );
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } catch (e) {
      debugPrint("QA Log: Lokasi gagal diambil, tapi tetap update baterai.");
    }

    // KIRIM KE FIREBASE (Ini intinya)
    await FirebaseFirestore.instance.collection('status').doc('farid').set({
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      'battery': level,
      'isCharging': state == BatteryState.charging,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint("QA Log: Backend update success! Baterai: $level%");
  } catch (e) {
    debugPrint("QA Log: Update Gagal Total: $e");
  }
}