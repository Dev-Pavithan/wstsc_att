import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_theme.dart';
import 'login_screen.dart';

class InstallScreen extends StatelessWidget {
  const InstallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppTheme.darkBg, Color(0xFF1E1B4B)],
              ),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon
                  Hero(
                    tag: 'app_logo',
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.darkAccent.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.darkAccent.withOpacity(0.2)),
                      ),
                      child: const Icon(LucideIcons.smartphone, size: 80, color: AppTheme.darkAccent),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  Text(
                    'Install Attendance Pro',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'To access your classroom attendance management, please install the app on your home screen.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 16, color: Colors.white54, height: 1.5),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Instruction Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        _buildStep(1, 'Tap the share icon in your browser'),
                        const SizedBox(height: 16),
                        _buildStep(2, 'Select "Add to Home Screen"'),
                        const SizedBox(height: 16),
                        _buildStep(3, 'Open the app from your home screen'),
                      ],
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Temporary Bypass (For Demo/Dev)
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                    },
                    child: Text(
                      'I\'ve already installed it',
                      style: GoogleFonts.inter(color: AppTheme.darkAccent, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String text) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: AppTheme.darkAccent,
          child: Text(number.toString(), style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(color: Colors.white.withOpacity(0.9), fontSize: 14),
          ),
        ),
      ],
    );
  }
}
