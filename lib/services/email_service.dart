// lib/services/email_service.dart
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EmailService {
  // Generate a random OTP
  static String generateOTP() {
    final random = Random();
    // Generate a 6-digit code
    return (100000 + random.nextInt(900000)).toString();
  }

  // Send OTP email
  static Future<Map<String, dynamic>> sendOTPEmail(String email, String username, String otp) async {
    try {
      final apiBaseUrl = dotenv.env['API_BASE_URL'];
      if (apiBaseUrl == null) {
        throw Exception('API_BASE_URL not found in .env file');
      }
      
      print('Sending OTP request to API for email: $email');
      
      // Call backend API endpoint for sending emails
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'username': username,
          'otp': otp,
        }),
      );
      
      print('OTP API response: ${response.statusCode}');
      
      final responseData = json.decode(response.body);
      return {
        'success': response.statusCode == 200 && responseData['status'] == 'success',
        'data': responseData,
        'message': responseData['message'] ?? 'Unknown error'
      };
    } catch (e) {
      print('Error sending OTP email: $e');
      return {
        'success': false,
        'data': null,
        'message': e.toString()
      };
    }
  }
  
  // Resend OTP for registration
  static Future<Map<String, dynamic>> resendRegistrationOTP(String email) async {
    try {
      final apiBaseUrl = dotenv.env['API_BASE_URL'];
      if (apiBaseUrl == null) {
        throw Exception('API_BASE_URL not found in .env file');
      }
      
      // Call the resend OTP endpoint
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/auth/resend-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
        }),
      );
      
      print('Resend OTP API response: ${response.statusCode}');
      
      final responseData = json.decode(response.body);
      return {
        'success': response.statusCode == 200 && responseData['status'] == 'success',
        'data': responseData,
        'otp': responseData['otp'], // For development only
        'message': responseData['message'] ?? 'Unknown error'
      };
    } catch (e) {
      print('Error resending OTP: $e');
      return {
        'success': false,
        'data': null,
        'message': e.toString()
      };
    }
  }
}