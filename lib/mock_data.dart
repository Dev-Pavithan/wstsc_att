import 'package:flutter/foundation.dart';

class Student {
  final int siid;       // Integer PK — used for attendance API calls
  final String id;      // String ID like "STU00001"
  final String name;
  bool isPresent;
  final String? imageUrl;
  final String? motherTongue;
  final String? school;
  final String? mainstreamGrade;
  final String? communityGrade;
  final String? asthma;
  final String? majorIllness;
  final String? allergies;
  final String? specialNeeds;
  final String? specialNeedsDetails;
  final String? emergencyName;
  final String? emergencyPhone;
  final String? emergencyRelationship;
  final String? emergencyHomePhone;
  final String? emergencyWorkPhone;
  final String? photoConsent;
  final String? medicalConsent;

  Student({
    required this.siid, 
    required this.id, 
    required this.name, 
    this.isPresent = true, 
    this.imageUrl,
    this.motherTongue,
    this.school,
    this.mainstreamGrade,
    this.communityGrade,
    this.asthma,
    this.majorIllness,
    this.allergies,
    this.specialNeeds,
    this.specialNeedsDetails,
    this.emergencyName,
    this.emergencyPhone,
    this.emergencyRelationship,
    this.emergencyHomePhone,
    this.emergencyWorkPhone,
    this.photoConsent,
    this.medicalConsent,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    // Debug print to help identify available keys in the response
    debugPrint('Student JSON keys: ${json.keys.toList()}');

    String? imageUrl = json['stu_image_url'] ?? json['student_image'] ?? json['stu_image'];
    
    // If it's a relative path or just a filename, format it
    if (imageUrl != null && !imageUrl.startsWith('http')) {
      final String filename = imageUrl.contains('/') ? imageUrl.split('/').last : imageUrl;
      imageUrl = 'https://wstsc.org.au/backend/api/student-image/$filename';
    }

    String? emergencyName;
    if (json['emergency_given_name'] != null || json['emergency_family_name'] != null) {
      emergencyName = '${json['emergency_given_name'] ?? ''} ${json['emergency_family_name'] ?? ''}'.trim();
    }

    return Student(
      siid: (json['studid_int'] as num?)?.toInt() ?? 0,
      id: json['studid']?.toString() ?? '',
      name: json['student_first__name'] != null 
          ? '${json['student_first__name']} ${json['student_family_name']}' 
          : (json['student_name'] ?? 'Unknown'),
      isPresent: json['attended'] == null ? true : (json['attended'] == 1 || json['attended'] == true || json['attended'] == "1"),
      imageUrl: imageUrl,
      motherTongue: json['mother_tongue'],
      school: json['current_mainstream_school'],
      mainstreamGrade: json['current_mainstream_grade']?.toString(),
      communityGrade: json['current_com_school_enr_grade']?.toString(),
      asthma: json['current_asthma']?.toString(),
      majorIllness: json['current_major_illness']?.toString(),
      allergies: json['current_allergies']?.toString(),
      specialNeeds: json['current_special_learning_needs']?.toString(),
      specialNeedsDetails: json['current_special_learning_needs_details'],
      emergencyName: emergencyName,
      emergencyPhone: json['emergency_mobile_phone'],
      emergencyRelationship: json['emergency_relationship'],
      emergencyHomePhone: json['emergency_home_phone'],
      emergencyWorkPhone: json['emergency_work_phone'],
      photoConsent: json['photo_video_consent']?.toString(),
      medicalConsent: json['medical_treatment_consent']?.toString(),
    );
  }
}

class ClassRoom {
  final String id;
  final String name;
  final String? teacherName;
  final List<Student> students;

  ClassRoom({
    required this.id,
    required this.name,
    this.teacherName,
    this.students = const [],
  });

  factory ClassRoom.fromJson(Map<String, dynamic> json) {
    return ClassRoom(
      id: json['class_id'] ?? '',
      name: json['class_name'] ?? 'Unnamed Class',
      teacherName: json['teacher_name'],
      students: (json['students'] as List?)?.map((s) => Student.fromJson(s)).toList() ?? [],
    );
  }
}

class Enrollment {
  final int id;
  final String firstName;
  final String lastName;
  final String status;
  final DateTime? submittedAt;

  Enrollment({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.status,
    this.submittedAt,
  });

  String get fullName => '$firstName $lastName';

  factory Enrollment.fromJson(Map<String, dynamic> json) {
    return Enrollment(
      id: json['enrid'] ?? 0,
      firstName: json['student_first__name'] ?? '',
      lastName: json['student_family_name'] ?? '',
      status: json['student_status'] ?? 'pending',
      submittedAt: json['submitted_at'] != null ? DateTime.tryParse(json['submitted_at']) : null,
    );
  }
}

class AttendanceHistory {
  final DateTime date;
  final String classId;
  final String className;
  final int presentCount;
  final int totalCount;

  AttendanceHistory({
    required this.date,
    required this.classId,
    required this.className,
    required this.presentCount,
    required this.totalCount,
  });

  factory AttendanceHistory.fromJson(Map<String, dynamic> json) {
    return AttendanceHistory(
      date: DateTime.parse(json['mark_date']),
      classId: json['class_id'] ?? '',
      className: json['class_name'] ?? 'Class',
      presentCount: json['present_count'] ?? 0,
      totalCount: json['total_count'] ?? 0,
    );
  }
}
