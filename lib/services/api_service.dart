import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/business_ad.dart';

// Move enum to top-level
enum ImageUploadStrategy { directUpload, preSignedUrl }

class ApiService extends ChangeNotifier {
  static const String _baseUrl =
      "https://um7x7rirpc.execute-api.us-east-1.amazonaws.com/prod";

  // Image upload strategy
  static const ImageUploadStrategy _uploadStrategy =
      ImageUploadStrategy.preSignedUrl;

  // Constructor
  ApiService();

  /// Primary image upload method using pre-signed URL strategy (recommended)
  Future<String> uploadImageWithPreSignedUrl(
    Uint8List bytes, {
    required String filename,
    void Function(double progress)? onProgress,
  }) async {
    try {
      // Update progress to 10%
      onProgress?.call(0.1);

      // Step 1: Get pre-signed URL from Lambda
      onProgress?.call(0.2);
      final presignedData = await _getPresignedUploadUrl(filename);
      final presignedUrl = presignedData['uploadUrl']!;
      final finalCloudFrontUrl = presignedData['cloudFrontUrl']!;

      // Step 2: Upload directly to S3 using pre-signed URL
      onProgress?.call(0.3);
      final uploadResponse = await http
          .put(
            Uri.parse(presignedUrl),
            headers: {
              'Content-Type': _getContentType(filename),
              'Content-Length': bytes.length.toString(),
            },
            body: bytes,
          )
          .timeout(const Duration(seconds: 60));

      if (uploadResponse.statusCode == 200) {
        onProgress?.call(1.0);
        return finalCloudFrontUrl;
      } else {
        throw Exception('S3 upload failed: ${uploadResponse.statusCode}');
      }
    } catch (e) {
      throw Exception('Image upload failed: ${e.toString()}');
    }
  }

  /// Alternative image upload method using direct Lambda upload
  Future<String> uploadImageDirectly(
    Uint8List bytes, {
    required String filename,
    void Function(double progress)? onProgress,
  }) async {
    try {
      onProgress?.call(0.1);

      // Convert bytes to base64 for Lambda upload
      final base64Image = base64Encode(bytes);

      final response = await http
          .post(
            Uri.parse('$_baseUrl/upload-image'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'filename': filename,
              'imageData': base64Image,
              'contentType': _getContentType(filename),
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        onProgress?.call(1.0);
        return responseData['cloudFrontUrl'] as String;
      } else {
        throw Exception('Direct upload failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Image upload failed: ${e.toString()}');
    }
  }

  /// Main upload method that chooses strategy
  Future<String> uploadImageBytes(
    Uint8List bytes, {
    required String filename,
    void Function(double progress)? onProgress,
  }) async {
    switch (_uploadStrategy) {
      case ImageUploadStrategy.preSignedUrl:
        return uploadImageWithPreSignedUrl(
          bytes,
          filename: filename,
          onProgress: onProgress,
        );
      case ImageUploadStrategy.directUpload:
        return uploadImageDirectly(
          bytes,
          filename: filename,
          onProgress: onProgress,
        );
    }
  }

  /// Get pre-signed URL from Lambda function
  Future<Map<String, String>> _getPresignedUploadUrl(String filename) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/presigned-url?filename=$filename'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'uploadUrl': responseData['uploadUrl'] as String,
          'cloudFrontUrl': responseData['cloudFrontUrl'] as String,
        };
      } else {
        throw Exception('Failed to get presigned URL: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get presigned URL: ${e.toString()}');
    }
  }

  /// Get content type based on filename
  String _getContentType(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// Enhanced submitAd method with better error handling
  Future<void> submitAd(BusinessAd ad) async {
    try {
      print('🚀 Submitting ad to AWS: ${ad.title}');
      print('📄 Ad data: ${jsonEncode(ad.toJson())}');
      print('🌐 API URL: $_baseUrl/');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/'), // Changed from '/ads' to '/'
            body: jsonEncode(ad.toJson()),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Access-Control-Allow-Origin': '*',
              'Access-Control-Allow-Methods': 'POST, GET, OPTIONS, PUT, DELETE',
              'Access-Control-Allow-Headers': 'Content-Type, Authorization',
            },
          )
          .timeout(const Duration(seconds: 30));

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('✅ Ad submitted successfully to AWS');
        notifyListeners();
      } else {
        final errorBody = response.body;
        print('❌ HTTP Error: ${response.statusCode} - $errorBody');
        throw Exception(
          'Submission failed: HTTP ${response.statusCode} - $errorBody',
        );
      }
    } catch (e) {
      print('❌ Error submitting ad: $e');
      print('❌ Error type: ${e.runtimeType}');

      if (e.toString().contains('TimeoutException')) {
        throw Exception(
          'Request timeout: Please check your internet connection',
        );
      } else if (e.toString().contains('SocketException')) {
        throw Exception('Network error: Please check your internet connection');
      } else if (e.toString().contains('Failed to fetch')) {
        throw Exception(
          'Network error: Unable to connect to server. Please check your internet connection.',
        );
      } else {
        throw Exception('Submission failed: ${e.toString()}');
      }
    }
  }

  /// Enhanced getFeaturedAds with better error handling
  Future<List<BusinessAd>> getFeaturedAds() async {
    // Fetch from AWS
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/ads'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic> adsJson = responseData['ads'] ?? [];
        final List<BusinessAd> featuredAds = adsJson
            .map((adJson) => BusinessAd.fromJson(adJson))
            .take(3) // Take only first 3 ads as featured
            .toList();

        print('🌐 Fetched ${featuredAds.length} featured ads from AWS');
        return featuredAds;
      } else {
        throw Exception(
          'Failed to fetch featured ads: HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error fetching featured ads: $e');
      return [];
    }
  }

  /// Enhanced getBusinessAds with better error handling
  Future<List<BusinessAd>> getBusinessAds() async {
    // Fetch from AWS
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/ads'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic> adsJson = responseData['ads'] ?? [];
        final List<BusinessAd> ads = adsJson
            .map((adJson) => BusinessAd.fromJson(adJson))
            .toList();

        print('🌐 Fetched ${ads.length} ads from AWS');
        return ads;
      } else {
        throw Exception('Failed to fetch ads: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching ads: $e');
      return [];
    }
  }
}
