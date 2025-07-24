import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as path;
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:io';
import '../models/business_ad.dart';
import '../services/api_service.dart';

class AddBusinessScreen extends StatefulWidget {
  const AddBusinessScreen({super.key});

  @override
  State<AddBusinessScreen> createState() => _AddBusinessScreenState();
}

class _AddBusinessScreenState extends State<AddBusinessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userNameController = TextEditingController();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  // Combined media selection (keeping original structure but combining images and videos)
  List<XFile> _selectedImages = [];
  List<XFile> _selectedVideos = [];
  bool _isSubmitting = false;
  double _uploadProgress = 0;
  
  // Error and success messages
  String? _errorMessage;
  String? _successMessage;
  String? _selectedCategory;
  
  // WeDeshi business categories
  final List<String> _categories = [
    'Restaurant & Food',
    'Fashion & Clothing',
    'Beauty & Wellness',
    'Electronics & Tech',
    'Home & Garden',
    'Automotive',
    'Education & Training',
    'Health & Medical',
    'Professional Services',
    'Entertainment & Events',
    'Sports & Fitness',
    'Travel & Tourism',
    'Real Estate',
    'Agriculture & Farming',
    'Handicrafts & Art',
    'Other',
  ];

  // Media optimization settings
  static const int _maxImageWidth = 1920;
  static const int _maxImageHeight = 1080;
  static const int _imageQuality = 85;
  static const int _maxImageFileSize = 5 * 1024 * 1024; // 5MB for images
  static const int _maxVideoFileSize = 20 * 1024 * 1024; // 20MB for videos

  @override
  void dispose() {
    _userNameController.dispose();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    try {
      setState(() {
        _errorMessage = null;
        _successMessage = null;
      });

      // Show media picker dialog for both images and videos
      final List<XFile> media = await _picker.pickMultipleMedia(
        requestFullMetadata: true,
        maxWidth: _maxImageWidth.toDouble(),
        maxHeight: _maxImageHeight.toDouble(),
        imageQuality: _imageQuality,
      );

      if (media.isNotEmpty) {
        List<XFile> validImages = [];
        List<XFile> validVideos = [];
        
        for (XFile file in media) {
          final bytes = await file.readAsBytes();
          final isVideo = _isVideoFile(file.name);
          final maxSize = isVideo ? _maxVideoFileSize : _maxImageFileSize;
          
          if (bytes.length > maxSize) {
            setState(() {
              _errorMessage = '${file.name} is too large. Maximum size is ${isVideo ? '20MB' : '5MB'}';
            });
            _showErrorSnackbar(_errorMessage!);
            continue;
          }
          
          if (isVideo) {
            if (validVideos.length < 1) { // Max 1 video
              validVideos.add(file);
            } else {
              setState(() {
                _errorMessage = 'Maximum 1 video allowed';
              });
              _showErrorSnackbar(_errorMessage!);
            }
          } else {
            if (validImages.length < 10) { // Max 10 images
              validImages.add(file);
            } else {
              setState(() {
                _errorMessage = 'Maximum 10 images allowed';
              });
              _showErrorSnackbar(_errorMessage!);
            }
          }
        }
        
        if (validImages.isNotEmpty || validVideos.isNotEmpty) {
          setState(() {
            _selectedImages = validImages;
            _selectedVideos = validVideos;
            _successMessage = '${validImages.length} image(s) and ${validVideos.length} video(s) selected successfully';
          });
          _showSuccessSnackbar(_successMessage!);
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error picking media: $e');
      _showErrorSnackbar(_errorMessage!);
    }
  }

  bool _isVideoFile(String filename) {
    final videoExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.3gp'];
    final lowerFilename = filename.toLowerCase();
    return videoExtensions.any((ext) => lowerFilename.endsWith(ext));
  }

  Future<void> _submitAd() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if at least one media file is selected
    if (_selectedImages.isEmpty && _selectedVideos.isEmpty) {
      setState(() => _errorMessage = 'Please select at least one image or video');
      _showErrorSnackbar(_errorMessage!);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _uploadProgress = 0;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final List<String> imageUrls = [];
      final List<String> videoUrls = [];
      final int totalImages = _selectedImages.length;
      final int totalVideos = _selectedVideos.length;
      final int totalMedia = totalImages + totalVideos;
      
      // Upload images
      for (int i = 0; i < totalImages; i++) {
        final image = _selectedImages[i];
        final baseProgress = i / totalMedia;
        setState(() {
          _uploadProgress = baseProgress;
        });
        
        Uint8List bytes = await image.readAsBytes();
        if (!kIsWeb) {
          bytes = await _compressImage(bytes, image.name);
        }
        
        final url = await apiService.uploadImageBytes(
          bytes,
          filename: _generateUniqueFilename(image.name),
          onProgress: (progress) {
            setState(() {
              _uploadProgress = baseProgress + (progress / totalMedia);
            });
          },
        );
        
        imageUrls.add(url);
        print('✅ Uploaded image ${i + 1}/$totalImages: ${image.name}');
      }

      // Upload videos
      for (int i = 0; i < totalVideos; i++) {
        final video = _selectedVideos[i];
        final baseProgress = (totalImages + i) / totalMedia;
        setState(() {
          _uploadProgress = baseProgress;
        });

        Uint8List bytes = await video.readAsBytes();
        
        final url = await apiService.uploadImageBytes(
          bytes,
          filename: _generateUniqueFilename(video.name),
          onProgress: (progress) {
            setState(() {
              _uploadProgress = baseProgress + (progress / totalMedia);
            });
          },
        );

        videoUrls.add(url);
        print('✅ Uploaded video ${i + 1}/$totalVideos: ${video.name}');
      }

      setState(() => _uploadProgress = 0.95);
      
      // Use the username from the form
      final ad = BusinessAd(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        imageUrls: imageUrls,
        videoUrls: videoUrls, // Add videoUrls to the ad
        userName: _userNameController.text.trim(),
        userId: _userNameController.text.trim().toLowerCase().replaceAll(
          ' ',
          '_',
        ), // Use username as consistent userId
        userProfileImage: null, // Optional profile image
        createdAt: DateTime.now(),
      );
      
      await apiService.submitAd(ad);
      
      setState(() {
        _uploadProgress = 1.0;
        _successMessage =
            'Great! ${_userNameController.text.trim()}\'s business ad is now live!';
      });
      
      _showSuccessSnackbar(_successMessage!);
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) Navigator.pop(context, true);
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Submission failed: ${e.toString()}';
        _isSubmitting = false;
        _uploadProgress = 0;
      });
      _showErrorSnackbar(_errorMessage!);
    }
  }

  Future<Uint8List> _compressImage(Uint8List bytes, String filename) async {
    try {
      int targetQuality = _imageQuality;
      if (bytes.length > 2 * 1024 * 1024) {
        targetQuality = 70;
      } else if (bytes.length > 1 * 1024 * 1024) {
        targetQuality = 80;
      }

      final compressedBytes = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 800,
        minHeight: 600,
        quality: targetQuality,
        format: CompressFormat.jpeg,
      );

      final compressionRatio =
          (bytes.length - compressedBytes.length) / bytes.length;
      print(
        '🗜️ Compressed $filename: ${_formatBytes(bytes.length)} → ${_formatBytes(compressedBytes.length)} (${(compressionRatio * 100).toStringAsFixed(1)}% reduction)',
      );

      return compressedBytes;
    } catch (e) {
      print('⚠️ Image compression failed for $filename, using original: $e');
      return bytes;
    }
  }

  String _generateUniqueFilename(String originalName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = path.extension(originalName);
    final nameWithoutExtension = path.basenameWithoutExtension(originalName);
    return '${nameWithoutExtension}_$timestamp$extension';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildImagePreview(XFile image) {
    return FutureBuilder<Uint8List>(
      future: image.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(
                  snapshot.data!,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, st) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.error, color: Colors.red),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Text(
                      _formatBytes(snapshot.data!.length),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          );
        } else if (snapshot.hasError) {
          return Container(
            color: Colors.grey[300],
            child: const Icon(Icons.error, color: Colors.red),
          );
        } else {
          return Container(
            color: Colors.grey[100],
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildVideoPreview(XFile video) {
    return FutureBuilder<Uint8List>(
      future: video.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: Colors.black,
                  child: const Center(
                    child: Icon(
                      Icons.videocam,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Text(
                      _formatBytes(snapshot.data!.length),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                // Play button overlay
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.6),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.play_arrow,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        } else if (snapshot.hasError) {
          return Container(
            color: Colors.grey[300],
            child: const Icon(Icons.error, color: Colors.red),
          );
        } else {
          return Container(
            color: Colors.grey[100],
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
              ),
            ),
          );
        }
      },
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // WeDeshi theme with orange color scheme
    final customTheme = Theme.of(context).copyWith(
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      primaryColor: const Color(0xFFFF6B35),
      textTheme: Theme.of(context).textTheme.copyWith(
        titleMedium: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF333333),
        ),
        bodySmall: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: Color(0xFF666666),
        ),
        bodyMedium: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: Color(0xFF333333),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        margin: EdgeInsets.zero,
        shadowColor: const Color(0xFFFF6B35).withOpacity(0.1),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFFFF6B35),
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 14,
          color: Color(0xFFBBBBBB),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        prefixIconColor: const Color(0xFFFF6B35),
        alignLabelWithHint: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B35),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          elevation: 4,
          shadowColor: const Color(0xFFFF6B35).withOpacity(0.3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFF6B35),
          side: const BorderSide(color: Color(0xFFFF6B35)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      dividerColor: const Color(0xFFE0E0E0),
    );
    
    return Theme(
      data: customTheme,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFFF6B35),
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Create Business Ad',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF6B35), Color(0xFFFF8A65)],
              ),
            ),
          ),
          actions: [
            if (_isSubmitting)
              const Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Welcome Header
                  Card(
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFF6B35), Color(0xFFFF8A65)],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.business_center,
                            color: Colors.white,
                            size: 32,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Create Your Business Ad',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tell us who you are and showcase your business to thousands of customers on WeDeshi',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Form fields
                  // Username field
                  TextFormField(
                    controller: _userNameController,
                    decoration: const InputDecoration(
                      labelText: 'Your Name *',
                      hintText: 'Enter your name (will be displayed as poster)',
                      prefixIcon: Icon(Icons.person),
                      helperText:
                          'This name will appear on all your business ads',
                    ),
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return 'Your name is required';
                      }
                      if (value!.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                    maxLength: 30,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Business Title *',
                      hintText: 'Enter your business name',
                      prefixIcon: Icon(Icons.business),
                    ),
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return 'Business title is required';
                      }
                      if (value!.trim().length < 3) {
                        return 'Title must be at least 3 characters';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                    maxLength: 50,
                  ),
                  const SizedBox(height: 16),

                  // Category Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Business Category *',
                      hintText: 'Select your business category',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: _categories.map((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(
                          category,
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 14,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedCategory = newValue;
                      });
                    },
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Please select a business category';
                      }
                      return null;
                    },
                    dropdownColor: Colors.white,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      color: Color(0xFF333333),
                    ),
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Color(0xFFFF6B35),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _descController,
                    decoration: const InputDecoration(
                      labelText: 'Business Description *',
                      hintText: 'Describe your business and services',
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 4,
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return 'Business description is required';
                      }
                      if (value!.trim().length < 10) {
                        return 'Description must be at least 10 characters';
                      }
                      return null;
                    },
                    maxLength: 200,
                  ),
                  const SizedBox(height: 24),

                  // Combined Media Selection
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Business Media *',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select images (max 5MB each) and videos (max 20MB each). Multiple files will automatically slide in your ad post!',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),

                          OutlinedButton.icon(
                            icon: const Icon(Icons.add_photo_alternate),
                            label: Text(
                              _selectedImages.isEmpty && _selectedVideos.isEmpty
                                  ? 'Select Media'
                                  : 'Change Media (${_selectedImages.length + _selectedVideos.length})',
                            ),
                            onPressed: _isSubmitting ? null : _pickMedia,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFF6B35),
                              side: const BorderSide(color: Color(0xFFFF6B35)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Selected: ${_selectedImages.length} image(s), ${_selectedVideos.length} video(s)',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (_selectedImages.isNotEmpty || _selectedVideos.isNotEmpty)
                                TextButton.icon(
                                  onPressed: _isSubmitting
                                      ? null
                                      : () {
                                          setState(() {
                                            _selectedImages.clear();
                                            _selectedVideos.clear();
                                            _successMessage = null;
                                          });
                                        },
                                  icon: const Icon(Icons.clear, size: 16),
                                  label: const Text('Clear All'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_selectedImages.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Image Preview',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 1,
                              ),
                              itemCount: _selectedImages.length,
                              itemBuilder: (context, index) => Stack(
                                fit: StackFit.expand,
                                children: [
                                  _buildImagePreview(_selectedImages[index]),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: _isSubmitting
                                          ? null
                                          : () {
                                              setState(() {
                                                _selectedImages.removeAt(index);
                                              });
                                            },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.red.withOpacity(0.8),
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: const Icon(
                                          Icons.close,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  if (_selectedVideos.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Video Preview',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 16 / 9,
                              ),
                              itemCount: _selectedVideos.length,
                              itemBuilder: (context, index) => Stack(
                                fit: StackFit.expand,
                                children: [
                                  _buildVideoPreview(_selectedVideos[index]),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: _isSubmitting
                                          ? null
                                          : () {
                                              setState(() {
                                                _selectedVideos.removeAt(index);
                                              });
                                            },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.red.withOpacity(0.8),
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: const Icon(
                                          Icons.close,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  if (_isSubmitting) ...[
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              'Uploading Ad...',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: _uploadProgress.clamp(0.0, 1.0),
                                minHeight: 8,
                                valueColor: const AlwaysStoppedAnimation(
                                  Color(0xFFFF6B35),
                                ),
                                backgroundColor: const Color(0xFFF0F0F0),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${(_uploadProgress * 100).clamp(0.0, 100.0).toStringAsFixed(1)}% complete',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  if (_successMessage != null && !_isSubmitting) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: const Color(0xFFE8F5E8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFF4CAF50),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _successMessage!,
                                style: const TextStyle(
                                  color: Color(0xFF2E7D32),
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitAd,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      elevation: 6,
                      shadowColor: const Color(0xFFFF6B35).withOpacity(0.4),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Create Business Ad'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
