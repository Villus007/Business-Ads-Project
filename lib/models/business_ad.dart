class BusinessAd {
  final String id;
  final String title;
  final String description;
  final List<String> imageUrls;

  BusinessAd({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrls,
  });

  // Add fromJson if needed
  factory BusinessAd.fromJson(Map<String, dynamic> json) {
    return BusinessAd(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      imageUrls: List<String>.from(json['imageUrls']),
    );
  }

  // Add toJson if needed
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'imageUrls': imageUrls,
  };
}
