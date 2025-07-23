import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:async';
import '../models/business_ad.dart';
import '../screens/business_home_screen.dart'; // For UserProfileScreen and ImageDetailScreen
import '../services/api_service.dart';

class AdCard extends StatefulWidget {
  final BusinessAd ad;
  final bool isFeatured;
  final VoidCallback? onLongPress;

  const AdCard({
    super.key,
    required this.ad,
    this.isFeatured = false,
    this.onLongPress,
  });

  @override
  State<AdCard> createState() => _AdCardState();
}

class _AdCardState extends State<AdCard> with TickerProviderStateMixin {
  bool isLiked = false;
  int likeCount = 0;
  late PageController _pageController;
  int _currentImageIndex = 0;
  Timer? _autoSlideTimer;

  @override
  void initState() {
    super.initState();
    likeCount = widget.ad.likes;
    _pageController = PageController();

    // Start auto slide timer if there are multiple images
    if (widget.ad.imageUrls.length > 1) {
      _startAutoSlideTimer();
    }
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSlideTimer() {
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted && widget.ad.imageUrls.length > 1) {
        final nextIndex = (_currentImageIndex + 1) % widget.ad.imageUrls.length;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _onImageChanged(int index) {
    if (mounted) {
      setState(() {
        _currentImageIndex = index;
      });
    }
  }

  void _toggleLike() {
    setState(() {
      isLiked = !isLiked;
      likeCount = isLiked ? likeCount + 1 : likeCount - 1;
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with user info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // User avatar and info (clickable to profile)
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => UserProfileScreen(
                            userId: widget.ad.userId,
                            userName: widget.ad.userName,
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        // User avatar
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.orange.shade300,
                          child: Text(
                            widget.ad.userName.isNotEmpty
                                ? widget.ad.userName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // User info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.ad.userName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                'Just now',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Like/Heart button (moved from bottom)
                InkWell(
                  onTap: _toggleLike,
                  borderRadius: BorderRadius.circular(20),
                  onLongPress: () {
                    print(
                      '👆 LONG PRESS DETECTED on heart button! Ad: ${widget.ad.title}',
                    );
                    HapticFeedback.mediumImpact();
                    if (widget.onLongPress != null) {
                      widget.onLongPress!();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isLiked ? Colors.red.shade50 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : Colors.grey[600],
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          likeCount.toString(),
                          style: TextStyle(
                            color: isLiked ? Colors.red : Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Image carousel (clickable to full screen)
          if (widget.ad.imageUrls.isNotEmpty)
            GestureDetector(
              onTap: () => _navigateToImageDetail(context),
              onLongPress: () {
                print(
                  '👆 LONG PRESS DETECTED on image! Ad: ${widget.ad.title}',
                );
                HapticFeedback.mediumImpact();
                if (widget.onLongPress != null) {
                  widget.onLongPress!();
                }
              },
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                  bottom: Radius.circular(8),
                ),
                child: SizedBox(
                  height: 280,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      // Image carousel
                      PageView.builder(
                        controller: _pageController,
                        onPageChanged: _onImageChanged,
                        itemCount: widget.ad.imageUrls.length,
                        itemBuilder: (context, index) {
                          return _buildImageWidget(widget.ad.imageUrls[index]);
                        },
                      ),

                      // Image counter overlay (top right)
                      if (widget.ad.imageUrls.length > 1)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_currentImageIndex + 1}/${widget.ad.imageUrls.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                      // Dots indicator (bottom center)
                      if (widget.ad.imageUrls.length > 1)
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              widget.ad.imageUrls.length,
                              (index) => Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentImageIndex == index
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.4),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // Title (clickable for long press)
          GestureDetector(
            onLongPress: () {
              print('👆 LONG PRESS DETECTED on title! Ad: ${widget.ad.title}');
              HapticFeedback.mediumImpact();
              if (widget.onLongPress != null) {
                widget.onLongPress!();
              }
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: Text(
                widget.ad.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
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
      try {
        final base64String = imageUrl.split(',')[1];
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
        );
      } catch (e) {
        return _buildErrorWidget();
      }
    }

    // Use CachedNetworkImage for regular URLs with timeout
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.grey[100],
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, url, error) => _buildErrorWidget(),
      httpHeaders: const {'User-Agent': 'Flutter App'},
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.grey[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported, color: Colors.grey[400], size: 32),
          const SizedBox(height: 4),
          Text(
            'Image not available',
            style: TextStyle(color: Colors.grey[600], fontSize: 10),
          ),
        ],
      ),
    );
  }

  void _navigateToImageDetail(BuildContext context) async {
    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      // Get all ads to find posts from the same user
      final allAds = await apiService.getBusinessAds();
      final userAds = allAds
          .where((ad) => ad.userId == widget.ad.userId)
          .toList();

      // Navigate to full-screen image detail view
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ImageDetailScreen(ad: widget.ad, allAds: userAds),
          ),
        );
      }
    } catch (error) {
      // Fallback: just show this single ad
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ImageDetailScreen(ad: widget.ad, allAds: [widget.ad]),
          ),
        );
      }
    }
  }
}
