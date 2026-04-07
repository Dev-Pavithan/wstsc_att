import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../services/api_service.dart';
import '../main.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;

  // Phase 1 — list of dated sessions
  List<Map<String, dynamic>> _historyDates = [];

  // Phase 2 — detail view for a selected date+class
  Map<String, dynamic>? _selectedSession;
  List<Map<String, dynamic>> _detailRecords = [];
  bool _isLoadingDetail = false;
  int _detailPresent = 0;
  int _detailTotal = 0;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadHistory();
    // Listen for global attendance updates or tab switches
    attendanceRefreshNotifier.addListener(_onGlobalRefresh);
    dashboardIndexNotifier.addListener(_onTabSwitch);
  }

  void _onGlobalRefresh() {
    if (mounted) _loadHistory();
  }

  void _onTabSwitch() {
    if (mounted && dashboardIndexNotifier.value == 2) {
      _loadHistory();
    }
  }

  @override
  void dispose() {
    attendanceRefreshNotifier.removeListener(_onGlobalRefresh);
    dashboardIndexNotifier.removeListener(_onTabSwitch);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final response = await _api.get('attendance/history-dates');
      final data = (response['data'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() { _historyDates = data; _isLoading = false; });
      debugPrint('History: Loaded ${_historyDates.length} sessions');
    } catch (e) {
      debugPrint('Error Loading History: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDetail(Map<String, dynamic> session) async {
    setState(() { _selectedSession = session; _isLoadingDetail = true; _detailRecords = []; });
    try {
      final classId = session['class_id'];
      final date = session['mark_date'];
      final response = await _api.get('attendance/class/$classId/date/$date');
      final records = (response['data'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {
        _detailRecords = records;
        _detailPresent = (response['present_count'] as num?)?.toInt() ?? 0;
        _detailTotal = (response['total'] as num?)?.toInt() ?? 0;
        _isLoadingDetail = false;
      });
      debugPrint('History Detail: $classId on $date → $_detailPresent/$_detailTotal present');
    } catch (e) {
      debugPrint('Error Loading Detail: $e');
      setState(() => _isLoadingDetail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _selectedSession == null
          ? _buildHistoryList(isDark)
          : _buildDetailView(isDark),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VIEW 1: History Session List
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHistoryList(bool isDark) {
    final accent = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;
    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Attendance History',
                  style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.5)),
                const SizedBox(height: 6),
                Text('Tap a session to review student records.',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white38 : Colors.black45)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: _historyDates.isEmpty
              ? _emptyState('No attendance records found yet.\nMark attendance in the Dashboard to begin.', isDark)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                  itemCount: _historyDates.length,
                  itemBuilder: (context, i) => TweenAnimationBuilder<double>(
                    duration: Duration(milliseconds: 400 + (i * 100)),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    ),
                    child: _sessionCard(_historyDates[i], isDark),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _sessionCard(Map<String, dynamic> session, bool isDark) {
    final accent = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;
    final date = session['mark_date'] ?? '';
    final className = session['class_name'] ?? 'Unknown Class';
    final present = (session['present_count'] as num?)?.toInt() ?? 0;
    final total = (session['total_students'] as num?)?.toInt() ?? 0;
    final pct = (session['percentage'] as num?)?.toDouble() ?? 0.0;

    DateTime? parsedDate;
    try { parsedDate = DateTime.parse(date); } catch (_) {}
    final displayDate = parsedDate != null
        ? DateFormat('EEE, d MMM yyyy').format(parsedDate) : date;
    final dayNum = parsedDate != null ? DateFormat('d').format(parsedDate) : '';
    final monthStr = parsedDate != null ? DateFormat('MMM').format(parsedDate).toUpperCase() : '';

    final pctColor = pct >= 80 ? Colors.green : (pct >= 60 ? Colors.orange : Colors.red);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _loadDetail(session),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: isDark ? Border.all(color: Colors.white.withOpacity(0.05)) : Border.all(color: Colors.grey.shade100),
              boxShadow: [
                if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              children: [
                // Premium Date badge
                Container(
                  width: 58, height: 58,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [accent, accent.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: accent.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(dayNum, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                      Text(monthStr, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 0.5)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(className,
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(LucideIcons.clock, size: 12, color: isDark ? Colors.white24 : Colors.black26),
                          const SizedBox(width: 4),
                          Text(displayDate,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white38 : Colors.black45)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$present/$total',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: pctColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10)),
                      child: Text('${pct.toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800,
                          color: pctColor)),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Icon(LucideIcons.chevronRight, size: 18, color: isDark ? Colors.white12 : Colors.grey.shade300),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VIEW 2: Detail View for a Session
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDetailView(bool isDark) {
    final session = _selectedSession!;
    final accent = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;
    final date = session['mark_date'] ?? '';
    final className = session['class_name'] ?? '';
    DateTime? parsedDate;
    try { parsedDate = DateTime.parse(date); } catch (_) {}
    final displayDate = parsedDate != null
        ? DateFormat('EEEE, d MMMM yyyy').format(parsedDate) : date;

    final filtered = _detailRecords.where((r) {
      final name = (r['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        // Premium Back header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface.withOpacity(0.5) : Colors.white.withOpacity(0.5),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() { _selectedSession = null; _searchQuery = ''; _searchController.clear(); }),
                    icon: Icon(LucideIcons.arrowLeft, color: isDark ? Colors.white : Colors.black87),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(className,
                          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.5)),
                        Text(displayDate,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white38 : Colors.black45)),
                      ],
                    ),
                  ),
                ],
              ),
              if (!_isLoadingDetail) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _detailStatPill('Present', '$_detailPresent', Colors.green, LucideIcons.checkCircle2, isDark)),
                    const SizedBox(width: 12),
                    Expanded(child: _detailStatPill('Absent', '${_detailTotal - _detailPresent}', Colors.red, LucideIcons.xCircle, isDark)),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Search bar
        if (!_isLoadingDetail && _detailRecords.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search student names...',
                hintStyle: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white24 : Colors.black26),
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                filled: true,
                fillColor: isDark ? AppTheme.darkSurface : Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: accent.withOpacity(0.5))),
              ),
            ),
          ),

        // List
        Expanded(
          child: _isLoadingDetail
            ? const Center(child: CircularProgressIndicator())
            : filtered.isEmpty
              ? _emptyState('Search returned no results.', isDark)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _recordTile(filtered[i], isDark),
                ),
        ),
      ],
    );
  }

  Widget _detailStatPill(String label, String value, Color color, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(width: 6),
          Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: color.withOpacity(0.7))),
        ],
      ),
    );
  }

  Widget _recordTile(Map<String, dynamic> r, bool isDark) {
    final accent = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;
    final isPresent = r['is_present'] == true || r['is_present'] == 1;
    final name = r['name'] ?? '${r['student_first__name'] ?? ''} ${r['student_family_name'] ?? ''}'.trim();
    final studId = r['studid'] ?? '';
    final statusColor = isPresent ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: isDark ? Border.all(color: Colors.white.withOpacity(0.05)) : Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15)),
            child: Center(
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: accent)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 2),
                Text(studId, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white24 : Colors.black26)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)),
            child: Text(isPresent ? 'PRESENT' : 'ABSENT',
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 0.5)),
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
          Icon(LucideIcons.clipboardSignature, size: 64, color: isDark ? Colors.white12 : Colors.black12),
          const SizedBox(height: 20),
          Text(message, textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: isDark ? Colors.white24 : Colors.black26)),
        ],
      ),
    ),
  );
}
