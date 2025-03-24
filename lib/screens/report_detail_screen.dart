import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../models/report.dart';
import '../providers/report_provider.dart';
import '../widgets/app_bar.dart';
import '../widgets/custom_button.dart';
import '../widgets/loading_indicator.dart';
import '../utils/date_utils.dart' as date_utils;
import 'dart:io';

class ReportDetailScreen extends StatefulWidget {
  static const routeName = '/report-detail';
  final int reportId;

  const ReportDetailScreen({
    Key? key,
    required this.reportId,
  }) : super(key: key);

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  Report? _report;
  bool _isLoading = true;
  bool _isDeleting = false;
  String? _errorMessage;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final reportProvider = Provider.of<ReportProvider>(context, listen: false);
      final report = await reportProvider.getReportById(widget.reportId);

      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load report: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  
  // Delete report function
  Future<void> _deleteReport() async {
    // Show confirmation dialog first
    final shouldDelete = await _showDeleteConfirmationDialog();
    
    if (shouldDelete != true) {
      return;
    }
    
    setState(() {
      _isDeleting = true;
    });
    
    try {
      final reportProvider = Provider.of<ReportProvider>(context, listen: false);
      
      // Convert nullable int? to non-nullable int
      final reportId = _report?.id;
      if (reportId == null) {
        throw Exception('Cannot delete report: Invalid report ID');
      }
      
      final success = await reportProvider.deleteReport(reportId);
      
      if (success) {
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate back to previous screen
          Navigator.of(context).pop(true); // Return true to indicate deletion success
        }
      } else {
        // Show error message
        if (mounted) {
          setState(() {
            _isDeleting = false;
            _errorMessage = 'Failed to delete report: ${reportProvider.errorMessage}';
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete report: ${reportProvider.errorMessage}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _errorMessage = 'Failed to delete report: ${e.toString()}';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete report: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Show confirmation dialog
  Future<bool?> _showDeleteConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Report'),
        content: const Text(
          'Are you sure you want to delete this report? This action cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'DELETE',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Report Details',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isDeleting ? null : _loadReport,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _isDeleting || _report == null ? null : _deleteReport,
            tooltip: 'Delete Report',
            color: Colors.red,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator(message: 'Loading report details...'))
          : _isDeleting
              ? const Center(child: LoadingIndicator(message: 'Deleting report...'))
              : _errorMessage != null
                  ? _buildErrorView()
                  : _report == null
                      ? _buildNotFoundView()
                      : _buildReportDetails(),
      bottomNavigationBar: _report != null && !_isLoading && !_isDeleting
          ? _buildBottomBar(context)
          : null,
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: CustomButton(
          text: 'Delete Report',
          icon: Icons.delete_outline,
          onPressed: _deleteReport,
          isFullWidth: true,
          isSecondary: true,
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Try Again',
              icon: Icons.refresh,
              onPressed: _loadReport,
              isFullWidth: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundView() {
    return const Center(
      child: Text('Report not found'),
    );
  }

  Widget _buildReportDetails() {
    final report = _report!;
    final theme = Theme.of(context);
    
    // Set up status color and icon
    Color statusColor;
    IconData statusIcon;
    String statusText = report.status;
    
    switch (report.status.toLowerCase()) {
      case 'submitted':
        statusColor = Colors.blue;
        statusIcon = Icons.send;
        statusText = 'Submitted';
        break;
      case 'analyzing':
        statusColor = Colors.orange;
        statusIcon = Icons.analytics;
        statusText = 'Analyzing';
        break;
      case 'analyzed':
        statusColor = Colors.purple;
        statusIcon = Icons.done_all;
        statusText = 'Analyzed';
        break;
      case 'resolved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Resolved';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Rejected';
        break;
      case 'pending':
        statusColor = Colors.amber.shade700;
        statusIcon = Icons.watch_later;
        statusText = 'Pending Upload';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusText = report.status;
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image (if available)
          if (report.imageUrl != null)
            report.isUploaded
                ? report.imageUrl!.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: report.imageUrl!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: double.infinity,
                          height: 200,
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                          ),
                        ),
                      )
                    : Container(
                        width: double.infinity,
                        height: 200,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.image, size: 48, color: Colors.grey),
                        ),
                      )
                : Image.file(
                    File(report.imageUrl!),
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: double.infinity,
                      height: 200,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                      ),
                    ),
                  ),

          // Status and date
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Status chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Date
                Text(
                  date_utils.formatFullDateTime(report.reportDate),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Description',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  report.description,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          
          // Full description from analysis (if available)
          if (report.fullDescription != null && report.fullDescription!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analysis Details',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      report.fullDescription!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 16),

          // Waste type and severity (if analyzed)
          if (report.wasteType != null || report.severityScore != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analysis',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (report.wasteType != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: theme.primaryColor),
                          ),
                          child: Text(
                            report.wasteType!,
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (report.priorityLevel != null) ...[
                        _buildPriorityChip(report.priorityLevel!),
                      ],
                    ],
                  ),
                  if (report.severityScore != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Severity Score: ${report.severityScore}/10',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          
          const SizedBox(height: 16),

          // Location
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Location',
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 8),
          
          // Location info
          if (report.locationName != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      report.locationName!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 8),

          // Coordinates
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Lat: ${report.latitude.toStringAsFixed(6)}, Lng: ${report.longitude.toStringAsFixed(6)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
          
          const SizedBox(height: 16),

          // Map
          SizedBox(
            height: 300,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                center: LatLng(report.latitude, report.longitude),
                zoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.tlwaste.monitoring',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(report.latitude, report.longitude),
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
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPriorityChip(String priorityLevel) {
    Color priorityColor;
    
    switch (priorityLevel.toLowerCase()) {
      case 'low':
        priorityColor = Colors.green;
        break;
      case 'medium':
        priorityColor = Colors.orange;
        break;
      case 'high':
        priorityColor = Colors.red.shade600;
        break;
      case 'critical':
        priorityColor = Colors.red.shade900;
        break;
      default:
        priorityColor = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: priorityColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: priorityColor),
      ),
      child: Text(
        priorityLevel,
        style: TextStyle(
          color: priorityColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}