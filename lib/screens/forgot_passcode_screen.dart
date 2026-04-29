import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ForgotPasscodeScreen extends StatefulWidget {
  const ForgotPasscodeScreen({super.key});

  @override
  State<ForgotPasscodeScreen> createState() => _ForgotPasscodeScreenState();
}

class _ForgotPasscodeScreenState extends State<ForgotPasscodeScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;
  int _step = 1; // 1: Enter Email, 2: Enter Code + New PIN

  String _getApiUrl(String endpoint) {
    const String baseUrl = 'https://wstsc.org.au/backend';
    return '$baseUrl/api/$endpoint';
  }

  Future<void> _sendResetCode() async {
    if (_emailController.text.isEmpty) {
      _showError('Please enter your staff email');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(_getApiUrl('forgot-passcode')),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': _emailController.text.trim()}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        // In demo mode, the backend returns the code for convenience
        if (data.containsKey('reset_code')) {
           _showInfo('Demo Mode: Reset code is ${data['reset_code']}');
        } else {
           _showInfo('Reset code sent to your email');
        }
        setState(() => _step = 2);
      } else {
        _showError(data['message'] ?? 'Failed to send reset code');
      }
    } catch (e) {
      _showError('Network error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPasscode() async {
    if (_codeController.text.length != 6 || _pinController.text.length != 4) {
      _showError('Please enter the 6-digit code and a new 4-digit PIN');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id') ?? 'unknown_device';

      final response = await http.post(
        Uri.parse(_getApiUrl('reset-passcode')),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'reset_code': _codeController.text.trim(),
          'new_passcode': _pinController.text.trim(),
          'device_id': deviceId,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        _showSuccess('Passcode reset successfully! You can now login.');
        Navigator.pop(context);
      } else {
        _showError(data['message'] ?? 'Failed to reset passcode');
      }
    } catch (e) {
      _showError('Network error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.darkAccent),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'Forgot Passcode',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _step == 1 
                  ? 'Enter your email to receive a reset code.' 
                  : 'Enter the 6-digit code and set your new PIN.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 48),

              if (_step == 1) ...[
                _buildTextField('Staff Email', _emailController, LucideIcons.mail, false),
                const SizedBox(height: 32),
                _buildButton(_isLoading ? 'Sending...' : 'Send Reset Code', _isLoading ? null : _sendResetCode),
              ] else ...[
                _buildTextField('6-Digit Reset Code', _codeController, LucideIcons.hash, false, isNumber: true, maxLength: 6),
                const SizedBox(height: 24),
                _buildTextField('New 4-Digit Security PIN', _pinController, LucideIcons.key, false, isNumber: true, maxLength: 4),
                const SizedBox(height: 32),
                _buildButton(_isLoading ? 'Resetting...' : 'Update Passcode', _isLoading ? null : _resetPasscode),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, bool isPassword, {bool isNumber = false, int? maxLength}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: isNumber ? TextInputType.number : TextInputType.emailAddress,
          inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
          maxLength: maxLength,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppTheme.darkAccent, size: 20),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            counterText: "",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.darkAccent, width: 1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButton(String label, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.darkAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
