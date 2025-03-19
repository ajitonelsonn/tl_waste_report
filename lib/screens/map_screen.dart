import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/report.dart';
import '../providers/report_provider.dart';
import '../providers/location_provider.dart';
import '../widgets/loading_indicator.dart';

class MapScreen extends StatefulWidget {
  static const routeName = '/map';
  final bool isInTabView;

  const MapScreen({Key? key, this.isInTabView = false}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  List<Marker> _markers = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  LatLng? _initialCenter;

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  // Initialize map with current location
  Future<void> _initMap() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Try to get current location
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      await locationProvider.getCurrentLocation();

      // Set initial camera position
      if (locationProvider.latitude != null && locationProvider.longitude != null) {
        _initialCenter = LatLng(
          locationProvider.latitude!,
          locationProvider.longitude!,
        );
      } else {
        // Fall back to default location (Dili, Timor-Leste)
        _initialCenter = LatLng(
          AppConfig.defaultLatitude,
          AppConfig.defaultLongitude,
        );
      }

      // Load reports and create markers
      await _loadReportsAndCreateMarkers();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize map: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Refresh map data
  Future<void> _refreshMap() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });

    try {
      // Refresh reports from API
      final reportProvider = Provider.of<ReportProvider>(context, listen: false);
      await reportProvider.loadUserReports();
      
      // Reload markers
      await _loadReportsAndCreateMarkers();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Map data refreshed'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refresh: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  // Load reports and create markers
  Future<void> _loadReportsAndCreateMarkers() async {
    try {
      final reportProvider = Provider.of<ReportProvider>(context, listen: false);

      // Get all reports
      final allReports = reportProvider.reports;

      // Create markers
      final markers = <Marker>[];
      for (final report in allReports) {
        markers.add(
          Marker(
            width: 40.0,
            height: 40.0,
            point: LatLng(report.latitude, report.longitude),
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(_getReportTitle(report)),
                    content: Text(report.description),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
              child: Icon(
                Icons.location_pin,
                color: _getMarkerColor(report),
                size: 40,
              ),
            ),
          ),
        );
      }

      setState(() {
        _markers = markers;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load reports: ${e.toString()}';
      });
    }
  }

  // Get appropriate marker color based on report status and severity
  Color _getMarkerColor(Report report) {
    // Determine marker color based on priority or status
    if (report.priorityLevel != null) {
      switch (report.priorityLevel!.toLowerCase()) {
        case 'critical':
          return Colors.red;
        case 'high':
          return Colors.orange;
        case 'medium':
          return Colors.amber;
        case 'low':
          return Colors.green;
        default:
          return Colors.blue;
      }
    } else {
      // Default marker color based on status
      switch (report.status.toLowerCase()) {
        case 'resolved':
          return Colors.green;
        case 'rejected':
          return Colors.red;
        case 'analyzed':
          return Colors.purple;
        case 'analyzing':
          return Colors.orange;
        case 'submitted':
        default:
          return Colors.blue;
      }
    }
  }

  // Get title for report marker
  String _getReportTitle(Report report) {
    // If waste type is available, use it as title
    if (report.wasteType != null && report.wasteType!.isNotEmpty) {
      return '${report.wasteType} Waste';
    }

    // Otherwise, use status
    return 'Waste Report (${report.status})';
  }

  @override
  Widget build(BuildContext context) {
    // For tab view, don't use a scaffold as it's already in one
    if (widget.isInTabView) {
      return _buildMapContent();
    }
    
    // For standalone view, use a scaffold with app bar
    return Scaffold(
      appBar: AppBar(
        title: const Text('Waste Map'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshMap,
          ),
        ],
      ),
      body: _buildMapContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: _centerOnUserLocation,
        child: const Icon(Icons.my_location),
        tooltip: 'My Location',
      ),
    );
  }
  
  // Map content widget
  Widget _buildMapContent() {
    return Stack(
      children: [
        // Map
        if (_initialCenter != null)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter!,
              initialZoom: AppConfig.defaultMapZoom,
              onTap: (_, __) {},
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.tl_waste_monitoring',
              ),
              MarkerLayer(markers: _markers),
            ],
          ),

        // Loading indicator
        if (_isLoading)
          Container(
            color: Colors.black26,
            child: const Center(
              child: LoadingIndicator(message: 'Loading map data...'),
            ),
          ),

        // Error message
        if (_errorMessage != null)
          Container(
            color: Colors.black26,
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _initMap,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        
        // Refresh button - positioned in the top right
        Positioned(
          right: 16,
          top: 16,
          child: FloatingActionButton.small(
            onPressed: _isRefreshing ? null : _refreshMap,
            backgroundColor: Colors.white,
            foregroundColor: Theme.of(context).primaryColor,
            child: _isRefreshing 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            heroTag: 'refreshButton',
            tooltip: 'Refresh Map',
          ),
        ),
        
        // My location button - positioned in the bottom right
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: _centerOnUserLocation,
            child: const Icon(Icons.my_location),
            heroTag: 'locationButton', // Prevent conflicts with other FABs
          ),
        ),
      ],
    );
  }

  // Center map on user location
  Future<void> _centerOnUserLocation() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    
    // Request current location
    await locationProvider.getCurrentLocation();
    
    // Center map on position
    if (locationProvider.latitude != null && locationProvider.longitude != null) {
      _mapController.move(
        LatLng(locationProvider.latitude!, locationProvider.longitude!),
        15,
      );
    } else {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to get current location'),
        ),
      );
    }
  }
}