import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:convert';
import 'dart:async';
import '../models/business_ad.dart';

class AdDetailScreen extends StatefulWidget {
  final BusinessAd ad;

  const AdDetailScreen({super.key, required this.ad});

  @override
  State<AdDetailScreen> createState() => _AdDetailScreenState();
}

class _AdDetailScreenState extends State<AdDetailScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  
  // Video player controllers
  Map<String, VideoPlayerController> _videoControllers = {};
  Map<String, ChewieController> _chewieControllers = {};
  Map<String, bool> _videoInitialized = {};
  
  // Track if any video is currently playing
  bool _isVideoPlaying = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initializeVideoControllers();
  }

  @override
  void dispose() {
    _pageController.dispose();
    
    // Dispose video controllers
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    for (var controller in _chewieControllers.values) {
      controller.dispose();
    }
    
    super.dispose();
  }

  void _initializeVideoControllers() async {
    print('🎥 Initializing videos for ad: ${widget.ad.id}');
    print('🎥 Video URLs: ${widget.ad.videoUrls}');
    
    for (int i = 0; i < widget.ad.videoUrls.length; i++) {
      final videoUrl = widget.ad.videoUrls[i];
      final controllerKey = '${widget.ad.id}_video_$i';
      
      try {
        print('🎥 Initializing video $i: $videoUrl');
        
        final videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
        await videoController.initialize();
        
        print('✅ Video $i initialized successfully: $videoUrl');
        
        if (mounted) {
          setState(() {
            _videoControllers[controllerKey] = videoController;
            _videoInitialized[controllerKey] = true;
            _chewieControllers[controllerKey] = ChewieController(
              videoPlayerController: videoController,
              autoPlay: false,
              looping: true,
              aspectRatio: videoController.value.aspectRatio,
              allowFullScreen: true,
              allowMuting: true,
              showControls: true,
              placeholder: Container(
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            );
          });
        }
      } catch (error) {
        print('❌ Error initializing video controller for $videoUrl: $error');
        if (mounted) {
          setState(() {
            _videoInitialized[controllerKey] = false;
          });
        }
      }
    }
  }

  // Get combined media list (images + videos)
  List<Map<String, dynamic>> get _combinedMedia {
    List<Map<String, dynamic>> media = [];
    
    print('🖼️ Processing images: ${widget.ad.imageUrls.length}');
    print('🎥 Processing videos: ${widget.ad.videoUrls.length}');
    
    // Add images
    for (int i = 0; i < widget.ad.imageUrls.length; i++) {
      media.add({
        'type': 'image',
        'url': widget.ad.imageUrls[i],
        'index': i,
      });
      print('🖼️ Added image $i: ${widget.ad.imageUrls[i]}');
    }
    
    // Add videos
    for (int i = 0; i < widget.ad.videoUrls.length; i++) {
      media.add({
        'type': 'video',
        'url': widget.ad.videoUrls[i],
        'index': i,
      });
      print('🎥 Added video $i: ${widget.ad.videoUrls[i]}');
    }
    
    print('📊 Total combined media: ${media.length}');
    return media;
  }

  @override
  Widget build(BuildContext context) {
    final combinedMedia = _combinedMedia;
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.orange,
              child: Text(
                widget.ad.userName.isNotEmpty ? widget.ad.userName[0].toUpperCase() : 'U',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Text(widget.ad.userName),
          ],
        ),
        actions: [
          if (combinedMedia.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  '${_currentIndex + 1}/${combinedMedia.length}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Media Carousel
          if (combinedMedia.isNotEmpty)
            SizedBox(
              height: 400,
              child: PageView.builder(
                controller: _pageController,
                itemCount: combinedMedia.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                  
                  // Pause all videos when page changes
                  for (var controller in _videoControllers.values) {
                    if (controller.value.isPlaying) {
                      controller.pause();
                    }
                  }
                  _isVideoPlaying = false;
                },
                itemBuilder: (ctx, index) {
                  final media = combinedMedia[index];
                  if (media['type'] == 'image') {
                    return _buildImageWidget(media['url']);
                  } else {
                    return _buildVideoWidget(media['url'], '${widget.ad.id}_video_${media['index']}');
                  }
                },
              ),
            ),
          
          // Media Indicators
          if (combinedMedia.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(combinedMedia.length, (index) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == index ? Colors.blue : Colors.grey[300],
                    ),
                  );
                }),
              ),
            ),
          
          // Details Section
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.ad.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.ad.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  
                  // Media Info
                  if (combinedMedia.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            combinedMedia[_currentIndex]['type'] == 'video' 
                              ? Icons.videocam 
                              : Icons.image,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            combinedMedia[_currentIndex]['type'] == 'video' 
                              ? 'Video ${_currentIndex + 1}' 
                              : 'Image ${_currentIndex + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          Text(
                            '${_currentIndex + 1} of ${combinedMedia.length}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Contact Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _contactBusiness(widget.ad),
                      icon: const Icon(Icons.phone),
                      label: const Text('Contact Business'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWidget(String imageUrl) {
    // Check if it's a data URL (for local development)
    if (imageUrl.startsWith('data:image/')) {
      final base64String = imageUrl.split(',')[1];
      final bytes = base64Decode(base64String);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Container(color: Colors.grey[200], child: const Icon(Icons.error)),
      );
    }

    // Use CachedNetworkImage for regular URLs
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) =>
          const Center(child: CircularProgressIndicator()),
      errorWidget: (context, url, error) => const Icon(Icons.error),
    );
  }

  Widget _buildVideoWidget(String videoUrl, String controllerKey) {
    print('🎬 Building video widget for: $videoUrl with key: $controllerKey');
    print('🎬 Video initialized: ${_videoInitialized[controllerKey]}');
    print('🎬 Chewie controller exists: ${_chewieControllers.containsKey(controllerKey)}');
    
    // Check if video is initialized
    if (!_videoInitialized.containsKey(controllerKey) || !_videoInitialized[controllerKey]!) {
      print('⏳ Video not yet initialized, showing loading...');
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Loading video...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    final chewieController = _chewieControllers[controllerKey];
    if (chewieController == null) {
      print('❌ Chewie controller is null for key: $controllerKey');
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Colors.white, size: 48),
              SizedBox(height: 16),
              Text(
                'Video failed to load',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    print('✅ Rendering video with Chewie controller');
    return Container(
      color: Colors.black,
      child: Chewie(controller: chewieController),
    );
  }

  void _contactBusiness(BusinessAd ad) {
    // Implement contact logic
    debugPrint('Contacting business: ${ad.title}');
    
    // Show a simple dialog for now
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Business'),
        content: Text('Contact information for ${ad.title}:\n\nPhone: +1 (555) 123-4567\nEmail: contact@${ad.userName.toLowerCase().replaceAll(' ', '')}.com'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
