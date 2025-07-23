import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/business_ad.dart';
import '../services/api_service.dart';
import '../widgets/ad_card.dart';
import 'add_business_screen.dart';

class BusinessHomeScreen extends StatefulWidget {
  const BusinessHomeScreen({super.key});

  @override
  State<BusinessHomeScreen> createState() => _BusinessHomeScreenState();
}

class _BusinessHomeScreenState extends State<BusinessHomeScreen> {
  late Future<List<BusinessAd>> _featuredAdsFuture;
  late Future<List<BusinessAd>> _allAdsFuture;
  final RefreshController _refreshController = RefreshController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final apiService = Provider.of<ApiService>(context, listen: false);
    setState(() {
      _featuredAdsFuture = apiService.getFeaturedAds();
      _allAdsFuture = apiService.getBusinessAds();
    });
  }

  Future<void> _handleRefresh() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await Future.wait([
        apiService.getFeaturedAds(),
        apiService.getBusinessAds(),
      ]);
      _loadData();
    } finally {
      _refreshController.refreshCompleted();
    }
  }

  void _showDeleteConfirmationDialog(BusinessAd ad) {
    print('📱 Showing delete dialog for ad: ${ad.title} (ID: ${ad.id})');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red[700]),
              const SizedBox(width: 8),
              const Text('Delete Post'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to delete "${ad.title}"?'),
              const SizedBox(height: 8),
              const Text(
                'This action cannot be undone.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                'Ad ID: ${ad.id}',
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                print('❌ Delete cancelled by user');
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                print('🗑️ Delete confirmed by user for ad: ${ad.id}');
                Navigator.of(context).pop(); // Close dialog
                await _deleteAd(ad);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAd(BusinessAd ad) async {
    print('🗑️ Starting delete process for ad: ${ad.id}');

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
        ),
      ),
    );

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      print('🌐 Calling API service to delete ad: ${ad.id}');

      final success = await apiService.deleteBusinessAd(ad.id);
      print('📡 Delete API response: $success');

      // Close loading dialog
      Navigator.of(context).pop();

      if (success) {
        print('✅ Delete successful, showing success message');

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Post "${ad.title}" deleted successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Reload data
        print('🔄 Reloading data after successful delete');
        _loadData();
      } else {
        print('❌ Delete failed according to API service');

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete "${ad.title}"'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('💥 Exception during delete: $e');

      // Close loading dialog
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting post: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF6B35),
        elevation: 0,
        title: const Text(
          'Business Ads',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: const Color(0xFFFF6B35),
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Featured Ads Section Header
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Featured Ads',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF6B35),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Featured Ads Section
            SliverToBoxAdapter(
              child: SizedBox(
                height: 220,
                child: FutureBuilder<List<BusinessAd>>(
                  future: _featuredAdsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFFF6B35),
                          ),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return _buildErrorWidget('Failed to load featured ads');
                    }
                    if (snapshot.data!.isEmpty) {
                      return _buildEmptyWidget('No featured ads available');
                    }
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (ctx, index) => Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: SizedBox(
                          width: 300,
                          child: _buildStyledAdCard(
                            snapshot.data![index],
                            isFeatured: true,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // All Ads Section Header
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'All Business Ads',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF6B35),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // All Ads Grid
            FutureBuilder<List<BusinessAd>>(
              future: _allAdsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFFF6B35),
                        ),
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    child: _buildErrorWidget('Failed to load ads'),
                  );
                }
                if (snapshot.data!.isEmpty) {
                  return SliverFillRemaining(
                    child: _buildEmptyWidget('No ads available yet'),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildFullWidthAdCard(snapshot.data![index]),
                      ),
                      childCount: snapshot.data!.length,
                    ),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "add",
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (ctx) => const AddBusinessScreen()),
          );
          if (result == true) _loadData();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStyledAdCard(BusinessAd ad, {bool isFeatured = false}) {
    return AdCard(
      ad: ad,
      isFeatured: isFeatured,
      onLongPress: () => _showDeleteConfirmationDialog(ad),
    );
  }

  Widget _buildFullWidthAdCard(BusinessAd ad) {
    return AdCard(
      ad: ad,
      isFeatured: false,
      onLongPress: () => _showDeleteConfirmationDialog(ad),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFFF6B35)),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: const Color(0xFFFF6B35)),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.hourglass_empty, size: 48, color: Color(0xFFFF6B35)),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: const Color(0xFFFF6B35)),
          ),
        ],
      ),
    );
  }
}

// Dummy RefreshController class since we're not using pull_to_refresh package
class RefreshController {
  void refreshCompleted() {}
}

// Image Detail Screen Widget
class ImageDetailScreen extends StatefulWidget {
  final BusinessAd ad;
  final List<BusinessAd> allAds;

  const ImageDetailScreen({super.key, required this.ad, required this.allAds});

  @override
  State<ImageDetailScreen> createState() => _ImageDetailScreenState();
}

class _ImageDetailScreenState extends State<ImageDetailScreen> {
  late PageController _pageController;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: GestureDetector(
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
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFFF6B35),
                backgroundImage: widget.ad.userProfileImage != null
                    ? NetworkImage(widget.ad.userProfileImage!)
                    : null,
                child: widget.ad.userProfileImage == null
                    ? Text(
                        widget.ad.userName.isNotEmpty
                            ? widget.ad.userName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                widget.ad.userName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (widget.ad.imageUrls.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_currentImageIndex + 1}/${widget.ad.imageUrls.length}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: Consumer<ApiService>(
        builder: (context, apiService, child) {
          // If allAds is provided (from user profile), use it directly
          if (widget.allAds.isNotEmpty) {
            final reorderedAds = [
              widget.ad,
              ...widget.allAds.where((ad) => ad.id != widget.ad.id),
            ];

            return PageView.builder(
              scrollDirection: Axis.vertical,
              itemCount: reorderedAds.length,
              itemBuilder: (context, pageIndex) {
                final currentAd = reorderedAds[pageIndex];

                return Column(
                  children: [
                    // Image section with overlay
                    Expanded(
                      child: Stack(
                        children: [
                          // Image PageView for multiple images
                          PageView.builder(
                            onPageChanged: (imageIndex) {
                              if (pageIndex == 0) {
                                // Only update for current ad
                                setState(() {
                                  _currentImageIndex = imageIndex;
                                });
                              }
                            },
                            itemCount: currentAd.imageUrls.length,
                            itemBuilder: (context, imageIndex) {
                              return InteractiveViewer(
                                child: Container(
                                  width: double.infinity,
                                  height: double.infinity,
                                  color: Colors.black,
                                  child: Center(
                                    child: Image.network(
                                      currentAd.imageUrls[imageIndex],
                                      fit: BoxFit.contain,
                                      width: double.infinity,
                                      height: double.infinity,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                color: Colors.grey[800],
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.business,
                                                    color: Colors.white,
                                                    size: 50,
                                                  ),
                                                ),
                                              ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          // Description overlay
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 40,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    currentAd.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    currentAd.description,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 18,
                                      height: 1.5,
                                      letterSpacing: 0.3,
                                    ),
                                    maxLines: 8,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Page indicators for images
                          if (currentAd.imageUrls.length > 1)
                            Positioned(
                              bottom: 20,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  currentAd.imageUrls.length,
                                  (index) => Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          index ==
                                              (pageIndex == 0
                                                  ? _currentImageIndex
                                                  : 0)
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.5),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // Scroll indicator
                          if (pageIndex < reorderedAds.length - 1)
                            Positioned(
                              bottom: 50,
                              left: 0,
                              right: 0,
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Colors.white.withOpacity(0.8),
                                    size: 30,
                                  ),
                                  Text(
                                    'Swipe up for more',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          }

          // Otherwise, fetch from API and filter by user
          return FutureBuilder<List<BusinessAd>>(
            future: apiService.getBusinessAds(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFFF6B35),
                    ),
                  ),
                );
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return const Center(
                  child: Text(
                    'No posts available',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }

              // Get ads from the same user only
              final allBusinessAds = snapshot.data!;
              final userAds = allBusinessAds
                  .where((ad) => ad.userId == widget.ad.userId)
                  .toList();
              final reorderedAds = [
                widget.ad,
                ...userAds.where((ad) => ad.id != widget.ad.id),
              ];

              return PageView.builder(
                scrollDirection: Axis.vertical,
                itemCount: reorderedAds.length,
                itemBuilder: (context, pageIndex) {
                  final currentAd = reorderedAds[pageIndex];

                  return Column(
                    children: [
                      // Image section with overlay
                      Expanded(
                        child: Stack(
                          children: [
                            // Image PageView for multiple images
                            PageView.builder(
                              onPageChanged: (imageIndex) {
                                if (pageIndex == 0) {
                                  // Only update for current ad
                                  setState(() {
                                    _currentImageIndex = imageIndex;
                                  });
                                }
                              },
                              itemCount: currentAd.imageUrls.length,
                              itemBuilder: (context, imageIndex) {
                                return InteractiveViewer(
                                  child: Container(
                                    width: double.infinity,
                                    height: double.infinity,
                                    color: Colors.black,
                                    child: Center(
                                      child: Image.network(
                                        currentAd.imageUrls[imageIndex],
                                        fit: BoxFit.contain,
                                        width: double.infinity,
                                        height: double.infinity,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Container(
                                                  color: Colors.grey[800],
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.business,
                                                      color: Colors.white,
                                                      size: 50,
                                                    ),
                                                  ),
                                                ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            // Description overlay
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 40,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      currentAd.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      currentAd.description,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 18,
                                        height: 1.5,
                                        letterSpacing: 0.3,
                                      ),
                                      maxLines: 8,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Page indicators for images
                            if (currentAd.imageUrls.length > 1)
                              Positioned(
                                bottom: 20,
                                left: 0,
                                right: 0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    currentAd.imageUrls.length,
                                    (index) => Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color:
                                            index ==
                                                (pageIndex == 0
                                                    ? _currentImageIndex
                                                    : 0)
                                            ? Colors.white
                                            : Colors.white.withOpacity(0.5),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            // Scroll indicator
                            if (pageIndex < reorderedAds.length - 1)
                              Positioned(
                                bottom: 50,
                                left: 0,
                                right: 0,
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.keyboard_arrow_down,
                                      color: Colors.white.withOpacity(0.8),
                                      size: 30,
                                    ),
                                    Text(
                                      'Swipe up for more',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// User Profile Screen Widget
class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late Future<List<BusinessAd>> _userAdsFuture;

  @override
  void initState() {
    super.initState();
    _loadUserAds();
  }

  void _loadUserAds() {
    final apiService = Provider.of<ApiService>(context, listen: false);
    setState(() {
      _userAdsFuture = apiService.getBusinessAds().then(
        (ads) => ads.where((ad) => ad.userId == widget.userId).toList(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF6B35),
        elevation: 0,
        title: Text(
          widget.userName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<List<BusinessAd>>(
        future: _userAdsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Color(0xFFFF6B35),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load user posts',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFFFF6B35),
                    ),
                  ),
                ],
              ),
            );
          }

          final userAds = snapshot.data ?? [];

          if (userAds.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.photo_library_outlined,
                    size: 48,
                    color: Color(0xFFFF6B35),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No posts yet',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFFFF6B35),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.userName} hasn\'t posted any ads yet',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // User info header
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: const Color(0xFFFF6B35),
                      child: Text(
                        widget.userName.isNotEmpty
                            ? widget.userName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.userName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${userAds.length} ${userAds.length == 1 ? 'post' : 'posts'}',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Posts grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.8,
                        ),
                    itemCount: userAds.length,
                    itemBuilder: (context, index) {
                      final ad = userAds[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  ImageDetailScreen(ad: ad, allAds: userAds),
                            ),
                          );
                        },
                        onLongPress: () {
                          print(
                            '🔍 Long press detected on ad: ${ad.title} (ID: ${ad.id})',
                          );
                          // Add haptic feedback to confirm long press is working
                          HapticFeedback.mediumImpact();
                          _showDeleteConfirmationDialog(ad);
                        },
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Image
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ad.imageUrls.isNotEmpty
                                        ? Image.network(
                                            ad.imageUrls.first,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Container(
                                                      color: Colors.grey[200],
                                                      child: const Center(
                                                        child: Icon(
                                                          Icons.business,
                                                          size: 40,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    ),
                                          )
                                        : Container(
                                            color: Colors.grey[200],
                                            child: const Center(
                                              child: Icon(
                                                Icons.business,
                                                size: 40,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              // Title
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  ad.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFF6B35),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteConfirmationDialog(BusinessAd ad) {
    print('📱 Showing delete dialog for ad: ${ad.title} (ID: ${ad.id})');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red[700]),
              const SizedBox(width: 8),
              const Text('Delete Post'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to delete "${ad.title}"?'),
              const SizedBox(height: 8),
              const Text(
                'This action cannot be undone.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                'Ad ID: ${ad.id}',
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                print('❌ Delete cancelled by user');
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                print('🗑️ Delete confirmed by user for ad: ${ad.id}');
                Navigator.of(context).pop(); // Close dialog
                await _deleteAd(ad);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAd(BusinessAd ad) async {
    print('🗑️ Starting delete process for ad: ${ad.id}');

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
        ),
      ),
    );

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      print('🌐 Calling API service to delete ad: ${ad.id}');

      final success = await apiService.deleteBusinessAd(ad.id);
      print('📡 Delete API response: $success');

      // Close loading dialog
      Navigator.of(context).pop();

      if (success) {
        print('✅ Delete successful, showing success message');

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Post "${ad.title}" deleted successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Reload user ads
        print('🔄 Reloading user ads after successful delete');
        _loadUserAds();
      } else {
        print('❌ Delete failed according to API service');

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete "${ad.title}"'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('💥 Exception during delete: $e');

      // Close loading dialog
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting post: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
