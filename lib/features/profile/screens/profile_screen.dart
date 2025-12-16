import 'package:flutter/material.dart';
import 'package:transport_book_app/utils/appbar.dart';
import 'package:transport_book_app/utils/custom_button.dart';
import '../../../utils/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/screens/login_screen.dart';
import '../../../utils/app_constants.dart';
import '../../../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _phoneNumber = '';
  String _businessName = AppConstants.defaultBusinessName;
  String _ownerName = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _phoneNumber = prefs.getString('phone') ?? '';
      _businessName = prefs.getString('user_name') ?? AppConstants.defaultBusinessName;
      _ownerName = prefs.getString('owner_name') ?? '';
    });
  }

  Future<void> _showEditProfileDialog() async {
    final businessNameController = TextEditingController(text: _businessName);
    final ownerNameController = TextEditingController(text: _ownerName);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Edit Profile',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: businessNameController,
                  decoration: InputDecoration(
                    labelText: 'Business Name',
                    hintText: 'Enter business name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.business),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ownerNameController,
                  decoration: InputDecoration(
                    labelText: 'Owner Name',
                    hintText: 'Enter owner name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          actions: [
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (result == true && mounted) {
      final newBusinessName = businessNameController.text.trim();
      final newOwnerName = ownerNameController.text.trim();

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Call API to update profile in database
      final response = await ApiService.updateProfile(
        businessName: newBusinessName.isNotEmpty ? newBusinessName : null,
        ownerName: newOwnerName.isNotEmpty ? newOwnerName : null,
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (response['success'] == true) {
        // Save to local storage after API success
        final prefs = await SharedPreferences.getInstance();
        if (newBusinessName.isNotEmpty) {
          await prefs.setString('user_name', newBusinessName);
        }
        await prefs.setString('owner_name', newOwnerName);

        setState(() {
          _businessName = newBusinessName.isNotEmpty ? newBusinessName : AppConstants.defaultBusinessName;
          _ownerName = newOwnerName;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to update profile'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    businessNameController.dispose();
    ownerNameController.dispose();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Logout',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),

          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),

          actions: [
            Row(
              children: [
                // Cancel Button (Border style)
                TextButton( onPressed: () => Navigator.pop(context, false), child: const Text('Cancel'), ),
                const SizedBox(width: 40),

                // Logout Button (Red)
                Expanded(
                  child: CustomButton(
                    text: "Logout",
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: CustomAppBar(
        title: 'Profile',
        onBack: () => Navigator.pop(context),
      ),      body: SingleChildScrollView(
      child: Column(
        children: [
          // ===== PROFILE HEADER CARD =====
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: Column(
              children: [
                // Profile Image
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey.shade200,
                    child: const Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.grey,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Business Name
                Text(
                  _businessName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                // Owner Name
                if (_ownerName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _ownerName,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],

                const SizedBox(height: 6),

                // Phone Number
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _phoneNumber.isNotEmpty ? '+91 $_phoneNumber' : '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ===== SETTINGS CARD =====
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section Title
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 18, 16, 6),
                  child: Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),

                // Divider line
                Divider(color: Colors.grey.shade300, height: 1),

                // Settings List Items
                _buildSettingsItem(
                  icon: Icons.person_outline,
                  title: 'Edit Profile',
                  onTap: _showEditProfileDialog,
                ),
                // TODO: Uncomment when features are ready
                // _buildSettingsItem(
                //   icon: Icons.business_outlined,
                //   title: 'Business Settings',
                //   onTap: () {},
                // ),
                // _buildSettingsItem(
                //   icon: Icons.language,
                //   title: 'Language',
                //   onTap: () {},
                // ),
                // _buildSettingsItem(
                //   icon: Icons.notifications_outlined,
                //   title: 'Notifications',
                //   onTap: () {},
                // ),
                // _buildSettingsItem(
                //   icon: Icons.help_outline,
                //   title: 'Help & Support',
                //   onTap: () {},
                // ),
                // _buildSettingsItem(
                //   icon: Icons.info_outline,
                //   title: 'About',
                //   onTap: () {},
                // ),

                // Logout (red text)
                _buildSettingsItem(
                  icon: Icons.logout,
                  title: 'Logout',
                  onTap: _logout,
                  isDestructive: true,
                ),

                const SizedBox(height: 4),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    ),

    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red : Colors.grey.shade700,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: isDestructive ? Colors.red : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
