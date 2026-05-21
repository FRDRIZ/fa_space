import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http; // 👈 IMPORT UNTUK HTTP REQUEST
import 'dart:convert';

class AddPlanScreen extends StatefulWidget {
  const AddPlanScreen({super.key});

  @override
  State<AddPlanScreen> createState() => _AddPlanScreenState();
}

class _AddPlanScreenState extends State<AddPlanScreen> {
  final TextEditingController _titleController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _withAura = false;
  bool _isLoading = false; 
  
  final List<Map<String, TextEditingController>> _itineraryFields = [];

  @override
  void initState() {
    super.initState();
    _addItineraryField();
  }

  void _addItineraryField() {
    setState(() {
      _itineraryFields.add({
        'time': TextEditingController(),
        'activity': TextEditingController(),
      });
    });
  }

  void _removeItineraryField(int index) {
    if (_itineraryFields.length > 1) {
      setState(() {
        _itineraryFields.removeAt(index);
      });
    }
  }

  // 🔥 JURUS GRATISAN: Kirim Email via EmailJS HTTP API (Aman untuk Web & Android)
  Future<void> _sendEmailViaAPI(String title, String formattedDate, List<Map<String, String>> itinerary) async {
    // Susun baris teks itinerary biasa
    String itineraryText = "";
    for (var item in itinerary) {
      if (item['time']!.isNotEmpty || item['activity']!.isNotEmpty) {
        itineraryText += "🕒 Jam ${item['time']}: ${item['activity']}\n";
      }
    }

    // ⚠️ MASUKKAN CREDENTIAL EMAILJS KAMU DI SINI
    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'origin': 'http://localhost', // Diperlukan oleh EmailJS demi keamanan cors web
      },
      body: json.encode({
        'service_id': 'service_o0oro9w',   // 👈 Ganti dengan Service ID kamu
        'template_id': 'template_acgcit4', // 👈 Ganti dengan Template ID kamu
        'user_id': 'lvwL5hzfXIT97Ohue',     // 👈 Ganti dengan Public Key kamu
        'template_params': {
          'title': title,
          'date': formattedDate,
          'itinerary': itineraryText,
          'reply_to': 'muhamadfaridrizqi76@gmail.com'
        }
      }),
    );

    if (response.statusCode == 200) {
      print('✅ [QA API] Email sukses terkirim ke Aura via EmailJS!');
    } else {
      print('🚨 [QA API] Gagal kirim email API: ${response.body}');
      throw Exception('Gagal mengirim email undangan.');
    }
  }

  Future<void> _savePlan() async {
    if (_titleController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    List<Map<String, String>> itineraryData = _itineraryFields.map((field) {
      return {
        'time': field['time']!.text,
        'activity': field['activity']!.text,
      };
    }).toList();

    Map<String, dynamic> planData = {
      'title': _titleController.text,
      'date': Timestamp.fromDate(_selectedDate),
      'type': _withAura ? 'with_aura' : 'without_aura',
      'itinerary': itineraryData,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      // 1. Jika kencan bareng Aura, tembak API emailnya duluan
      if (_withAura) {
        String formattedDate = DateFormat('dd MMMM yyyy').format(_selectedDate);
        await _sendEmailViaAPI(_titleController.text, formattedDate, itineraryData);
      }

      // 2. Simpan data ke Database Firestore (Gratis & Unlimited untuk skala kecil)
      print('🔄 [QA Debug] Menyimpan data ke Firestore...');
      await FirebaseFirestore.instance.collection('plans').add(planData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_withAura ? "Plan Saved & Email Invitation Dispatched! ❤️" : "Plan Saved!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('🚨 [QA Debug] Gagal mengeksekusi proses: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("New Schedule"), backgroundColor: Colors.pink.shade100),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.pink),
                  SizedBox(height: 15),
                  Text("Processing schedule data & automated invites..."),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: "Main Goal / Title", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  
                  SwitchListTile(
                    title: const Text("Plan with Aura? ❤️", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text("Sends email invitation if enabled"),
                    value: _withAura,
                    activeColor: Colors.pink,
                    onChanged: (val) => setState(() => _withAura = val),
                  ),
                  
                  const Divider(),
                  ListTile(
                    title: const Text("Date"),
                    trailing: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context, 
                        initialDate: _selectedDate, 
                        firstDate: DateTime.now(), 
                        lastDate: DateTime(2030)
                      );
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  const Text("Itinerary / Timeline", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),

                  ..._itineraryFields.asMap().entries.map((entry) {
                    int idx = entry.key;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: entry.value['time'],
                              decoration: const InputDecoration(hintText: "08:00", border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: entry.value['activity'],
                              decoration: const InputDecoration(hintText: "Activity detail...", border: OutlineInputBorder()),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                            onPressed: () => _removeItineraryField(idx),
                          )
                        ],
                      ),
                    );
                  }),
                  
                  TextButton.icon(
                    onPressed: _addItineraryField, 
                    icon: const Icon(Icons.add), 
                    label: const Text("Add More Activity")
                  ),

                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _savePlan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink, 
                      minimumSize: const Size(double.infinity, 50)
                    ),
                    child: const Text("Save Plan", style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
            ),
    );
  }
}