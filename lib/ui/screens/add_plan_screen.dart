import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AddPlanScreen extends StatefulWidget {
  const AddPlanScreen({super.key});

  @override
  State<AddPlanScreen> createState() => _AddPlanScreenState();
}

class _AddPlanScreenState extends State<AddPlanScreen> {
  final _planController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add New Plan")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _planController,
              decoration: const InputDecoration(labelText: "What's the plan?"),
            ),
            ListTile(
              title: Text("Date: ${DateFormat('dd MMM yyyy').format(_selectedDate)}"),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (_planController.text.isNotEmpty) {
                  FirebaseFirestore.instance.collection('plans').add({
                    'title': _planController.text,
                    'date': Timestamp.fromDate(_selectedDate),
                    'isDone': false,
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text("Save Plan"),
            )
          ],
        ),
      ),
    );
  }
}