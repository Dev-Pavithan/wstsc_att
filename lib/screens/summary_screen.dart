import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_theme.dart';
import '../services/api_service.dart';
import '../main.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;

  int _totalStudents = 0;
  int _activeClasses = 0;
  double _avgPercentage = 0;
  List<Map<String, dynamic>> _classBreakdown = [];
  List<Map<String, dynamic>> _topStudents = [];

  @override
  void initState() {
    super.initState();
    _loadSummary();
    // Listen for global attendance updates or tab switches
    attendanceRefreshNotifier.addListener(_onGlobalRefresh);
    dashboardIndexNotifier.addListener(_onTabSwitch);
    globalRefreshNotifier.addListener(_onGlobalRefresh);
  }

  void _onGlobalRefresh() {
    if (mounted) _loadSummary();
  }

  void _onTabSwitch() {
    if (mounted && dashboardIndexNotifier.value == 3) {
      _loadSummary();
    }
  }

  @override
  void dispose() {
    attendanceRefreshNotifier.removeListener(_onGlobalRefresh);
    dashboardIndexNotifier.removeListener(_onTabSwitch);
    globalRefreshNotifier.removeListener(_onGlobalRefresh);
    super.dispose();
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoading = true);
    try {
      final response = await _api.get('attendance/class/all/stats');
      final data = response['data'] as Map<String, dynamic>;

      final breakdown = (data['class_breakdown'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final top = (data['top_students'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      setState(() {
        _totalStudents = (data['total_students'] as num?)?.toInt() ?? 0;
        _activeClasses = (data['active_classes_count'] as num?)?.toInt() ?? 0;
        _avgPercentage = (data['average_percentage'] as num?)?.toDouble() ?? 0;
        _classBreakdown = breakdown;
        _topStudents = top;
        _isLoading = false;
      });
      debugPrint('Summary: avg=$_avgPercentage% students=$_totalStudents classes=$_activeClasses');
    } catch (e) {
      debugPrint('Error Loading Summary: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadSummary,
            displacement: 40,
            color: accent,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Premium Header ---
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Performance Summary',
                          style: GoogleFonts.outfit(
                            fontSize: 32, 
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: -0.5,
                          )),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, 
                                boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.5), blurRadius: 4, spreadRadius: 1)]),
                            ),
                            const SizedBox(width: 8),
                            Text('Live attendance insights',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white38 : Colors.black45)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Top 3 Animated Stats ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(child: _statCard('Average',
                          '${_avgPercentage.toStringAsFixed(1)}%',
                          LucideIcons.trendingUp, [accent, accent.withOpacity(0.7)], isDark)),
                        const SizedBox(width: 10),
                        Expanded(child: _statCard('Students',
                          '$_totalStudents',
                          LucideIcons.users, [const Color(0xFF6366F1), const Color(0xFF818CF8)], isDark)),
                        const SizedBox(width: 10),
                        Expanded(child: _statCard('Classes',
                          '$_activeClasses',
                          LucideIcons.bookOpen, [const Color(0xFFF59E0B), const Color(0xFFFBBF24)], isDark)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Overall Hero Card with Animated Progress ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark 
                            ? [AppTheme.darkSurface, AppTheme.darkSurface.withOpacity(0.8)]
                            : [Colors.white, Colors.white.withOpacity(0.9)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
                        ],
                        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Row(
                          children: [
                            TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 1500),
                              tween: Tween(begin: 0, end: _avgPercentage / 100),
                              curve: Curves.easeOutCirc,
                              builder: (context, value, _) => SizedBox(
                                width: 90, height: 90,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      value: value,
                                      strokeWidth: 12,
                                      backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                                      color: accent,
                                      strokeCap: StrokeCap.round,
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('${(value * 100).toStringAsFixed(0)}%',
                                          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800,
                                            color: isDark ? Colors.white : Colors.black87)),
                                        Text('RATE', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.black38)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Overall Performance',
                                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87)),
                                  const SizedBox(height: 6),
                                  Text('Based on $_activeClasses classes and $_totalStudents students.',
                                    style: GoogleFonts.inter(fontSize: 13, height: 1.4,
                                      color: isDark ? Colors.white54 : Colors.black54)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- Class Breakdown Section ---
                  if (_classBreakdown.isNotEmpty) ...[
                    _sectionHeader('Class Breakdown', isDark),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: isDark ? Border.all(color: Colors.white.withOpacity(0.05)) : Border.all(color: Colors.grey.shade100),
                        ),
                        child: Column(
                          children: [
                            for (int i = 0; i < _classBreakdown.length; i++) ...[
                              _classRow(_classBreakdown[i], isDark, accent),
                              if (i < _classBreakdown.length - 1)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Divider(height: 1, color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // --- Top Students Section ---
                  if (_topStudents.isNotEmpty) ...[
                    _sectionHeader('Top Performers', isDark),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _topStudents.length,
                      itemBuilder: (context, i) => _topStudentTile(i + 1, _topStudents[i], isDark, accent),
                    ),
                  ] else
                    _emptyState('No attendance data available.', isDark),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
    );
  }

  Widget _sectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87)),
          Icon(LucideIcons.chevronRight, size: 18, color: isDark ? Colors.white24 : Colors.black26),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, List<Color> gradient, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isDark ? Border.all(color: Colors.white.withOpacity(0.05)) : Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 18)),
          const SizedBox(height: 16),
          Text(value,
            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 2),
          Text(label.toUpperCase(),
            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5,
              color: isDark ? Colors.white38 : Colors.black38)),
        ],
      ),
    );
  }

  Widget _classRow(Map<String, dynamic> cls, bool isDark, Color accent) {
    final name = cls['class_name'] ?? 'Unknown';
    final rate = (cls['attendance_rate'] as num?)?.toDouble() ?? 0.0;
    final present = (cls['present_count'] as num?)?.toInt() ?? 0;
    final total = (cls['total_records'] as num?)?.toInt() ?? 0;
    final color = rate >= 80 ? Colors.green : (rate >= 60 ? Colors.orange : Colors.red);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(name,
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
              child: Text('${rate.toStringAsFixed(1)}%',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Stack(
          children: [
            Container(
              height: 8, width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(4)),
            ),
            TweenAnimationBuilder<double>(
              duration: const Duration(seconds: 1),
              tween: Tween(begin: 0, end: rate / 100),
              builder: (context, value, _) => FractionallySizedBox(
                widthFactor: value,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color, color.withOpacity(0.6)]),
                    borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('$present sessions marked successfully',
          style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
      ],
    );
  }

  Widget _topStudentTile(int rank, Map<String, dynamic> student, bool isDark, Color accent) {
    final name = student['name'] ?? 'Unknown';
    final rate = (student['attendance_rate'] as num?)?.toDouble() ?? 0.0;
    final present = (student['present_days'] as num?)?.toInt() ?? 0;
    final total = (student['total_days'] as num?)?.toInt() ?? 0;
    
    Color rankColor = rank == 1 ? Colors.amber : (rank == 2 ? const Color(0xFF94A3B8) : const Color(0xFFB45309));
    IconData rankIcon = rank == 1 ? LucideIcons.trophy : (rank == 2 ? LucideIcons.medal : LucideIcons.award);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isDark ? Border.all(color: Colors.white.withOpacity(0.05)) : Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: rankColor.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
            child: Icon(rankIcon, color: rankColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 2),
                Text('$present / $total Days', style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white38 : Colors.black45)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${rate.toStringAsFixed(0)}%', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: rate >= 90 ? Colors.green : Colors.orange)),
              Text('SCORE', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: isDark ? Colors.white24 : Colors.black26)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String message, bool isDark) => Center(
    child: Padding(
      padding: const EdgeInsets.all(60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.barChart3, size: 64, color: isDark ? Colors.white12 : Colors.black12),
          const SizedBox(height: 20),
          Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 15, color: isDark ? Colors.white24 : Colors.black26)),
        ],
      ),
    ),
  );
}
