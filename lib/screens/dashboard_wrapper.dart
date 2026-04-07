import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_theme.dart';
import 'attendance_screen.dart';
import 'class_list_screen.dart';
import 'history_screen.dart';
import 'summary_screen.dart';
import 'profile_screen.dart';
import '../widgets/custom_app_bar.dart';
import '../main.dart'; // Import to access dashboardIndexNotifier
import '../services/api_service.dart';
import 'dart:convert';

class DashboardWrapper extends StatefulWidget {
  const DashboardWrapper({super.key});

  @override
  State<DashboardWrapper> createState() => _DashboardWrapperState();
}

class _DashboardWrapperState extends State<DashboardWrapper> {
  // Use global dashboardIndexNotifier instead of local state
  
  final List<Widget> _screens = [
    const ClassListScreen(),
    const AttendanceScreen(),
    const HistoryScreen(),
    const SummaryScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialProfile();
  }

  Future<void> _loadInitialProfile() async {
    try {
      final response = await ApiService().getProfile();
      if (response['success']) {
        profileNotifier.value = response['data']['profile'];
      }
    } catch (e) {
      debugPrint('Error loading initial profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ValueListenableBuilder<int>(
      valueListenable: dashboardIndexNotifier,
      builder: (context, selectedIndex, _) {
        String? currentTitle;
        bool showLogo = true;

        switch (selectedIndex) {
          case 1:
            currentTitle = 'Daily Attendance';
            showLogo = false;
            break;
          case 2:
            currentTitle = 'Past Records';
            showLogo = false;
            break;
          case 3:
            currentTitle = 'Performance Insights';
            showLogo = false;
            break;
          case 4:
            currentTitle = 'Teacher Profile';
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
          body: IndexedStack(
            index: selectedIndex,
            children: _screens,
          ),
          bottomNavigationBar: Container(
            height: 90,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Flexible(
                    child: _buildNavItem(0, LucideIcons.layoutGrid, 'DASHBOARD', isDark, selectedIndex),
                  ),
                  Flexible(
                    child: _buildNavItem(1, LucideIcons.users, 'STUDENTS', isDark, selectedIndex),
                  ),
                  Flexible(
                    child: _buildNavItem(2, LucideIcons.history, 'HISTORY', isDark, selectedIndex),
                  ),
                  Flexible(
                    child: _buildNavItem(3, LucideIcons.barChart3, 'SUMMARY', isDark, selectedIndex),
                  ),
                  Flexible(
                    child: _buildNavItem(4, LucideIcons.user, 'PROFILE', isDark, selectedIndex),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, bool isDark, int selectedIndex) {
    bool isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () => dashboardIndexNotifier.value = index,
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
              padding: EdgeInsets.symmetric(
                horizontal: isSelected ? 24 : 12, 
                vertical: isSelected ? 14 : 8
              ),
              decoration: isSelected 
                ? BoxDecoration(
                    color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? AppTheme.darkAccent : AppTheme.lightAccent).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      )
                    ],
                  )
                : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon, 
                    size: 20, 
                    color: isSelected 
                      ? (isDark ? Colors.black : Colors.white) 
                      : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label, 
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 9, 
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700, 
                      color: isSelected 
                        ? (isDark ? Colors.black : Colors.white) 
                        : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)
                    )
                  ),
                ],
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
