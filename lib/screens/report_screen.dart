import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:animate_do/animate_do.dart';

import '../providers/report_provider.dart';
import '../providers/location_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/loading_indicator.dart';
import '../utils/validators.dart';
import '../models/report.dart';

// Import the image optimizer
import '../utils/image_optimizer.dart';

class ReportScreen extends StatefulWidget {
  static const routeName = '/report';

  const ReportScreen({Key? key}) : super(key: key);

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  
  File? _imageFile;
  File? _optimizedImageFile;
  bool _isSubmitting = false;
  bool _isSuccessful = false;
  bool _isLocating = false;
  bool _isOptimizingImage = false;
  String? _errorMessage;
  Report? _submittedReport;
  
  // Image info
  double? _imageSizeKB;
  
  // Location data
  double? _latitude;
  double? _longitude;
  String? _locationName;
  
  @override
  void initState() {
    super.initState();
    // Request location permission when screen loads
    _checkAndRequestLocationPermission();
  }
  
  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
  
  // Check and request location permissions
  Future<void> _checkAndRequestLocationPermission() async {
    final status = await Permission.location.status;
    
    if (status.isDenied) {
      await Permission.location.request();
    } else if (status.isPermanentlyDenied) {
      // Show dialog suggesting to open app settings
      _showPermissionSettingsDialog();
    } else if (status.isGranted) {
      // If permission is already granted, get current location
      _getCurrentLocation();
    }
  }
  
  // Show dialog to direct user to app settings for permissions
  void _showPermissionSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'Location permission is needed to report waste accurately. '
          'Please enable location permission in app settings.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
  
  // Get current location
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _errorMessage = null;
    });
    
    try {
      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      // Format address
      final placemark = placemarks.first;
      final address = [
        placemark.street,
        placemark.subLocality,
        placemark.locality,
        placemark.administrativeArea,
      ].where((element) => element != null && element.isNotEmpty).join(', ');
      
      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _locationName = address;
          _isLocating = false;
        });
      }
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLocating = false;
          _errorMessage = 'Failed to get location. Please try again.';
        });
      }
    }
  }
  
  // Pick image from camera
  Future<void> _takePhoto() async {
    final imagePicker = ImagePicker();
    final permissionStatus = await Permission.camera.request();
    
    if (permissionStatus.isGranted) {
      final pickedFile = await imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90, // High initial quality
        maxWidth: 1920, // Allow higher initial resolution, we'll optimize later
        maxHeight: 1920,
      );
      
      if (pickedFile != null && mounted) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _optimizedImageFile = null; // Reset optimized image when new photo is taken
          _imageSizeKB = null; // Reset size info
        });
        
        // Optimize the image immediately after taking the photo
        _optimizeImage();
      }
    } else if (permissionStatus.isPermanentlyDenied) {
      // Show dialog suggesting to open app settings for camera permission
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Camera Permission Required'),
          content: const Text('Please enable camera permission in app settings.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }
  }
  
  // Optimize the selected image
  Future<void> _optimizeImage() async {
    if (_imageFile == null) return;
    
    setState(() {
      _isOptimizingImage = true;
    });
    
    try {
      // Show progress dialog
      final progressNotifier = ValueNotifier<double>(0.0);
      
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => ImageOptimizationProgressDialog(progress: progressNotifier),
        );
      }
      
      // Simulate progress updates (in a real app, you'd get actual progress from the optimization process)
      for (double i = 0.1; i <= 0.9; i += 0.1) {
        await Future.delayed(const Duration(milliseconds: 100));
        progressNotifier.value = i;
      }
      
      // Perform actual optimization
      final result = await ImageOptimizer.optimizeImage(_imageFile!);
      
      progressNotifier.value = 1.0;
      await Future.delayed(const Duration(milliseconds: 200));
      
      if (mounted) {
        Navigator.of(context).pop(); // Close progress dialog
        
        setState(() {
          _optimizedImageFile = result['file'];
          _imageSizeKB = result['sizeInKB'];
          _isOptimizingImage = false;
        });
      }
    } catch (e) {
      // Close progress dialog if open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      setState(() {
        _isOptimizingImage = false;
        _errorMessage = 'Failed to optimize image: ${e.toString()}';
      });
    }
  }
  
  // Submit report
  Future<void> _submitReport() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // Validate location
    if (_latitude == null || _longitude == null) {
      setState(() {
        _errorMessage = 'Location is required. Please wait for location detection or try again.';
      });
      return;
    }
    
    // Validate image
    if (_imageFile == null) {
      setState(() {
        _errorMessage = 'Please take a photo of the waste.';
      });
      return;
    }
    
    // Ensure image is optimized before submission
    if (_optimizedImageFile == null) {
      setState(() {
        _errorMessage = 'Please wait for image optimization to complete.';
      });
      return;
    }
    
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    
    try {
      final reportProvider = Provider.of<ReportProvider>(context, listen: false);
      
      // Device info (simplified)
      final deviceInfo = {
        'platform': Platform.operatingSystem,
        'version': Platform.operatingSystemVersion,
      };
      
      // Submit report
      final report = await reportProvider.submitReportInitial(
        latitude: _latitude!,
        longitude: _longitude!,
        description: _descriptionController.text.trim().isEmpty ? 
          'Waste report from ${_locationName ?? 'unknown location'}' : 
          _descriptionController.text.trim(),
        image: _optimizedImageFile, // Use the optimized image file
        deviceInfo: deviceInfo,
      );
      
      if (report != null && mounted) {
        // Success - show success UI
        setState(() {
          _isSuccessful = true;
          _submittedReport = report;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString();
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Waste'),
        elevation: 0,
      ),
      body: _isSuccessful 
          ? _buildSuccessView()
          : _isSubmitting 
              ? _buildSubmittingView()
              : _buildFormView(theme),
    );
  }
  
  // Submitting view with loading animation
  Widget _buildSubmittingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          LoadingIndicator(message: 'Submitting report...'),
          SizedBox(height: 20),
          Text(
            'Uploading to server...',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
  
  // Success view with animation
  Widget _buildSuccessView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeInDown(
            duration: const Duration(milliseconds: 400),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 64,
              ),
            ),
          ),
          const SizedBox(height: 24),
          FadeInUp(
            duration: const Duration(milliseconds: 400),
            child: const Text(
              'Report Submitted!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FadeInUp(
            duration: const Duration(milliseconds: 400),
            delay: const Duration(milliseconds: 200),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Your report has been submitted successfully',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Loading indicator for analysis
          FadeInUp(
            duration: const Duration(milliseconds: 400),
            delay: const Duration(milliseconds: 300),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  "Analyzing your report...",
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          // Back to Home button
          FadeInUp(
            duration: const Duration(milliseconds: 400),
            delay: const Duration(milliseconds: 400),
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_submittedReport),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Back to Home'),
            ),
          ),
        ],
      ),
    );
  }
  // Form view
  Widget _buildFormView(ThemeData theme) {
    return Stack(
      children: [
        // Background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.primaryColor.withOpacity(0.05),
                Colors.white,
              ],
              stops: const [0, 0.3],
            ),
          ),
        ),
        
        // Form content
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Section title
                FadeInUp(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    'Report a Waste Issue',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                FadeInUp(
                  duration: const Duration(milliseconds: 400),
                  delay: const Duration(milliseconds: 100),
                  child: Text(
                    'Help keep Timor-Leste clean by reporting waste issues',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Location section
                FadeInUp(
                  duration: const Duration(milliseconds: 400),
                  delay: const Duration(milliseconds: 200),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: theme.primaryColor,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Location',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (_isLocating)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Location display
                        if (_latitude != null && _longitude != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Location name
                              Text(
                                _locationName ?? 'Location detected',
                                style: TextStyle(
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              // Mini map preview
                              Container(
                                height: 160,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: FlutterMap(
                                  options: MapOptions(
                                    initialCenter: LatLng(_latitude!, _longitude!),
                                    initialZoom: 15,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName: 'com.example.tl_waste_monitoring',
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          width: 40.0,
                                          height: 40.0,
                                          point: LatLng(_latitude!, _longitude!),
                                          child: const Icon(
                                            Icons.location_pin,
                                            color: Colors.red,
                                            size: 40,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Detecting your location...',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        const SizedBox(height: 16),
                        
                        // Refresh location button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _getCurrentLocation,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Refresh Location'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade200,
                              foregroundColor: Colors.grey.shade800,
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Description field
                FadeInUp(
                  duration: const Duration(milliseconds: 400),
                  delay: const Duration(milliseconds: 250),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.description,
                              color: theme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Description',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Optional: Add details about the waste',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            hintText: 'Describe the waste (optional)',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Photo section
                FadeInUp(
                  duration: const Duration(milliseconds: 400),
                  delay: const Duration(milliseconds: 300),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.photo_camera,
                              color: theme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Photo',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Take a photo of the waste to help with analysis',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 16),
                        
                        // Image preview
                        if (_imageFile != null)
                          Stack(
                            children: [
                              Container(
                                width: double.infinity,
                                height: 200,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: FileImage(_optimizedImageFile ?? _imageFile!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              // Image optimization indicator
                              if (_isOptimizingImage)
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.black.withOpacity(0.7),
                                    child: const Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          CircularProgressIndicator(color: Colors.white),
                                          SizedBox(height: 12),
                                          Text(
                                            "Optimizing image...",
                                            style: TextStyle(color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              // Image info tag
                              if (!_isOptimizingImage && _optimizedImageFile != null && _imageSizeKB != null)
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check_circle, color: Colors.green, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${_imageSizeKB!.toStringAsFixed(0)} KB',
                                          style: const TextStyle(color: Colors.white, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              // Dimensions info tag
                              if (!_isOptimizingImage && _optimizedImageFile != null)
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.aspect_ratio, color: Colors.white, size: 14),
                                        SizedBox(width: 4),
                                        Text(
                                          'Max 771×1024',
                                          style: TextStyle(color: Colors.white, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              // Close button
                              Positioned(
                                top: 8,
                                right: 8,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _imageFile = null;
                                      _optimizedImageFile = null;
                                      _imageSizeKB = null;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Container(
                            width: double.infinity,
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.photo_camera, size: 48, color: Colors.grey),
                                const SizedBox(height: 8),
                                const Text(
                                  'Take a photo to continue',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Image will be optimized to max 500KB',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 16),

                        // Photo buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isOptimizingImage ? null : _takePhoto,
                                icon: const Icon(Icons.camera_alt),
                                label: Text(_imageFile == null ? 'Take Photo' : 'Retake Photo'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  disabledBackgroundColor: Colors.grey.shade300,
                                  disabledForegroundColor: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Image optimization info
                        if (_imageFile != null && !_isOptimizingImage)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _optimizedImageFile != null ? Icons.check_circle : Icons.info_outline,
                                  size: 14,
                                  color: _optimizedImageFile != null ? Colors.green : Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _optimizedImageFile != null
                                      ? 'Image optimized to ${_imageSizeKB!.toStringAsFixed(0)} KB'
                                      : 'Optimization pending',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _optimizedImageFile != null ? Colors.green : Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Error message if any
                if (_errorMessage != null)
                  FadeInUp(
                    duration: const Duration(milliseconds: 400),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red.shade700,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                const SizedBox(height: 24),
                
                // Submit button
                FadeInUp(
                  duration: const Duration(milliseconds: 400),
                  delay: const Duration(milliseconds: 500),
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: (_isOptimizingImage || _optimizedImageFile == null || _imageFile == null || _latitude == null || _longitude == null) 
                        ? null 
                        : _submitReport,
                      icon: const Icon(Icons.send),
                      label: const Text(
                        'SUBMIT REPORT',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ],
    );
  }
}