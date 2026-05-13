import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CyclePhase {
  final String name;
  final Color color;
  final Color textColor;
  final int startDay;
  final int endDay;
  final String bio;
  final String auraFeels;
  final String faridShould;
  final IconData icon;

  const CyclePhase({
    required this.name,
    required this.color,
    required this.textColor,
    required this.startDay,
    required this.endDay,
    required this.bio,
    required this.auraFeels,
    required this.faridShould,
    required this.icon,
  });
}

const List<CyclePhase> kCyclePhases = [
  CyclePhase(
    name: 'Menstruasi',
    color: Color(0xFFF4C0D1),
    textColor: Color(0xFF4B1528),
    startDay: 0,
    endDay: 4,
    bio: 'Lapisan rahim luruh dan kadar hormon berada di titik terendah. Tubuh bekerja keras untuk memperbarui diri.',
    auraFeels: 'Aura mungkin merasakan kram, mudah lelah, dan butuh lebih banyak istirahat. Mood cenderung sensitif dan ingin dipeluk.',
    faridShould: 'Siapkan minuman hangat, beri pijatan lembut, dan hindari memaksakan aktivitas berat. Ucapkan kata-kata penenang tanpa perlu logika.',
    icon: Icons.favorite,
  ),
  CyclePhase(
    name: 'Folikular',
    color: Color(0xFFB5D4F4),
    textColor: Color(0xFF042C53),
    startDay: 5,
    endDay: 12,
    bio: 'Estrogen mulai naik, folikel berkembang, dan energi tubuh meningkat secara alami.',
    auraFeels: 'Aura merasa lebih bersemangat, kreatif, dan terbuka untuk hal baru. Mood positif dan komunikasi terasa lebih mudah.',
    faridShould: 'Ajak jalan-jalan atau lakukan aktivitas baru bersama. Diskusi atau rencana ke depan mudah dibahas di fase ini.',
    icon: Icons.wb_sunny,
  ),
  CyclePhase(
    name: 'Ovulasi',
    color: Color(0xFFC0DD97),
    textColor: Color(0xFF173404),
    startDay: 13,
    endDay: 16,
    bio: 'Sel telur dilepas, kadar estrogen dan LH mencapai puncak. Ini fase paling subur dalam siklus.',
    auraFeels: 'Aura di puncak kepercayaan diri, suka bersosialisasi, dan sangat terbuka secara emosional. Fase paling "bersinar".',
    faridShould: 'Rencanakan sesuatu yang spesial — dinner, kejutan kecil, atau momen romantis. Ungkapkan perasaan; ia paling mudah menerima di fase ini.',
    icon: Icons.star,
  ),
  CyclePhase(
    name: 'Luteal',
    color: Color(0xFFFAC775),
    textColor: Color(0xFF412402),
    startDay: 17,
    endDay: 27,
    bio: 'Progesteron naik lalu turun drastis. Di hari-hari terakhir, gejala PMS mungkin muncul.',
    auraFeels: 'Aura mungkin lebih sensitif, mudah lelah, dan butuh validasi emosi. Hari ke-21+ adalah fase PMS yang perlu perhatian ekstra.',
    faridShould: 'Dengarkan tanpa langsung memberi solusi. Validasi perasaannya. Bawakan cemilan favoritnya dan minimalkan perdebatan kecil.',
    icon: Icons.cloud,
  ),
];

CyclePhase getPhaseForCycleDay(int cd, int periodDuration) {
  if (cd < periodDuration) return kCyclePhases[0];
  if (cd <= 12) return kCyclePhases[1];
  if (cd <= 16) return kCyclePhases[2];
  return kCyclePhases[3];
}

DateTime getAnchorDateFor(DateTime target, List<dynamic> history) {
  if (history.isEmpty) return DateTime.now();
  List<dynamic> sorted = List.from(history);
  sorted.sort((a, b) => (a['start'] as Timestamp).compareTo(b['start'] as Timestamp));
  DateTime anchor = (sorted.first['start'] as Timestamp).toDate();
  for (var log in sorted) {
    DateTime logStart = (log['start'] as Timestamp).toDate();
    if (logStart.isBefore(target) || isSameDay(logStart, target)) {
      anchor = logStart;
    }
  }
  return anchor;
}

int getDynamicCycleDay(DateTime targetDate, List<dynamic> history, int cycleLen) {
  if (history.isEmpty) return 0;
  DateTime anchor = getAnchorDateFor(targetDate, history);
  final diff = DateTime(targetDate.year, targetDate.month, targetDate.day)
      .difference(DateTime(anchor.year, anchor.month, anchor.day))
      .inDays;
  if (diff < 0) {
    int fallback = diff % cycleLen;
    if (fallback < 0) fallback += cycleLen;
    return fallback;
  }
  return diff % cycleLen;
}

class PeriodTrackerScreen extends StatefulWidget {
  const PeriodTrackerScreen({super.key});

  @override
  State<PeriodTrackerScreen> createState() => _PeriodTrackerScreenState();
}

class _PeriodTrackerScreenState extends State<PeriodTrackerScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Future<void> _updatePeriodData({
    required DateTime start,
    required DateTime end,
    required int cycleLen,
  }) async {
    await FirebaseFirestore.instance.collection('period').doc('aura').set({
      'history': FieldValue.arrayUnion([
        {
          'start': Timestamp.fromDate(start),
          'end': Timestamp.fromDate(end),
        }
      ]),
      'cycleLength': cycleLen,
    }, SetOptions(merge: true));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Riwayat siklus berhasil ditambahkan ✨'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showEditSheet(BuildContext ctx, List<dynamic> history, int currentCycleLen) {
    DateTime tempStart = getAnchorDateFor(DateTime.now(), history);
    DateTime tempEnd = tempStart.add(const Duration(days: 4));
    int tempCycleLen = currentCycleLen;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModal) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tambah/Edit Data Siklus',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, color: Colors.redAccent),
                  title: const Text('Tanggal mulai haid'),
                  subtitle: Text(DateFormat('dd MMMM yyyy').format(tempStart)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: tempStart,
                      firstDate: DateTime(2024, 1, 1),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setModal(() {
                        tempStart = picked;
                        tempEnd = picked.add(const Duration(days: 4));
                      });
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_available, color: Colors.pinkAccent),
                  title: const Text('Tanggal selesai haid'),
                  subtitle: Text(DateFormat('dd MMMM yyyy').format(tempEnd)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: tempEnd,
                      firstDate: tempStart,
                      lastDate: tempStart.add(const Duration(days: 10)),
                    );
                    if (picked != null) {
                      setModal(() => tempEnd = picked);
                    }
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Panjang siklus: $tempCycleLen hari',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Slider(
                  value: tempCycleLen.toDouble(),
                  min: 21,
                  max: 35,
                  divisions: 14,
                  label: '$tempCycleLen hari',
                  activeColor: Colors.redAccent,
                  onChanged: (v) => setModal(() => tempCycleLen = v.round()),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _updatePeriodData(
                        start: tempStart,
                        end: tempEnd,
                        cycleLen: tempCycleLen,
                      );
                    },
                    child: const Text('Simpan'),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _showDayDetail(BuildContext ctx, DateTime day, CyclePhase phase, int cd) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: phase.color.withOpacity(0.95),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(phase.icon, color: phase.textColor, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    phase.name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: phase.textColor,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: phase.textColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Hari ${cd + 1}',
                      style: TextStyle(
                        color: phase.textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                DateFormat('EEEE, dd MMMM yyyy', 'id').format(day),
                style: TextStyle(color: phase.textColor.withOpacity(0.7), fontSize: 13),
              ),
              const SizedBox(height: 16),
              _DetailSection(
                title: 'Apa yang terjadi secara biologis',
                content: phase.bio,
                textColor: phase.textColor,
              ),
              const SizedBox(height: 12),
              _DetailSection(
                title: 'Aura mungkin merasakan',
                content: phase.auraFeels,
                textColor: phase.textColor,
                icon: Icons.favorite_border,
              ),
              const SizedBox(height: 12),
              _DetailSection(
                title: 'Farid sebaiknya',
                content: phase.faridShould,
                textColor: phase.textColor,
                icon: Icons.handshake_outlined,
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Aura's Flo Calendar"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('period').doc('aura').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          List<dynamic> history = [];
          int cycleLen = 28;
          int periodDuration = 5;

          if (snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            cycleLen = data['cycleLength'] ?? 28;
            periodDuration = data['periodDuration'] ?? 5;
            
            if (data.containsKey('history')) {
              history = data['history'];
            } else if (data.containsKey('lastPeriodStart')) {
              history = [
                {
                  'start': data['lastPeriodStart'],
                  'end': data['lastPeriodEnd'] ?? data['lastPeriodStart'],
                }
              ];
            }
          }

          if (history.isEmpty) {
            history = [
              {
                'start': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 10))),
                'end': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 6))),
              }
            ];
          }

          final DateTime today = DateTime.now();
          final int todayCd = getDynamicCycleDay(today, history, cycleLen);
          final CyclePhase todayPhase = getPhaseForCycleDay(todayCd, periodDuration);
          final bool isPMS = todayCd >= 21 && todayCd < cycleLen;
          
          final DateTime anchorToday = getAnchorDateFor(today, history);
          final DateTime nextPeriod = anchorToday.add(Duration(days: cycleLen));

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              if (isPMS)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAEEDA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBA7517)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFBA7517)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Mood Warning: Aura sedang di fase PMS. Sabar ya, Rid! ❤️',
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              _TodayInsightCard(
                phase: todayPhase,
                cycleDay: todayCd,
                nextPeriod: nextPeriod,
              ),
              const SizedBox(height: 16),
              _PhaseLegend(),
              const SizedBox(height: 8),
              TableCalendar(
                firstDay: DateTime.utc(2024, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                  final cd = getDynamicCycleDay(selected, history, cycleLen);
                  final phase = getPhaseForCycleDay(cd, periodDuration);
                  _showDayDetail(context, selected, phase, cd);
                },
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
                calendarStyle: const CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Colors.black12,
                    shape: BoxShape.circle,
                  ),
                ),
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    final cd = getDynamicCycleDay(day, history, cycleLen);
                    final phase = getPhaseForCycleDay(cd, periodDuration);
                    return _buildCalendarDay(day, phase, false);
                  },
                  selectedBuilder: (context, day, focusedDay) {
                    final cd = getDynamicCycleDay(day, history, cycleLen);
                    final phase = getPhaseForCycleDay(cd, periodDuration);
                    return _buildCalendarDay(day, phase, true);
                  },
                  todayBuilder: (context, day, focusedDay) {
                    final cd = getDynamicCycleDay(day, history, cycleLen);
                    final phase = getPhaseForCycleDay(cd, periodDuration);
                    return _buildCalendarDayToday(day, phase);
                  },
                ),
              ),
              const SizedBox(height: 16),
              _UpcomingPhasesCard(
                history: history,
                cycleLen: cycleLen,
                periodDuration: periodDuration,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showEditSheet(context, history, cycleLen),
                icon: const Icon(Icons.edit_calendar),
                label: const Text('Edit Data Siklus'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCalendarDay(DateTime day, CyclePhase phase, bool selected) {
    return Container(
      margin: const EdgeInsets.all(5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: phase.color.withOpacity(selected ? 1.0 : 0.65),
        shape: BoxShape.circle,
        border: selected ? Border.all(color: phase.textColor, width: 2) : null,
      ),
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: phase.textColor,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildCalendarDayToday(DateTime day, CyclePhase phase) {
    return Container(
      margin: const EdgeInsets.all(5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: phase.color,
        shape: BoxShape.circle,
        border: Border.all(color: phase.textColor, width: 2.5),
      ),
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: phase.textColor,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _TodayInsightCard extends StatelessWidget {
  final CyclePhase phase;
  final int cycleDay;
  final DateTime nextPeriod;

  const _TodayInsightCard({
    required this.phase,
    required this.cycleDay,
    required this.nextPeriod,
  });

  @override
  Widget build(BuildContext context) {
    final daysToNext = nextPeriod.difference(DateTime.now()).inDays;

    return Card(
      color: phase.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: phase.textColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(phase.icon, color: phase.textColor),
                const SizedBox(width: 8),
                Text(
                  'Hari ini — ${phase.name}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: phase.textColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: phase.textColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Hari ${cycleDay + 1}',
                    style: TextStyle(
                      color: phase.textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              phase.auraFeels,
              style: TextStyle(color: phase.textColor, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: phase.textColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.handshake_outlined, size: 16, color: phase.textColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      phase.faridShould,
                      style: TextStyle(color: phase.textColor, fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.timelapse, size: 14, color: phase.textColor.withOpacity(0.7)),
                const SizedBox(width: 4),
                Text(
                  daysToNext > 0
                      ? 'Haid berikutnya ~$daysToNext hari lagi'
                      : 'Haid berikutnya sudah dekat!',
                  style: TextStyle(
                    fontSize: 12,
                    color: phase.textColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PhaseLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: kCyclePhases.map((p) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: p.color,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(p.icon, size: 12, color: p.textColor),
              const SizedBox(width: 4),
              Text(
                p.name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: p.textColor,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _UpcomingPhasesCard extends StatelessWidget {
  final List<dynamic> history;
  final int cycleLen;
  final int periodDuration;

  const _UpcomingPhasesCard({
    required this.history,
    required this.cycleLen,
    required this.periodDuration,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayCd = getDynamicCycleDay(today, history, cycleLen);

    final List<Map<String, dynamic>> upcoming = [];
    for (final phase in kCyclePhases) {
      int daysUntil = phase.startDay - todayCd;
      if (daysUntil <= 0) daysUntil += cycleLen;
      final startDate = today.add(Duration(days: daysUntil));
      upcoming.add({'phase': phase, 'date': startDate, 'days': daysUntil});
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fase Mendatang',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ...upcoming.map((item) {
              final CyclePhase p = item['phase'] as CyclePhase;
              final DateTime d = item['date'] as DateTime;
              final int days = item['days'] as int;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: p.color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(p.icon, size: 18, color: p.textColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(
                            DateFormat('EEE, dd MMM').format(d),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: p.color.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$days hari lagi',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: p.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final String content;
  final Color textColor;
  final IconData? icon;

  const _DetailSection({
    required this.title,
    required this.content,
    required this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: textColor.withOpacity(0.7)),
              const SizedBox(width: 4),
            ],
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textColor.withOpacity(0.7),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: TextStyle(fontSize: 14, color: textColor, height: 1.5),
        ),
      ],
    );
  }
}