import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../app_theme.dart';
import '../main.dart';
import '../widgets/custom_app_bar.dart';
import 'login_screen.dart';
import 'teacher_attendance_history_screen.dart';
import 'student_detail_screen.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';
import '../widgets/app_effects.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  bool _notificationsEnabled = true;
  bool _biometricsEnabled = true;
  bool _isLoading = true;

  // Real user data loaded from API
  String _userName = '';
  String _userEmail = '';
  String _userRole = 'Teacher';
  String _userPhone = '';
  String? _photoUrl;
  Map<String, dynamic>? _address;
  List<dynamic> _children = [];
  List<dynamic> _availableRoles = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadPreferences();
    globalRefreshNotifier.addListener(_loadUserData);
  }

  @override
  void dispose() {
    globalRefreshNotifier.removeListener(_loadUserData);
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricsEnabled = prefs.getBool('biometric_lock_enabled') ?? false;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    });
  }

  Future<void> _loadUserData() async {
    try {
      final response = await _apiService.getProfile();
      if (response['success']) {
        final profile = response['data']['profile'];
        profileNotifier.value = profile; // Update global notifier
        
        List<dynamic> allRoles = profile['all_roles'] ?? [];
        
        // Filter roles to keep ONLY Teacher and Parent
        List<dynamic> relevantRoles = allRoles.where((role) {
          String name = (role['display_name'] ?? '').toString().toLowerCase();
          return name.contains('teacher') || name.contains('parent');
        }).toList();

        if (relevantRoles.isEmpty) {
          _handleLogout();
          return;
        }

        // Determine which role to display:
        // Use the current role if it's already set and still available, otherwise try primary role, then fallback to first available
        String role = _userRole;
        if (role.isEmpty || !relevantRoles.any((r) => r['display_name'] == role)) {
          String primaryDisplay = profile['primary_role']['display_name'] ?? '';
          if (relevantRoles.any((r) => r['display_name'] == primaryDisplay)) {
            role = primaryDisplay;
          } else {
            role = relevantRoles.first['display_name'];
          }
        }
        
        setState(() {
          _userName = profile['full_name'] ?? profile['first_name'] ?? 'No Name';
          _userEmail = profile['email'] ?? '';
          _userRole = role;
          currentRoleNotifier.value = role; // Update global role notifier
          _availableRoles = relevantRoles;
          _userPhone = profile['phone'] ?? '';
          _photoUrl = profile['photo_url'];
          _address = profile['address'];
        });


        _fetchChildrenIfNeeded();

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userName = prefs.getString('user_name') ?? 'User';
        _userEmail = prefs.getString('user_email') ?? '';
        _userRole = prefs.getString('user_role') ?? 'Teacher';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchChildrenIfNeeded() async {
    if (_userRole.toLowerCase().contains('parent')) {
      try {
        final childrenResponse = await _apiService.getParentStudents();
        if (childrenResponse['success']) {
          setState(() {
            _children = childrenResponse['data']['students'] ?? [];
          });
        }
      } catch (e) {
        debugPrint('Error loading children: $e');
      }
    } else {
      setState(() {
        _children = [];
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        setState(() => _isLoading = true);
        final response = await _apiService.updateProfilePicture(image);
        if (response['success']) {
          await _loadUserData();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated!')));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    }
  }

  void _showEditProfileSheet() {
    final TextEditingController phoneController = TextEditingController(text: _userPhone);
    final TextEditingController line1Controller = TextEditingController(text: _address?['address_line1'] ?? '');
    final TextEditingController line2Controller = TextEditingController(text: _address?['address_line2'] ?? '');
    final TextEditingController cityController = TextEditingController(text: _address?['city'] ?? '');
    final TextEditingController stateController = TextEditingController(text: _address?['state'] ?? '');
    final TextEditingController zipController = TextEditingController(text: _address?['postal_code'] ?? '');
    final TextEditingController countryController = TextEditingController(text: _address?['country'] ?? 'Australia');
    
    String addressType = _address?['address_type'] ?? 'home';
    bool isSamePostal = (_address?['is_same_postal_address'] ?? 'Y') == 'Y';
    bool isUpdating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),
                Text('Personal Details', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                _buildEditField('Mobile phone', LucideIcons.phone, phoneController),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Address Type', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: addressType,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkSurface : Colors.grey.shade100,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            ),
                            items: ['home', 'work', 'other'].map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
                            onChanged: (val) => setModalState(() => addressType = val!),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                _buildEditField('Address Line 1', LucideIcons.mapPin, line1Controller),
                const SizedBox(height: 12),
                _buildEditField('Address Line 2 (Optional)', LucideIcons.mapPin, line2Controller),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(child: _buildEditField('City', LucideIcons.building, cityController)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildEditField('State', LucideIcons.map, stateController)),
                  ],
                ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(child: _buildEditField('Postal Code', LucideIcons.hash, zipController)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildEditField('Country', LucideIcons.globe, countryController)),
                  ],
                ),

                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Same as Postal Address', style: TextStyle(fontSize: 14)),
                  value: isSamePostal,
                  activeColor: AppTheme.darkAccent,
                  onChanged: (val) => setModalState(() => isSamePostal = val!),
                ),

                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isUpdating ? null : () async {
                    setModalState(() => isUpdating = true);
                    try {
                      final response = await _apiService.updateProfile({
                        'phone': phoneController.text,
                        'address_type': addressType,
                        'address_line1': line1Controller.text,
                        'address_line2': line2Controller.text,
                        'person_city': cityController.text,
                        'person_state': stateController.text,
                        'postal_code': zipController.text,
                        'person_country': countryController.text,
                        'is_same_postal_address': isSamePostal ? 'Y' : 'N',
                        'person_address_status': 'active',
                      });
                      if (response['success']) {
                        await _loadUserData();
                        if (mounted) Navigator.pop(context);
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                    } finally {
                      setModalState(() => isUpdating = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.darkAccent,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: isUpdating ? const CircularProgressIndicator(color: Colors.black) : const Text('Save Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditField(String label, IconData icon, TextEditingController controller) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18),
            filled: true,
            fillColor: isDark ? AppTheme.darkSurface : Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  void _showChangePasscodeDialog() {
    final TextEditingController currentController = TextEditingController();
    final TextEditingController newController = TextEditingController();
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Change Passcode', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'Current 4-digit PIN', counterText: ''),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'New 4-digit PIN', counterText: ''),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isUpdating ? null : () async {
                if (currentController.text.length != 4 || newController.text.length != 4) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN must be 4 digits')));
                  return;
                }
                setState(() => isUpdating = true);
                try {
                  final response = await _apiService.updatePasscode(currentController.text, newController.text);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'])));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                } finally {
                  setState(() => isUpdating = false);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.darkAccent, foregroundColor: Colors.black),
              child: isUpdating ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleRoleSwitch(String newValue) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    setState(() {
      _userRole = newValue;
      currentRoleNotifier.value = newValue; // Update global role notifier
      _fetchChildrenIfNeeded();
    });

    // Show success popup with auto-close
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        });
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSuccess.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.checkCircle, color: AppTheme.darkSuccess, size: 40),
                ),
                const SizedBox(height: 20),
                Text(
                  'Profile Switched',
                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'You are now viewing as ${newValue.toUpperCase()}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRoleSelectionSheet() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Switch Profile',
              style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose your active role for this session',
              style: GoogleFonts.inter(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 32),
            ..._availableRoles.map((role) {
              final String roleName = role['display_name'];
              final bool isSelected = roleName == _userRole;
              final IconData roleIcon = roleName.toLowerCase().contains('teacher') 
                  ? LucideIcons.graduationCap 
                  : LucideIcons.users;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? accent.withOpacity(0.1) 
                      : (isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected ? accent.withOpacity(0.3) : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: ListTile(
                  onTap: () {
                    Navigator.pop(context);
                    if (!isSelected) {
                      _handleRoleSwitch(roleName);
                    }
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? accent : (isDark ? Colors.white10 : Colors.grey.shade200),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      roleIcon, 
                      color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
                      size: 24,
                    ),
                  ),
                  title: Text(
                    roleName.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: isSelected ? accent : null,
                    ),
                  ),
                  subtitle: Text(
                    isSelected ? 'Currently Active' : 'Tap to switch',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isSelected ? accent.withOpacity(0.7) : (isDark ? Colors.white38 : Colors.black38),
                    ),
                  ),
                  trailing: isSelected 
                      ? Icon(LucideIcons.checkCircle2, color: accent, size: 24) 
                      : Icon(LucideIcons.chevronRight, size: 18, color: Colors.grey.withOpacity(0.3)),
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: profileNotifier,
        builder: (context, profile, _) {
          if (profile != null) {
            _userName = profile['full_name'] ?? profile['first_name'] ?? 'No Name';
            _userEmail = profile['email'] ?? '';
            // REMOVED: _userRole = profile['primary_role']['display_name'] ?? 'Teacher'; 
            _userPhone = profile['phone'] ?? '';
            _photoUrl = profile['photo_url'];
            _address = profile['address'];
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
          children: [
            // Profile Header Card
            FadeInAnimation(
              delay: const Duration(milliseconds: 100),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  border: isDark ? null : Border.all(color: Colors.grey.shade100),
                ),
                child: _isLoading ? const Center(child: CircularProgressIndicator()) : Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: (isDark ? AppTheme.darkAccent : AppTheme.lightAccent).withOpacity(0.3), width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: (isDark ? AppTheme.darkAccent : AppTheme.lightAccent).withOpacity(0.2),
                            backgroundImage: _photoUrl != null ? NetworkImage('${_photoUrl!}?v=${profile?['updated_at'] ?? '1'}') : null,
                            child: _photoUrl == null ? Text(
                              _userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
                              style: GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent),
                            ) : null,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _pickAndUploadImage(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(LucideIcons.camera, size: 16, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(_userName, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                    Text(_userEmail, style: GoogleFonts.inter(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
                    const SizedBox(height: 12),
                    
                    // Role Switcher / Display
                    if (_availableRoles.length > 1)
                      GestureDetector(
                        onTap: _showRoleSelectionSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: (isDark ? AppTheme.darkAccent : AppTheme.lightAccent).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: (isDark ? AppTheme.darkAccent : AppTheme.lightAccent).withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _userRole.toLowerCase().contains('teacher') ? LucideIcons.graduationCap : LucideIcons.users,
                                size: 16,
                                color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _userRole.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(LucideIcons.chevronDown, size: 14, color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSuccess.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_userRole, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.darkSuccess)),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Settings Sections
            FadeInAnimation(
              delay: const Duration(milliseconds: 200),
              child: Column(
                children: [
                  _buildSectionHeader('Personal Information'),
                  _buildSettingTile(
                    'Mobile Number',
                    _userPhone.isEmpty ? 'Not set' : _userPhone,
                    LucideIcons.phone,
                    onTap: _showEditProfileSheet,
                  ),
                  _buildSettingTile(
                    'Home Address',
                    _address?['address_line1'] ?? 'Not set',
                    LucideIcons.mapPin,
                    onTap: _showEditProfileSheet,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            if (_userRole.toLowerCase().contains('teacher'))
              FadeInAnimation(
                delay: const Duration(milliseconds: 300),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    _buildSectionHeader('Attendance'),
                    _buildSettingTile(
                      'Attendance History',
                      'View your check-in records',
                      LucideIcons.calendar,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const TeacherAttendanceHistoryScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),
            FadeInAnimation(
              delay: const Duration(milliseconds: 400),
              child: Column(
                children: [
                  _buildSectionHeader('Appearance'),
                  _buildSettingTile(
                    'Dark Mode',
                    'Adjust the app color theme',
                    LucideIcons.moon,
                    trailing: Switch(
                      value: isDark,
                      activeColor: AppTheme.darkAccent,
                      onChanged: (val) async {
                        final prefs = await SharedPreferences.getInstance();
                        themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                        await prefs.setBool('isDarkMode', val);
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            FadeInAnimation(
              delay: const Duration(milliseconds: 500),
              child: Column(
                children: [
                  _buildSectionHeader('Security'),
                  _buildSettingTile(
                    'Change Passcode',
                    'Update your numeric PIN',
                    LucideIcons.lock,
                    onTap: _showChangePasscodeDialog,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            FadeInAnimation(
              delay: const Duration(milliseconds: 600),
              child: Column(
                children: [
                  _buildSectionHeader('Notifications'),
                  _buildSettingTile(
                    'Push Notifications',
                    'Stay updated with class alerts',
                    LucideIcons.bell,
                    trailing: Switch(
                      value: _notificationsEnabled,
                      activeColor: AppTheme.darkAccent,
                      onChanged: (val) => setState(() => _notificationsEnabled = val),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Logout Button
            ElevatedButton(
              onPressed: _handleLogout,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.red.withOpacity(0.1) : Colors.red.shade50,
                foregroundColor: Colors.redAccent,
                minimumSize: const Size.fromHeight(60),
                elevation: 0,
                side: BorderSide(color: Colors.redAccent.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(LucideIcons.logOut, size: 20),
                  SizedBox(width: 12),
                  Text('Logout Account', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      );
    },
  ),
);
}

  Widget _buildChildrenList() {
    if (_children.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(LucideIcons.userX, size: 48, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(
              'No enrolled students found',
              style: GoogleFonts.outfit(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _children.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final child = _children[index];
        return _buildChildCard(child);
      },
    );
  }

  Widget _buildChildCard(Map<String, dynamic> child) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StudentDetailScreen(student: child),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      child['student_name']?[0] ?? 'S',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child['student_name'] ?? 'Unknown Student',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${child['studid'] ?? 'N/A'} • Grade: ${child['class_grade'] ?? 'N/A'}',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  LucideIcons.chevronRight,
                  color: Colors.grey.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
        ),
      ),
    );
  }

  Widget _buildSettingTile(String title, String subtitle, IconData icon, {Widget? trailing, VoidCallback? onTap}) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? null : Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (isDark ? AppTheme.darkAccent : AppTheme.lightAccent).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent, size: 20),
        ),
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
        trailing: trailing ?? const Icon(LucideIcons.chevronRight, size: 18, color: Colors.white24),
      ),
    );
  }
}
