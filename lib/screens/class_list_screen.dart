import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../main.dart';
import '../mock_data.dart';
import '../services/api_service.dart';

class ClassListScreen extends StatefulWidget {
  const ClassListScreen({super.key});

  @override
  State<ClassListScreen> createState() => _ClassListScreenState();
}

class _ClassListScreenState extends State<ClassListScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  final ApiService _api = ApiService();
  bool _isLoading = true;
  bool _isSaving = false;

  // Phase 1 state — classroom list
  List<ClassRoom> _classes = [];
  List<String> _serverMarkedClassIds = [];
  String _teacherName = 'Teacher';
  int _totalStudents = 0;

  // Phase 2 state — student attendance in selected class
  ClassRoom? _selectedClass;
  List<Student> _students = [];
  bool _attendanceAlreadyMarked = false;

  final String _todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _loadDashboard();
    // Listen for global attendance updates or tab switches
    attendanceRefreshNotifier.addListener(_onGlobalRefresh);
    dashboardIndexNotifier.addListener(_onTabSwitch);
    globalRefreshNotifier.addListener(_onGlobalRefresh);
  }

  void _onGlobalRefresh() {
    if (mounted) _loadDashboard();
  }

  void _onTabSwitch() {
    // When returning to dashboard (index 0), refresh to update 'Done' badges & stats
    if (mounted && dashboardIndexNotifier.value == 0) {
      _loadDashboard();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    attendanceRefreshNotifier.removeListener(_onGlobalRefresh);
    dashboardIndexNotifier.removeListener(_onTabSwitch);
    globalRefreshNotifier.removeListener(_onGlobalRefresh);
    super.dispose();
  }

  // ─── Load Teachers Name + Active Classrooms ─────────────────────────────────
  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('user_name') ?? 'Teacher';
      setState(() => _teacherName = savedName.split(' ').first);

      final classroomsResponse = await _api.get('classrooms/active');
      final classroomsData = classroomsResponse['data']['classrooms'] as List;
      final statsResponse = await _api.get('attendance/class/all/stats');

      setState(() {
        _classes = classroomsData.map((c) => ClassRoom.fromJson(c)).toList();
        _totalStudents = (statsResponse['data']['total_students'] as num?)?.toInt() ?? 0;
        _serverMarkedClassIds = (statsResponse['data']['marked_today'] as List?)?.map((id) => id.toString()).toList() ?? [];
        _isLoading = false;
      });
      debugPrint('Dashboard: Loaded ${_classes.length} classes, $_totalStudents total students');
    } catch (e) {
      debugPrint('Error Loading Dashboard: $e');
      setState(() => _isLoading = false);
    }
  }

  // ─── Load Students for Selected Classroom ───────────────────────────────────
  Future<void> _selectClass(ClassRoom classRoom) async {
    setState(() { _selectedClass = classRoom; _isLoading = true; _attendanceAlreadyMarked = false; });
    try {
      // Check if attendance already saved today
      final prefs = await SharedPreferences.getInstance();
      final savedDate = prefs.getString('attendance_marked_${classRoom.id}');
      final alreadyMarked = savedDate == _todayKey;

      final response = await _api.get('attendance/class/${classRoom.id}/active-students');
      final data = response['data'] as List;
      final serverMarked = response['attendance_already_marked'] == true;

      setState(() {
        _students = data.map((s) => Student.fromJson(s)).toList();
        _attendanceAlreadyMarked = alreadyMarked || serverMarked;
        _isLoading = false;
      });
      debugPrint('Students: Loaded ${_students.length} students for ${classRoom.id} | MarkedToday=$alreadyMarked');
    } catch (e) {
      debugPrint('Error Loading Students: $e');
      setState(() => _isLoading = false);
    }
  }

  // ─── Save Bulk Attendance ────────────────────────────────────────────────────
  Future<void> _saveAttendance() async {
    if (_selectedClass == null || _students.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final attendanceData = _students.map((s) => {
        'studid': s.siid,          // Use integer siid, NOT the string "STU..."
        'is_present': s.isPresent,
      }).toList();

      final response = await _api.post('attendance/mark-bulk', {
        'class_id': _selectedClass!.id,
        'mark_date': _todayKey,
        'attendance_data': attendanceData,
      });

      debugPrint('Attendance API: ${response['message']}');

      if (response['status'] == true) {
        // Persist that today's attendance is done for this class
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('attendance_marked_${_selectedClass!.id}', _todayKey);

        setState(() => _attendanceAlreadyMarked = true);
        attendanceRefreshNotifier.value++; // Trigger global refresh for other screens
        _showSnack('Attendance saved successfully!', isError: false);
      } else {
        _showSnack(response['message'] ?? 'Failed to save', isError: true);
      }
    } catch (e) {
      debugPrint('Error Saving Attendance: $e');
      _showSnack('Error: $e', isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF1E1B4B),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ─── Back to Class List ──────────────────────────────────────────────────────
  void _goBack() {
    setState(() { _selectedClass = null; _students = []; _attendanceAlreadyMarked = false; });
    _loadDashboard();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedClass == null
            ? _buildClassList(isDark)
            : _buildStudentAttendance(isDark),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VIEW 1: Class Selection
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildClassList(bool isDark) {
    final today = DateFormat('EEEE, d MMMM').format(DateTime.now());
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Greeting
          ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: profileNotifier,
            builder: (context, profile, _) {
              final String displayName = profile != null 
                ? (profile['first_name'] ?? profile['full_name']?.split(' ').first ?? _teacherName)
                : _teacherName;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hello, $displayName 👋',
                    style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87)),
                  Text(today, style: GoogleFonts.inter(fontSize: 14,
                    color: isDark ? Colors.white38 : Colors.black45)),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Stats strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                (isDark ? AppTheme.darkAccent : AppTheme.lightAccent).withOpacity(0.35),
                isDark ? AppTheme.darkBg : Colors.white,
              ]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: (isDark ? AppTheme.darkAccent : AppTheme.lightAccent).withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statChip('${_classes.length}', 'Classes', isDark),
                _divider(isDark),
                _statChip('$_totalStudents', 'Students', isDark),
                _divider(isDark),
                _statChip(DateFormat('d MMM').format(DateTime.now()), 'Today', isDark),
              ],
            ),
          ),

          const SizedBox(height: 28),

          Text('Select a Class to Mark Attendance',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black87)),
          const SizedBox(height: 12),

          // Class cards
          if (_classes.isEmpty)
            _emptyState('No active classrooms found.\nContact your admin.', isDark)
          else
            ..._classes.map((cls) => _classCard(cls, isDark)),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _classCard(ClassRoom cls, bool isDark) {
    final prefs = SharedPreferences.getInstance(); // async – use FutureBuilder for badge
    final accent = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;
    return FutureBuilder<SharedPreferences>(
      future: prefs,
      builder: (context, snap) {
        final markedToday = (snap.hasData &&
            snap.data!.getString('attendance_marked_${cls.id}') == _todayKey) ||
            _serverMarkedClassIds.contains(cls.id.toString());
        return GestureDetector(
          onTap: () => _selectClass(cls),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: isDark ? null : Border.all(color: Colors.grey.shade100),
              boxShadow: isDark ? null : [
                BoxShadow(color: Colors.black.withOpacity(0.04),
                  blurRadius: 12, offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16)),
                  child: Icon(LucideIcons.bookOpen, color: accent),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cls.name,
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 4),

                    ],
                  ),
                ),
                if (markedToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12)),
                    child: Text('✓ Done',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700,
                        color: Colors.green)),
                  )
                else
                  Icon(LucideIcons.chevronRight,
                    color: isDark ? Colors.white24 : Colors.grey.shade300),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VIEW 2: Student Attendance Marking
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildStudentAttendance(bool isDark) {
    final presentCount = _students.where((s) => s.isPresent).length;
    final accent = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;

    return Column(
      children: [
        // Header row with back button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: _goBack,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: isDark ? null : Border.all(color: Colors.grey.shade200)),
                  child: Icon(LucideIcons.arrowLeft, size: 20,
                    color: isDark ? Colors.white : Colors.black87),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedClass!.name,
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87)),
                    Text(_todayKey,
                      style: GoogleFonts.inter(fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black45)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Already marked banner
        if (_attendanceAlreadyMarked)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.green.withOpacity(0.3))),
            child: Row(
              children: [
                const Icon(LucideIcons.checkCircle, color: Colors.green, size: 18),
                const SizedBox(width: 10),
                Text('Attendance already submitted for today.',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.green,
                    fontWeight: FontWeight.w600)),
              ],
            ),
          ),

        // Present / Absent summary
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(
            children: [
              Expanded(child: _summaryPill('$presentCount Present', Colors.green, isDark)),
              const SizedBox(width: 12),
              Expanded(child: _summaryPill('${_students.length - presentCount} Absent',
                Colors.red, isDark)),
            ],
          ),
        ),

        // Student list
        Expanded(
          child: _students.isEmpty
            ? _emptyState('No students enrolled in this class yet.', isDark)
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                itemCount: _students.length,
                itemBuilder: (context, i) => _studentTile(_students[i], isDark),
              ),
        ),

        // Save Button (bottom)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkBg : const Color(0xFFF8FAFC),
            border: Border(top: BorderSide(
              color: isDark ? Colors.white10 : Colors.grey.shade100)),
          ),
          child: SafeArea(
            child: ElevatedButton(
              onPressed: (_attendanceAlreadyMarked || _students.isEmpty) ? null : _saveAttendance,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: _attendanceAlreadyMarked ? Colors.grey.shade400 : accent,
                foregroundColor: isDark ? Colors.black : Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: _isSaving
                ? const SizedBox(width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_attendanceAlreadyMarked ? LucideIcons.checkCircle2 : LucideIcons.save,
                        size: 20, color: _attendanceAlreadyMarked ? Colors.green : (isDark ? Colors.black : Colors.white)),
                      const SizedBox(width: 10),
                      Text(
                        _attendanceAlreadyMarked
                          ? 'Already Submitted Today'
                          : 'Save Attendance  ($presentCount / ${_students.length} Present)',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _studentTile(Student student, bool isDark) {
    final accent = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isDark ? null : Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14)),
            child: Center(
              child: Text(
                student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold,
                  color: accent),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Name + ID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87)),
                Text(student.id,
                  style: GoogleFonts.inter(fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38)),
              ],
            ),
          ),

          // Status label
          Text(
            student.isPresent ? 'Present' : 'Absent',
            style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: student.isPresent ? Colors.green : Colors.red),
          ),
          const SizedBox(width: 8),

          // Toggle — disabled if already marked today
          Switch(
            value: student.isPresent,
            activeColor: Colors.white,
            activeTrackColor: accent,
            onChanged: _attendanceAlreadyMarked
              ? null
              : (val) => setState(() => student.isPresent = val),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────
  Widget _statChip(String value, String label, bool isDark) {
    return Column(children: [
      Text(value, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87)),
      Text(label, style: GoogleFonts.inter(fontSize: 12,
        color: isDark ? Colors.white54 : Colors.black45)),
    ]);
  }

  Widget _divider(bool isDark) {
    return Container(width: 1, height: 32,
      color: isDark ? Colors.white12 : Colors.grey.shade200);
  }

  Widget _summaryPill(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2))),
      child: Center(
        child: Text(label,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ),
    );
  }

  Widget _emptyState(String message, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.inbox, size: 48,
              color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 15,
                color: isDark ? Colors.white38 : Colors.black45)),
          ],
        ),
      ),
    );
  }
}
