import 'package:cloud_firestore/cloud_firestore.dart';

class PlanModel {
  final String title;
  final String category; // Misal: Kuliah, Kerja, Me Time
  final DateTime startTime;
  final DateTime endTime;
  final String locationName;

  PlanModel({
    required this.title,
    required this.category,
    required this.startTime,
    required this.endTime,
    required this.locationName,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'category': category,
    'startTime': startTime,
    'endTime': endTime,
    'locationName': locationName,
  };
}