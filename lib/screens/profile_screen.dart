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
import '../services/api_service.dart';
import '../services/biometric_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadPreferences();
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
        setState(() {
          _userName = profile['full_name'] ?? profile['first_name'] ?? 'No Name';
          _userEmail = profile['email'] ?? '';
          _userRole = profile['primary_role']['display_name'] ?? 'Teacher';
          _userPhone = profile['phone'] ?? '';
          _photoUrl = profile['photo_url'];
          _address = profile['address'];
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
            _userRole = profile['primary_role']['display_name'] ?? 'Teacher';
            _userPhone = profile['phone'] ?? '';
            _photoUrl = profile['photo_url'];
            _address = profile['address'];
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
          children: [
            // Profile Header Card
            Container(
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

            const SizedBox(height: 32),

            // Settings Sections
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

            const SizedBox(height: 24),
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

            const SizedBox(height: 24),
            _buildSectionHeader('Security'),
            _buildSettingTile(
              'Biometric Login',
              'Use FaceID or TouchID',
              LucideIcons.fingerprint,
              trailing: Switch(
                value: _biometricsEnabled,
                activeColor: AppTheme.darkAccent,
                onChanged: (val) async {
                  if (val) {
                    // VERIFY IDENTITY BEFORE ENABLING
                    final authenticated = await BiometricService.authenticate();
                    if (!authenticated) {
                       if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text('Authentication failed. Cannot enable biometric login.'), behavior: SnackBarBehavior.floating),
                       );
                       return;
                    }
                  }

                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('biometric_lock_enabled', val);
                  setState(() => _biometricsEnabled = val);
                },
              ),
            ),
            _buildSettingTile(
              'Change Passcode',
              'Update your numeric PIN',
              LucideIcons.lock,
              onTap: _showChangePasscodeDialog,
            ),

            const SizedBox(height: 24),
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
