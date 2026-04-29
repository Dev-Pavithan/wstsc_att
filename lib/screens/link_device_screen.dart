import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../app_theme.dart';
import 'dashboard_wrapper.dart';

class LinkDeviceScreen extends StatefulWidget {
  const LinkDeviceScreen({super.key});

  @override
  State<LinkDeviceScreen> createState() => _LinkDeviceScreenState();
}

class _LinkDeviceScreenState extends State<LinkDeviceScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscurePIN = true;
  int _step = 1; // 1: Email/Password, 2: Set PIN

  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedId = prefs.getString('device_id');
    if (savedId != null) return savedId;

    String deviceId = 'unknown';
    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (kIsWeb) {
        deviceId = 'web_${DateTime.now().millisecondsSinceEpoch}';
      } else {
        if (defaultTargetPlatform == TargetPlatform.android) {
          final androidInfo = await deviceInfo.androidInfo;
          deviceId = androidInfo.id;
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          final iosInfo = await deviceInfo.iosInfo;
          deviceId = iosInfo.identifierForVendor ?? 'ios_${DateTime.now().millisecondsSinceEpoch}';
        } else {
          deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
        }
      }
    } catch (e) {
      deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
    }
    await prefs.setString('device_id', deviceId);
    return deviceId;
  }

  void _handleLink() async {
    if (_pinController.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN must be 4 digits'), backgroundColor: AppTheme.darkError),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final deviceId = await _getDeviceId();
      const String apiUrl = 'https://wstsc.org.au/backend/api/link-device';

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text,
          'password': _passwordController.text,
          'device_id': deviceId,
          'device_name': kIsWeb ? 'Web Browser' : defaultTargetPlatform.name,
          'passcode': _pinController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_passcode', _pinController.text);
        await prefs.setBool('isLoggedIn', true);
        await prefs.setBool('is_device_linked', true);
        await prefs.setString('auth_token', data['token'] ?? '');
        
        // Save user data
        final userData = data['user'];
        if (userData != null) {
          final personData = userData['person'];
          if (personData != null) {
            final firstName = personData['person_first_name'] ?? '';
            final lastName = personData['person_last_name'] ?? '';
            await prefs.setString('user_name', '$firstName $lastName'.trim());
            await prefs.setString('user_email', personData['person_email'] ?? '');
          }
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardWrapper()),
          );
        }
      } else {
        final msg = jsonDecode(response.body)['message'] ?? 'Failed to link device';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppTheme.darkError),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error'), backgroundColor: AppTheme.darkError),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Stack(
        children: [
          // Background Decorative Elements
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.darkAccent.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            top: 200,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.darkAccent.withOpacity(0.03),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header / AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(LucideIcons.chevronLeft, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.05),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 10),
                        
                        // Visual Illustration
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.darkAccent.withOpacity(0.1),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.darkAccent.withOpacity(0.2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.darkAccent.withOpacity(0.2),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                )
                              ],
                            ),
                            child: Icon(
                              _step == 1 ? LucideIcons.smartphone : LucideIcons.shieldCheck,
                              size: 48,
                              color: AppTheme.darkAccent,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        Text(
                          _step == 1 ? 'Link Device' : 'Secure Your App',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            _step == 1 
                              ? 'Sign in with your staff credentials to authorize this device for attendance.'
                              : 'Set a 4-digit security PIN for quick access to this device.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: Colors.white54,
                              height: 1.5,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 40),

                        // Form Container / Main Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.darkSurface.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 40,
                                offset: const Offset(0, 20),
                              )
                            ],
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.1, 0),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: _step == 1 ? Column(
                              key: const ValueKey('step1'),
                              children: [
                                _buildTextField(
                                  label: 'Staff Email', 
                                  controller: _emailController, 
                                  icon: LucideIcons.mail, 
                                  isPassword: false,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  label: 'Password', 
                                  controller: _passwordController, 
                                  icon: LucideIcons.lock, 
                                  isPassword: true,
                                  isObscured: _obscurePassword,
                                  onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                const SizedBox(height: 32),
                                _buildButton('Continue', () => setState(() => _step = 2)),
                              ],
                            ) : Column(
                              key: const ValueKey('step2'),
                              children: [
                                _buildTextField(
                                  label: 'Security PIN', 
                                  controller: _pinController, 
                                  icon: LucideIcons.key, 
                                  isPassword: true,
                                  isNumber: true, 
                                  maxLength: 4,
                                  isObscured: _obscurePIN,
                                  onToggleObscure: () => setState(() => _obscurePIN = !_obscurePIN),
                                ),
                                const SizedBox(height: 32),
                                _buildButton(
                                  _isLoading ? 'Processing...' : 'Complete Setup', 
                                  _isLoading ? null : _handleLink,
                                  isLoading: _isLoading,
                                ),
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: () => setState(() => _step = 1),
                                  style: TextButton.styleFrom(foregroundColor: Colors.white38),
                                  child: Text('Use different account', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label, 
    required TextEditingController controller, 
    required IconData icon, 
    required bool isPassword, 
    bool isNumber = false, 
    int? maxLength,
    bool? isObscured,
    VoidCallback? onToggleObscure,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isObscured ?? false,
        keyboardType: isNumber ? TextInputType.number : TextInputType.emailAddress,
        inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
        maxLength: maxLength,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          counterText: "",
          labelText: label,
          labelStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
          floatingLabelStyle: GoogleFonts.inter(color: AppTheme.darkAccent, fontWeight: FontWeight.bold),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Icon(icon, color: AppTheme.darkAccent, size: 22),
          ),
          suffixIcon: isPassword ? IconButton(
            icon: Icon(
              isObscured! ? LucideIcons.eyeOff : LucideIcons.eye,
              color: Colors.white38,
              size: 20,
            ),
            onPressed: onToggleObscure,
          ) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback? onPressed, {bool isLoading = false}) {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (onPressed != null)
            BoxShadow(
              color: AppTheme.darkAccent.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.darkAccent,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: isLoading 
          ? const SizedBox(
              width: 24, 
              height: 24, 
              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3)
            )
          : Text(
              text, 
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
            ),
      ),
    );
  }
}
