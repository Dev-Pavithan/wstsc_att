import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_theme.dart';
import '../services/api_service.dart';
import 'student_attendance_history_screen.dart';
import 'student_detail_screen.dart';
import '../widgets/app_effects.dart';

class ParentChildrenScreen extends StatefulWidget {
  const ParentChildrenScreen({super.key});

  @override
  State<ParentChildrenScreen> createState() => _ParentChildrenScreenState();
}

class _ParentChildrenScreenState extends State<ParentChildrenScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final response = await _apiService.getParentStudents();
      if (response['success'] == true || response['status'] == true) {
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
              debugPrint('Failed to fetch image for student ${student['studid']}: $e');
            }
          }
        }

        if (mounted) {
          setState(() {
            _students = studentList;
            _isLoading = false;
          });
          _fetchAttendanceRates(studentList);
        }
      }

    } catch (e) {
      debugPrint('Error fetching students: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAttendanceRates(List students) async {
    for (var student in students) {
      final studid = student['studid']?.toString();
      if (studid == null) continue;

      try {
        final response = await _apiService.get('attendance/student-stats/$studid');
        if (response['success'] == true || response['status'] == true) {
          final data = response['data'];
          if (mounted && data is Map) {
            setState(() {
              student['attendance_rate'] = _toDouble(data['percentage'] ?? data['attendance_rate']);
            });
          }
        }
      } catch (e) {
        debugPrint('Failed to fetch stats for $studid: $e');
      }
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
        child: _isLoading 
          ? Center(child: CircularProgressIndicator(color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent))
          : _students.isEmpty
            ? _buildEmptyState(isDark)
            : ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: _students.length,
                itemBuilder: (context, index) {
                  final student = _students[index];
                  return FadeInAnimation(
                    delay: Duration(milliseconds: index * 100),
                    child: _buildStudentCard(student, isDark),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.users, size: 64, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'No children found',
            style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student, bool isDark) {
    final accent = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;
    
    // Debug info for image troubleshooting
    debugPrint('Building card for student: ${student['student_name']} (ID: ${student['studid']})');
    debugPrint('Available student keys: ${student.keys.toList()}');
    if (student.containsKey('stu_image')) debugPrint('stu_image: ${student['stu_image']}');
    if (student.containsKey('student_image')) debugPrint('student_image: ${student['student_image']}');

    String? photoUrl = student['student_image'] ?? student['stu_image_url'] ?? student['stu_image'];
    
    // Resolve photo URL and address potential CORS issues on Web
    if (photoUrl != null && photoUrl.isNotEmpty) {
      if (!photoUrl.startsWith('http') || photoUrl.contains('/backend/storage/')) {
        final String filename = photoUrl.contains('/') ? photoUrl.split('/').last : photoUrl;
        photoUrl = 'https://wstsc.org.au/backend/api/student-image/$filename';
      }
    } else {
      photoUrl = null;
    }

    
    debugPrint('Final photoUrl for ${student['student_name']}: $photoUrl');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            Navigator.push(
              context,
              AppTransitions.fadeInRoute(
                StudentAttendanceHistoryScreen(
                  studid: student['studid']?.toString() ?? '',
                  studentName: student['student_name'] ?? 'Student',
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: photoUrl != null
                          ? Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                debugPrint('Dashboard image load failed for $photoUrl: $error');
                                return Center(
                                  child: Text(
                                    student['student_name']?[0] ?? 'S',
                                    style: GoogleFonts.outfit(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: accent,
                                    ),
                                  ),
                                );
                              },
                            )
                          : Center(
                              child: Text(
                                student['student_name']?[0] ?? 'S',
                                style: GoogleFonts.outfit(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: accent,
                                ),
                              ),
                            ),
                      ),
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
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['student_name'] ?? 'Unknown Student',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
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
                              
                              return Row(
                                children: [
                                  _buildBadge(displayClass ?? 'N/A', isDark),
                                  if (student['attendance_rate'] != null) ...[
                                    const SizedBox(width: 8),
                                    _buildAttendanceBadge(student['attendance_rate'], isDark),
                                  ],
                                ],
                              );
                            }
                          ),
                          if (photoUrl == null) ...[
                            const SizedBox(width: 8),
                            Text(
                              'Upload Photo',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: accent,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSuccess.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.history, size: 12, color: AppTheme.darkSuccess),
                            const SizedBox(width: 6),
                            Text(
                              'View Attendance History',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.darkSuccess,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(LucideIcons.calendarDays, color: accent.withOpacity(0.5)),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.calendarCheck, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            '${rate.toStringAsFixed(0)}% Attendance',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
