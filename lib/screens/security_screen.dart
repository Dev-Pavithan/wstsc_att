import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_theme.dart';
import '../widgets/custom_app_bar.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../services/biometric_service.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final enabled = await BiometricService.isLockEnabled();
    setState(() => _biometricEnabled = enabled);
  }

  Future<void> _toggleBiometrics() async {
    if (!_biometricEnabled) {
      // Trying to enable
      final canAuth = await BiometricService.canCheckBiometrics();
      if (!canAuth) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometrics not available on this device')),
        );
        return;
      }

      final authenticated = await BiometricService.authenticate();
      if (authenticated) {
        await BiometricService.setLockEnabled(true);
        setState(() => _biometricEnabled = true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric Lock Enabled Successfully')),
        );
      }
    } else {
      // Turning off
      await BiometricService.setLockEnabled(false);
      setState(() => _biometricEnabled = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric Lock Disabled')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(),
      body: PageView(
        controller: _pageController,
        onPageChanged: (idx) => setState(() => _currentPage = idx),
        children: [
          _buildPasscodePage(isDark),
          _buildBiometricPage(isDark),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPageIndicator(0),
            const SizedBox(width: 8),
            _buildPageIndicator(1),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator(int index) {
    bool isSelected = _currentPage == index;
    return Container(
      width: isSelected ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.darkAccent : Colors.grey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildPasscodePage(bool isDark) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            const HeroIconBox(icon: LucideIcons.shieldCheck),
            const SizedBox(height: 32),
            Text('Set Up Security', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 34)),
            const SizedBox(height: 16),
            Text(
              'Protecting student data is our priority.\nSecure your account to ensure sensitive\nrecords remain confidential and\naccessible only by you.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 48),
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.keyboard, color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent),
                      const SizedBox(width: 12),
                      Text('Set Passcode', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildDot(true),
                      _buildDot(false),
                      _buildDot(false),
                      _buildDot(false),
                    ],
                  ),
                  const SizedBox(height: 48),
                  _buildKeypad(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(bool filled) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: filled ? AppTheme.darkAccent : Colors.white24,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildKeypad(bool isDark) {
    return Column(
      children: [
        _buildKeyRow(['1', '2', '3'], isDark),
        _buildKeyRow(['4', '5', '6'], isDark),
        _buildKeyRow(['7', '8', '9'], isDark),
        _buildKeyRow(['', '0', 'back'], isDark),
      ],
    );
  }

  Widget _buildKeyRow(List<String> keys, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: keys.map((k) => _buildKey(k, isDark)).toList(),
      ),
    );
  }

  Widget _buildKey(String key, bool isDark) {
    if (key.isEmpty) return const SizedBox(width: 70);
    if (key == 'back') return IconButton(onPressed: () {}, icon: const Icon(LucideIcons.delete, color: Colors.white60));

    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(key, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white70)),
        ),
      ),
    );
  }

  Widget _buildBiometricPage(bool isDark) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.lock, color: isDark ? Colors.lightGreen : Colors.green),
                      const SizedBox(width: 12),
                      Text('Device Security', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Use your phone’s built-in authentication for faster, more secure access.', style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(child: _buildBiometricCard(LucideIcons.smile, 'FACE ID', isDark, isSelected: _biometricEnabled)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildBiometricCard(LucideIcons.fingerprint, 'TOUCH ID', isDark, isSelected: _biometricEnabled)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _toggleBiometrics,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor: _biometricEnabled ? AppTheme.darkError.withOpacity(0.1) : (isDark ? AppTheme.darkAccent : AppTheme.lightAccent),
                      foregroundColor: _biometricEnabled ? AppTheme.darkError : (isDark ? Colors.black : Colors.white),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      border: _biometricEnabled ? BorderSide(color: AppTheme.darkError) : null,
                    ),
                    child: Text(_biometricEnabled ? 'Disable Biometric Lock' : 'Enable Biometric Lock'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          value: _biometricEnabled ? 1.0 : 0.75,
                          strokeWidth: 6,
                          backgroundColor: Colors.white10,
                          color: _biometricEnabled ? AppTheme.darkSuccess : (isDark ? Colors.white30 : Colors.grey.shade300),
                        ),
                      ),
                      Text(_biometricEnabled ? '100%' : '75%', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _biometricEnabled ? AppTheme.darkSuccess : Colors.white30)),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Security Health', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
                        const SizedBox(height: 4),
                        Text(
                          _biometricEnabled 
                            ? 'Your account is fully protected with biometric security.' 
                            : 'Setting up biometrics will complete your account protection profile.', 
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            Text('Attendly uses bank-grade encryption to secure all local and cloud data.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildBiometricCard(IconData icon, String label, bool isDark, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: isSelected ? Border.all(color: (isDark ? AppTheme.darkAccent : AppTheme.lightAccent).withOpacity(0.3)) : null,
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent),
          const SizedBox(height: 16),
          Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)),
        ],
      ),
    );
  }
}

class HeroIconBox extends StatelessWidget {
  final IconData icon;
  const HeroIconBox({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.darkAccent.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 64, color: AppTheme.darkAccent),
    );
  }
}
