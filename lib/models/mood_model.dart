import 'package:cloud_firestore/cloud_firestore.dart';

class MoodModel {
  final String mood; // 😊, 😡, 🥺, 😴
  final String note;
  final DateTime date;

  MoodModel({required this.mood, required this.note, required this.date});

  Map<String, dynamic> toMap() => {
    'mood': mood,
    'note': note,
    'date': Timestamp.fromDate(date),
  };
}