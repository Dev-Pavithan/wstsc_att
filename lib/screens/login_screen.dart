import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import '../app_theme.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';
import 'dashboard_wrapper.dart';
import 'link_device_screen.dart';
import 'forgot_passcode_screen.dart';
import '../main.dart'; // Added for dashboardIndexNotifier support (needed by AppBar if we jump)

class LoginScreen extends StatefulWidget {
  final bool showInstallPrompt;

  const LoginScreen({super.key, this.showInstallPrompt = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _passcode = "";
  bool _isLoading = false;
  final String _correctPasscode = "1234";
  bool _isDeviceLinked = false;
  bool _biometricsEnabled = false;
  bool _hideInstallBanner = false;

  @override
  void initState() {
    super.initState();
    _checkDeviceLink();
  }

  void _checkDeviceLink() async {
    final prefs = await SharedPreferences.getInstance();
    final linked = prefs.getBool('is_device_linked') ?? false;
    // MATCHING THE KEY USED IN BIOMETRIC SERVICE
    final bioEnabled = prefs.getBool('biometric_lock_enabled') ?? false; 
    
    setState(() {
      _isDeviceLinked = linked;
      _biometricsEnabled = bioEnabled;
    });

    if (linked && bioEnabled) {
      // Auto-trigger biometric on start if enabled
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) _handleBiometric();
      });
    }
  }

  void _handleKeyPress(String key) {
    if (_passcode.length < 4) {
      setState(() {
        _passcode += key;
      });
      if (_passcode.length == 4) {
        _verifyPasscode();
      }
    }
  }

  void _handleDelete() {
    if (_passcode.isNotEmpty) {
      setState(() {
        _passcode = _passcode.substring(0, _passcode.length - 1);
      });
    }
  }

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

  Future<void> _handleBiometric() async {
    final bool didAuth = await BiometricService.authenticate();

    if (didAuth && mounted) {
      final prefs = await SharedPreferences.getInstance();
      final cachedPin = prefs.getString('cached_passcode') ?? "";
      if (cachedPin.isNotEmpty) {
        setState(() => _passcode = cachedPin);
        _verifyPasscode();
      }
    } else if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Authentication failed. Please use PIN.'), behavior: SnackBarBehavior.floating),
       );
    }
  }

  void _verifyPasscode() async {
    setState(() => _isLoading = true);

    try {
      final deviceId = await _getDeviceId();
      
      const String apiUrl = 'https://urbanviewre.com/wstsc-backend/api/device-login';
      final url = Uri.parse(apiUrl);
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'device_id': deviceId,
          'passcode': _passcode,
          'device_name': kIsWeb ? 'Web Browser' : defaultTargetPlatform.name,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('auth_token', data['token'] ?? '');
        await prefs.setString('cached_passcode', _passcode);

        final bool bioEnabled = await BiometricService.isLockEnabled();
        final bool canBio = await BiometricService.isAvailable();

        if (!bioEnabled && canBio && mounted) {
          _showEnableBiometricDialog(context);
          return;
        }
        
        if (mounted) _proceedToDashboard();
      } else if (response.statusCode == 404) {
        final data = jsonDecode(response.body);
        if (data['code'] == 'DEVICE_NOT_FOUND') {
          setState(() {
            _isLoading = false;
            _passcode = "";
          });
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LinkDeviceScreen()),
            );
          }
        }
      } else {
        _handleLoginError(response);
      }
    } catch (e) {
      _handleNetworkError(e);
    }
  }

  void _handleLoginError(http.Response response) {
    final errorMsg = jsonDecode(response.body)['message'] ?? 'Authentication failed';
    setState(() {
      _isLoading = false;
      _passcode = "";
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: AppTheme.darkError, behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _handleNetworkError(dynamic e) {
    setState(() {
      _isLoading = false;
      _passcode = "";
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: please check connection.'), backgroundColor: AppTheme.darkError, behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _showEnableBiometricDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('Enable Fingerprint Login?', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Would you like to use your fingerprint for faster, more secure logins in the future?', 
          style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => _proceedToDashboard(),
            child: Text('Maybe Later', style: GoogleFonts.inter(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await BiometricService.authenticate();
              if (ok) {
                await BiometricService.setLockEnabled(true);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fingerprint Login Enabled!')));
                  _proceedToDashboard();
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.darkAccent, foregroundColor: Colors.black),
            child: const Text('Enable Now'),
          ),
        ],
      ),
    );
  }

  void _proceedToDashboard() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const DashboardWrapper(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  void _navigateToLink() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LinkDeviceScreen()),
    );
  }

  void _navigateToForgot() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ForgotPasscodeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool showBanner = widget.showInstallPrompt && !_hideInstallBanner;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                Hero(
                  tag: 'app_logo',
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        'logo.png',
                        width: 64,
                        height: 64,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(LucideIcons.school, size: 48, color: AppTheme.darkAccent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Verify & Continue', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Text('Enter your 4-digit security PIN', style: GoogleFonts.inter(color: Colors.white54)),
                const SizedBox(height: 48),
                
                // Passcode Dots
                _isLoading 
                  ? CircularProgressIndicator(color: AppTheme.darkAccent)
                  : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) => _buildDot(index < _passcode.length)),
                  ),
                
                const Spacer(flex: 3),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _navigateToForgot,
                      child: Text('Forgot PIN?', style: GoogleFonts.inter(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.normal)),
                    ),
                    if (!_isDeviceLinked) ...[
                      const Text(' • ', style: TextStyle(color: Colors.white24)),
                      TextButton(
                        onPressed: _navigateToLink,
                        child: Text('Register New Device', style: GoogleFonts.inter(color: AppTheme.darkAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 12),

                // Keypad
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  child: Column(
                    children: [
                      _buildKeypadRow(['1', '2', '3']),
                      _buildKeypadRow(['4', '5', '6']),
                      _buildKeypadRow(['7', '8', '9']),
                      _buildKeypadRow(_biometricsEnabled ? ['0', 'bio', 'del'] : ['', '0', 'del']),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildDot(bool isFilled) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: isFilled ? AppTheme.darkAccent : Colors.white24,
        shape: BoxShape.circle,
        border: isFilled ? null : Border.all(color: Colors.white12),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: keys.map((key) => _buildKey(key)).toList(),
      ),
    );
  }

  Widget _buildKey(String key) {
    if (key.isEmpty || (key == 'bio' && !_biometricsEnabled)) {
       return const SizedBox(width: 70, height: 70);
    }

    Widget child;
    if (key == 'bio') {
      child = const Icon(LucideIcons.fingerprint, color: AppTheme.darkAccent, size: 32);
    } else if (key == 'del') {
      child = const Icon(LucideIcons.delete, color: Colors.white54, size: 24);
    } else {
      child = Text(key, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white));
    }

    return InkWell(
      onTap: () {
        if (key == 'bio') {
          _handleBiometric();
        } else if (key == 'del') {
          _handleDelete();
        } else {
          _handleKeyPress(key);
        }
      },
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 70,
        height: 70,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          shape: BoxShape.circle,
        ),
        child: child,
      ),
    );
  }

  Widget _buildBackground() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0C141C), Color(0xFF151F28), Color(0xFF0C141C)],
      ),
    ),
  );
}
