import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'dart:math' as math;
import '../models/business_ad.dart';
import '../services/api_service.dart';

class AddBusinessScreen extends StatefulWidget {
  const AddBusinessScreen({super.key});

  @override
  State<AddBusinessScreen> createState() => _AddBusinessScreenState();
}

class _AddBusinessScreenState extends State<AddBusinessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<XFile> _selectedImages = [];
  bool _isSubmitting = false;
  double _uploadProgress = 0;
  String? _errorMessage;
  String? _successMessage;

  // Image optimization settings
  static const int _maxImageWidth = 1920;
  static const int _maxImageHeight = 1080;
  static const int _imageQuality = 85;
  static const int _maxFileSize = 5 * 1024 * 1024; // 5MB

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      setState(() {
        _errorMessage = null;
        _successMessage = null;
      });

      final images = await _picker.pickMultiImage(
        maxWidth: _maxImageWidth.toDouble(),
        maxHeight: _maxImageHeight.toDouble(),
        imageQuality: _imageQuality,
      );

      if (images.isNotEmpty) {
        // Validate image count
        if (images.length > 10) {
          setState(() => _errorMessage = 'Maximum 10 images allowed');
          _showErrorSnackbar(_errorMessage!);
          return;
        }

        // Validate file sizes
        for (final image in images) {
          final bytes = await image.readAsBytes();
          if (bytes.length > _maxFileSize) {
            setState(
              () => _errorMessage =
                  'Image ${image.name} is too large. Maximum size is 5MB',
            );
            _showErrorSnackbar(_errorMessage!);
            return;
          }
        }

        setState(() {
          _selectedImages = images;
          _successMessage = '${images.length} image(s) selected successfully';
        });

        _showSuccessSnackbar(_successMessage!);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to pick images: ${e.toString()}');
      _showErrorSnackbar(_errorMessage!);
    }
  }

  Future<void> _submitAd() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImages.isEmpty) {
      setState(() => _errorMessage = 'Please select at least one image');
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
      final int totalImages = _selectedImages.length;

      // Upload images with progress tracking
      for (int i = 0; i < totalImages; i++) {
        final image = _selectedImages[i];

        // Update overall progress
        final baseProgress = i / totalImages;
        setState(() {
          _uploadProgress = baseProgress;
        });

        // Read and optimize image
        Uint8List bytes = await image.readAsBytes();

        // Compress image for better performance
        if (!kIsWeb) {
          bytes = await _compressImage(bytes, image.name);
        }

        // Upload with individual progress tracking
        final url = await apiService.uploadImageBytes(
          bytes,
          filename: _generateUniqueFilename(image.name),
          onProgress: (progress) {
            setState(() {
              _uploadProgress = baseProgress + (progress / totalImages);
            });
          },
        );

        imageUrls.add(url);
        print('✅ Uploaded image ${i + 1}/$totalImages: ${image.name}');
      }

      // Submit ad data
      setState(() => _uploadProgress = 0.95);

      final ad = BusinessAd(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        imageUrls: imageUrls,
      );

      await apiService.submitAd(ad);

      setState(() {
        _uploadProgress = 1.0;
        _successMessage = 'Ad submitted successfully!';
      });

      // Show success message
      _showSuccessSnackbar(_successMessage!);

      // Wait briefly then navigate back
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Submission failed: ${e.toString()}';
        _isSubmitting = false;
        _uploadProgress = 0;
      });
      _showErrorSnackbar(_errorMessage!);
    }
  }

  /// Compress image for optimal performance
  Future<Uint8List> _compressImage(Uint8List bytes, String filename) async {
    try {
      // Determine target quality based on file size
      int targetQuality = _imageQuality;
      if (bytes.length > 2 * 1024 * 1024) {
        // > 2MB
        targetQuality = 70;
      } else if (bytes.length > 1 * 1024 * 1024) {
        // > 1MB
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

  /// Generate unique filename to prevent conflicts
  String _generateUniqueFilename(String originalFilename) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = math.Random().nextInt(1000);
    final extension = originalFilename.split('.').last;
    return 'ad_${timestamp}_$random.$extension';
  }

  /// Format bytes for display
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
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.error, color: Colors.red),
                  ),
                ),
                // Image info overlay
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
              child: CircularProgressIndicator(strokeWidth: 2),
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
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Business Ad'),
        centerTitle: true,
        actions: [
          if (_isSubmitting)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
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
                // Form fields
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Business Title *',
                    hintText: 'Enter your business name',
                    border: OutlineInputBorder(),
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

                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: 'Business Description *',
                    hintText: 'Describe your business and services',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                    alignLabelWithHint: true,
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

                // Image selection
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Business Images *',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select up to 10 images (max 5MB each)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),

                        OutlinedButton.icon(
                          icon: const Icon(Icons.add_photo_alternate),
                          label: Text(
                            _selectedImages.isEmpty
                                ? 'Select Images'
                                : 'Change Images',
                          ),
                          onPressed: _isSubmitting ? null : _pickImages,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),

                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Selected: ${_selectedImages.length} image(s)',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (_selectedImages.isNotEmpty)
                              TextButton.icon(
                                onPressed: _isSubmitting
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedImages.clear();
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

                // Image preview grid
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

                // Upload progress
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
                          LinearProgressIndicator(
                            value: _uploadProgress,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(_uploadProgress * 100).toStringAsFixed(1)}% complete',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Status messages
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
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _successMessage!,
                              style: const TextStyle(color: Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Submit button
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitAd,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
                      : const Text(
                          'Submit Business Ad',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
