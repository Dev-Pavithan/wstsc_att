import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'screens/dashboard_wrapper.dart';
import 'screens/login_screen.dart';
import 'screens/link_device_screen.dart';
import 'screens/app_lock_screen.dart';

final ValueNotifier<bool> appLockNotifier = ValueNotifier(false);
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
final ValueNotifier<int> dashboardIndexNotifier = ValueNotifier(0);
final ValueNotifier<Map<String, dynamic>?> profileNotifier = ValueNotifier(null);
final ValueNotifier<int> attendanceRefreshNotifier = ValueNotifier(0);
final ValueNotifier<int> globalRefreshNotifier = ValueNotifier(0);

void main() async {
  print("DEBUG: App main() starting...");
  WidgetsFlutterBinding.ensureInitialized();
  print("DEBUG: Binding initialized");
  
  final prefs = await SharedPreferences.getInstance();
  print("DEBUG: SharedPreferences acquired");
  
  final bool isDarkMode = prefs.getBool('isDarkMode') ?? true;
  themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;

  print("DEBUG: Running runApp...");
  runApp(AttendanceApp(prefs: prefs));
}

class AttendanceApp extends StatelessWidget {
  final SharedPreferences prefs;
  const AttendanceApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'WSTSC',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          home: const SplashGate(),
        );
      },
    );
  }
}

class LockWrapper extends StatefulWidget {
  final Widget child;
  const LockWrapper({super.key, required this.child});

  @override
  State<LockWrapper> createState() => _LockWrapperState();
}

class _LockWrapperState extends State<LockWrapper> with WidgetsBindingObserver {
  int _lastActiveTime = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final bool lockEnabled = prefs.getBool('biometric_lock_enabled') ?? false;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _lastActiveTime = DateTime.now().millisecondsSinceEpoch;
    } else if (state == AppLifecycleState.resumed) {
      /*
      if (isLoggedIn && lockEnabled) {
        final int currentTime = DateTime.now().millisecondsSinceEpoch;
        final int inactiveDuration = currentTime - _lastActiveTime;

        // Lock if inactive for more than 30 seconds
        if (inactiveDuration > 30000) {
          appLockNotifier.value = true;
        }
      }
      */
      // Reset to prevent infinite loops from overlay dialogs
      _lastActiveTime = DateTime.now().millisecondsSinceEpoch;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ValueListenableBuilder<bool>(
          valueListenable: appLockNotifier,
          builder: (context, isLocked, _) {
            if (!isLocked) return const SizedBox.shrink();
            return Material(
              color: Colors.transparent,
              child: AppLockScreen(
                onUnlocked: () => appLockNotifier.value = false,
              ),
            );
          },
        ),
      ],
    );
  }
}

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  void _checkStatus() async {
    print("DEBUG: SplashGate _checkStatus starting");
    final prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final bool isDeviceLinked = prefs.getBool('is_device_linked') ?? false;
    
    print("DEBUG: isLoggedIn: $isLoggedIn, isDeviceLinked: $isDeviceLinked");
    
    await Future.delayed(const Duration(milliseconds: 500)); 

    if (!mounted) return;

    if (isLoggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardWrapper()),
      );
    } else if (!isDeviceLinked) {
      // First-time setup - force link device
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LinkDeviceScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen(showInstallPrompt: false)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Using a simple styled container as logo to avoid network image hang issues
            Hero(
              tag: 'app_logo',
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.darkAccent : AppTheme.lightAccent).withOpacity(0.1), 
                  shape: BoxShape.circle
                ),
                child: Icon(
                  Icons.school_rounded,
                  size: 80, 
                  color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'WSTSC',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'ATTENDANCE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            const SizedBox(height: 64),
            CircularProgressIndicator(
              strokeWidth: 3,
              color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent
            ),
          ],
        ),
      ),
    );
  }
}
