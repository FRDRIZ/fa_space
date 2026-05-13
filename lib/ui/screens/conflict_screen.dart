import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/gemini_service.dart';

class ConflictScreen extends StatefulWidget {
  const ConflictScreen({
    super.key,
  });

  @override
  State<ConflictScreen> createState() => _ConflictScreenState();
}

class _ConflictScreenState extends State<ConflictScreen>
    with TickerProviderStateMixin {
  final TextEditingController _problemController = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = false;
  Map<String, dynamic>? _resolution;
  String? _error;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  static const Color _rose = Color(0xFFF4A7B9);
  static const Color _roseDark = Color(0xFFE07A95);
  static const Color _roseLight = Color(0xFFFFF0F3);
  static const Color _roseSurface = Color(0xFFFAE8ED);
  static const Color _text = Color(0xFF2D1B22);
  static const Color _textMuted = Color(0xFF9B7280);
  static const Color _textLight = Color(0xFFBFA0A8);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _green = Color(0xFF10B981);
  static const Color _purple = Color(0xFF8B5CF6);

  static const List<String> _quotes = [
    '"Communication is not optional, it\'s everything."',
    '"Say what you mean before silence says it for you."',
    '"Being understood is a love language too."',
    '"Don\'t let your ego outlast the relationship."',
    '"Miscommunication is the villain in most love stories."',
    '"Speak up. Silence isn\'t always peace."',
    '"Feelings aren\'t facts, but they still deserve to be heard."',
  ];

  late String _currentQuote;
  String _userPov = 'Aura';
  String _partnerPov = 'Farid';

  void _detectPov(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('aura') && !lower.contains('farid')) {
      _userPov = 'Farid';
      _partnerPov = 'Aura';
    } else {
      _userPov = 'Aura';
      _partnerPov = 'Farid';
    }
  }

  @override
  void initState() {
    super.initState();
    final shuffled = List<String>.from(_quotes)..shuffle();
    _currentQuote = shuffled.first;
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _problemController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _getHelp() async {
    if (_problemController.text.trim().isEmpty) return;
    _focusNode.unfocus();

    _detectPov(_problemController.text.trim());

    setState(() {
      _isLoading = true;
      _resolution = null;
      _error = null;
    });

    _fadeController.reset();
    _slideController.reset();

    try {
      final result = await _geminiService.analyzeConflict(
        description: _problemController.text.trim(),
        mood: 'neutral',
        daysTogether: 0,
        userPov: _userPov,
        partnerPov: _partnerPov,
      );
      setState(() {
        _resolution = result;
        _isLoading = false;
      });
      _fadeController.forward();
      _slideController.forward();
      await Future.delayed(const Duration(milliseconds: 200));
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    } catch (e) {
      setState(() {
        _error = 'Waduh, ada yang error nih. Coba lagi ya 🙏';
        _isLoading = false;
      });
    }
  }

  void _reset() {
    final shuffled = List<String>.from(_quotes)..shuffle();
    setState(() {
      _resolution = null;
      _error = null;
      _currentQuote = shuffled.first;
    });
    _problemController.clear();
    _fadeController.reset();
    _slideController.reset();
  }

  void _copyMessage(String message) {
    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Kalimat disalin! Tinggal kirim deh 💌'),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: _roseDark,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _roseLight,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildInputCard(),
                  if (_isLoading) ...[
                    const SizedBox(height: 32),
                    _buildLoadingState(),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 20),
                    _buildErrorCard(),
                  ],
                  if (_resolution != null) ...[
                    const SizedBox(height: 32),
                    _buildResultSection(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      backgroundColor: _roseLight,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        color: _text,
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _roseSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _rose.withOpacity(0.4)),
            ),
            child: const Center(
              child: Text('🕊️', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'FA Mediator (AI)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _text,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
      actions: [
        if (_resolution != null)
          TextButton(
            onPressed: _reset,
            child: const Text(
              'Reset',
              style: TextStyle(
                fontSize: 13,
                color: _roseDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          _currentQuote,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _text,
            height: 1.3,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInputCard() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _rose.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: _rose.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _problemController,
            focusNode: _focusNode,
            maxLines: 5,
            minLines: 4,
            style: const TextStyle(
              fontSize: 15,
              color: _text,
              height: 1.6,
            ),
            decoration: const InputDecoration(
              hintText:
                  'Ceritain masalahnya di sini...\n\nContoh: "Farid tiba-tiba ngejauh dan ga balas chat gue dari kemarin."',
              hintStyle: TextStyle(
                fontSize: 14,
                color: _textLight,
                height: 1.6,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.fromLTRB(16, 14, 16, 8),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _problemController,
              builder: (context, value, _) {
                final hasText = value.text.trim().isNotEmpty;
                return AnimatedOpacity(
                  opacity: hasText ? 1 : 0.4,
                  duration: const Duration(milliseconds: 200),
                  child: GestureDetector(
                    onTap: hasText && !_isLoading ? _getHelp : null,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: hasText ? _roseDark : _rose,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isLoading)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          else
                            const Icon(Icons.auto_awesome_rounded,
                                color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            _isLoading
                                ? 'Lagi dianalisis...'
                                : 'Analisis Konflik',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        _LoadingShimmer(color: _roseSurface),
        const SizedBox(height: 12),
        _LoadingShimmer(color: _roseSurface, height: 80),
        const SizedBox(height: 12),
        _LoadingShimmer(color: _roseSurface, height: 60),
      ],
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDA4AF)),
      ),
      child: Row(
        children: [
          const Text('😔', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF9F1239)),
            ),
          ),
          TextButton(
            onPressed: _getHelp,
            child: const Text(
              'Coba lagi',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFFBE123C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSection() {
    final r = _resolution!;
    final label = r['label'] ?? 'other';
    final labelEmoji = r['label_emoji'] ?? '💬';
    final rootCause = r['root_cause'] ?? '';
    final perspectiveUser = r['perspective_user'] ?? '';
    final perspectivePartner = r['perspective_partner'] ?? '';
    final suggestedMessage = r['suggested_message'] ?? '';
    final whatToAvoid = r['what_to_avoid'] ?? '';
    final nextStep = r['next_step'] ?? '';

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _roseSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _rose.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(labelEmoji,
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        _capitalizeLabel(label),
                        style: const TextStyle(
                          fontSize: 13,
                          color: _roseDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Terdeteksi',
                  style: TextStyle(fontSize: 13, color: _textMuted),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              icon: Icons.lightbulb_outline_rounded,
              iconColor: _amber,
              title: 'Akar masalah',
              content: rootCause,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildPerspectiveCard(
                    emoji: '🫵',
                    title: 'Perspektif $_userPov',
                    content: perspectiveUser,
                    color: const Color(0xFFEFF6FF),
                    borderColor: const Color(0xFFBFDBFE),
                    textColor: const Color(0xFF1E40AF),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildPerspectiveCard(
                    emoji: '💜',
                    title: 'Perspektif $_partnerPov',
                    content: perspectivePartner,
                    color: const Color(0xFFF5F3FF),
                    borderColor: const Color(0xFFDDD6FE),
                    textColor: _purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildMessageCard(suggestedMessage),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildSectionCard(
                    icon: Icons.block_rounded,
                    iconColor: const Color(0xFFEF4444),
                    title: 'Hindari ini',
                    content: whatToAvoid,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSectionCard(
                    icon: Icons.arrow_forward_rounded,
                    iconColor: _green,
                    title: 'Langkah selanjutnya',
                    content: nextStep,
                    compact: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: GestureDetector(
                onTap: _reset,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _rose.withOpacity(0.4)),
                  ),
                  child: const Text(
                    '↩ Coba konflik lain',
                    style: TextStyle(
                      fontSize: 13,
                      color: _roseDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _rose.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: _rose.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _textMuted,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: compact ? 13 : 14,
              color: _text,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerspectiveCard({
    required String emoji,
    required String title,
    required String content,
    required Color color,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
                fontSize: 13, color: _text, height: 1.55),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(String message) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _roseDark.withOpacity(0.95),
            _rose.withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _roseDark.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.send_rounded,
                    size: 14, color: Colors.white70),
                const SizedBox(width: 6),
                const Text(
                  'Kalimat yang bisa lo kirim',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _copyMessage(message),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded,
                            size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Salin',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '"$message"',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  height: 1.6,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _copyMessage(message),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.copy_rounded, size: 14, color: _roseDark),
                    SizedBox(width: 6),
                    Text(
                      'Salin kalimat ini',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _roseDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _capitalizeLabel(String label) {
    if (label.isEmpty) return label;
    return label[0].toUpperCase() + label.substring(1);
  }
}

class _LoadingShimmer extends StatefulWidget {
  final Color color;
  final double height;

  const _LoadingShimmer({required this.color, this.height = 100});

  @override
  State<_LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<_LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(
            widget.color,
            widget.color.withOpacity(0.4),
            _anim.value,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}