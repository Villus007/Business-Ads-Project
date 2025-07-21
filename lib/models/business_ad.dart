class BusinessAd {
  final String id;
  final String title;
  final String description;
  final List<String> imageUrls;
  final String userName;
  final String userId;
  final String? userProfileImage;
  final DateTime createdAt;

  BusinessAd({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrls,
    required this.userName,
    required this.userId,
    this.userProfileImage,
    required this.createdAt,
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
  };
}
