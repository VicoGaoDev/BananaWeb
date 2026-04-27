class HistoryImage {
  const HistoryImage({
    required this.id,
    required this.imageUrl,
    required this.previewUrl,
    required this.thumbUrl,
    required this.status,
  });

  final int id;
  final String imageUrl;
  final String previewUrl;
  final String thumbUrl;
  final String status;

  factory HistoryImage.fromJson(Map<String, dynamic> json) {
    return HistoryImage(
      id: json['id'] as int? ?? 0,
      imageUrl: json['image_url'] as String? ?? '',
      previewUrl: json['preview_url'] as String? ?? '',
      thumbUrl: json['thumb_url'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}

class UserHistoryCardItem {
  const UserHistoryCardItem({
    required this.taskId,
    required this.imageId,
    required this.prompt,
    required this.model,
    required this.status,
    required this.size,
    required this.resolution,
    required this.creditCost,
    required this.createdAt,
    required this.imageUrl,
    required this.previewUrl,
    required this.images,
  });

  final int taskId;
  final int imageId;
  final String prompt;
  final String model;
  final String status;
  final String size;
  final String resolution;
  final int creditCost;
  final String createdAt;
  final String imageUrl;
  final String previewUrl;
  final List<HistoryImage> images;

  factory UserHistoryCardItem.fromJson(Map<String, dynamic> json) {
    return UserHistoryCardItem(
      taskId: json['task_id'] as int? ?? 0,
      imageId: json['image_id'] as int? ?? 0,
      prompt: json['prompt'] as String? ?? '',
      model: json['model'] as String? ?? '',
      status: json['status'] as String? ?? '',
      size: json['size'] as String? ?? '',
      resolution: json['resolution'] as String? ?? '',
      creditCost: json['credit_cost'] as int? ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      previewUrl: json['preview_url'] as String? ?? '',
      images: (json['images'] as List<dynamic>? ?? [])
          .map((item) => HistoryImage.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class UserHistoryResponse {
  const UserHistoryResponse({
    required this.total,
    required this.items,
  });

  final int total;
  final List<UserHistoryCardItem> items;

  factory UserHistoryResponse.fromJson(Map<String, dynamic> json) {
    return UserHistoryResponse(
      total: json['total'] as int? ?? 0,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => UserHistoryCardItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
