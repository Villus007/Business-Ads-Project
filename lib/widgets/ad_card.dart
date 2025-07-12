import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import '../models/business_ad.dart';
import '../screens/ad_detail_screen.dart'; // Add this import

class AdCard extends StatelessWidget {
  final BusinessAd ad;
  final bool isFeatured;

  const AdCard({super.key, required this.ad, this.isFeatured = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToDetail(context),
        child: SizedBox(
          height: isFeatured ? 220 : 180, // Fixed height to prevent overflow
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Section
              if (ad.imageUrls.isNotEmpty)
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: _buildImageWidget(ad.imageUrls.first),
                  ),
                ),

              // Content Section with fixed height
              Container(
                height: isFeatured ? 65 : 50, // Fixed height for content
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      ad.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: isFeatured ? 12 : 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 2),

                    // Description
                    Expanded(
                      child: Text(
                        ad.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: isFeatured ? 10 : 9,
                          color: Colors.grey[600],
                        ),
                        maxLines: isFeatured ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Featured badge
                    if (isFeatured)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 10),
                          const SizedBox(width: 2),
                          Text(
                            'Featured',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.amber[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

  void _navigateToDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AdDetailScreen(ad: ad)),
    );
  }
}
