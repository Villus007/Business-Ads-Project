import 'package:flutter/material.dart';
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
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.9,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildStyledAdCard(snapshot.data![index]),
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
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isFeatured
              ? const LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFFF8A65)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isFeatured ? null : Colors.white,
          border: isFeatured
              ? null
              : Border.all(color: const Color(0xFFFF6B35).withOpacity(0.3)),
        ),
        child: AdCard(ad: ad, isFeatured: isFeatured),
      ),
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
