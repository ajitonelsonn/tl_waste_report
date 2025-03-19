import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';

class ImageService {
  final String baseUrl;
  final int quality;
  final int maxWidth;
  
  ImageService({
    String? customBaseUrl,
    this.quality = 80,
    this.maxWidth = 1200,
  }) : baseUrl = customBaseUrl ?? dotenv.env['API_BASE_URL'] ?? 'http://localhost:5001';

  // Configure headers with optional token
  Map<String, String> _getHeaders({String? token}) {
    final headers = {
      'Accept': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }

  // Compress image file
  Future<File> compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath = path.join(dir.path, '${const Uuid().v4()}.jpg');
    
    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: quality,
      minWidth: maxWidth,
    );
    
    if (result == null) {
      // If compression fails, return original file
      return file;
    }
    
    return File(result.path);
  }

  // Convert image to base64 string
  Future<String> imageToBase64(File file) async {
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  // Upload image to server
  Future<Map<String, dynamic>> uploadImage(File file, {String? token}) async {
    try {
      // First compress the image
      final compressedFile = await compressImage(file);
      
      // Create multipart request
      final url = Uri.parse('$baseUrl/api/upload');
      final request = http.MultipartRequest('POST', url);
      
      // Add headers
      request.headers.addAll(_getHeaders(token: token));
      
      // Add file
      final fileStream = http.ByteStream(compressedFile.openRead());
      final fileLength = await compressedFile.length();
      final multipartFile = http.MultipartFile(
        'image',
        fileStream,
        fileLength,
        filename: path.basename(compressedFile.path),
      );
      
      request.files.add(multipartFile);
      
      // Send the request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'url': data['url'],
        };
      } else {
        return {
          'success': false,
          'message': 'Upload failed with status code: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error uploading image: ${e.toString()}',
      };
    }
  }

  // Convert base64 to image file
  Future<File> base64ToImage(String base64String) async {
    final bytes = base64Decode(base64String);
    final dir = await getTemporaryDirectory();
    final file = File(path.join(dir.path, '${const Uuid().v4()}.jpg'));
    await file.writeAsBytes(bytes);
    return file;
  }

  // Save an image to local documents directory
  Future<File> saveImageLocally(File imageFile, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(path.join(dir.path, 'images'));
    
    // Create directory if it doesn't exist
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    
    final localPath = path.join(imagesDir.path, fileName);
    return await imageFile.copy(localPath);
  }

  // Delete local image file
  Future<bool> deleteLocalImage(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting local image: ${e.toString()}');
      return false;
    }
  }

  // Get local image directory path
  Future<String> getLocalImageDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = path.join(dir.path, 'images');
    
    // Create directory if it doesn't exist
    final dirObj = Directory(imagesDir);
    if (!await dirObj.exists()) {
      await dirObj.create(recursive: true);
    }
    
    return imagesDir;
  }

  // Create a unique file name for an image
  String generateUniqueImageName() {
    return '${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}.jpg';
  }
}