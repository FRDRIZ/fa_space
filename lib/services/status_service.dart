import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';

class StatusService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Battery _battery = Battery();

  Future<void> updateMyStatus(String userId) async {
    // Ambil Lokasi
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high
    );

    // Ambil Baterai
    int batteryLevel = await _battery.batteryLevel;
    BatteryState state = await _battery.batteryState;

    await _db.collection('status').doc(userId).set({
      'lat': position.latitude,
      'lng': position.longitude,
      'battery': batteryLevel,
      'isCharging': state == BatteryState.charging,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}