import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PlanCalendarView extends StatefulWidget {
  const PlanCalendarView({super.key});

  @override
  State<PlanCalendarView> createState() => _PlanCalendarViewState();
}

class _PlanCalendarViewState extends State<PlanCalendarView> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    // Secara default langsung pilih hari ini saat halaman dibuka
    _selectedDay = DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day);
  }

  @override
  Widget build(BuildContext context) {
    // Logika menentukan range waktu 24 jam penuh pada hari yang dipilih
    DateTime targetDay = _selectedDay ?? DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day);
    DateTime startOfDay = DateTime(targetDay.year, targetDay.month, targetDay.day, 0, 0, 0);
    DateTime endOfDay = DateTime(targetDay.year, targetDay.month, targetDay.day, 23, 59, 59);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detailed Plans", style: TextStyle(fontWeight: FontWeight.bold)), 
        backgroundColor: Colors.pink.shade100,
        centerTitle: true,
      ),
      body: Column(
        children: [
          TableCalendar(
            focusedDay: _focusedDay,
            firstDay: DateTime(2024),
            lastDay: DateTime(2030),
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) => setState(() => _calendarFormat = format),
            eventLoader: (day) {
              // Di sini bisa ditambahkan logic penanda dot jika dibutuhkan nanti
              return [];
            },
            calendarStyle: CalendarStyle(
              selectedDecoration: const BoxDecoration(
                color: Colors.pink,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.pink.shade200.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // FIX: Menggunakan jalur Tol Range Query biar jam brapapun di database tetep tembus dibaca
              stream: FirebaseFirestore.instance
                  .collection('plans')
                  .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
                  .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                var docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No plans for this day.", 
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    bool isDateWithAura = data['type'] == 'with_aura';
                    List itinerary = data['itinerary'] ?? [];

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: isDateWithAura ? Colors.pink.shade50 : Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        initiallyExpanded: true, // AUTO OPEN: Rincian itinerary langsung ke-render rapi
                        leading: Icon(
                          isDateWithAura ? Icons.favorite : Icons.person, 
                          color: isDateWithAura ? Colors.pink : Colors.grey,
                          size: 28,
                        ),
                        title: Text(
                          data['title'] ?? 'Plan', 
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 16,
                            color: isDateWithAura ? Colors.pink.shade900 : Colors.black,
                          ),
                        ),
                        subtitle: Text(isDateWithAura ? "Date with Aura ❤️" : "Personal Task"),
                        children: itinerary.map((item) {
                          return ListTile(
                            dense: true,
                            leading: Icon(Icons.access_time, size: 16, color: Colors.pink.shade300),
                            title: Text(
                              "${item['time'] ?? '--:--'}   👉   ${item['activity'] ?? ''}",
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}