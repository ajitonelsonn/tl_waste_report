import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/report.dart';
import '../models/user.dart';
import '../utils/image_utils.dart';

class ApiService {
  final String apiBaseUrl;
  final String reportingAgentUrl;
  final Dio _dio = Dio();
  
  ApiService({String? customApiBaseUrl, String? customReportingAgentUrl}) 
      : apiBaseUrl = customApiBaseUrl ?? dotenv.env['API_BASE_URL'] ?? 'http://localhost:5002',
        reportingAgentUrl = customReportingAgentUrl ?? dotenv.env['REPORTING_AGENT_URL'] ?? 'http://localhost:5001';
  
  // Configure headers with optional authentication token
  Map<String, String> _getHeaders({String? token}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }

  // Authentication
  
  // Register new user
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    String? phoneNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/auth/register'),
        headers: _getHeaders(),
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          if (phoneNumber != null) 'phone_number': phoneNumber,
        }),
      );
      
      return _parseResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to register: ${e.toString()}',
      };
    }
  }
  
  // Login user
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/auth/login'),
        headers: _getHeaders(),
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );
      
      return _parseResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to login: ${e.toString()}',
      };
    }
  }
  
  // Change password
  Future<Map<String, dynamic>> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/auth/change-password'),
        headers: _getHeaders(token: token),
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );
      
      return _parseResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to change password: ${e.toString()}',
      };
    }
  }
  
  // User profile
  
  // Get user profile
  Future<Map<String, dynamic>> getUserProfile({
    required int userId,
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/users/$userId'),
        headers: _getHeaders(token: token),
      );
      
      return _parseResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get user profile: ${e.toString()}',
      };
    }
  }
  
  // Update user profile
  Future<Map<String, dynamic>> updateUserProfile({
    required int userId,
    required String token,
    String? email,
    String? phoneNumber,
    String? profileImageUrl,
  }) async {
    try {
      final Map<String, dynamic> body = {};
      if (email != null) body['email'] = email;
      if (phoneNumber != null) body['phone_number'] = phoneNumber;
      if (profileImageUrl != null) body['profile_image_url'] = profileImageUrl;
      
      if (body.isEmpty) {
        return {
          'success': false,
          'message': 'No fields to update',
        };
      }
      
      final response = await http.patch(
        Uri.parse('$apiBaseUrl/api/users/$userId'),
        headers: _getHeaders(token: token),
        body: jsonEncode(body),
      );
      
      return _parseResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update profile: ${e.toString()}',
      };
    }
  }
  
  // Get user reports
  Future<Map<String, dynamic>> getUserReports({
    required int userId,
    required String token,
    int page = 1,
    int perPage = 100,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/users/$userId/reports?page=$page&per_page=$perPage'),
        headers: _getHeaders(token: token),
      );
      
      return _parseResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get user reports: ${e.toString()}',
      };
    }
  }
  
  // Report management
  
  // Get reports with filtering
  Future<Map<String, dynamic>> getReports({
    required String token,
    String? status,
    String? wasteType,
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      String url = '$apiBaseUrl/api/reports?page=$page&per_page=$perPage';
      if (status != null) url += '&status=$status';
      if (wasteType != null) url += '&waste_type=$wasteType';
      
      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(token: token),
      );
      
      return _parseResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get reports: ${e.toString()}',
      };
    }
  }
  
  // Get nearby reports
  Future<Map<String, dynamic>> getNearbyReports({
    required String token,
    required double latitude,
    required double longitude,
    double radius = 5.0,
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/reports/nearby?lat=$latitude&lon=$longitude&radius=$radius&page=$page&per_page=$perPage'),
        headers: _getHeaders(token: token),
      );
      
      return _parseResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get nearby reports: ${e.toString()}',
      };
    }
  }
  
  // Get report details
  Future<Map<String, dynamic>> getReport({
    required int reportId,
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$reportingAgentUrl/api/reports/$reportId'),
        headers: _getHeaders(token: token),
      );
      
      return _parseResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get report: ${e.toString()}',
      };
    }
  }
  
  // Submit a new report (to reporting agent)
  Future<Map<String, dynamic>> submitReport({
    required int userId,
    required double latitude,
    required double longitude,
    required String description,
    File? image,
    Map<String, dynamic>? deviceInfo,
    String? token,
  }) async {
    try {
      // Prepare report data
      final Map<String, dynamic> reportData = {
        'user_id': userId,
        'latitude': latitude,
        'longitude': longitude,
        'description': description,
        'device_info': deviceInfo ?? _getDeviceInfo(),
      };
      
      // Add image if available
      if (image != null) {
        final imageBase64 = await ImageUtils.imageToBase64(image);
        reportData['image_data'] = imageBase64;
      }
      
      // Make API request to reporting agent
      final response = await http.post(
        Uri.parse('$reportingAgentUrl/api/reports'),
        headers: _getHeaders(token: token),
        body: jsonEncode(reportData),
      );
      
      return _parseResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to submit report: ${e.toString()}',
      };
    }
  }
  
  // Waste types
  
  // Get waste types
  Future<Map<String, dynamic>> getWasteTypes({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/waste-types'),
        headers: _getHeaders(token: token),
      );
      
      return _parseResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get waste types: ${e.toString()}',
      };
    }
  }
  
  // Submit multiple pending reports (for offline support)
  Future<List<Map<String, dynamic>>> submitPendingReports(
    List<Map<String, dynamic>> pendingReports, 
    {String? token}
  ) async {
    final results = <Map<String, dynamic>>[];
    
    for (final reportData in pendingReports) {
      try {
        final response = await submitReport(
          userId: reportData['user_id'],
          latitude: reportData['latitude'],
          longitude: reportData['longitude'],
          description: reportData['description'],
          image: reportData['image_path'] != null 
              ? File(reportData['image_path']) 
              : null,
          deviceInfo: reportData['device_info'],
          token: token,
        );
        
        results.add({
          'local_id': reportData['local_id'],
          'success': response['success'] == true,
          'report_id': response['report_id'],
          'message': response['message'] ?? 'Report submitted successfully'
        });
      } catch (e) {
        results.add({
          'local_id': reportData['local_id'],
          'success': false,
          'message': e.toString()
        });
      }
    }
    
    return results;
  }

  // Add these methods to your existing ApiService class

  // Verify Registration OTP

   Future<Map<String, dynamic>> verifyRegistration({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/auth/verify-registration'),
        headers: _getHeaders(),
        body: jsonEncode({
          'email': email,
          'otp': otp,
        }),
      );
      
      return _parseResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to verify registration. Please try again.',
      };
    }
  }
  
  // Verify OTP for existing account
  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/auth/verify-otp'),
        headers: _getHeaders(),
        body: jsonEncode({
          'email': email,
          'otp': otp,
        }),
      );
      
      return _parseResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to verify OTP. Please try again.',
      };
    }
  }
  
  // Resend OTP for registration
  Future<Map<String, dynamic>> resendRegistrationOtp({
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/auth/resend-otp'),
        headers: _getHeaders(),
        body: jsonEncode({
          'email': email,
        }),
      );
      
      return _parseResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to resend OTP. Please try again.',
      };
    }
  }
  
  // Send OTP for existing account
  Future<Map<String, dynamic>> sendOtp({
    required String email,
    required String username,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/auth/send-otp'),
        headers: _getHeaders(),
        body: jsonEncode({
          'email': email,
          'username': username,
        }),
      );
      
      return _parseResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to send OTP. Please try again.',
      };
    }
  }

// Delete a report
Future<Map<String, dynamic>> deleteReport({
  required int reportId,
  required String token,
}) async {
  try {
    final response = await http.delete(
      Uri.parse('$apiBaseUrl/api/reports/$reportId'),
      headers: _getHeaders(token: token),
    );
    
    return _parseResponse(response);
  } catch (e) {
    return {
      'success': false,
      'message': 'Failed to delete report: ${e.toString()}',
    };
  }
}
  
  // Helper methods
  
  // Parse HTTP response
Map<String, dynamic> _parseResponse(http.Response response) {
  try {
    print("API Response Status Code: ${response.statusCode}");
    print("API Response Body: ${response.body}");
    
    final data = jsonDecode(response.body);
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return {
        'success': true,
        ...data,
      };
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Unknown error occurred',
        'statusCode': response.statusCode,
      };
    }
  } catch (e) {
    print("Error parsing response: $e");
    return {
      'success': false,
      'message': 'Failed to parse response: ${e.toString()}',
      'statusCode': response.statusCode,
    };
  }
}
  
  // Get basic device info for tracking
  Map<String, dynamic> _getDeviceInfo() {
    return {
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
      'app_version': '1.0.0', // TODO: Use actual app version
    };
  }
}