import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  bool _isUpdatingName = false;

  @override
  void initState() {
    super.initState();
    final appProvider = context.read<AppProvider>();
    final userInfo = appProvider.userInfo;
    final user = context.read<AuthProvider>().currentUser;
    
    _nameController.text = userInfo?['name'] ?? user?.name ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.bgSecondary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Consumer2<AuthProvider, AppProvider>(
        builder: (context, authProvider, appProvider, child) {
          final user = authProvider.currentUser;
          final userInfo = appProvider.userInfo;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Picture Section (display only)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.bgPrimary,
                            width: 3,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(37),
                          child: Image.asset(
                            'assets/logo/logo.png',
                            width: 74,
                            height: 74,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        userInfo?['name'] ?? user?.name ?? 'UserName',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Profile Information
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Profile Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Name field (editable)
                      _buildProfileField(
                        label: 'Name',
                        controller: _nameController,
                        isEditable: true,
                        onUpdate: () => _updateUserName(appProvider),
                        isUpdating: _isUpdatingName,
                      ),
                      const SizedBox(height: 16),
                      
                      // Email field (non-editable)
                      _buildProfileField(
                        label: 'Email',
                        value: userInfo?['email'] ?? user?.email ?? 'user@example.com',
                        isEditable: false,
                      ),
                      const SizedBox(height: 16),
                      
                      // Role field (display only)
                      _buildProfileField(
                        label: 'Role',
                        value: _formatRole(userInfo?['role'] as String? ?? 'student'),
                        isEditable: false,
                      ),
                      const SizedBox(height: 16),
                      
                      // Created At field (display only)
                      _buildProfileField(
                        label: 'Member Since',
                        value: _formatDate(userInfo?['created_at'] as String?),
                        isEditable: false,
                      ),
                      
                      // Last Login field (display only)
                      if (userInfo?['last_login'] != null) ...[
                        const SizedBox(height: 16),
                        _buildProfileField(
                          label: 'Last Login',
                          value: _formatDate(userInfo?['last_login'] as String?),
                          isEditable: false,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Build a profile field row with optional editing capability
  Widget _buildProfileField({
    required String label,
    String? value,
    TextEditingController? controller,
    bool isEditable = false,
    VoidCallback? onUpdate,
    bool isUpdating = false,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: isEditable && controller != null
              ? TextFormField(
                  controller: controller,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: AppColors.white,
                  ),
                )
              : Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.grey300),
                    borderRadius: BorderRadius.circular(4),
                    color: isEditable ? AppColors.white : AppColors.grey100,
                  ),
                  child: Text(
                    value ?? 'N/A',
                    style: TextStyle(
                      fontSize: 14,
                      color: isEditable ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 8),
        if (isEditable && onUpdate != null)
          SizedBox(
            width: 70,
            child: isUpdating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: onUpdate,
                    child: const Text('Update'),
                  ),
          )
        else
          const SizedBox(width: 70), // Placeholder for alignment
      ],
    );
  }

  /// Update user name in database
  Future<void> _updateUserName(AppProvider appProvider) async {
    if (_isUpdatingName) return;
    
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    setState(() {
      _isUpdatingName = true;
    });

    try {
      final success = await appProvider.updateUserProfile({
        'name': newName,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Name updated successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update name. Please try again.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An error occurred. Please try again.')),
        );
      }
    }

    setState(() {
      _isUpdatingName = false;
    });
  }

  /// Format role string for display
  String _formatRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Administrator';
      case 'instructor':
        return 'Instructor';
      case 'student':
        return 'Student';
      default:
        return role.substring(0, 1).toUpperCase() + role.substring(1).toLowerCase();
    }
  }

  /// Format date string for display
  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    
    try {
      final date = DateTime.parse(dateString);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}, ${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }
}