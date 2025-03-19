import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/user.dart';

class AuthService {
  final String baseUrl;
  
  AuthService({String? customBaseUrl}) 
      : baseUrl = customBaseUrl ?? dotenv.env['API_BASE_URL'] ?? 'http://localhost:5001';

  // Configure headers with optional token
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

  // Login user
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final url = Uri.parse('$baseUrl/auth/login');
      final response = await http.post(
        url,
        headers: _getHeaders(),
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'token': data['token'],
          'user': User.fromJson(data['user']),
          'expiresIn': data['expires_in'] ?? 86400, // Default to 24 hours
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  // Register user
  Future<Map<String, dynamic>> register(
    String username, 
    String email, 
    String password,
  ) async {
    try {
      final url = Uri.parse('$baseUrl/auth/register');
      final response = await http.post(
        url,
        headers: _getHeaders(),
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'token': data['token'],
          'user': User.fromJson(data['user']),
          'expiresIn': data['expires_in'] ?? 86400, // Default to 24 hours
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  // Update user profile
  Future<Map<String, dynamic>> updateProfile({
    required int userId,
    required String token,
    String? email,
    String? phoneNumber,
    String? profileImageUrl,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/users/$userId');
      
      final body = <String, dynamic>{};
      if (email != null) body['email'] = email;
      if (phoneNumber != null) body['phone_number'] = phoneNumber;
      if (profileImageUrl != null) body['profile_image_url'] = profileImageUrl;
      
      final response = await http.patch(
        url,
        headers: _getHeaders(token: token),
        body: jsonEncode(body),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'user': User.fromJson(data['user']),
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Profile update failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
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
      final url = Uri.parse('$baseUrl/auth/change-password');
      final response = await http.post(
        url,
        headers: _getHeaders(token: token),
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );
      
      if (response.statusCode == 200) {
        return {
          'success': true,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Password change failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  // Forgot password (request reset)
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final url = Uri.parse('$baseUrl/auth/forgot-password');
      final response = await http.post(
        url,
        headers: _getHeaders(),
        body: jsonEncode({
          'email': email,
        }),
      );
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Password reset link sent to your email',
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Password reset request failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  // Reset password (with token)
  Future<Map<String, dynamic>> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/auth/reset-password');
      final response = await http.post(
        url,
        headers: _getHeaders(),
        body: jsonEncode({
          'token': resetToken,
          'new_password': newPassword,
        }),
      );
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Password reset successful',
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Password reset failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  // Verify token validity
  Future<bool> verifyToken(String token) async {
    try {
      final url = Uri.parse('$baseUrl/auth/verify-token');
      final response = await http.get(
        url,
        headers: _getHeaders(token: token),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}