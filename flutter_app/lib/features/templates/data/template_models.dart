class TemplateTag {
  const TemplateTag({
    required this.id,
    required this.name,
    this.templateCount = 0,
  });

  final int id;
  final String name;
  final int templateCount;

  factory TemplateTag.fromJson(Map<String, dynamic> json) {
    return TemplateTag(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      templateCount: json['template_count'] as int? ?? 0,
    );
  }
}

class CreativeTemplate {
  const CreativeTemplate({
    required this.id,
    required this.prompt,
    required this.model,
    required this.referenceImages,
    required this.numImages,
    required this.size,
    required this.resolution,
    required this.customSize,
    required this.resultImage,
    required this.sortOrder,
    required this.tags,
    required this.createdAt,
    this.referenceImageThumbs = const [],
    this.resultImageThumb = '',
  });

  final int id;
  final String prompt;
  final String model;
  final List<String> referenceImages;
  final List<String> referenceImageThumbs;
  final int numImages;
  final String size;
  final String resolution;
  final String customSize;
  final String resultImage;
  final String resultImageThumb;
  final int sortOrder;
  final List<TemplateTag> tags;
  final String createdAt;

  factory CreativeTemplate.fromJson(Map<String, dynamic> json) {
    return CreativeTemplate(
      id: json['id'] as int? ?? 0,
      prompt: json['prompt'] as String? ?? '',
      model: json['model'] as String? ?? '',
      referenceImages: (json['reference_images'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      referenceImageThumbs:
          (json['reference_image_thumbs'] as List<dynamic>? ?? [])
              .map((item) => item.toString())
              .toList(),
      numImages: json['num_images'] as int? ?? 1,
      size: json['size'] as String? ?? '',
      resolution: json['resolution'] as String? ?? '',
      customSize: json['custom_size'] as String? ?? '',
      resultImage: json['result_image'] as String? ?? '',
      resultImageThumb: json['result_image_thumb'] as String? ?? '',
      sortOrder: json['sort_order'] as int? ?? 0,
      tags: (json['tags'] as List<dynamic>? ?? [])
          .map((item) => TemplateTag.fromJson(item as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class TemplateListResponse {
  const TemplateListResponse({
    required this.total,
    required this.items,
  });

  final int total;
  final List<CreativeTemplate> items;

  factory TemplateListResponse.fromJson(Map<String, dynamic> json) {
    return TemplateListResponse(
      total: json['total'] as int? ?? 0,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => CreativeTemplate.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TemplateHomeData {
  const TemplateHomeData({
    required this.tags,
    required this.templates,
  });

  final List<TemplateTag> tags;
  final List<CreativeTemplate> templates;
}
