import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PeriodTrackerScreen extends StatefulWidget {
  const PeriodTrackerScreen({super.key});

  @override
  State<PeriodTrackerScreen> createState() => _PeriodTrackerScreenState();
}

class _PeriodTrackerScreenState extends State<PeriodTrackerScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final int cycleLength = 28;
  final int periodDuration = 5;

  Future<void> _updatePeriodDate(DateTime pickedDate) async {
    await FirebaseFirestore.instance.collection('period').doc('aura').set({
      'lastPeriodStart': Timestamp.fromDate(pickedDate),
      'nextPrediction': Timestamp.fromDate(pickedDate.add(Duration(days: cycleLength))),
    }, SetOptions(merge: true));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Siklus berhasil diupdate! ✨")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Aura's Flo Calendar")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('period').doc('aura').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          DateTime lastPeriodStart = (snapshot.data!['lastPeriodStart'] as Timestamp).toDate();
          int dayInCycle = (DateTime.now().difference(lastPeriodStart).inDays % cycleLength) + 1;
          bool isPMS = dayInCycle >= 21 && dayInCycle <= 28;

          return ListView(
            children: [
              if (isPMS)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row( // CONST DI SINI SUDAH DIHAPUS
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Mood Warning: Aura sedang dalam fase PMS. Be patient, Rid! ❤️",
                          style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

              TableCalendar(
                firstDay: DateTime.utc(2024, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
               calendarBuilders: CalendarBuilders(
  defaultBuilder: (context, day, focusedDay) {
    // Normalisasi tanggal agar jamnya sama (00:00:00) supaya hitungannya presisi
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final normalizedStart = DateTime(lastPeriodStart.year, lastPeriodStart.month, lastPeriodStart.day);

    // Hitung selisih hari murni
    int diff = normalizedDay.difference(normalizedStart).inDays;
    
    // Gunakan modulo untuk perulangan siklus 28 hari
    // Kita pastikan hasilnya positif agar tidak error kalau lihat bulan sebelumnya
    int cycleDay = diff % cycleLength;
    if (cycleDay < 0) cycleDay += cycleLength;

    // 1. Masa Menstruasi (Hari ke 0 sampai 4 dari tanggal mulai)
    if (cycleDay >= 0 && cycleDay < periodDuration) {
      return _buildDayContainer(day, Colors.redAccent);
    }
    
    // 2. Fase PMS (Hari ke 21 sampai 27 dari siklus)
    if (cycleDay >= 21 && cycleDay <= 27) {
      return _buildDayContainer(day, Colors.orangeAccent);
    }
    
    return null;
  },
),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: lastPeriodStart,
                      firstDate: DateTime(2024), // PARAMETER BENAR
                      lastDate: DateTime.now().add(const Duration(days: 365)), // PARAMETER BENAR
                    );
                    if (picked != null) _updatePeriodDate(picked);
                  },
                  icon: const Icon(Icons.edit_calendar),
                  label: const Text("Edit Tanggal Haid Terakhir"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
              
              _buildStatusCard(dayInCycle, isPMS),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDayContainer(DateTime day, Color color) {
    return Container(
      margin: const EdgeInsets.all(6),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text("${day.day}", style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _buildStatusCard(int day, bool isPMS) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListTile(
        leading: Icon(Icons.info_outline, color: isPMS ? Colors.orange : Colors.blue),
        title: Text("Hari ke-$day dalam Siklus"),
        subtitle: Text(isPMS ? "Fase Luteal (Mood Warning)" : "Fase Normal"),
      ),
    );
  }
}