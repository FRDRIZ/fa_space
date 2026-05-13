import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Ganti path ini sesuai dengan struktur folder kamu:
import '../utils/cycle_engine.dart'; 

class PhaseDetailSheet extends StatelessWidget {
  final CycleDay cycleDay;
  final List<Map<String, dynamic>> plans;

  const PhaseDetailSheet({
    super.key,
    required this.cycleDay,
    required this.plans,
  });

  static Future<void> show(
    BuildContext context,
    CycleDay cycleDay,
    List<Map<String, dynamic>> plans,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PhaseDetailSheet(cycleDay: cycleDay, plans: plans),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = CycleEngine.phaseData[cycleDay.phase]!;
    final dateLabel = DateFormat('EEEE, d MMMM yyyy', 'id').format(cycleDay.date);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    _buildHeader(info, dateLabel, cycleDay),
                    const SizedBox(height: 20),
                    _buildPhaseCard(info),
                    const SizedBox(height: 16),
                    _buildInsightCard(
                      icon: Icons.favorite,
                      color: info.textColor,
                      title: 'Aura Feels',
                      content: info.auraFeels,
                      emoji: '💁‍♀️',
                    ),
                    const SizedBox(height: 12),
                    _buildInsightCard(
                      icon: Icons.handshake,
                      color: info.textColor,
                      title: 'Farid Should Do',
                      content: info.faridShouldDo,
                      emoji: '🧔',
                    ),
                    if (plans.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildPlansSection(plans, info.color),
                    ],
                    const SizedBox(height: 12),
                    if (cycleDay.isPredicted)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.auto_awesome, color: Colors.blue.shade600, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Ini adalah prediksi berdasarkan siklus bulanan. Bisa berbeda dengan kondisi aktual nanti.',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(PhaseInfo info, String dateLabel, CycleDay day) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: info.lightColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(info.emoji, style: const TextStyle(fontSize: 28)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                info.name,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: info.textColor,
                ),
              ),
              Text(
                dateLabel,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                'Hari ke-${day.dayInCycle + 1} dalam siklus',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseCard(PhaseInfo info) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: info.lightColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: info.color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science_outlined, color: info.textColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'Apa yang terjadi secara biologis',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: info.textColor,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            info.biologicalExplanation,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard({
    required IconData icon,
    required Color color,
    required String title,
    required String content,
    required String emoji,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlansSection(List<Map<String, dynamic>> plans, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.event_note, color: accentColor, size: 18),
            const SizedBox(width: 8),
            Text(
              'Rencana Hari Ini',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: accentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...plans.map((plan) {
          final timestamp = plan['date'] as Timestamp?;
          String timeLabel = '';
          if (timestamp != null) {
            timeLabel = DateFormat('HH:mm').format(timestamp.toDate());
          }
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accentColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.circle, color: accentColor, size: 8),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    plan['title'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
                  ),
                ),
                if (timeLabel.isNotEmpty)
                  Text(
                    timeLabel,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}