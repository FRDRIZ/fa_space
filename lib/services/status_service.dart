import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class StatusService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Battery _battery = Battery();

  Timer? _inactivityTimer;
  static const Duration _inactivityThreshold = Duration(minutes: 3);

  Future<void> updateMyStatus(String userId, {bool isOnline = true}) async {
    double? lat, lng;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();
      if (serviceEnabled &&
          (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse)) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        lat = position.latitude;
        lng = position.longitude;
      }
    } catch (e) {
      debugPrint('StatusService: Location unavailable.');
    }

    int batteryLevel = await _battery.batteryLevel;
    BatteryState state = await _battery.batteryState;

    await _db.collection('status').doc(userId).set({
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      'battery': batteryLevel,
      'isCharging': state == BatteryState.charging,
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void setOnline(String userId) {
    _inactivityTimer?.cancel();
    updateMyStatus(userId, isOnline: true);
    _scheduleOffline(userId);
  }

  void setOffline(String userId) {
    _inactivityTimer?.cancel();
    _db.collection('status').doc(userId).set({
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _scheduleOffline(String userId) {
    _inactivityTimer = Timer(_inactivityThreshold, () {
      setOffline(userId);
    });
  }

  void resetInactivityTimer(String userId) {
    _inactivityTimer?.cancel();
    _scheduleOffline(userId);
  }

  Stream<DocumentSnapshot> watchStatus(String userId) {
    return _db.collection('status').doc(userId).snapshots();
  }

  static String formatLastSeen(Timestamp? lastSeen) {
    if (lastSeen == null) return 'Belum pernah online';
    final dt = lastSeen.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit yang lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam yang lalu';
    if (diff.inDays == 1) return 'Kemarin';
    return '${diff.inDays} hari yang lalu';
  }

  void dispose() {
    _inactivityTimer?.cancel();
  }
}