import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class StatusService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Battery _battery = Battery();
  
  // Tracker waktu internal untuk mendeteksi apakah background tersendat (layar mati)
  DateTime? _lastUpdateTime;

  Future<void> updateMyStatus(String userId) async {
    try {
      DateTime now = DateTime.now();
      bool shouldUpdateLastSeen = true;

      // --- LOGIKA DETEKSI JEDA BACKGROUND (LAYAR MATI) ---
      if (_lastUpdateTime != null) {
        int differenceInSeconds = now.difference(_lastUpdateTime!).inSeconds;
        
        // Jika interval timer harusnya 15 detik, tapi melorot > 25 detik,
        // artinya HP sedang lockscreen/deep sleep (Layar Mati).
        if (differenceInSeconds > 25) {
          shouldUpdateLastSeen = false;
          debugPrint("QA Log: Background tersendat ($differenceInSeconds s). Layar Terindikasi MATI.");
        }
      }
      
      // Update pencatatan waktu eksekusi terakhir
      _lastUpdateTime = now;

      double? lat, lng;

      // 1. Ambil Data Baterai
      int batteryLevel = await _battery.batteryLevel;
      BatteryState state = await _battery.batteryState;

      // 2. Ambil Lokasi (Akurasi diturunkan ke low + diberi timeLimit agar tidak menggantung)
      try {
        bool isLocationEnabled = await Geolocator.isLocationServiceEnabled();
        LocationPermission permission = await Geolocator.checkPermission();

        if (isLocationEnabled && (permission == LocationPermission.always || permission == LocationPermission.whileInUse)) {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low, 
            timeLimit: const Duration(seconds: 3), // Membatasi nunggu GPS biar hemat baterai
          );
          lat = position.latitude;
          lng = position.longitude;
        }
      } catch (e) {
        debugPrint("QA Log: Gagal mengambil lokasi, lanjut update baterai saja.");
      }

      // 3. Siapkan Payload Data ke Firestore
      Map<String, dynamic> dataToUpdate = {
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'battery': batteryLevel,
        'isCharging': state == BatteryState.charging,
      };

      // Jika kondisi layar hidup (lancar), perbarui lastSeen
      if (shouldUpdateLastSeen) {
        dataToUpdate['lastSeen'] = FieldValue.serverTimestamp();
      }

      // 4. Eksekusi ke Firebase
      await _db.collection('status').doc(userId).set(
        dataToUpdate, 
        SetOptions(merge: true),
      );
      
      debugPrint("QA Log: StatusService success! Update LastSeen = $shouldUpdateLastSeen");
    } catch (e) {
      debugPrint("QA Log: Gagal total update status: $e");
    }
  }
}