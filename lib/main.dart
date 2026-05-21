import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Import Screen & Service
import 'firebase_options.dart';
import 'services/background_service.dart';
import 'ui/screens/add_plan_screen.dart'; 
import 'ui/screens/conflict_screen.dart';
import 'ui/screens/period_tracker.dart';
import 'ui/screens/plan_calendar_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  if (!kIsWeb) {
    await initializeService(); 
  }
  
  runApp(const FASpaceApp());
}

class FASpaceApp extends StatelessWidget {
  const FASpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FA Space',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF48FB1),
          brightness: Brightness.light,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentStreak = 0;
  bool _isLoadingStreak = true;

  // Variabel animasi maps
  final MapController _mapController = MapController();
  ll.LatLng? _animatedPos;
  AnimationController? _movementController;
  Tween<double>? _latTween;
  Tween<double>? _lngTween;

  @override
  void initState() {
    super.initState();
    _refreshMoodStreak();
  }

  @override
  void dispose() {
    _movementController?.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // FIX: Mengoptimalkan pergerakan animasi marker agar tidak berbenturan dengan render peta
  void _animateMarkerAndMap(double targetLat, double targetLng) {
    if (_animatedPos == null) {
      setState(() {
        _animatedPos = ll.LatLng(targetLat, targetLng);
      });
      return;
    }

    _movementController?.dispose();
    _movementController = AnimationController(
      duration: const Duration(milliseconds: 1200), // Sedikit diperlambat agar transisi transparan & smooth
      vsync: this,
    );

    _latTween = Tween<double>(begin: _animatedPos!.latitude, end: targetLat);
    _lngTween = Tween<double>(begin: _animatedPos!.longitude, end: targetLng);

    Animation<double> animation = CurvedAnimation(
      parent: _movementController!,
      curve: Curves.easeInOutQuad, // Mengganti ke Quad untuk pergerakan interpolasi yang lebih stabil
    );

    _movementController!.addListener(() {
      if (_latTween != null && _lngTween != null) {
        setState(() {
          _animatedPos = ll.LatLng(_latTween!.evaluate(animation), _lngTween!.evaluate(animation));
        });
      }
    });

    // Geser kamera peta secara smooth sekali saja di awal koordinat baru masuk, tidak mengunci di listener
    _mapController.move(ll.LatLng(targetLat, targetLng), _mapController.camera.zoom);

    _movementController!.forward();
  }

  Future<void> _refreshMoodStreak() async {
    setState(() => _isLoadingStreak = true);
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('moods')
          .orderBy('timestamp', descending: true)
          .limit(30)
          .get();

      int streak = 0;
      DateTime? lastDate;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (!data.containsKey('label') || data['timestamp'] == null) continue;
        
        String mood = data['label'] ?? '';
        DateTime currentDate = (data['timestamp'] as Timestamp).toDate();
        DateTime normalizedCurrent = DateTime(currentDate.year, currentDate.month, currentDate.day);

        if (mood.toLowerCase() == 'happy') {
          if (lastDate == null) {
            streak = 1;
            lastDate = normalizedCurrent;
          } else {
            int diff = lastDate.difference(normalizedCurrent).inDays;
            if (diff == 1) {
              streak++;
              lastDate = normalizedCurrent;
            } else if (diff == 0) {
              continue; 
            } else {
              break; 
            }
          }
        } else {
          if (streak > 0) break;
        }
      }
      setState(() {
        _currentStreak = streak;
        _isLoadingStreak = false;
      });
    } catch (e) {
      debugPrint("Gagal mengambil streak: $e");
      setState(() => _isLoadingStreak = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FA Space', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddPlanScreen()),
            ).then((_) => setState(() {})),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // Memantau document koordinat & status user secara live stream
        stream: FirebaseFirestore.instance.collection('status').doc('farid').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final statusData = snapshot.data!.data() as Map<String, dynamic>?;

          int battery = statusData?['battery'] ?? 0;
          bool isCharging = statusData?['isCharging'] ?? false;
          String photoUrl = statusData?['photoUrl'] ?? ''; // 🔥 Ambil data photoUrl dari database

          double? rawLat = (statusData != null && statusData.containsKey('lat')) 
              ? double.tryParse(statusData['lat'].toString()) : null;
          double? rawLng = (statusData != null && statusData.containsKey('lng')) 
              ? double.tryParse(statusData['lng'].toString()) : null;

          if (rawLat != null && rawLng != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_animatedPos == null || 
                  _latTween?.end != rawLat || 
                  _lngTween?.end != rawLng) {
                _animateMarkerAndMap(rawLat, rawLng);
              }
            });
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // --- SECTION 1: ANNIVERSARY & STREAK ---
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text("Days Since We Started ❤️", style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 5),
                      Text(
                        "${DateTime.now().difference(DateTime(2026, 3, 26)).inDays} Days", 
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      
                      if (!_isLoadingStreak && _currentStreak > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text("🔥", style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 4),
                              Text(
                                "$_currentStreak Days Happy Streak!",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- SECTION 2: STATUS DEVICE ---
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Farid's Phone", style: TextStyle(fontSize: 14, color: Colors.grey)),
                          const SizedBox(height: 5),
                          Text(
                            isCharging ? "⚡ Charging..." : "🔋 On Battery",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ],
                      ),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: battery / 100,
                            color: battery < 20 ? Colors.red : Colors.green,
                            strokeWidth: 6,
                          ),
                          Text("$battery%", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- SECTION 3: MAPS (SMOOTH AVATAR MOVEMENT + LIVE PHOTO) ---
              const Text("Where is Farid?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                height: 350,
                clipBehavior: Clip.antiAlias, 
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: (_animatedPos != null)
                    ? FlutterMap(
                        mapController: _mapController, 
                        options: MapOptions(
                          initialCenter: _animatedPos!, 
                          initialZoom: 16,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.farid.fa_space',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _animatedPos!,
                                width: 75,
                                height: 75,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Efek bayangan pink melingkar di bawah avatar marker
                                    Container(
                                      width: 68,
                                      height: 68,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.pinkAccent.withOpacity(0.25),
                                      ),
                                    ),
                                    // Bingkai avatar warna putih solid + pink accent
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        radius: 26,
                                        backgroundColor: Colors.pink.shade100,
                                        // FIX: Menampilkan gambar dinamis dari Cloud URL jika tersedia, fallback ke Aset Lokal jika kosong
                                        backgroundImage: photoUrl.isNotEmpty
                                            ? NetworkImage(photoUrl) as ImageProvider
                                            : const AssetImage('assets/images/farid_profile.png'),
                                      ),
                                    ),
                                    // Pin indikator arah lokasi di paling bawah marker
                                    Positioned(
                                      bottom: 0,
                                      child: Icon(
                                        Icons.arrow_drop_down, 
                                        color: Colors.pinkAccent.shade400, 
                                        size: 26
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Container(
                        color: Colors.grey.shade200,
                        child: const Center(child: Text("Waiting for location...")),
                      ),
              ),
              const SizedBox(height: 24),

              // --- SECTION 4: MOOD TRACKER ---
              const Text("How's Our Vibe Today?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _moodButton(context, "😊", "Happy"),
                  _moodButton(context, "🥺", "Miss You"),
                  _moodButton(context, "😡", "Mad"),
                  _moodButton(context, "😴", "Flat"),
                ],
              ),
              const SizedBox(height: 24),

              // --- SECTION 5: PERIOD TRACKER ---
              Card(
                color: Colors.redAccent.withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: const Icon(Icons.calendar_month, color: Colors.redAccent),
                  title: const Text("Aura's Flo Calendar", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text("Tap to see cycle prediction"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => const PeriodTrackerScreen())
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // --- SECTION 6: MONTHLY PLANS ---
              const Text("Coming Soon Plans 📅", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('plans')
                    .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
                    .orderBy('date', descending: false)
                    .limit(3)
                    .snapshots(),
                builder: (context, planSnapshot) {
                  if (planSnapshot.hasError) {
                    return const Text(
                      "Gagal memuat rencana. Pastikan Index Firestore sudah dibuat.", 
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    );
                  }
                  if (!planSnapshot.hasData) return const LinearProgressIndicator();
                  
                  var plans = planSnapshot.data!.docs;
                  if (plans.isEmpty) return const Text("No upcoming plans yet.", style: TextStyle(color: Colors.grey));

                  return Column(
                    children: plans.map((doc) {
                      final planData = doc.data() as Map<String, dynamic>?;
                      if (planData == null || planData['date'] == null) return const SizedBox.shrink();

                      DateTime date = (planData['date'] as Timestamp).toDate();
                      String title = planData['title'] ?? 'No Title';
                      bool isWithAura = planData['type'] == 'with_aura';

                      return Card(
                        color: isWithAura ? Colors.pink.shade50 : Colors.white,
                        child: ListTile(
                          leading: Icon(
                            isWithAura ? Icons.favorite : Icons.event, 
                            color: isWithAura ? Colors.pink : Colors.pinkAccent
                          ),
                          title: Text(
                            title, 
                            style: TextStyle(fontWeight: isWithAura ? FontWeight.bold : FontWeight.normal)
                          ),
                          subtitle: Text(DateFormat('EEEE, dd MMMM').format(date)),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const PlanCalendarView()),
                            );
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.check_circle_outline),
                            onPressed: () => doc.reference.delete(),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),

              // --- SECTION 7: CONFLICT RESOLUTION ---
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (context) => const ConflictScreen())
                ),
                icon: const Icon(Icons.psychology),
                label: const Text("Conflict Resolution (AI)"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _moodButton(BuildContext context, String emoji, String label) {
    return InkWell(
      onTap: () async {
        await FirebaseFirestore.instance.collection('moods').add({
          'emoji': emoji,
          'label': label,
          'timestamp': FieldValue.serverTimestamp(),
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Mood $label sent!")));
        }
        _refreshMoodStreak(); 
      },
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 30)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

Widget _avatarErrorBuilder(BuildContext context, Object error, StackTrace? stackTrace) {
  return Container(
    color: Colors.pink.shade100,
    child: const Icon(Icons.person, size: 40, color: Colors.pink),
  );
}