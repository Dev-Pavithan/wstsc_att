import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../mock_data.dart';
import '../services/api_service.dart';


class AttendanceScreen extends StatefulWidget {
  final ClassRoom? classRoom;

  const AttendanceScreen({super.key, this.classRoom});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with SingleTickerProviderStateMixin {
  late ClassRoom currentClass;
  List<Student> students = [];
  List<Student> filteredStudents = [];
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  final ApiService _api = ApiService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _animationController.forward();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      if (widget.classRoom != null) {
        currentClass = widget.classRoom!;
      } else {
        final classroomsResponse = await _api.get('classrooms/active');
        final classroomsData = classroomsResponse['data']['classrooms'] as List;
        if (classroomsData.isNotEmpty) {
          currentClass = ClassRoom.fromJson(classroomsData.first);
        } else {
          throw Exception('No active classrooms found');
        }
      }
      await _loadStudents();
    } catch (e) {
      debugPrint('Error Loading Classrooms: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStudents() async {
    try {
      final response = await _api.get('attendance/class/${currentClass.id}/active-students');
      final data = response['data'] as List;
      setState(() {
        students = data.map((s) => Student.fromJson(s)).toList();
        filteredStudents = students;
        _isLoading = false;
      });
      debugPrint('Loaded ${students.length} students for class ${currentClass.id}');
    } catch (e) {
      debugPrint('Error Loading Students: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filterStudents(String query) {
    setState(() {
      filteredStudents = students.where((s) => s.name.toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  void _showFilterOptions() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter Students', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildFilterOption(LucideIcons.users, 'Show All', () => _applyFilter('all'), isDark),
            _buildFilterOption(LucideIcons.checkCircle, 'Present Only', () => _applyFilter('present'), isDark, color: Colors.green),
            _buildFilterOption(LucideIcons.xCircle, 'Absent Only', () => _applyFilter('absent'), isDark, color: Colors.red),
            _buildFilterOption(LucideIcons.arrowUpAZ, 'Sort (A-Z)', () => _applyFilter('sort_name'), isDark),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(IconData icon, String label, VoidCallback onTap, bool isDark, {Color? color}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (color ?? (isDark ? AppTheme.darkAccent : AppTheme.lightAccent)).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color ?? (isDark ? AppTheme.darkAccent : AppTheme.lightAccent), size: 20),
      ),
      title: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  void _applyFilter(String type) {
    setState(() {
      if (type == 'all') {
        filteredStudents = List.from(students);
      } else if (type == 'present') {
        filteredStudents = students.where((s) => s.isPresent).toList();
      } else if (type == 'absent') {
        filteredStudents = students.where((s) => !s.isPresent).toList();
      } else if (type == 'sort_name') {
        filteredStudents.sort((a, b) => a.name.compareTo(b.name));
      }
    });
    Navigator.pop(context);
  }

  void _saveAttendance() async {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        title: const Text('Confirm Attendance'),
        content: Text('Marking ${students.where((s) => s.isPresent).length} students as present for ${currentClass.name}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performBulkMarking();
            },
            child: Text('Confirm', style: TextStyle(color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _performBulkMarking() async {
    setState(() => _isLoading = true);
    try {
      final attendanceData = students.map((s) => {
        'studid': s.siid,          // Integer siid, NOT int.parse(string id)
        'is_present': s.isPresent
      }).toList();

      final response = await _api.post('attendance/mark-bulk', {
        'class_id': currentClass.id,
        'mark_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'attendance_data': attendanceData
      });

      if (response['status'] == true) {
        _showSuccess();
      }
      debugPrint('Attendance Mark-Bulk: ${response['message']}');
    } catch (e) {
      debugPrint('Error Marking Attendance: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccess() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.darkAccent : AppTheme.lightAccent).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.checkCircle, color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Success!', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    const Text('Attendance record has been saved successfully.', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF1E1B4B), // Deep navy matching the app gradient
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : (students.isEmpty 
          ? Center(child: Text('No students assigned to this class.', style: Theme.of(context).textTheme.bodyLarge))
          : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          currentClass.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 34, height: 1.1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${DateFormat('EEEE, d MMMM').format(DateTime.now())} • ${students.length} Students',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterStudents,
                      decoration: const InputDecoration(
                        hintText: 'Search students...',
                        prefixIcon: Icon(LucideIcons.search, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: _showFilterOptions,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: isDark ? null : Border.all(color: Colors.grey.shade200),
                      ),
                      child: Icon(LucideIcons.slidersHorizontal, color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Summary Cards — real values from API data
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(child: _buildSummaryCard(
                    'Present Today',
                    '${students.where((s) => s.isPresent).length}',
                    '/ ${students.length}',
                    isDark)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildSummaryCard(
                    'Absent',
                    '${students.where((s) => !s.isPresent).length}',
                    'students',
                    isDark,
                    isHighlight: true)),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Student List Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('STUDENT NAME', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
                  Text('STATUS', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
                ],
              ),
            ),

            // Student List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredStudents.length,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              itemBuilder: (context, index) {
                final student = filteredStudents[index];
                return _buildStudentTile(student, isDark);
              },
            ),

            const SizedBox(height: 32),
            
            // Save Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton(
                onPressed: _saveAttendance,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.checkCircle2, size: 20),
                    const SizedBox(width: 12),
                    const Text('Save Attendance'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      )),
    );
  }

  Widget _buildSummaryCard(String title, String mainValue, String subValue, bool isDark, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isDark ? null : Border.all(color: Colors.grey.shade200),
      ),
      child: Stack(
        children: [
          if (isHighlight)
            Positioned(
              left: -10,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(mainValue, style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: isHighlight ? (isDark ? AppTheme.darkAccent : AppTheme.lightAccent) : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary))),
                  if (subValue.isNotEmpty)
                    Text(' $subValue', style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white38 : Colors.black38)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentTile(Student student, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? null : Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (isDark ? AppTheme.darkAccent : AppTheme.lightAccent).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: (isDark ? AppTheme.darkAccent : AppTheme.lightAccent).withOpacity(0.1)),
            ),
            child: Center(
              child: Text(
                student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
                const SizedBox(height: 2),
                Text('ID: ${student.id}', style: GoogleFonts.inter(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
              ],
            ),
          ),
          Text(
            student.isPresent ? 'Present' : 'Absent',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
          ),
          const SizedBox(width: 8),
          Switch(
            value: student.isPresent,
            activeColor: Colors.white,
            activeTrackColor: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
            onChanged: (val) => setState(() => student.isPresent = val),
          ),
        ],
      ),
    );
  }
}
