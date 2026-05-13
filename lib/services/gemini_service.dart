import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  // PASTE API KEY KAMU DI SINI
  static const _apiKey = 'AIzaSyCvZLgwteXbct7TkJVgSv9YDr9Ed5dsCyk';

  static Future<String> getMediatorAdvice(String masalah) async {
    // Pakai model Gemini 1.5 Flash (Cepat & Hemat Kuota)
    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
    
    final prompt = """
    Kamu adalah mediator hubungan profesional bernama 'FA Mediator'.
    User sedang mengalami konflik: '$masalah'.
    
    Tugasmu:
    1. Berikan analisis singkat kenapa masalah ini bisa terjadi (empati ke keduanya).
    2. Berikan saran konkret untuk Farid agar lebih mengerti Aura.
    3. Berikan saran konkret untuk Aura agar lebih tenang menghadapi Farid.
    
    Gunakan bahasa gaul anak muda Indonesia yang santai, bijak, dan tidak memihak.
    Jangan terlalu formal, tapi harus tetap berbobot.
    """;

    try {
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      return response.text ?? "Aduh, koneksi AI-nya lagi putus nih. Mungkin ini tandanya kalian harus baikan manual? 😊";
    } catch (e) {
      return "Error: Kamu mungkin belum pasang API Key atau kuotanya habis. Pesan error: $e";
    }
  }
}