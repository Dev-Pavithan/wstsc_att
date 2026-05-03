import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../main.dart';
import '../mock_data.dart';
import '../services/api_service.dart';
import '../widgets/app_effects.dart';

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

  bool _isStudentsLoading = false;

  // ─── Load Teachers Name + Active Classrooms ─────────────────────────────────
  Future<void> _loadDashboard() async {
    // Only show full-screen loader if we're on the dashboard list, not in student details
    if (_selectedClass == null) setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('user_name') ?? 'Teacher';
      setState(() => _teacherName = savedName.split(' ').first);

      final classroomsResponse = await _api.get('classrooms/active');
      final classroomsData = classroomsResponse['data']['classrooms'] as List;
      final statsResponse = await _api.get('attendance/class/all/stats');

      if (!mounted) return;
      setState(() {
        _classes = classroomsData.map((c) => ClassRoom.fromJson(c)).toList();
        _totalStudents = (statsResponse['data']['total_students'] as num?)?.toInt() ?? 0;
        _serverMarkedClassIds = (statsResponse['data']['marked_today'] as List?)?.map((id) => id.toString()).toList() ?? [];
        _isLoading = false;
      });
      debugPrint('Dashboard: Loaded ${_classes.length} classes, $_totalStudents total students');
    } catch (e) {
      debugPrint('Error Loading Dashboard: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Load Students for Selected Classroom ───────────────────────────────────
  Future<void> _selectClass(ClassRoom classRoom) async {
    setState(() { 
      _selectedClass = classRoom; 
      _isStudentsLoading = true; 
      _students = []; // Clear existing list to prevent flickering/stale data
      _attendanceAlreadyMarked = false; 
    });
    
    try {
      // Check if attendance already saved today
      final prefs = await SharedPreferences.getInstance();
      final savedDate = prefs.getString('attendance_marked_${classRoom.id}');
      final alreadyMarked = savedDate == _todayKey;

      final response = await _api.get('attendance/class/${classRoom.id}/active-students');
      final data = response['data'] as List;
      final serverMarked = response['attendance_already_marked'] == true;

      if (!mounted) return;
      setState(() {
        _students = data.map((s) => Student.fromJson(s)).toList();
        _attendanceAlreadyMarked = alreadyMarked || serverMarked;
        _isStudentsLoading = false;
      });
      debugPrint('ClassList: Loaded ${_students.length} students for ${classRoom.id}');
    } catch (e) {
      debugPrint('Error Loading Students for ClassView: $e');
      if (mounted) setState(() => _isStudentsLoading = false);
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

      if (response['success'] == true) {
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
      if (mounted) setState(() => _isSaving = false);
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
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        switchInCurve: Curves.easeOutQuart,
        switchOutCurve: Curves.easeInQuad,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: animation.drive(Tween<Offset>(
                begin: const Offset(0.0, 0.05),
                end: Offset.zero,
              )),
              child: child,
            ),
          );
        },
        child: _isLoading
          ? KeyedSubtree(key: const ValueKey('loading'), child: _buildSkeleton(isDark))
          : _selectedClass == null
            ? KeyedSubtree(key: const ValueKey('classes'), child: _buildClassList(isDark))
            : KeyedSubtree(key: const ValueKey('students'), child: _buildStudentAttendance(isDark)),
      ),
    );
  }

  Widget _buildSkeleton(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const AppSkeleton(width: 200, height: 32),
          const SizedBox(height: 8),
          const AppSkeleton(width: 140, height: 16),
          const SizedBox(height: 24),
          const AppSkeleton(width: double.infinity, height: 80, borderRadius: 24),
          const SizedBox(height: 32),
          const AppSkeleton(width: 150, height: 20),
          const SizedBox(height: 16),
          ...List.generate(4, (i) => const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: AppSkeleton(width: double.infinity, height: 90, borderRadius: 24),
          )),
        ],
      ),
    );
  }

  Widget _buildStudentSkeleton(bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const AppSkeleton(width: 40, height: 40, borderRadius: 14),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  AppSkeleton(width: 120, height: 20),
                  SizedBox(height: 4),
                  AppSkeleton(width: 80, height: 14),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 6,
            itemBuilder: (context, i) => const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: AppSkeleton(width: double.infinity, height: 70, borderRadius: 18),
            ),
          ),
        ),
      ],
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
          FadeInAnimation(
            delay: const Duration(milliseconds: 100),
            child: ValueListenableBuilder<Map<String, dynamic>?>(
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
          ),
          const SizedBox(height: 20),

          // Stats strip
          FadeInAnimation(
            delay: const Duration(milliseconds: 200),
            child: Container(
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
          ),

          const SizedBox(height: 28),

          Text('Your Classrooms',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black87)),
          const SizedBox(height: 12),

          // Class cards
          if (_classes.isEmpty)
            _emptyState('No active classrooms found.\nContact your admin.', isDark)
          else
            ..._classes.asMap().entries.map((entry) {
              final int index = entry.key;
              final ClassRoom cls = entry.value;
              return FadeInAnimation(
                delay: Duration(milliseconds: 300 + (index * 100)),
                child: _classCard(cls, isDark),
              );
            }),

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
  void _showStudentDetails(Student student) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            
            // Student Image & Basic Info
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: (isDark ? AppTheme.darkAccent : AppTheme.lightAccent).withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
                image: student.imageUrl != null
                  ? DecorationImage(image: NetworkImage(student.imageUrl!), fit: BoxFit.cover)
                  : null,
              ),
              child: student.imageUrl == null
                ? Center(child: Text(student.name[0], style: GoogleFonts.outfit(fontSize: 48, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent)))
                : null,
            ),
            const SizedBox(height: 16),
            Text(student.name, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
            Text('Student ID: ${student.id}', style: GoogleFonts.inter(color: Colors.grey)),
            
            const SizedBox(height: 32),
            
            // Detail Sections
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _buildSectionHeader('ACADEMIC INFORMATION', isDark),
                  _buildDetailRow(LucideIcons.school, 'Mainstream School', '${student.school ?? 'Not specified'} (Grade ${student.mainstreamGrade ?? 'N/A'})', isDark),
                  _buildDetailRow(LucideIcons.graduationCap, 'Community Grade', student.communityGrade ?? 'Not specified', isDark),
                  _buildDetailRow(LucideIcons.languages, 'Mother Tongue', student.motherTongue ?? 'Not specified', isDark),
                  
                  const SizedBox(height: 20),
                  _buildSectionHeader('MEDICAL & SPECIAL NEEDS', isDark),
                  _buildMedicalRow(LucideIcons.alertCircle, 'Asthma', student.asthma, isDark),
                  _buildMedicalRow(LucideIcons.thermometer, 'Allergies', student.allergies, isDark),
                  _buildMedicalRow(LucideIcons.activity, 'Major Illness', student.majorIllness, isDark),
                  _buildDetailRow(LucideIcons.brain, 'Special Needs', student.specialNeeds ?? 'None', isDark),
                  if (student.specialNeedsDetails != null && student.specialNeedsDetails!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 52, bottom: 12),
                      child: Text(student.specialNeedsDetails!, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey)),
                    ),

                  const SizedBox(height: 20),
                  _buildSectionHeader('EMERGENCY CONTACT', isDark),
                  _buildDetailRow(LucideIcons.userCircle2, 'Contact Person', '${student.emergencyName ?? 'Not specified'} (${student.emergencyRelationship ?? 'N/A'})', isDark),
                  _buildDetailRow(LucideIcons.phone, 'Mobile Phone', student.emergencyPhone ?? 'Not specified', isDark),
                  if (student.emergencyHomePhone != null) _buildDetailRow(LucideIcons.home, 'Home Phone', student.emergencyHomePhone!, isDark),
                  if (student.emergencyWorkPhone != null) _buildDetailRow(LucideIcons.briefcase, 'Work Phone', student.emergencyWorkPhone!, isDark),

                  const SizedBox(height: 20),
                  _buildSectionHeader('CONSENTS', isDark),
                  _buildDetailRow(LucideIcons.camera, 'Photo/Video Consent', _formatConsent(student.photoConsent), isDark),
                  _buildDetailRow(LucideIcons.shieldCheck, 'Medical Treatment', _formatConsent(student.medicalConsent), isDark),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatConsent(String? val) {
    if (val == '1' || val == 'true' || val == 'Yes') return 'Granted';
    if (val == '0' || val == 'false' || val == 'No') return 'Declined';
    return 'Not specified';
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent)),
    );
  }

  Widget _buildMedicalRow(IconData icon, String label, String? value, bool isDark) {
    bool isAlert = value?.toLowerCase() == 'yes' || value == '1' || value == 'true';
    return _buildDetailRow(
      icon, 
      label, 
      value ?? 'No', 
      isDark, 
      valueColor: isAlert ? Colors.redAccent : null
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isDark ? AppTheme.darkAccent : AppTheme.lightAccent).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: valueColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VIEW 2: Student Details List
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildStudentAttendance(bool isDark) {
    final accent = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;

    return Column(
      children: [
        // Header row with back button
        FadeInAnimation(
          delay: const Duration(milliseconds: 100),
          child: Padding(
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
                      Text('Class Student Directory',
                        style: GoogleFonts.inter(fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.black45)),
                    ],
                  ),
                ),
                if (!_isStudentsLoading)
                  IconButton(
                    onPressed: () => _selectClass(_selectedClass!),
                    icon: Icon(LucideIcons.refreshCw, size: 18, color: isDark ? Colors.white38 : Colors.black38),
                    tooltip: 'Refresh List',
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Student list
        Expanded(
          child: _isStudentsLoading
            ? _buildStudentSkeleton(isDark)
            : _students.isEmpty
              ? _emptyState('No students enrolled in this class yet.', isDark)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  itemCount: _students.length,
                  itemBuilder: (context, i) => FadeInAnimation(
                    delay: Duration(milliseconds: 200 + (i * 50)),
                    child: _studentTile(_students[i], isDark),
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
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isDark ? null : Border.all(color: Colors.grey.shade100),
      ),
      child: InkWell(
        onTap: () => _showStudentDetails(student),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  image: student.imageUrl != null
                    ? DecorationImage(image: NetworkImage(student.imageUrl!), fit: BoxFit.cover)
                    : null,
                ),
                child: student.imageUrl == null
                  ? Center(
                      child: Text(
                        student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold,
                          color: accent),
                      ),
                    )
                  : null,
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

              Icon(LucideIcons.chevronRight, size: 18, color: isDark ? Colors.white24 : Colors.black12),
            ],
          ),
        ),
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
