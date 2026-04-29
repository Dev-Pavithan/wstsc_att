import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../services/biometric_service.dart';
import 'login_screen.dart';
import 'dart:async';

class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const AppLockScreen({super.key, required this.onUnlocked});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isAuthenticating = false;
  int _failedAttempts = 0;
  DateTime? _cooldownUntil;
  Timer? _cooldownTimer;
  bool _showPinInput = false;
  String _pinBuffer = "";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    /*
    // Auto-authenticate on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleAuth();
    });
    */
  }

  @override
  void dispose() {
    _controller.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  /*
  Future<void> _handleAuth() async {
    if (_isAuthenticating || _isLockedOut()) return;
    
    setState(() => _isAuthenticating = true);
    final authenticated = await BiometricService.authenticate();
    setState(() => _isAuthenticating = false);

    if (mounted && authenticated) {
      _failedAttempts = 0;
      widget.onUnlocked();
    } else {
      _incrementFailure();
    }
  }
  */
  void _handleAuth() {} // STUB

  bool _isLockedOut() {
    if (_cooldownUntil == null) return false;
    return DateTime.now().isBefore(_cooldownUntil!);
  }

  void _incrementFailure() {
    _failedAttempts++;
    if (_failedAttempts >= 3) {
      _failedAttempts = 0;
      _cooldownUntil = DateTime.now().add(const Duration(seconds: 30));
      _startCooldownTimer();
    }
    setState(() {});
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (!_isLockedOut()) {
        timer.cancel();
      }
      setState(() {});
    });
  }

  Future<void> _handlePinInput(String digit) async {
    if (_pinBuffer.length >= 4) return;
    
    setState(() => _pinBuffer += digit);
    
    if (_pinBuffer.length == 4) {
      final prefs = await SharedPreferences.getInstance();
      final correctPin = prefs.getString('cached_passcode') ?? "";
      
      if (_pinBuffer == correctPin) {
        widget.onUnlocked();
      } else {
        setState(() {
          _pinBuffer = "";
          _incrementFailure();
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false, // STICKY LOCK: No back button bypass
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Scaffold(
          backgroundColor: (isDark ? AppTheme.darkBg : AppTheme.lightBg).withOpacity(0.85),
          body: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _showPinInput ? _buildPinScreen(isDark) : _buildAuthScreen(isDark),
                  ),
                ),
              ),
              
              // Logout Emergency Fallback
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: TextButton.icon(
                    onPressed: _handleLogout,
                    icon: const Icon(LucideIcons.logOut, size: 14, color: Colors.white24),
                    label: Text('Logout & Reset', 
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white24)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthScreen(bool isDark) {
    return Column(
      key: const ValueKey('auth_screen'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Biometric UI
        _buildGlowIcon(),
        const SizedBox(height: 48),
        Text('WSTSC Locked',
          style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        
        if (_isLockedOut())
           Text('Try again in ${ _cooldownUntil!.difference(DateTime.now()).inSeconds }s',
              style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold))
        else
          Text('Verify identity to unlock',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white38)),
        
        const SizedBox(height: 64),
        
        /*
        ElevatedButton.icon(
          onPressed: _isLockedOut() ? null : _handleAuth,
          icon: const Icon(LucideIcons.shieldCheck, size: 20),
          label: Text(_isAuthenticating ? 'Authenticating...' : 'Unlock Now'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.darkAccent,
            foregroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 64),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
        
        const SizedBox(height: 24),
        */
        TextButton(
          onPressed: () => setState(() => _showPinInput = true),
          child: Text('Use App PIN', style: GoogleFonts.inter(color: Colors.white60)),
        ),
      ],
    );
  }

  Widget _buildPinScreen(bool isDark) {
    return Column(
      key: const ValueKey('pin_screen'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Enter Secret PIN', 
          style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 48),
        
        // Passcode Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 16, height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index < _pinBuffer.length ? AppTheme.darkAccent : Colors.white10,
            ),
          )),
        ),
        
        const SizedBox(height: 64),
        
        if (_isLockedOut())
           Text('Security Wait: ${ _cooldownUntil!.difference(DateTime.now()).inSeconds }s',
              style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold))
        else
          _buildPinPad(),
          
        const SizedBox(height: 48),
        /*
        TextButton.icon(
          onPressed: () => setState(() { _showPinInput = false; _pinBuffer = ""; }),
          icon: const Icon(LucideIcons.fingerprint, size: 16),
          label: Text('Back to Biometrics', style: GoogleFonts.inter(color: Colors.white30)),
        ),
        */
      ],
    );
  }

  Widget _buildPinPad() {
    return Wrap(
      spacing: 24, runSpacing: 24,
      alignment: WrapAlignment.center,
      children: List.generate(10, (index) {
        int val = (index + 1) % 10;
        return InkWell(
          onTap: () => _handlePinInput(val.toString()),
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 70, height: 70,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10),
            ),
            child: Text(val.toString(), style: GoogleFonts.inter(fontSize: 24, color: Colors.white)),
          ),
        );
      }),
    );
  }

  Widget _buildGlowIcon() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.darkAccent.withOpacity(0.1 + (0.2 * _controller.value)),
              blurRadius: 30, spreadRadius: 10 * _controller.value,
            )
          ],
          border: Border.all(color: AppTheme.darkAccent.withOpacity(0.1 + (0.3 * _controller.value)), width: 2),
        ),
        child: Icon(LucideIcons.fingerprint, size: 72, color: AppTheme.darkAccent),
      ),
    );
  }
}
