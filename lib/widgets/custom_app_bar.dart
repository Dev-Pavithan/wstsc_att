import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../main.dart';
import '../screens/dashboard_wrapper.dart';
import '../screens/login_screen.dart';
import '../screens/profile_screen.dart';

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String? title;
  final String? subtitle;
  final bool showLogo;

  const CustomAppBar({
    super.key,
    this.title,
    this.subtitle,
    this.showLogo = true,
  });

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _CustomAppBarState extends State<CustomAppBar> {
  String _userName = 'Teacher';
  String _userRole = 'Teacher';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'Teacher';
      _userRole = prefs.getString('user_role') ?? 'Teacher';
    });
  }

  void _showNotifications(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Notifications', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x)),
              ],
            ),
            const SizedBox(height: 16),
            _buildNotificationItem(context, 'Attendance Sheet Ready', 'Period 4 attendance is ready to be recorded.', LucideIcons.fileText, isDark),
            _buildNotificationItem(context, 'Monthly Report', 'Your monthly summary is available.', LucideIcons.pieChart, isDark),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(BuildContext context, String title, String sub, IconData icon, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(sub, style: GoogleFonts.inter(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileFlow(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withOpacity(0.2), width: 2),
              ),
              child: Center(
                child: Text(
                  _userName.isNotEmpty ? _userName[0].toUpperCase() : 'T',
                  style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: accent),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(_userName, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(_userRole, style: GoogleFonts.inter(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
            const SizedBox(height: 32),
            _buildProfileOption(context, LucideIcons.user, 'My Profile', isDark),
            _buildProfileOption(context, LucideIcons.settings, 'Settings', isDark),
            _buildProfileOption(context, LucideIcons.logOut, 'Logout', isDark, isLast: true, color: Colors.redAccent),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption(BuildContext context, IconData icon, String label, bool isDark, {bool isLast = false, Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? (isDark ? Colors.white70 : Colors.black87)),
      title: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: color)),
      onTap: () async {
        if (label == 'My Profile') {
          Navigator.pop(context);
          dashboardIndexNotifier.value = 4;
        } else if (isLast && label == 'Logout') {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', false);
          if (context.mounted) {
            Navigator.pop(context);
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }
        } else {
          Navigator.pop(context);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      leadingWidth: 180,
      leading: widget.showLogo
          ? Padding(
              padding: const EdgeInsets.only(left: 20),
              child: GestureDetector(
                onTap: () {
                  dashboardIndexNotifier.value = 0;
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkAccent.withOpacity(0.1) : AppTheme.lightAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.asset(
                        'assets/logo.png',
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          LucideIcons.school, 
                          color: accent, 
                          size: 20
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'WSTSC',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      title: widget.title != null 
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.title!, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
              if (widget.subtitle != null)
                Text(widget.subtitle!, style: GoogleFonts.inter(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
            ],
          )
        : null,
      actions: [
        IconButton(
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            themeNotifier.value = themeNotifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
            await prefs.setBool('isDarkMode', themeNotifier.value == ThemeMode.dark);
          },
          icon: Icon(themeNotifier.value == ThemeMode.dark ? LucideIcons.moon : LucideIcons.sun, size: 20),
        ),
        IconButton(
          onPressed: () => _showNotifications(context),
          icon: const Icon(LucideIcons.bell, size: 20),
        ),
        ValueListenableBuilder<Map<String, dynamic>?>(
          valueListenable: profileNotifier,
          builder: (context, profile, _) {
            final String currentName = profile != null ? (profile['full_name'] ?? _userName) : _userName;
            final String? currentPhoto = profile?['photo_url'];

            return GestureDetector(
              onTap: () => dashboardIndexNotifier.value = 4,
              child: Padding(
                padding: const EdgeInsets.only(right: 20, left: 8),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withOpacity(0.2), width: 2),
                    image: currentPhoto != null
                        ? DecorationImage(
                            image: NetworkImage(currentPhoto + (profile?['updated_at'] != null ? '?v=${profile!['updated_at']}' : '')),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: currentPhoto == null
                      ? Center(
                          child: Text(
                            currentName.isNotEmpty ? currentName[0].toUpperCase() : 'T',
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: accent),
                          ),
                        )
                      : null,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
