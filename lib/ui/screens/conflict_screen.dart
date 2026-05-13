import 'package:flutter/material.dart';
import '../../services/gemini_service.dart';

class ConflictScreen extends StatefulWidget {
  const ConflictScreen({super.key});

  @override
  State<ConflictScreen> createState() => _ConflictScreenState();
}

class _ConflictScreenState extends State<ConflictScreen> {
  final _inputController = TextEditingController();
  String _advice = "";
  bool _isLoading = false;

  void _getAdvice() async {
    setState(() => _isLoading = true);
    final result = await GeminiService.getMediatorAdvice(_inputController.text);
    setState(() {
      _advice = result;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("FA Mediator (AI)")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text("Ada masalah apa hari ini? Tumpahin di sini biar aku bantu cari jalan tengahnya.", 
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 15),
          TextField(
            controller: _inputController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: "Misal: Farid telat jemput karena ketiduran pas ngoding...",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _getAdvice,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Minta Saran Gemini"),
          ),
          const SizedBox(height: 30),
          if (_advice.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.blueGrey,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
              ),
              child: Text(_advice, style: const TextStyle(fontSize: 15, height: 1.5)),
            ),
        ],
      ),
    );
  }
}