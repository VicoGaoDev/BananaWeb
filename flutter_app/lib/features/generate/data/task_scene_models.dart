class SceneOptionItem {
  const SceneOptionItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  factory SceneOptionItem.fromJson(Map<String, dynamic> json) {
    return SceneOptionItem(
      label: json['label'] as String? ?? '',
      value: json['value'] as String? ?? '',
    );
  }
}

class TaskSceneConfig {
  const TaskSceneConfig({
    required this.sceneKey,
    required this.sceneType,
    required this.sceneLabel,
    required this.sceneDescription,
    required this.displayName,
    required this.subtitle,
    required this.sortOrder,
    required this.hideAspectRatio,
    required this.hideResolution,
    required this.hideCustomSize,
    required this.creditCost,
    required this.aspectRatioOptions,
    required this.imageSizeOptions,
    required this.customSizeOptions,
  });

  final String sceneKey;
  final String sceneType;
  final String sceneLabel;
  final String sceneDescription;
  final String displayName;
  final String subtitle;
  final int sortOrder;
  final bool hideAspectRatio;
  final bool hideResolution;
  final bool hideCustomSize;
  final int creditCost;
  final List<SceneOptionItem> aspectRatioOptions;
  final List<SceneOptionItem> imageSizeOptions;
  final List<SceneOptionItem> customSizeOptions;

  factory TaskSceneConfig.fromJson(Map<String, dynamic> json) {
    return TaskSceneConfig(
      sceneKey: json['scene_key'] as String? ?? '',
      sceneType: json['scene_type'] as String? ?? 'generate',
      sceneLabel: json['scene_label'] as String? ?? '',
      sceneDescription: json['scene_description'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      sortOrder: json['sort_order'] as int? ?? 0,
      hideAspectRatio: json['hide_aspect_ratio'] as bool? ?? false,
      hideResolution: json['hide_resolution'] as bool? ?? false,
      hideCustomSize: json['hide_custom_size'] as bool? ?? false,
      creditCost: json['credit_cost'] as int? ?? 0,
      aspectRatioOptions: (json['aspect_ratio_options'] as List<dynamic>? ?? [])
          .map((item) => SceneOptionItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      imageSizeOptions: (json['image_size_options'] as List<dynamic>? ?? [])
          .map((item) => SceneOptionItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      customSizeOptions: (json['custom_size_options'] as List<dynamic>? ?? [])
          .map((item) => SceneOptionItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
