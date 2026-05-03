import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_theme.dart';
import 'attendance_screen.dart';
import 'class_list_screen.dart';
import 'history_screen.dart';
import 'summary_screen.dart';
import 'profile_screen.dart';
import 'parent_dashboard_screen.dart';
import 'parent_children_screen.dart';
import '../widgets/custom_app_bar.dart';
import '../main.dart'; // Import to access dashboardIndexNotifier
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'dart:convert';

class DashboardWrapper extends StatefulWidget {
  const DashboardWrapper({super.key});

  @override
  State<DashboardWrapper> createState() => _DashboardWrapperState();
}

class _DashboardWrapperState extends State<DashboardWrapper> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: dashboardIndexNotifier.value);
    _loadInitialProfile();
    
    // Listen for role changes to reset navigation if needed
    currentRoleNotifier.addListener(_handleRoleChange);
    // Sync PageController if dashboardIndexNotifier changes from elsewhere
    dashboardIndexNotifier.addListener(_syncPageController);
  }

  void _syncPageController() {
    if (_pageController.hasClients && _pageController.page?.round() != dashboardIndexNotifier.value) {
      _pageController.animateToPage(
        dashboardIndexNotifier.value,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutQuart,
      );
    }
  }

  @override
  void dispose() {
    currentRoleNotifier.removeListener(_handleRoleChange);
    dashboardIndexNotifier.removeListener(_syncPageController);
    _pageController.dispose();
    super.dispose();
  }

  void _handleRoleChange() {
    bool isParent = currentRoleNotifier.value.toLowerCase().contains('parent');
    if (isParent) {
      // If current screen is a teacher-only screen (2 or 3), reset to Dashboard (0)
      if (dashboardIndexNotifier.value > 1 && dashboardIndexNotifier.value < 4) {
        dashboardIndexNotifier.value = 0;
      }
    }
  }

  Future<void> _loadInitialProfile() async {
    try {
      final response = await ApiService().getProfile();
      if (response['success']) {
        final profile = response['data']['profile'];
        profileNotifier.value = profile;

        // Role filtering logic: Only Teacher and Parent roles are allowed
        List<dynamic> allRoles = profile['all_roles'] ?? [];
        List<dynamic> relevantRoles = allRoles.where((role) {
          String name = (role['display_name'] ?? '').toString().toLowerCase();
          return name.contains('teacher') || name.contains('parent');
        }).toList();

        if (relevantRoles.isEmpty) {
          // If no allowed role is found, deny access
          _handleLogout();
          return;
        }

        // If the user has exactly one allowed role, force the app to that role
        if (relevantRoles.length == 1) {
          currentRoleNotifier.value = relevantRoles.first['display_name'];
        }
        // If they have both, they will have the option to switch in the profile screen
      }
    } catch (e) {
      debugPrint('Error loading initial profile: $e');
    }
  }

  void _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Denied: You must be a Teacher or Parent to use this app.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ValueListenableBuilder<String>(
      valueListenable: currentRoleNotifier,
      builder: (context, currentRole, _) {
        bool isParent = currentRole.toLowerCase().contains('parent');
        
        return ValueListenableBuilder<int>(
          valueListenable: dashboardIndexNotifier,
          builder: (context, selectedIndex, _) {
            String? currentTitle;
            bool showLogo = true;

            switch (selectedIndex) {
              case 1:
                currentTitle = isParent ? 'My Children' : 'Daily Attendance';
                showLogo = false;
                break;
              case 2:
                currentTitle = isParent ? 'Attendance History' : 'Past Records';
                showLogo = false;
                break;
              case 3:
                currentTitle = isParent ? 'Family Insights' : 'Performance Insights';
                showLogo = false;
                break;
              case 4:
                currentTitle = isParent ? 'Parent Profile' : 'Teacher Profile';
                showLogo = false;
                break;
              default:
                currentTitle = null;
                showLogo = true;
            }

            return Scaffold(
              extendBody: false,
              appBar: CustomAppBar(
                title: currentTitle,
                showLogo: showLogo,
              ),
              body: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), 
                children: [
                  isParent ? const ParentDashboardScreen() : const ClassListScreen(),
                  isParent ? const ParentChildrenScreen() : const AttendanceScreen(),
                  const HistoryScreen(),
                  const SummaryScreen(),
                  const ProfileScreen(),
                ],
              ),
              bottomNavigationBar: Container(
                height: 100, // Slightly increased to fit labels and ensure good padding
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), // Increased spacing and floating feel
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Flexible(
                        child: _buildNavItem(0, LucideIcons.layoutGrid, 'Home', isDark, selectedIndex),
                      ),
                      Flexible(
                        child: _buildNavItem(1, isParent ? LucideIcons.users : LucideIcons.clipboardCheck, isParent ? 'Children' : 'Attendance', isDark, selectedIndex),
                      ),
                      if (!isParent)
                        Flexible(
                          child: _buildNavItem(2, LucideIcons.history, 'History', isDark, selectedIndex),
                        ),
                      if (!isParent)
                        Flexible(
                          child: _buildNavItem(3, LucideIcons.barChart3, 'Analytics', isDark, selectedIndex),
                        ),
                      // Flexible(
                      //   child: _buildNavItem(4, LucideIcons.user, 'Profile', isDark, selectedIndex),
                      // ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, bool isDark, int selectedIndex) {
    bool isSelected = selectedIndex == index;
    final accentColor = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;

    return GestureDetector(
      onTap: () {
        dashboardIndexNotifier.value = index;
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutQuart,
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        color: Colors.transparent, // Ensure hit testing works on the whole area
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: EdgeInsets.symmetric(
                horizontal: isSelected ? 20 : 12, 
                vertical: isSelected ? 8 : 8
              ),
              decoration: isSelected 
                ? BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  )
                : const BoxDecoration(
                    color: Colors.transparent,
                  ),
              child: AnimatedScale(
                scale: isSelected ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                child: Icon(
                  icon, 
                  size: 24, 
                  color: isSelected 
                    ? accentColor 
                    : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isSelected ? 1.0 : 0.6,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected 
                    ? accentColor
                    : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                ),
                child: Text(label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlaceholderWidget extends StatelessWidget {
  final String title;
  const PlaceholderWidget({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(title, style: Theme.of(context).textTheme.displayLarge));
  }
}
