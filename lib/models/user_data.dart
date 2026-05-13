import 'package:cloud_firestore/cloud_firestore.dart';

class UserData {
  final double lat;
  final double lng;
  final int battery;
  final bool isCharging;
  final DateTime lastSeen;

  UserData({
    required this.lat,
    required this.lng,
    required this.battery,
    required this.isCharging,
    required this.lastSeen,
  });

  factory UserData.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return UserData(
      lat: data['lat'] ?? 0.0,
      lng: data['lng'] ?? 0.0,
      battery: data['battery'] ?? 0,
      isCharging: data['isCharging'] ?? false,
      lastSeen: (data['lastSeen'] as Timestamp).toDate(),
    );
  }
}