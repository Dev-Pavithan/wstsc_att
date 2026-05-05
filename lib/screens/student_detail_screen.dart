import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_theme.dart';
import '../services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'student_attendance_history_screen.dart';
import '../widgets/app_effects.dart';

class StudentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();
  late Map<String, dynamic> _studentData;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isUploading = false;
  XFile? _pickedImage;
  final _formKey = GlobalKey<FormState>();

  // Controllers for editing
  late TextEditingController _mainstreamSchoolController;
  late TextEditingController _mainstreamGradeController;
  late TextEditingController _comSchoolGradeController;
  late TextEditingController _motherTongueController;
  late TextEditingController _specialNeedsDetailsController;
  
  late TextEditingController _emergencyGivenNameController;
  late TextEditingController _emergencyFamilyNameController;
  late TextEditingController _emergencyRelationshipController;
  late TextEditingController _emergencyMobilePhoneController;
  late TextEditingController _emergencyHomePhoneController;
  late TextEditingController _emergencyWorkPhoneController;

  // Boolean state
  bool _hasAsthma = false;
  bool _hasMajorIllness = false;
  bool _hasAllergies = false;
  bool _hasSpecialNeeds = false;
  bool _photoConsent = false;
  bool _medicalConsent = false;

  double _attendancePercentage = 0.0;
  int _totalDays = 0;
  int _presentDays = 0;

  @override
  void initState() {
    super.initState();
    if (mounted) {
      setState(() {
        _studentData = Map<String, dynamic>.from(widget.student);
        _isLoading = false;
      });
    }
    _initializeControllers();
    _fetchFullStudentData();
    _fetchAttendanceStats();
    _fetchMissingImage();
  }

  void _initializeControllers() {
    final profile = _studentData['profile'] ?? {};
    final emergencies = _studentData['emergency_contacts'] as List? ?? [];
    final firstEmergency = emergencies.isNotEmpty ? emergencies[0] : {};

    // Mainstream School
    final mSchool = profile['current_mainstream_school'] ?? _studentData['mainstream_school'] ?? '';
    final mGrade = profile['current_mainstream_grade'] ?? _studentData['class_grade'] ?? '';
    
    // WSTSC Grade - Prioritize name from class_info
    String? cGrade;
    final classInfo = _studentData['class_info'];
    if (classInfo is Map) {
      cGrade = classInfo['class_name']?.toString();
    } else if (classInfo is String && classInfo.trim().startsWith('{')) {
      try {
        final decoded = json.decode(classInfo);
        cGrade = decoded['class_name']?.toString();
      } catch (_) {}
    }
    
    cGrade ??= profile['current_com_school_enr_grade']?.toString() ?? _studentData['com_school_enr_grade']?.toString() ?? '';
    final mTongue = profile['mother_tongue'] ?? _studentData['mother_tongue'] ?? '';
    
    // Mainstream School
    _mainstreamSchoolController = TextEditingController(text: mSchool);
    _mainstreamGradeController = TextEditingController(text: mGrade);
    _comSchoolGradeController = TextEditingController(text: cGrade);
    _motherTongueController = TextEditingController(text: mTongue);
    _specialNeedsDetailsController = TextEditingController(text: profile['current_special_learning_needs_details'] ?? '');

    // Emergency Contact
    String eGiven = profile['emergency_given_name'] ?? _studentData['emergency_given_name'] ?? firstEmergency['name'] ?? '';
    String eFamily = profile['emergency_family_name'] ?? '';
    String eRel = profile['emergency_relationship'] ?? firstEmergency['relationship'] ?? '';
    String eMobile = profile['emergency_mobile_phone'] ?? _studentData['emergency_mobile_phone'] ?? firstEmergency['mobile'] ?? '';
    String eHome = profile['emergency_home_phone'] ?? firstEmergency['home'] ?? '';
    String eWork = profile['emergency_work_phone'] ?? firstEmergency['work'] ?? '';

    _emergencyGivenNameController = TextEditingController(text: eGiven);
    _emergencyFamilyNameController = TextEditingController(text: eFamily);
    _emergencyRelationshipController = TextEditingController(text: eRel);
    _emergencyMobilePhoneController = TextEditingController(text: eMobile);
    _emergencyHomePhoneController = TextEditingController(text: eHome);
    _emergencyWorkPhoneController = TextEditingController(text: eWork);

    // Booleans
    _hasAsthma = _toBool(profile['current_asthma']);
    _hasMajorIllness = _toBool(profile['current_major_illness']);
    _hasAllergies = _toBool(profile['current_allergies']);
    _hasSpecialNeeds = _toBool(profile['current_special_learning_needs']);
    _photoConsent = _toBool(profile['photo_video_consent'] ?? _studentData['photo_consent']);
    _medicalConsent = _toBool(profile['medical_treatment_consent'] ?? _studentData['medical_consent']);
  }

  bool _toBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }

  Future<void> _fetchFullStudentData() async {
    try {
      final response = await _apiService.get('students/${_studentData['studid']}');
      if (response['success'] == true || response['status'] == true) {
        if (mounted) {
          setState(() {
            // Merge the data instead of overwriting, to preserve fields like student_image
            // that might be present in the dashboard data but missing in the detail API response
            final freshData = response['data'] ?? {};
            
            // Preserve the existing image if the new data doesn't have one
            final String? existingImage = _studentData['student_image'] ?? _studentData['stu_image_url'] ?? _studentData['stu_image'];
            if ((freshData['student_image'] == null || freshData['student_image'].toString().isEmpty) && 
                existingImage != null && existingImage.isNotEmpty) {
              freshData['student_image'] = existingImage;
            }

            _studentData = {
              ..._studentData,
              ...freshData,
            };

            // Ensure student_name is set for UI
            if (_studentData['student_name'] == null) {
              _studentData['student_name'] = _studentData['full_name'];
            }
            _initializeControllers();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching full student data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchMissingImage() async {
    final currentImage = _studentData['student_image'] ?? _studentData['stu_image_url'] ?? _studentData['stu_image'];
    if (currentImage == null || currentImage.toString().isEmpty) {
      try {
        final imageResponse = await _apiService.getStudentImage(_studentData['studid'].toString());
        if ((imageResponse['status'] == true || imageResponse['success'] == true) && imageResponse['data'] != null) {
          if (mounted) {
            setState(() {
              _studentData['stu_image_url'] = imageResponse['data']['stu_image_url'];
              _studentData['stu_image'] = imageResponse['data']['stu_image'];
            });
          }
        }
      } catch (e) {
        debugPrint('Failed to fetch image for detail: $e');
      }
    }
  }


  Future<void> _fetchAttendanceStats() async {
    final studid = _studentData['studid']?.toString();
    if (studid == null) return;

    final endpoints = [
      'attendance/student-stats/$studid',
      'attendance/student/$studid',
      'attendance/history/student/$studid',
      'attendance/stats/student/$studid',
      'student/attendance-stats/$studid',
      'student/attendance-history/$studid',
      'attendance/student/$studid/summary',
      'attendance/stats/$studid',
      'attendance/student-attendance/$studid',
      'attendance/stats/individual/$studid',
      'student-attendance-summary/$studid',
      'attendance/summary/student/$studid',
    ];

    for (var endpoint in endpoints) {
      try {
        var response;
        try {
          response = await _apiService.get(endpoint);
        } catch (e) {
          if (e.toString().contains('405')) {
            debugPrint('GET 405 for $endpoint, trying POST fallback...');
            response = await _apiService.post(endpoint, {});
          } else {
            rethrow;
          }
        }

        if (response != null && (response['success'] == true || response['status'] == true)) {
          final data = response['data'];
          
          if (mounted && data is Map) {
            setState(() {
              _attendancePercentage = _toDouble(data['percentage'] ?? data['attendance_rate']);
              _totalDays = _toInt(data['total_sessions'] ?? data['total_days']);
            });
            debugPrint('Successfully fetched attendance stats from $endpoint');
            return; // Success!
          } else if (data is List) {
            debugPrint('Endpoint $endpoint returned a List instead of a Map, skipping summary parsing.');
          }
        }
      } catch (e) {
        debugPrint('Failed to fetch attendance from $endpoint: $e');
        // Continue to next endpoint
      }
    }

    // Fallback: try to deduce from student detail profile if it exists there
    final profile = _studentData['profile'] ?? {};
    if (profile['attendance_percentage'] != null && mounted) {
      setState(() {
        _attendancePercentage = _toDouble(profile['attendance_percentage']);
        _totalDays = _toInt(profile['total_days']);
      });
      return;
    }

    // Deep fallback: filter this student from class daily history
    try {
      String classId = '';
      if (_studentData['current_class'] != null && _studentData['current_class'] is Map) {
        classId = (_studentData['current_class']['class_id'] ?? '').toString();
      }
      
      if (classId.isEmpty) {
        classId = (_studentData['class_id'] ?? _studentData['classroom_id'] ?? _studentData['cid'])?.toString() ?? '';
      }

      if (classId.isNotEmpty) {
        final response = await _apiService.get('attendance/class/$classId/date/${DateFormat('yyyy-MM-dd').format(DateTime.now())}');
        final List records = response['data'] ?? [];
        final studentRecord = records.firstWhere(
          (r) => r['studid'].toString() == studid,
          orElse: () => null,
        );

        if (studentRecord != null && mounted) {
          setState(() {
            _attendancePercentage = studentRecord['status'] == 'present' ? 100.0 : 0.0;
            _totalDays = 1;
          });
        }
      }
    } catch (e) {
      debugPrint('Attendance stats fetch failed completely: $e');
    }
  }



  @override
  void dispose() {
    _mainstreamSchoolController.dispose();
    _mainstreamGradeController.dispose();
    _comSchoolGradeController.dispose();
    _motherTongueController.dispose();
    _specialNeedsDetailsController.dispose();
    _emergencyGivenNameController.dispose();
    _emergencyFamilyNameController.dispose();
    _emergencyRelationshipController.dispose();
    _emergencyMobilePhoneController.dispose();
    _emergencyHomePhoneController.dispose();
    _emergencyWorkPhoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image != null) {
        setState(() {
          _pickedImage = image;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isEditing = false;
      _isUploading = true;
    });

    try {
      // 1. Save text fields
      final response = await _apiService.post('student-profiles', {
        'studid': _studentData['studid'],
        'current_mainstream_school': _mainstreamSchoolController.text,
        'current_mainstream_grade': _mainstreamGradeController.text,
        'current_com_school_enr_grade': _comSchoolGradeController.text,
        'mother_tongue': _motherTongueController.text,
        'current_special_learning_needs_details': _specialNeedsDetailsController.text,
        
        'emergency_given_name': _emergencyGivenNameController.text,
        'emergency_family_name': _emergencyFamilyNameController.text,
        'emergency_relationship': _emergencyRelationshipController.text,
        'emergency_mobile_phone': _emergencyMobilePhoneController.text,
        'emergency_home_phone': _emergencyHomePhoneController.text,
        'emergency_work_phone': _emergencyWorkPhoneController.text,

        'current_asthma': _hasAsthma ? 1 : 0,
        'current_major_illness': _hasMajorIllness ? 1 : 0,
        'current_allergies': _hasAllergies ? 1 : 0,
        'current_special_learning_needs': _hasSpecialNeeds ? 1 : 0,
        'photo_video_consent': _photoConsent,
        'medical_treatment_consent': _medicalConsent,
      });

      if (response['success'] == true || response['status'] == true) {
        // 2. Upload image if picked
        if (_pickedImage != null) {
          final uploadResponse = await _apiService.uploadStudentImage(
            _studentData['studid'].toString(),
            _pickedImage!,
          );
          if (uploadResponse['success'] == true || uploadResponse['status'] == true) {
            setState(() {
              _studentData['student_image'] = uploadResponse['data']['photo_url'];
              _pickedImage = null;
            });
          }
        }

        // Show success popup with auto-close
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            bool isDark = Theme.of(context).brightness == Brightness.dark;
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            });
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.darkSuccess.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.checkCircle, color: AppTheme.darkSuccess, size: 40),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Profile Updated',
                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Student profile has been updated successfully.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        );
        setState(() {
          _studentData['mainstream_school'] = _mainstreamSchoolController.text;
          _studentData['class_grade'] = _mainstreamGradeController.text;
          _studentData['com_school_enr_grade'] = _comSchoolGradeController.text;
          _studentData['mother_tongue'] = _motherTongueController.text;
          _studentData['emergency_given_name'] = _emergencyGivenNameController.text;
          _studentData['emergency_family_name'] = _emergencyFamilyNameController.text;
          _studentData['emergency_relationship'] = _emergencyRelationshipController.text;
          _studentData['emergency_mobile_phone'] = _emergencyMobilePhoneController.text;
          _studentData['emergency_home_phone'] = _emergencyHomePhoneController.text;
          _studentData['emergency_work_phone'] = _emergencyWorkPhoneController.text;
          
          // Update nested profile object as well
          _studentData['profile'] = {
            ...(_studentData['profile'] ?? {}),
            'current_mainstream_school': _mainstreamSchoolController.text,
            'current_mainstream_grade': _mainstreamGradeController.text,
            'current_com_school_enr_grade': _comSchoolGradeController.text,
            'mother_tongue': _motherTongueController.text,
            'current_special_learning_needs_details': _specialNeedsDetailsController.text,
            'emergency_given_name': _emergencyGivenNameController.text,
            'emergency_family_name': _emergencyFamilyNameController.text,
            'emergency_relationship': _emergencyRelationshipController.text,
            'emergency_mobile_phone': _emergencyMobilePhoneController.text,
            'emergency_home_phone': _emergencyHomePhoneController.text,
            'emergency_work_phone': _emergencyWorkPhoneController.text,
            'current_asthma': _hasAsthma ? 1 : 0,
            'current_major_illness': _hasMajorIllness ? 1 : 0,
            'current_allergies': _hasAllergies ? 1 : 0,
            'current_special_learning_needs': _hasSpecialNeeds ? 1 : 0,
            'photo_video_consent': _photoConsent,
            'medical_treatment_consent': _medicalConsent,
          };

          _isUploading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
      setState(() {
        _isEditing = true;
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(isDark, accent),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeInAnimation(
                      delay: const Duration(milliseconds: 100),
                      child: _buildAttendanceCard(isDark, accent),
                    ),
                    const SizedBox(height: 40),
                    
                    FadeInAnimation(
                      delay: const Duration(milliseconds: 200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('School Information', LucideIcons.graduationCap, accent),
                          const SizedBox(height: 20),
                          _buildInfoField('Mainstream School', _mainstreamSchoolController, LucideIcons.school, isDark),
                          Row(
                            children: [
                              Expanded(child: _buildInfoField('Mainstream Grade', _mainstreamGradeController, LucideIcons.bookOpen, isDark)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildInfoField('WSTSC Grade', _comSchoolGradeController, LucideIcons.bookmark, isDark, forceDisabled: true)),
                            ],
                          ),
                          _buildInfoField('Name in Community Language', _motherTongueController, LucideIcons.languages, isDark),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    FadeInAnimation(
                      delay: const Duration(milliseconds: 300),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Medical Information', LucideIcons.heart, accent),
                          const SizedBox(height: 20),
                          _buildSwitchField('Asthma', _hasAsthma, LucideIcons.wind, (val) => setState(() => _hasAsthma = val), isDark),
                          _buildSwitchField('Major Illness', _hasMajorIllness, LucideIcons.activity, (val) => setState(() => _hasMajorIllness = val), isDark),
                          _buildSwitchField('Allergies', _hasAllergies, LucideIcons.alertTriangle, (val) => setState(() => _hasAllergies = val), isDark),
                          _buildSwitchField('Special Learning Needs', _hasSpecialNeeds, LucideIcons.brain, (val) => setState(() => _hasSpecialNeeds = val), isDark),
                          if (_hasSpecialNeeds)
                            _buildInfoField('Special Needs Details', _specialNeedsDetailsController, LucideIcons.fileText, isDark),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                    FadeInAnimation(
                      delay: const Duration(milliseconds: 400),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Emergency Contact', LucideIcons.phone, accent),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(child: _buildInfoField('First Name', _emergencyGivenNameController, LucideIcons.user, isDark)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildInfoField('Family Name', _emergencyFamilyNameController, LucideIcons.users, isDark)),
                            ],
                          ),
                          _buildInfoField('Relationship', _emergencyRelationshipController, LucideIcons.heartHandshake, isDark),
                          _buildInfoField('Mobile Phone', _emergencyMobilePhoneController, LucideIcons.smartphone, isDark),
                          _buildInfoField('Home Phone', _emergencyHomePhoneController, LucideIcons.home, isDark),
                          _buildInfoField('Work Phone', _emergencyWorkPhoneController, LucideIcons.briefcase, isDark),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                    FadeInAnimation(
                      delay: const Duration(milliseconds: 500),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Consents & Declarations', LucideIcons.shieldCheck, accent),
                          const SizedBox(height: 20),
                          _buildSwitchField('Photo & Video Consent', _photoConsent, LucideIcons.camera, (val) => setState(() => _photoConsent = val), isDark),
                          _buildSwitchField('Medical Treatment Consent', _medicalConsent, LucideIcons.plusSquare, (val) => setState(() => _medicalConsent = val), isDark),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    if (!_isEditing)
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: () => setState(() => _isEditing = true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 0,
                          ),
                          child: Text(
                            'Edit Profile',
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setState(() => _isEditing = false),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _saveProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.darkSuccess,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                elevation: 0,
                              ),
                              child: Text('Save Changes', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(bool isDark, Color accent) {
    // Debug info for image troubleshooting
    debugPrint('StudentDetail keys: ${_studentData.keys.toList()}');
    if (_studentData.containsKey('stu_image')) debugPrint('stu_image: ${_studentData['stu_image']}');
    if (_studentData.containsKey('student_image')) debugPrint('student_image: ${_studentData['student_image']}');

    String? photoUrl = _studentData['student_image'] ?? _studentData['stu_image_url'] ?? _studentData['stu_image'];
    
    // Resolve photo URL and address potential CORS issues on Web
    if (photoUrl != null && photoUrl.isNotEmpty) {
      // If it's a relative path or a direct storage link, route it through the API image endpoint
      // This endpoint is more likely to handle CORS/Permissions correctly than static storage
      if (!photoUrl.startsWith('http') || photoUrl.contains('/backend/storage/')) {
        final String filename = photoUrl.contains('/') ? photoUrl.split('/').last : photoUrl;
        photoUrl = 'https://wstsc.org.au/backend/api/student-image/$filename';
      }
    } else {
      photoUrl = null;
    }
    
    final String displayName = _studentData['student_name'] ?? _studentData['full_name'] ?? 'Student Profile';
    
    debugPrint('Detail Screen Final photoUrl: $photoUrl');

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (isDark ? Colors.black26 : Colors.white70).withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: BackButton(color: isDark ? Colors.white : Colors.black87),
      ),
      actions: [
        if (_isUploading)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          )
        else if (!_isEditing)
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isDark ? Colors.black26 : Colors.white70).withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(LucideIcons.edit3, size: 20, color: isDark ? Colors.white : Colors.black87),
              onPressed: () => setState(() => _isEditing = true),
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent.withOpacity(0.8), accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: _pickedImage != null
                ? Image.network(_pickedImage!.path, fit: BoxFit.cover)
                : (photoUrl != null
                  ? Image.network(
                      photoUrl, 
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('Image load failed for $photoUrl: $error');
                        return _buildPlaceholderAvatar(displayName);
                      },
                    )
                  : _buildPlaceholderAvatar(displayName)),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, (isDark ? AppTheme.darkBg : AppTheme.lightBg).withOpacity(0.8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 24,
              right: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    'Student ID: ${_studentData['studid']}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: (isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
            if (_isEditing)
              Positioned.fill(
                child: Material(
                  color: Colors.black38,
                  child: InkWell(
                    onTap: _pickImage,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.camera, color: Colors.white, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'Change Photo',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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

  Widget _buildAttendanceCard(bool isDark, Color accent) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.darkSuccess.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.calendarCheck, color: AppTheme.darkSuccess),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_attendancePercentage.toStringAsFixed(0)}% Attendance',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  _totalDays > 0 
                      ? 'Based on $_totalDays recorded sessions'
                      : 'No attendance records yet',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StudentAttendanceHistoryScreen(
                    studid: _studentData['studid'].toString(),
                    studentName: _studentData['student_name'],
                  ),
                ),
              );
            },
            icon: Icon(LucideIcons.history, color: accent),
            tooltip: 'View History',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color accent) {
    return Row(
      children: [
        Icon(icon, size: 20, color: accent),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildInfoField(String label, TextEditingController controller, IconData icon, bool isDark, {bool forceDisabled = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: _isEditing && !forceDisabled,
        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(color: Colors.grey),
          prefixIcon: Icon(icon, size: 20, color: isDark ? Colors.white70 : Colors.black45),
          filled: true,
          fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

  Widget _buildSwitchField(String label, bool value, IconData icon, Function(bool) onChanged, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isDark ? Colors.white70 : Colors.black45),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            Switch(
              value: value,
              onChanged: _isEditing ? onChanged : null,
              activeColor: AppTheme.darkSuccess,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderAvatar(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0] : 'S',
        style: GoogleFonts.outfit(
          fontSize: 80,
          fontWeight: FontWeight.bold,
          color: Colors.white.withOpacity(0.5),
        ),
      ),
    );
  }
}
