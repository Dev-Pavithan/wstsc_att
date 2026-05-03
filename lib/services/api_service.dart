import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ApiService {
  static const String baseUrl = 'https://wstsc.org.au/backend/api';

  String get _url => baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      // Removed device_id from headers to bypass CORS preflight
    };
  }

  Future<dynamic> get(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_id') ?? '';
    
    final token = prefs.getString('auth_token') ?? '';
    
    // Append device_id and token as query parameters to bypass CORS and header stripping
    final uri = Uri.parse('$_url/$endpoint');
    final queryParams = Map<String, String>.from(uri.queryParameters);
    queryParams['device_id'] = deviceId;
    queryParams['token'] = token;
    
    final finalUrl = uri.replace(queryParameters: queryParams);
    final headers = await _getHeaders();
    
    debugPrint('API GET: $finalUrl');
    final response = await http.get(finalUrl, headers: headers);
    debugPrint('API Response [${response.statusCode}]: ${response.body}');
    
    return _handleResponse(response);
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_id') ?? '';
    
    final token = prefs.getString('auth_token') ?? '';
    
    // Append device_id and token as query parameters to bypass CORS and header stripping
    final uri = Uri.parse('$_url/$endpoint');
    final queryParams = Map<String, String>.from(uri.queryParameters);
    queryParams['device_id'] = deviceId;
    queryParams['token'] = token;
    
    final finalUrl = uri.replace(queryParameters: queryParams);
    final headers = await _getHeaders();
    
    debugPrint('API POST: $finalUrl');
    debugPrint('API Body: ${jsonEncode(body)}');
    final response = await http.post(finalUrl, headers: headers, body: jsonEncode(body));
    debugPrint('API Response [${response.statusCode}]: ${response.body}');
    
    return _handleResponse(response);
  }

  Future<dynamic> getProfile() async {
    return await get('profile/person');
  }

  Future<dynamic> updateProfile(Map<String, dynamic> data) async {
    return await post('profile/update', data);
  }

  Future<dynamic> updatePasscode(String currentPasscode, String newPasscode) async {
    return await post('update-passcode', {
      'current_passcode': currentPasscode,
      'new_passcode': newPasscode,
    });
  }

  Future<dynamic> updateProfilePicture(XFile xFile) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_id') ?? '';
    
    // Append device_id as query parameter
    final uri = Uri.parse('$_url/profile/picture');
    final finalUrl = uri.replace(queryParameters: {
      ...uri.queryParameters,
      'device_id': deviceId,
    });
    
    final token = prefs.getString('auth_token') ?? '';

    var request = http.MultipartRequest('POST', finalUrl);
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    if (kIsWeb) {
      // Use bytes for web
      final bytes = await xFile.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'profile_picture',
        bytes,
        filename: xFile.name,
      ));
    } else {
      // Use path for mobile/desktop
      request.files.add(await http.MultipartFile.fromPath('profile_picture', xFile.path));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    debugPrint('API Multipart POST: $finalUrl');
    debugPrint('API Response [${response.statusCode}]: ${response.body}');
    
    return _handleResponse(response);
  }

  Future<dynamic> markTeacherAttendance(String token) async {
    return await post('teacher-attendance/mark', {'token': token});
  }

  Future<dynamic> getDailyTeacherQrToken() async {
    return await get('teacher-attendance/daily-token');
  }

  Future<dynamic> getTeacherAttendanceHistory() async {
    return await get('teacher-attendance/history');
  }

  Future<dynamic> getParentStudents() async {
    try {
      return await get('parent/students');
    } catch (e) {
      // Fallback for servers where the above endpoint is not configured/accessible (405 Method Not Allowed)
      final errorStr = e.toString();
      if (errorStr.contains('405') || 
          errorStr.contains('Method Not Allowed') || 
          errorStr.contains('method is not supported')) {
        debugPrint('Fallback: Detected 405/Method Error. Attempting to fetch students via profile PEID...');
        try {
          final profileResponse = await getProfile();
          if (profileResponse['success'] == true) {
            final peid = profileResponse['data']?['profile']?['peid'];
            if (peid != null) {
              final fallbackResponse = await get('students/parents/with-students-complete/$peid');
              // Ensure the structure matches what the dashboard expects: response['data']['students']
              if (fallbackResponse['success'] == true && fallbackResponse['data'] != null) {
                return fallbackResponse;
              }
            }
          }
        } catch (fallbackError) {
          debugPrint('Fallback mechanism failed: $fallbackError');
        }
      }
      rethrow;
    }
  }

  Future<dynamic> getStudentAttendanceHistory(String studid) async {
    try {
      return await get('attendance/student/$studid');
    } catch (e) {
      if (e.toString().contains('405')) {
        debugPrint('GET failed with 405 for attendance history, trying POST...');
        try {
          return await post('attendance/student/$studid', {});
        } catch (postError) {
          debugPrint('POST fallback also failed: $postError');
        }
      }
      
      // Try another common endpoint
      try {
        return await get('attendance/history/student/$studid');
      } catch (_) {
        rethrow;
      }
    }
  }


  Future<dynamic> getStudentImage(String studid) async {
    return await get('student-images/$studid');
  }


  Future<dynamic> uploadStudentImage(String studid, XFile xFile) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_id') ?? '';
    
    // Append device_id as query parameter
    final uri = Uri.parse('$_url/student-images/upload');
    final finalUrl = uri.replace(queryParameters: {
      ...uri.queryParameters,
      'device_id': deviceId,
    });
    
    final token = prefs.getString('auth_token') ?? '';

    var request = http.MultipartRequest('POST', finalUrl);
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    request.fields['studid'] = studid;

    if (kIsWeb) {
      final bytes = await xFile.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'stu_image',
        bytes,
        filename: xFile.name,
      ));
    } else {
      request.files.add(await http.MultipartFile.fromPath('stu_image', xFile.path));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    debugPrint('API Student Image POST: $finalUrl');
    debugPrint('API Response [${response.statusCode}]: ${response.body}');
    
    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      final decoded = jsonDecode(response.body);
      throw Exception('HTTP ${response.statusCode}: ${decoded['message'] ?? decoded['error'] ?? 'API Error'}');
    }
  }
}
