class Student {
  final int siid;       // Integer PK — used for attendance API calls
  final String id;      // String ID like "STU00001"
  final String name;
  bool isPresent;
  final String? imageUrl;

  Student({required this.siid, required this.id, required this.name, this.isPresent = true, this.imageUrl});

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      siid: (json['studid_int'] as num?)?.toInt() ?? 0,
      id: json['studid']?.toString() ?? '',
      name: json['student_first__name'] != null 
          ? '${json['student_first__name']} ${json['student_family_name']}' 
          : (json['student_name'] ?? 'Unknown'),
      isPresent: json['attended'] == null ? true : (json['attended'] == 1 || json['attended'] == true || json['attended'] == "1"),
      imageUrl: json['stu_image_url'],
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
