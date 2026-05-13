import 'package:flutter/material.dart';

enum CyclePhase { menstrual, follicular, ovulation, luteal }

class PhaseInfo {
  final CyclePhase phase;
  final String name;
  final Color color;
  final Color lightColor;
  final Color textColor;
  final IconData icon;
  final String biologicalExplanation;
  final String auraFeels;
  final String faridShouldDo;
  final String emoji;

  const PhaseInfo({
    required this.phase,
    required this.name,
    required this.color,
    required this.lightColor,
    required this.textColor,
    required this.icon,
    required this.biologicalExplanation,
    required this.auraFeels,
    required this.faridShouldDo,
    required this.emoji,
  });
}

class CycleDay {
  final DateTime date;
  final CyclePhase phase;
  final int dayInCycle;
  final bool isPredicted;

  const CycleDay({
    required this.date,
    required this.phase,
    required this.dayInCycle,
    required this.isPredicted,
  });
}

class CycleEngine {
  static const Map<CyclePhase, PhaseInfo> phaseData = {
    CyclePhase.menstrual: PhaseInfo(
      phase: CyclePhase.menstrual,
      name: 'Menstruasi',
      color: Color(0xFFF4C0D1),
      lightColor: Color(0xFFFAEBF0),
      textColor: Color(0xFF4B1528),
      icon: Icons.water_drop,
      emoji: '🔴',
      biologicalExplanation:
          'Lapisan rahim luruh karena tidak terjadi pembuahan. Tubuh bekerja keras untuk memperbarui diri dengan kadar hormon di titik terendah.',
      auraFeels:
          'Aura mungkin merasakan kram, mudah lelah, dan butuh lebih banyak istirahat. Mood cenderung sensitif dan ingin dipeluk.',
      faridShouldDo:
          'Siapkan minuman hangat, beri pijatan lembut, dan hindari memaksakan aktivitas berat. Ucapkan kata-kata penenang tanpa perlu logika. ❤️',
    ),
    CyclePhase.follicular: PhaseInfo(
      phase: CyclePhase.follicular,
      name: 'Folikular',
      color: Color(0xFFB5D4F4),
      lightColor: Color(0xFFE3F0FB),
      textColor: Color(0xFF042C53),
      icon: Icons.local_florist,
      emoji: '🌸',
      biologicalExplanation:
          'FSH merangsang pertumbuhan folikel di ovarium. Estrogen mulai naik, dan energi tubuh meningkat secara alami.',
      auraFeels:
          'Aura merasa lebih bersemangat, kreatif, dan terbuka untuk hal baru. Mood positif dan komunikasi terasa lebih mudah.',
      faridShouldDo:
          'Ajak jalan-jalan atau lakukan aktivitas baru bersama. Diskusi atau rencana ke depan mudah dibahas di fase ini. 🌿',
    ),
    CyclePhase.ovulation: PhaseInfo(
      phase: CyclePhase.ovulation,
      name: 'Ovulasi',
      color: Color(0xFFC0DD97),
      lightColor: Color(0xFFEAF5DD),
      textColor: Color(0xFF173404),
      icon: Icons.star,
      emoji: '⭐',
      biologicalExplanation:
          'LH melonjak, memicu pelepasan sel telur matang. Estrogen mencapai puncaknya. Ini adalah fase paling subur dalam siklus.',
      auraFeels:
          'Aura di puncak kepercayaan diri, suka bersosialisasi, dan sangat terbuka secara emosional. Fase paling "bersinar" baginya.',
      faridShouldDo:
          'Rencanakan sesuatu yang spesial — dinner, kejutan kecil, atau momen romantis. Ungkapkan perasaan; ia paling mudah menerima di fase ini. ✨',
    ),
    CyclePhase.luteal: PhaseInfo(
      phase: CyclePhase.luteal,
      name: 'Luteal (PMS)',
      color: Color(0xFFFAC775),
      lightColor: Color(0xFFFDF0DA),
      textColor: Color(0xFF412402),
      icon: Icons.cloud,
      emoji: '🌙',
      biologicalExplanation:
          'Progesteron naik lalu turun drastis. Di hari-hari terakhir jika tidak ada pembuahan, perubahan hormon ini memicu gejala PMS.',
      auraFeels:
          'Aura mungkin lebih sensitif, mudah lelah, dan butuh validasi emosi. Hari ke-21 ke atas adalah fase PMS yang butuh ekstra perhatian.',
      faridShouldDo:
          'SABAR adalah kunci utama. Dengarkan tanpa langsung memberi solusi. Validasi perasaannya, bawakan cemilan favorit, dan minimalkan perdebatan. 💜',
    ),
  };

  static CyclePhase getPhaseForCycleDay(int cycleDay, int periodDuration) {
    if (cycleDay < periodDuration) return CyclePhase.menstrual;
    if (cycleDay <= 12) return CyclePhase.follicular;
    if (cycleDay <= 16) return CyclePhase.ovulation;
    return CyclePhase.luteal;
  }

  // MENCARI TANGGAL PATOKAN (ANCHOR) BERDASARKAN HISTORY
  static DateTime getAnchorDateFor(DateTime target, List<Map<String, dynamic>> history) {
    if (history.isEmpty) return DateTime.now().subtract(const Duration(days: 10)); // Fallback

    // Urutkan dari tanggal paling lama ke paling baru
    history.sort((a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime));

    DateTime anchor = history.first['start'] as DateTime;
    for (var log in history) {
      DateTime logStart = log['start'] as DateTime;
      // Jika history ini terjadi SEBELUM atau SAMA DENGAN target kalender, jadikan patokan
      if (logStart.isBefore(target) || DateUtils.isSameDay(logStart, target)) {
        anchor = logStart;
      }
    }
    return anchor;
  }

  // MENDAPATKAN DETAIL HARI SIKLUS SECARA DINAMIS
  static CycleDay getCycleDayData(
      DateTime targetDate, List<Map<String, dynamic>> history, int cycleLen, int periodDuration) {
    
    if (history.isEmpty) {
      return CycleDay(
        date: targetDate,
        phase: CyclePhase.menstrual,
        dayInCycle: 0,
        isPredicted: true,
      );
    }

    DateTime anchor = getAnchorDateFor(targetDate, history);
    final targetDateOnly = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final anchorDateOnly = DateTime(anchor.year, anchor.month, anchor.day);

    final diff = targetDateOnly.difference(anchorDateOnly).inDays;

    int cycleDay = diff % cycleLen;
    if (cycleDay < 0) cycleDay = (cycleDay + cycleLen) % cycleLen; // Handle minus jika scroll ke masa lalu sebelum history pertama

    // Prediksi terjadi jika jarak dari menstruasi terakhir sudah melebihi 1 siklus penuh
    bool isPredicted = diff >= cycleLen || diff < 0;

    return CycleDay(
      date: targetDate,
      phase: getPhaseForCycleDay(cycleDay, periodDuration),
      dayInCycle: cycleDay,
      isPredicted: isPredicted,
    );
  }
}