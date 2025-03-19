import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

import '../providers/auth_provider.dart';
import '../providers/report_provider.dart';
import '../utils/validators.dart';
import '../widgets/custom_button.dart';
import '../widgets/loading_indicator.dart';
import '../screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  static const routeName = '/profile';
  final bool isInTabView;

  const ProfileScreen({Key? key, this.isInTabView = false}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  bool _isEditing = false;
  File? _newProfileImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }
  
  void _initializeControllers() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    
    // Initialize controllers with current user data
    _usernameController = TextEditingController(text: user?.username ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Pick image from gallery
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 400,
      maxHeight: 400,
    );

    if (pickedFile != null) {
      setState(() {
        _newProfileImage = File(pickedFile.path);
      });
    }
  }

  // Toggle editing mode
  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      
      // Reset form if canceling edit
      if (!_isEditing) {
        _initializeControllers();
        _newProfileImage = null;
      }
    });
  }

  // Save profile changes
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      final success = await authProvider.updateProfile(
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        profileImageUrl: null, // Not implementing image upload in this version
      );

      if (success) {
        setState(() {
          _isEditing = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update: ${authProvider.errorMessage}')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Confirm logout dialog
  Future<void> _confirmLogout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      // Perform actual logout
      Provider.of<AuthProvider>(context, listen: false).signOut();
      Navigator.of(context).pushNamedAndRemoveUntil(
        LoginScreen.routeName, 
        (route) => false
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // For tab view, don't use a scaffold as it's already in one
    if (widget.isInTabView) {
      return _buildProfileContent();
    }
    
    // For standalone view, use a scaffold with app bar
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        elevation: 0,
      ),
      body: _buildProfileContent(),
    );
  }

  Widget _buildProfileContent() {
    return Consumer<AuthProvider>(
      builder: (ctx, authProvider, _) {
        final user = authProvider.currentUser;
        
        if (user == null) {
          return const Center(
            child: Text('Please log in to view profile'),
          );
        }

        if (authProvider.isLoading) {
          return const Center(
            child: LoadingIndicator(message: 'Loading profile...'),
          );
        }

        return Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile section with user info
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    child: Column(
                      children: [
                        // Profile image with ClipOval for perfect circle clipping
                        // Profile image
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade200,
                          ),
                          child: ClipOval(
                            child: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
                              ? FadeInImage.assetNetwork(
                                  placeholder: 'assets/images/default-avatar.jpg',
                                  image: user.profileImageUrl!,
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 100,
                                  imageErrorBuilder: (context, error, stackTrace) {
                                    return Image.asset(
                                      'assets/images/default-avatar.jpg',
                                      fit: BoxFit.cover,
                                      width: 100,
                                      height: 100,
                                    );
                                  },
                                )
                              : Image.asset(
                                  'assets/images/default-avatar.jpg',
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 100,
                                  errorBuilder: (context, error, stackTrace) {
                                    // If even the asset fails, show a fallback icon
                                    return const Icon(Icons.person, size: 60, color: Colors.grey);
                                  },
                                ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Username
                        Text(
                          user.username,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        // Status badge
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Email and phone section
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Email field
                          const Text(
                            'Email',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _isEditing 
                            ? TextFormField(
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.email),
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) => Validators.email(value),
                                enabled: true,
                              )
                            : ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.email, color: Colors.grey),
                                title: Text(
                                  user.email ?? 'No email provided',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          
                          const SizedBox(height: 16),
                          
                          // Phone field
                          const Text(
                            'Phone Number',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _isEditing 
                            ? TextFormField(
                                controller: _phoneController,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.phone),
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.phone,
                                validator: (value) => Validators.phone(value),
                                enabled: true,
                              )
                            : ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.phone, color: Colors.grey),
                                title: Text(
                                  user.phoneNumber ?? 'No phone number provided',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          
                          if (_isEditing) ...[
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                // Cancel button
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _isLoading ? null : _toggleEditMode,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: const Text('CANCEL'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Save button
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _saveProfile,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('SAVE'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Statistics section
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Statistics',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Stats cards
                        Consumer<ReportProvider>(
                          builder: (ctx, reportProvider, _) {
                            final reports = reportProvider.reports;
                            final totalReports = reports.length;
                            final analyzedCount = reportProvider.countReportsByStatus('analyzed');
                            
                            return Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    context,
                                    Icons.report,
                                    '$totalReports',
                                    'Total Reports',
                                    Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildStatCard(
                                    context,
                                    Icons.analytics,
                                    '$analyzedCount',
                                    'Analyzed',
                                    Colors.blue,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Sign out button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: CustomButton(
                      text: 'Sign Out',
                      icon: Icons.exit_to_app,
                      onPressed: _confirmLogout,
                      isSecondary: true,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
            
            // Edit button - positioned in the top right
            if (!_isEditing && widget.isInTabView)
              Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 18,
                  child: IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: _toggleEditMode,
                    tooltip: 'Edit Profile',
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // Helper widget for statistics cards
  Widget _buildStatCard(BuildContext context, IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}