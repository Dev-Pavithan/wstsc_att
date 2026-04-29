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
    
    // Append device_id as query parameter to bypass CORS
    final uri = Uri.parse('$_url/$endpoint');
    final queryParams = Map<String, String>.from(uri.queryParameters);
    queryParams['device_id'] = deviceId;
    
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
    
    // Append device_id as query parameter to bypass CORS
    final uri = Uri.parse('$_url/$endpoint');
    final queryParams = Map<String, String>.from(uri.queryParameters);
    queryParams['device_id'] = deviceId;
    
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

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['message'] ?? decoded['error'] ?? 'API Error');
    }
  }
}
