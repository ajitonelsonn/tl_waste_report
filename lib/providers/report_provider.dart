import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../models/report.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'auth_provider.dart';

class ReportProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final List<Report> _reports = [];
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  AuthProvider _authProvider;
  
  ReportProvider({required AuthProvider authProvider}) 
      : _authProvider = authProvider {
    // Initialize storage service
    _storageService.init();
  }
  
  // Update auth provider reference
  void updateAuth(AuthProvider authProvider) {
    _authProvider = authProvider;
  }
  
  // Getters
  List<Report> get reports => [..._reports];
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  
  // Get reports by status
  List<Report> getReportsByStatus(String status) {
    return _reports.where((report) => report.status.toLowerCase() == status.toLowerCase()).toList();
  }
  
  // Count reports by status
  int countReportsByStatus(String status) {
    return _reports.where((report) => report.status.toLowerCase() == status.toLowerCase()).length;
  }
  
  // Load user reports from API
  Future<void> loadUserReports() async {
    if (_authProvider.currentUser == null) {
      _setError('User not authenticated');
      return;
    }
    
    _setLoading(true);
    try {
      final userId = _authProvider.currentUser!.id;
      final token = _authProvider.token;
      
      final response = await _apiService.getUserReports(
        userId: userId,
        token: token!,
      );
      
      if (response['success']) {
        _reports.clear();
        if (response['reports'] != null) {
          for (var reportJson in response['reports']) {
            _reports.add(Report.fromJson(reportJson));
          }
        }
        
        _clearError();
      } else {
        _setError(response['message'] ?? 'Failed to load reports');
      }
    } catch (e) {
      _setError('Failed to load reports: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }
  
  // Submit a new report initially (just save to database without waiting for analysis)
  Future<Report?> submitReportInitial({
    required double latitude,
    required double longitude,
    required String description,
    File? image,
    Map<String, dynamic>? deviceInfo,
  }) async {
    if (_authProvider.currentUser == null) {
      _setError('User not authenticated');
      return null;
    }
    
    // Check internet connection
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult != ConnectivityResult.none;
    
    // If offline, return error
    if (!isOnline) {
      _setError('Internet connection required to submit reports');
      return null;
    }
    
    final userId = _authProvider.currentUser!.id;
    final token = _authProvider.token;
    
    _setLoading(true);
    try {
      // Online submission
      final response = await _apiService.submitReport(
        userId: userId,
        latitude: latitude,
        longitude: longitude,
        description: description,
        image: image,
        deviceInfo: deviceInfo,
        token: token,
      );
      
      if (response['status'] == 'success' && response['report_id'] != null) {
        // Create server report with the real ID
        final serverReport = Report(
          id: response['report_id'],
          userId: userId,
          latitude: latitude,
          longitude: longitude,
          description: description,
          imageUrl: response['image_url'] ?? image?.path,
          status: 'submitted',
          reportDate: DateTime.now(),
          deviceInfo: deviceInfo,
          isUploaded: true,
        );
        
        _reports.add(serverReport);
        notifyListeners();
        
        // Return the report with database confirmation
        return serverReport;
      } else {
        throw Exception('Failed to submit report: ${response['message']}');
      }
    } catch (e) {
      _setError('Failed to submit report: ${e.toString()}');
      return null;
    } finally {
      _setLoading(false);
    }
  }
  
  // Get a report by ID
  Future<Report?> getReportById(int reportId) async {
    try {
      // Check in submitted reports
      final reportIndex = _reports.indexWhere(
        (report) => report.id == reportId,
      );
      
      if (reportIndex >= 0) return _reports[reportIndex];
      
      // If not found locally, fetch from API
      _setLoading(true);
      
      if (_authProvider.currentUser != null && _authProvider.token != null) {
        final token = _authProvider.token!;
        
        final response = await _apiService.getReport(
          reportId: reportId,
          token: token,
        );
        
        if (response['success'] && response['report'] != null) {
          final report = Report.fromJson(response['report']);
          
          // Add to reports list if not exists
          if (!_reports.any((r) => r.id == reportId)) {
            _reports.add(report);
            notifyListeners();
          }
          
          return report;
        } else {
          _setError(response['message'] ?? 'Failed to get report');
          return null;
        }
      }
      
      return null;
    } catch (e) {
      _setError('Failed to get report: ${e.toString()}');
      return null;
    } finally {
      _setLoading(false);
    }
  }
  
  // Poll for report status updates
  Future<void> pollReportStatus(int reportId, {Duration interval = const Duration(seconds: 5)}) async {
    if (_authProvider.token == null) return;
    
    // Check current status
    Report? report = await getReportById(reportId);
    
    // Only poll for reports that are in submitted or analyzing states
    if (report == null || 
        !(report.status.toLowerCase() == 'submitted' || 
          report.status.toLowerCase() == 'analyzing')) {
      return;
    }
    
    try {
      final token = _authProvider.token!;
      
      final response = await _apiService.getReport(
        reportId: reportId,
        token: token,
      );
      
      if (response['success'] && response['report'] != null) {
        final updatedReport = Report.fromJson(response['report']);
        
        // Update report in list if status has changed
        final index = _reports.indexWhere((r) => r.id == reportId);
        if (index >= 0 && _reports[index].status != updatedReport.status) {
          _reports[index] = updatedReport;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error polling report status: ${e.toString()}');
    }
  }
  
  // Utility methods for state management
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String message) {
    _hasError = true;
    _errorMessage = message;
    notifyListeners();
  }
  
  void _clearError() {
    _hasError = false;
    _errorMessage = '';
    notifyListeners();
  }
}