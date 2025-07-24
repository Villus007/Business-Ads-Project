class BusinessAd {
  final String id;
  final String title;
  final String description;
  final List<String> imageUrls;
  final List<String> videoUrls; // New field for video URLs
  final String userName;
  final String userId;
  final String? userProfileImage;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String status;
  final int likes;
  final int viewCount;
  final List<dynamic> comments;
  final bool featured;

  BusinessAd({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrls,
    this.videoUrls = const [], // Default to empty list for backward compatibility
    required this.userName,
    required this.userId,
    this.userProfileImage,
    required this.createdAt,
    this.updatedAt,
    this.status = 'active',
    this.likes = 0,
    this.viewCount = 0,
    this.comments = const [],
    this.featured = false,
  });

  // Add fromJson if needed
  factory BusinessAd.fromJson(Map<String, dynamic> json) {
    print('📄 Parsing ad - Raw videoUrls: ${json['videoUrls']}');
    print('📄 Parsing ad - Raw imageUrls: ${json['imageUrls']}');
    
    // Handle videos that might be incorrectly stored in imageUrls
    List<String> imageUrls = List<String>.from(json['imageUrls'] ?? []);
    List<String> videoUrls = List<String>.from(json['videoUrls'] ?? []);
    
    // Check if any URLs in imageUrls are actually videos
    List<String> actualImageUrls = [];
    List<String> actualVideoUrls = [...videoUrls]; // Start with existing videoUrls
    
    for (String url in imageUrls) {
      if (_isVideoUrl(url)) {
        actualVideoUrls.add(url); // Move to videoUrls
        print('📄 Moving video URL from imageUrls to videoUrls: $url');
      } else {
        actualImageUrls.add(url); // Keep in imageUrls
      }
    }
    
    print('📄 Final videoUrls: $actualVideoUrls');
    print('📄 Final imageUrls: $actualImageUrls');
    
    return BusinessAd(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      imageUrls: actualImageUrls,
      videoUrls: actualVideoUrls,
      userName: json['userName'] ?? 'Unknown User',
      userId: json['userId'] ?? '',
      userProfileImage: json['userProfileImage'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      status: json['status'] ?? 'active',
      likes: (json['likes'] ?? 0).toInt(),
      viewCount: (json['viewCount'] ?? 0).toInt(),
      comments: json['comments'] ?? [],
      featured: json['featured'] ?? false,
    );
  }
  
  // Helper method to detect video URLs
  static bool _isVideoUrl(String url) {
    final videoExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.3gp'];
    final lowerUrl = url.toLowerCase();
    return videoExtensions.any((ext) => lowerUrl.endsWith(ext));
  }

  // Add toJson if needed
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'imageUrls': imageUrls,
    'videoUrls': videoUrls, // Include video URLs in JSON
    'userName': userName,
    'userId': userId,
    'userProfileImage': userProfileImage,
    'createdAt': createdAt.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    'status': status,
    'likes': likes,
    'viewCount': viewCount,
    'comments': comments,
    'featured': featured,
  };
}
