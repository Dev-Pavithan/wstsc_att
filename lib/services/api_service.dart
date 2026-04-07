import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ApiService {
  static const String baseUrl = 'https://urbanviewre.com/wstsc-backend/api';

  String get _url => baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final deviceId = prefs.getString('device_id') ?? '';
    
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'device_id': deviceId,
    };
  }

  Future<dynamic> get(String endpoint) async {
    final url = Uri.parse('$_url/$endpoint');
    final headers = await _getHeaders();
    
    debugPrint('API GET: $url');
    final response = await http.get(url, headers: headers);
    debugPrint('API Response [${response.statusCode}]: ${response.body}');
    
    return _handleResponse(response);
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('$_url/$endpoint');
    final headers = await _getHeaders();
    
    debugPrint('API POST: $url');
    debugPrint('API Body: ${jsonEncode(body)}');
    final response = await http.post(url, headers: headers, body: jsonEncode(body));
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
    final url = Uri.parse('$_url/profile/picture');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final deviceId = prefs.getString('device_id') ?? '';

    var request = http.MultipartRequest('POST', url);
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'device_id': deviceId,
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
    
    debugPrint('API Multipart POST: $url');
    debugPrint('API Response [${response.statusCode}]: ${response.body}');
    
    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['message'] ?? decoded['error'] ?? 'API Error');
    }
  }
}
