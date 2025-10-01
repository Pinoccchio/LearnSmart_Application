import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
  bool _isEditingName = false;
  bool _isUpdatingName = false;
  String _originalName = '';

  @override
  void initState() {
    super.initState();
    final appProvider = context.read<AppProvider>();
    final userInfo = appProvider.userInfo;
    final user = context.read<AuthProvider>().currentUser;

    _originalName = userInfo?['name'] ?? user?.name ?? '';
    _nameController.text = _originalName;

    // Listen for text changes to enable/disable save button
    _nameController.addListener(() {
      setState(() {}); // Rebuild to update save button state
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _hasNameChanged =>
      _nameController.text.trim() != _originalName &&
      _nameController.text.trim().isNotEmpty;

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

          return RefreshIndicator(
            onRefresh: () async {
              await appProvider.refreshProfileData();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Picture Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
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
                        Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.bgPrimary,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.bgPrimary.withValues(alpha: 0.2),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(47),
                                child: Image.asset(
                                  'assets/logo/logo.png',
                                  width: 94,
                                  height: 94,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.bgPrimary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.white,
                                    width: 3,
                                  ),
                                ),
                                child: const Icon(
                                  LucideIcons.user,
                                  color: AppColors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          userInfo?['name'] ?? user?.name ?? 'UserName',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatRole(userInfo?['role'] as String? ?? 'student'),
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Profile Information
                  Container(
                    width: double.infinity,
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
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.user,
                                color: AppColors.bgPrimary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Profile Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),

                        // Name field (editable)
                        _buildNameField(userInfo, user),

                        const Divider(height: 1),

                        // Email field (non-editable)
                        _buildInfoTile(
                          icon: LucideIcons.mail,
                          label: 'Email',
                          value: userInfo?['email'] ?? user?.email ?? 'user@example.com',
                        ),

                        const Divider(height: 1),

                        // Role field (display only)
                        _buildInfoTile(
                          icon: LucideIcons.briefcase,
                          label: 'Role',
                          value: _formatRole(userInfo?['role'] as String? ?? 'student'),
                        ),

                        const Divider(height: 1),

                        // Created At field (display only)
                        _buildInfoTile(
                          icon: LucideIcons.calendar,
                          label: 'Member Since',
                          value: _formatDate(userInfo?['created_at'] as String?),
                        ),

                        // Last Login field (display only)
                        if (userInfo?['last_login'] != null) ...{
                          const Divider(height: 1),
                          _buildInfoTile(
                            icon: LucideIcons.clock,
                            label: 'Last Login',
                            value: _formatDate(userInfo?['last_login'] as String?),
                          ),
                        },
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Help text
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.info,
                          size: 14,
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pull down to refresh your profile information',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary.withValues(alpha: 0.7),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Build name field with edit capability
  Widget _buildNameField(Map<String, dynamic>? userInfo, dynamic user) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isEditingName
            ? AppColors.bgPrimary.withValues(alpha: 0.05)
            : Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isEditingName ? LucideIcons.edit : LucideIcons.user,
                color: _isEditingName ? AppColors.bgPrimary : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Name',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _isEditingName ? AppColors.bgPrimary : AppColors.textSecondary,
                  ),
                ),
              ),
              if (!_isEditingName)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isEditingName = true;
                      _originalName = _nameController.text;
                    });
                  },
                  icon: const Icon(LucideIcons.edit3, size: 18),
                  tooltip: 'Edit Name',
                  color: AppColors.bgPrimary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isEditingName)
            // Edit mode
            Column(
              children: [
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Enter your name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.grey300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.bgPrimary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    filled: true,
                    fillColor: AppColors.white,
                    suffixIcon: _nameController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, size: 18),
                            onPressed: () {
                              _nameController.clear();
                            },
                          )
                        : null,
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isUpdatingName ? null : () {
                          setState(() {
                            _nameController.text = _originalName;
                            _isEditingName = false;
                          });
                        },
                        icon: const Icon(LucideIcons.x, size: 16),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(color: AppColors.grey300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: (_hasNameChanged && !_isUpdatingName)
                            ? () => _updateUserName(context.read<AppProvider>())
                            : null,
                        icon: _isUpdatingName
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                                ),
                              )
                            : const Icon(LucideIcons.check, size: 16),
                        label: Text(_isUpdatingName ? 'Saving...' : 'Save Changes'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.bgPrimary,
                          foregroundColor: AppColors.white,
                          disabledBackgroundColor: AppColors.grey300,
                          disabledForegroundColor: AppColors.textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            // View mode
            Text(
              userInfo?['name'] ?? user?.name ?? 'Not set',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  /// Build a read-only info tile
  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Update user name in database
  Future<void> _updateUserName(AppProvider appProvider) async {
    if (_isUpdatingName) return;

    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name cannot be empty'),
          backgroundColor: AppColors.error,
        ),
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
          setState(() {
            _originalName = newName;
            _isEditingName = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(LucideIcons.checkCircle, color: AppColors.white, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Name updated successfully!')),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(LucideIcons.alertCircle, color: AppColors.white, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Failed to update name. Please try again.')),
                ],
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.xCircle, color: AppColors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
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
