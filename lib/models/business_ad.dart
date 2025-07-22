class BusinessAd {
  final String id;
  final String title;
  final String description;
  final List<String> imageUrls;
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
    return BusinessAd(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      imageUrls: List<String>.from(json['imageUrls']),
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

  // Add toJson if needed
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'imageUrls': imageUrls,
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
