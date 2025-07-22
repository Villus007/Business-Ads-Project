import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/business_ad.dart';

// Move enum to top-level
enum ImageUploadStrategy { directUpload, preSignedUrl }

class ApiService extends ChangeNotifier {
  static const String _baseUrl =
      "https://um7x7rirpc.execute-api.us-east-1.amazonaws.com/prod";

  // Development mode flag - set to true to work with local storage instead of AWS
  static const bool _isDevelopmentMode = false;

  // Image upload strategy
  static const ImageUploadStrategy _uploadStrategy =
      ImageUploadStrategy.preSignedUrl;

  // Local cache for user information (temporary solution)
  final Map<String, Map<String, dynamic>> _userInfoCache = {};

  // Additional cache by username for fallback lookup
  final Map<String, Map<String, dynamic>> _userInfoByName = {};

  // Constructor
  ApiService() {
    // Pre-populate cache with known usernames from previous sessions
    _initializeKnownUsers();
  }

  void _initializeKnownUsers() {
    // Add known usernames that may exist on the server
    final knownUsers = [
      'Tasty Food Biz',
      'Best Burgers',
      'Pizza Palace',
      'Coffee Corner',
      'Sweet Treats',
    ];

    for (final userName in knownUsers) {
      final userId = userName.toLowerCase().replaceAll(' ', '_');
      _userInfoByName[userName.toLowerCase()] = {
        'userName': userName,
        'userId': userId,
        'userProfileImage': null,
        'createdAt': DateTime.now().toIso8601String(),
      };
    }

    print('📝 Pre-populated ${knownUsers.length} known usernames in cache');
  }

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
      final contentType = _getContentType(filename);
      final response = await http
          .get(
            Uri.parse(
              '$_baseUrl/presigned-url?filename=$filename&contentType=$contentType',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('🔗 Presigned URL response: ${responseData.toString()}');

        // Check if response contains required fields
        if (responseData['uploadUrl'] == null) {
          throw Exception('uploadUrl is null in presigned URL response');
        }
        if (responseData['cloudFrontUrl'] == null) {
          throw Exception('cloudFrontUrl is null in presigned URL response');
        }

        return {
          'uploadUrl': responseData['uploadUrl'] as String,
          'cloudFrontUrl': responseData['cloudFrontUrl'] as String,
        };
      } else {
        print(
          '❌ Presigned URL error: ${response.statusCode} - ${response.body}',
        );
        throw Exception('Failed to get presigned URL: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Presigned URL exception: ${e.toString()}');
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
      // Cache user information locally for this ad (both by ID and username)
      final userInfo = {
        'userName': ad.userName,
        'userId': ad.userId,
        'userProfileImage': ad.userProfileImage,
        'createdAt': ad.createdAt.toIso8601String(),
      };

      _userInfoCache[ad.id] = userInfo;
      _userInfoByName[ad.userName.toLowerCase()] = userInfo;

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
        print('💾 User info cached locally for ad: ${ad.id}');
        notifyListeners();
      } else {
        // Remove from cache if submission failed
        _userInfoCache.remove(ad.id);
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
    // Fetch from AWS with featured filter
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/ads?featured=true'),
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
            .toList();

        print('🌟 Fetched ${featuredAds.length} featured ads from AWS');
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

  /// Get ads by specific user
  Future<List<BusinessAd>> getAdsByUser(String userId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/ads?userId=$userId'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic> adsJson = responseData['ads'] ?? [];
        final List<BusinessAd> userAds = adsJson
            .map((adJson) => BusinessAd.fromJson(adJson))
            .toList();

        print('👤 Fetched ${userAds.length} ads for user: $userId');
        return userAds;
      } else {
        throw Exception(
          'Failed to fetch user ads: HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error fetching user ads: $e');
      return [];
    }
  }

  /// Get ads by username
  Future<List<BusinessAd>> getAdsByUserName(String userName) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/ads?userName=$userName'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic> adsJson = responseData['ads'] ?? [];
        final List<BusinessAd> userAds = adsJson
            .map((adJson) => BusinessAd.fromJson(adJson))
            .toList();

        print('👤 Fetched ${userAds.length} ads for user: $userName');
        return userAds;
      } else {
        throw Exception(
          'Failed to fetch user ads: HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error fetching user ads: $e');
      return [];
    }
  }

  /// Enhanced getBusinessAds with better error handling and user info merging
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
        final List<BusinessAd> ads = adsJson.map((adJson) {
          // Create ad from server data
          BusinessAd ad = BusinessAd.fromJson(adJson);

          print(
            '🔍 Processing ad: ${ad.title} - Username: "${ad.userName}" - ID: ${ad.id}',
          );

          // Merge with cached user info if available (try by ID first, then by username)
          Map<String, dynamic>? cachedInfo;

          if (_userInfoCache.containsKey(ad.id)) {
            cachedInfo = _userInfoCache[ad.id];
            print('💰 Found cached info by ID for: ${ad.id}');
          } else if (_userInfoByName.containsKey(ad.userName.toLowerCase())) {
            // Try username lookup for any ad that has a username (including server-returned usernames)
            cachedInfo = _userInfoByName[ad.userName.toLowerCase()];
            print('👤 Found cached info by username for: "${ad.userName}"');
          } else {
            print(
              '❌ No cached info found for: "${ad.userName}" (ID: ${ad.id})',
            );
            print(
              '📋 Available usernames in cache: ${_userInfoByName.keys.toList()}',
            );
          }

          if (cachedInfo != null) {
            ad = BusinessAd(
              id: ad.id,
              title: ad.title,
              description: ad.description,
              imageUrls: ad.imageUrls,
              userName: cachedInfo['userName'] ?? ad.userName,
              userId: cachedInfo['userId'] ?? ad.userId,
              userProfileImage:
                  cachedInfo['userProfileImage'] ?? ad.userProfileImage,
              createdAt: cachedInfo['createdAt'] != null
                  ? DateTime.parse(cachedInfo['createdAt']!)
                  : ad.createdAt,
            );
            print(
              '🔄 Merged cached user info for ad: ${ad.id} - User: ${ad.userName}',
            );
          }

          return ad;
        }).toList();

        print('🌐 Fetched ${ads.length} ads from AWS');
        print('💾 Active cache entries: ${_userInfoCache.length}');
        return ads;
      } else {
        throw Exception('Failed to fetch ads: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching ads: $e');
      return [];
    }
  }

  /// Delete a business ad
  Future<bool> deleteBusinessAd(String adId) async {
    try {
      print('🗑️ Deleting ad: $adId');

      if (_isDevelopmentMode) {
        // In development mode, just remove from local storage
        print('🔧 Development mode: Removing from local storage');

        final prefs = await SharedPreferences.getInstance();
        final adsJson = prefs.getString('business_ads') ?? '[]';
        final List<dynamic> adsList = json.decode(adsJson);

        // Remove the ad with matching ID
        adsList.removeWhere((ad) => ad['id'] == adId);

        // Save back to local storage
        await prefs.setString('business_ads', json.encode(adsList));

        // Remove from local cache
        _userInfoCache.remove(adId);

        // Notify listeners to refresh UI
        notifyListeners();
        print('✅ Ad deleted from local storage');
        return true;
      } else {
        // In production mode, send proper DELETE request to root endpoint
        final response = await http
            .delete(
              Uri.parse('$_baseUrl/'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: json.encode({
                'id': adId,
                'hard': false, // Use soft delete by default
              }),
            )
            .timeout(const Duration(seconds: 30));

        print('📡 Delete response status: ${response.statusCode}');
        print('📡 Delete response body: ${response.body}');

        if (response.statusCode >= 200 && response.statusCode < 300) {
          // Parse the response to check if deletion was successful
          try {
            final responseData = json.decode(response.body);
            final success = responseData['success'] ?? false;

            if (success) {
              print('✅ Ad deleted successfully');

              // Remove from local cache
              _userInfoCache.remove(adId);

              // Notify listeners to refresh UI
              notifyListeners();
              return true;
            } else {
              final error = responseData['error'] ?? 'Unknown error';
              print('❌ Delete failed: $error');
              return false;
            }
          } catch (e) {
            print('❌ Error parsing delete response: $e');
            return false;
          }
        } else {
          print('❌ Failed to delete ad: HTTP ${response.statusCode}');
          return false;
        }
      }
    } catch (e) {
      print('❌ Error deleting ad: $e');
      return false;
    }
  }
}
