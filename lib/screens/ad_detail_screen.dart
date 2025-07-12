import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import '../models/business_ad.dart';

class AdDetailScreen extends StatelessWidget {
  final BusinessAd ad;

  const AdDetailScreen({super.key, required this.ad});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(ad.title)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Image Gallery
            SizedBox(
              height: 300,
              child: PageView.builder(
                itemCount: ad.imageUrls.length,
                itemBuilder: (ctx, index) =>
                    _buildImageWidget(ad.imageUrls[index]),
              ),
            ),
            // Details Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ad.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ad.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  // Contact Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _contactBusiness(ad),
                      icon: const Icon(Icons.phone),
                      label: const Text('Contact Business'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

  void _contactBusiness(BusinessAd ad) {
    // Implement contact logic
    debugPrint('Contacting business: ${ad.title}');
  }
}
