import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_theme.dart';
import '../services/api_service.dart';
import '../main.dart';
import 'student_detail_screen.dart';
import 'student_attendance_history_screen.dart';
import '../widgets/app_effects.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _students = [];
  bool _isLoading = true;
  double _averageAttendance = 0.0;
  bool _isStatsLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
    
    // Listen for global refreshes
    globalRefreshNotifier.addListener(_fetchStudents);
  }

  @override
  void dispose() {
    globalRefreshNotifier.removeListener(_fetchStudents);
    super.dispose();
  }

  Future<void> _fetchStudents() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getParentStudents();
      if (response['success'] && mounted) {
        final List studentList = response['data']?['students'] ?? [];
        
        // Proactively fetch images if missing from enrollment data
        for (var student in studentList) {
          final currentImage = student['student_image'] ?? student['stu_image_url'] ?? student['stu_image'];
          if (currentImage == null || currentImage.toString().isEmpty) {
            try {
              final imageResponse = await _apiService.getStudentImage(student['studid'].toString());
              if ((imageResponse['status'] == true || imageResponse['success'] == true) && imageResponse['data'] != null) {
                // Merge the image data into the student object
                student['stu_image_url'] = imageResponse['data']['stu_image_url'];
                student['stu_image'] = imageResponse['data']['stu_image'];
              }
            } catch (e) {
              debugPrint('Dashboard: Failed to fetch image for student ${student['studid']}: $e');
            }
          }
        }

        if (mounted) {
          setState(() {
            _students = studentList;
            _isLoading = false;
          });
          _calculateAverageAttendance(studentList);
        }
      }
    } catch (e) {
      debugPrint('Error fetching students: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _calculateAverageAttendance(List students) async {
    if (students.isEmpty) return;
    if (mounted) setState(() => _isStatsLoading = true);

    double totalPercentage = 0;
    int count = 0;

    for (var student in students) {
      final studid = student['studid']?.toString();
      if (studid == null) continue;

      try {
        // Try the primary stats endpoint
        final response = await _apiService.get('attendance/student-stats/$studid');
        if (response['success'] == true || response['status'] == true) {
          final data = response['data'];
          if (data is Map) {
            final rate = _toDouble(data['percentage'] ?? data['attendance_rate']);
            student['attendance_rate'] = rate;
            totalPercentage += rate;
            count++;
          }
        }
      } catch (e) {
        debugPrint('Failed to fetch stats for student $studid: $e');
      }
    }

    if (mounted) {
      setState(() {
        if (count > 0) {
          _averageAttendance = totalPercentage / count;
        }
        _isStatsLoading = false;
      });
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _fetchStudents,
        color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeInAnimation(
                delay: const Duration(milliseconds: 100),
                child: _buildDynamicHeader(isDark),
              ),
              const SizedBox(height: 32),
              FadeInAnimation(
                delay: const Duration(milliseconds: 200),
                child: _buildStatsRow(isDark),
              ),
              const SizedBox(height: 40),
              _buildSectionTitle('Enrolled Students', isDark, LucideIcons.users),
              const SizedBox(height: 16),
              _buildChildrenGrid(isDark),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicHeader(bool isDark) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: profileNotifier,
      builder: (context, profile, _) {
        String firstName = profile?['first_name'] ?? 'Parent';
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Hello, ',
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                Text(
                  '$firstName!',
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (isDark ? AppTheme.darkAccent : AppTheme.lightAccent).withOpacity(0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.shieldCheck, 
                    size: 14, 
                    color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Authorized Parent Access',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatsRow(bool isDark) {
    return Row(
      children: [
        _buildStatItem(
          'Children',
          _isLoading ? '...' : _students.length.toString(),
          LucideIcons.baby,
          isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
          isDark,
        ),
        const SizedBox(width: 16),
        _buildStatItem(
          'Attendance',
          _isStatsLoading ? '...' : '${_averageAttendance.toStringAsFixed(0)}%',
          LucideIcons.calendarCheck,
          AppTheme.darkSuccess,
          isDark,
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: isDark ? null : [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Icon(LucideIcons.trendingUp, color: AppTheme.darkSuccess.withOpacity(0.5), size: 16),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const Spacer(),
        if (title == 'Enrolled Students' && _students.isNotEmpty)
          Text(
            '${_students.length} Total',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
      ],
    );
  }

  Widget _buildChildrenGrid(bool isDark) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent));
    }

    if (_students.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
        ),
        child: Column(
          children: [
            Icon(LucideIcons.userX, size: 48, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'No students linked to your account',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _students.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (context, index) {
        final student = _students[index];
        return FadeInAnimation(
          delay: Duration(milliseconds: 300 + (index * 100)),
          child: _buildStudentCard(student, isDark),
        );
      },
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student, bool isDark) {
    final accent = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;
    
    // Resolve photo URL with fallbacks and relative path handling
    String? photoUrl = student['student_image'] ?? student['stu_image_url'] ?? student['stu_image'];
    
    if (photoUrl != null && photoUrl.isNotEmpty) {
      // If it's a relative path or a direct storage link, route it through the API image endpoint
      if (!photoUrl.startsWith('http') || photoUrl.contains('/backend/storage/')) {
        final String filename = photoUrl.contains('/') ? photoUrl.split('/').last : photoUrl;
        photoUrl = 'https://wstsc.org.au/backend/api/student-image/$filename';
      }
    } else {
      photoUrl = null;
    }

    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: isDark ? null : [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StudentDetailScreen(student: student),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent.withOpacity(0.2), accent.withOpacity(0.05)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        image: photoUrl != null
                          ? DecorationImage(
                              image: NetworkImage(photoUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                      ),
                      child: photoUrl == null
                        ? Center(
                            child: Text(
                              student['student_name']?[0] ?? 'S',
                              style: GoogleFonts.outfit(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: accent,
                              ),
                            ),
                          )
                        : null,
                    ),
                    if (photoUrl == null)
                      Positioned(
                        bottom: 0,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: isDark ? AppTheme.darkSurface : Colors.white, width: 2),
                          ),
                          child: const Icon(LucideIcons.camera, size: 14, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  student['student_name'] ?? 'Unknown',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Builder(
                  builder: (context) {
                    // Prioritize class_name from class_info, then top-level class_name
                    String? displayClass;
                    
                    final classInfo = student['class_info'];
                    if (classInfo is Map) {
                      displayClass = classInfo['class_name']?.toString();
                    } else if (classInfo is String && classInfo.trim().startsWith('{')) {
                      try {
                        final decoded = json.decode(classInfo);
                        displayClass = decoded['class_name']?.toString();
                      } catch (_) {}
                    }
                    
                    // Fallbacks
                    displayClass ??= student['class_name']?.toString();
                    displayClass ??= student['class_grade']?.toString();
                    
                    return _buildBadge(displayClass ?? 'N/A', isDark);
                  }
                ),
                if (photoUrl == null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Upload Photo',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
      ),
    );
  }

  Widget _buildAttendanceBadge(dynamic rateValue, bool isDark) {
    final double rate = _toDouble(rateValue);
    final color = rate >= 90 ? AppTheme.darkSuccess : (rate >= 75 ? Colors.orange : Colors.red);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Text(
        '${rate.toStringAsFixed(0)}%',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildAttendanceProgress(dynamic rateValue, bool isDark) {
    final double rate = _toDouble(rateValue);
    final color = rate >= 90 ? AppTheme.darkSuccess : (rate >= 75 ? Colors.orange : Colors.red);
    
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: rate / 100,
            minHeight: 4,
            backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
