import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/services.dart';

import '../providers/report_provider.dart';
import '../providers/auth_provider.dart';
import '../models/report.dart';
import '../widgets/report_card.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/report_tracking_widget.dart';
import 'report_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'report_detail_screen.dart';
import '../utils/navigation_utils.dart'; // Import the navigation mixin

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';

  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with ConfirmExitMixin {
  int _currentIndex = 0;
  bool _isInit = false;
  bool _isRefreshing = false;
  bool _isOnline = true;
  
  // List of page titles
  final List<String> _titles = [
    'TL Waste Monitoring',
    'Waste Map',
    'My Profile'
  ];
  
  late final List<Widget> _pages;
  
  @override
  void initState() {
    super.initState();
    _pages = [
      _buildHomeContent(),
      const MapScreen(isInTabView: true),
      const ProfileScreen(isInTabView: true)
    ];
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Load reports on first load
    if (!_isInit) {
      _loadReports();
      _setupConnectivityListener();
      _isInit = true;
    }
  }
  
  // Set up connectivity listener
  void _setupConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      final isOnline = result != ConnectivityResult.none;
      
      if (isOnline && !_isOnline) {
        // Came back online, refresh data
        _refreshReports();
      }
      
      setState(() {
        _isOnline = isOnline;
      });
    });
    
    // Check initial connectivity
    Connectivity().checkConnectivity().then((result) {
      setState(() {
        _isOnline = result != ConnectivityResult.none;
      });
    });
  }
  
  // Initial loading of reports
  Future<void> _loadReports() async {
    final reportProvider = Provider.of<ReportProvider>(context, listen: false);
    await reportProvider.loadUserReports();
  }
  
  // Pull-to-refresh implementation
  Future<void> _refreshReports() async {
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      final reportProvider = Provider.of<ReportProvider>(context, listen: false);
      await reportProvider.loadUserReports();
    } catch (e) {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refresh reports: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }
  
  void _navigateToReportScreen() {
    if (!_isOnline) {
      // Show error message if offline
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to be online to submit reports'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReportScreen()),
    ).then((_) {
      // Refresh when returning from report screen
      _refreshReports();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    // Use WillPopScope to handle back button press
    return WillPopScope(
      onWillPop: onWillPop, // Use the mixin's method
      child: Scaffold(
        appBar: AppBar(
          title: Text(_titles[_currentIndex]),
          elevation: 0,
          // Remove back button from home screen
          automaticallyImplyLeading: false,
          // Add refresh button only on home tab
          actions: [
            if (_currentIndex == 0) 
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _isRefreshing ? null : _refreshReports,
                tooltip: 'Refresh',
              ),
          ],
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          elevation: 8,
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Home tab
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _currentIndex = 0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _currentIndex == 0 ? Icons.home : Icons.home_outlined,
                          color: _currentIndex == 0 
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade600,
                        ),
                        Text(
                          'Home',
                          style: TextStyle(
                            color: _currentIndex == 0 
                                ? Theme.of(context).primaryColor
                                : Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: _currentIndex == 0 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Map tab
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _currentIndex = 1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _currentIndex == 1 ? Icons.map : Icons.map_outlined,
                          color: _currentIndex == 1 
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade600,
                        ),
                        Text(
                          'Map',
                          style: TextStyle(
                            color: _currentIndex == 1 
                                ? Theme.of(context).primaryColor
                                : Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: _currentIndex == 1 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Add Report button (centered)
                Expanded(
                  child: InkWell(
                    onTap: _navigateToReportScreen,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add_a_photo,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const Text(
                          'Report',
                          style: TextStyle(
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Profile tab
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _currentIndex = 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _currentIndex == 2 ? Icons.person : Icons.person_outline,
                          color: _currentIndex == 2 
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade600,
                        ),
                        Text(
                          'Profile',
                          style: TextStyle(
                            color: _currentIndex == 2 
                                ? Theme.of(context).primaryColor
                                : Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: _currentIndex == 2 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildHomeContent() {
    return Column(
      children: [
        // Offline indicator - only shown when offline
        if (!_isOnline)
          FadeInDown(
            duration: const Duration(milliseconds: 400),
            child: Container(
              color: Colors.red.shade700,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              width: double.infinity,
              child: const Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No internet connection. You need to be online to submit reports.',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        // Report tracking widget
        const ReportTrackingWidget(),
        
        // Main reports list
        Expanded(
          child: Consumer<ReportProvider>(
            builder: (ctx, reportProvider, _) {
              final reports = reportProvider.reports;
              final isLoading = reportProvider.isLoading;
              final hasError = reportProvider.hasError;
              
              // Loading state
              if (isLoading && reports.isEmpty) {
                return const Center(
                  child: LoadingIndicator(message: 'Loading reports...'),
                );
              }
              
              // Error state
              if (hasError && reports.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 60,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          reportProvider.errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _refreshReports,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try Again'),
                        style: ButtonStyle(
                          padding: MaterialStateProperty.all<EdgeInsets>(
                            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              // Empty state
              if (reports.isEmpty) {
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        Image.asset(
                          'assets/images/empty_reports.png',
                          width: 180,
                          height: 180,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No reports yet',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'Start by reporting waste issues in your area',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _isOnline ? _navigateToReportScreen : null,
                          icon: const Icon(Icons.add_a_photo),
                          label: const Text('Create Report'),
                          style: ButtonStyle(
                            padding: MaterialStateProperty.all<EdgeInsets>(
                              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            ),
                            backgroundColor: MaterialStateProperty.resolveWith<Color>(
                              (Set<MaterialState> states) {
                                if (states.contains(MaterialState.disabled)) {
                                  return Colors.grey.shade300;
                                }
                                return Theme.of(context).primaryColor;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                );
              }
              
              // Sort by date (newest first)
              final sortedReports = List<Report>.from(reports);
              sortedReports.sort((a, b) => b.reportDate.compareTo(a.reportDate));
              
              // Reports list
              return RefreshIndicator(
                onRefresh: _refreshReports,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedReports.length,
                  itemBuilder: (ctx, index) {
                    final report = sortedReports[index];
                    return ReportCard(
                      report: report,
                      onTap: () {
                        Navigator.of(context).pushNamed(
                          ReportDetailScreen.routeName,
                          arguments: report.id,
                        ).then((_) {
                          // Refresh reports when returning from detail screen
                          _refreshReports();
                        });
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}