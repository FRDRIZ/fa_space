import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';

class StatusService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Battery _battery = Battery();

  // Tambahkan parameter updateLastSeen dengan nilai default true
  Future<void> updateMyStatus(String userId, {bool updateLastSeen = true}) async {
    try {
      // Ambil Lokasi
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );

      // Ambil Baterai
      int batteryLevel = await _battery.batteryLevel;
      BatteryState state = await _battery.batteryState;

      // Siapkan data yang mau di-update
      Map<String, dynamic> dataToUpdate = {
        'lat': position.latitude,
        'lng': position.longitude,
        'battery': batteryLevel,
        'isCharging': state == BatteryState.charging,
      };

      // Kalo lagi on-screen (true), baru masukin lastSeen ke map data
      if (updateLastSeen) {
        dataToUpdate['lastSeen'] = FieldValue.serverTimestamp();
      }

      await _db.collection('status').doc(userId).set(
        dataToUpdate, 
        SetOptions(merge: true),
      );
    } catch (e) {
      print("Gagal update status: $e");
    }
  }
}