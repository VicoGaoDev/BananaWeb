import 'package:flutter_riverpod/legacy.dart';

import '../../templates/data/template_models.dart';
import '../data/task_scene_models.dart';

class GenerateDraftState {
  const GenerateDraftState({
    this.prompt = '',
    this.model = '',
    this.numImages = 1,
    this.size = '',
    this.resolution = '',
    this.customSize = '',
    this.templateId,
    this.templatePrompt,
  });

  final String prompt;
  final String model;
  final int numImages;
  final String size;
  final String resolution;
  final String customSize;
  final int? templateId;
  final String? templatePrompt;

  GenerateDraftState copyWith({
    String? prompt,
    String? model,
    int? numImages,
    String? size,
    String? resolution,
    String? customSize,
    int? templateId,
    String? templatePrompt,
    bool clearTemplate = false,
  }) {
    return GenerateDraftState(
      prompt: prompt ?? this.prompt,
      model: model ?? this.model,
      numImages: numImages ?? this.numImages,
      size: size ?? this.size,
      resolution: resolution ?? this.resolution,
      customSize: customSize ?? this.customSize,
      templateId: clearTemplate ? null : (templateId ?? this.templateId),
      templatePrompt: clearTemplate ? null : (templatePrompt ?? this.templatePrompt),
    );
  }
}

class GenerateDraftController extends StateNotifier<GenerateDraftState> {
  GenerateDraftController() : super(const GenerateDraftState());

  void applyTemplate(CreativeTemplate template) {
    state = GenerateDraftState(
      prompt: template.prompt,
      model: template.model,
      numImages: template.numImages.clamp(1, 4),
      size: template.size,
      resolution: template.resolution,
      customSize: template.customSize,
      templateId: template.id,
      templatePrompt: template.prompt,
    );
  }

  void updatePrompt(String value) {
    state = state.copyWith(prompt: value);
  }

  void updateModel(String value) {
    state = state.copyWith(model: value);
  }

  void updateNumImages(int value) {
    state = state.copyWith(numImages: value.clamp(1, 4));
  }

  void updateSize(String value) {
    state = state.copyWith(size: value);
  }

  void updateResolution(String value) {
    state = state.copyWith(resolution: value);
  }

  void updateCustomSize(String value) {
    state = state.copyWith(customSize: value);
  }

  void ensureDefaults({
    String? model,
    String? size,
    String? resolution,
  }) {
    state = state.copyWith(
      model: state.model.isEmpty ? (model ?? state.model) : state.model,
      size: state.size.isEmpty ? (size ?? state.size) : state.size,
      resolution: state.resolution.isEmpty ? (resolution ?? state.resolution) : state.resolution,
    );
  }

  /// 按场景的 hide_* 与选项列表同步草稿（与 Web GenerateView 一致）。
  void applySceneDefaults(TaskSceneConfig scene) {
    var model = state.model.isEmpty ? scene.sceneKey : state.model;

    var size = state.size;
    if (scene.hideAspectRatio || scene.aspectRatioOptions.isEmpty) {
      size = '';
    } else if (size.isEmpty ||
        !scene.aspectRatioOptions.any((o) => o.value == size)) {
      size = scene.aspectRatioOptions.first.value;
    }

    var resolution = state.resolution;
    if (scene.hideResolution || scene.imageSizeOptions.isEmpty) {
      resolution = '';
    } else if (resolution.isEmpty ||
        !scene.imageSizeOptions.any((o) => o.value == resolution)) {
      resolution = scene.imageSizeOptions.first.value;
    }

    var customSize = state.customSize;
    if (scene.hideCustomSize || scene.customSizeOptions.isEmpty) {
      customSize = '';
    } else if (customSize.isEmpty ||
        !scene.customSizeOptions.any((o) => o.value == customSize)) {
      customSize = scene.customSizeOptions.first.value;
    }

    state = state.copyWith(
      model: model,
      size: size,
      resolution: resolution,
      customSize: customSize,
    );
  }

  void clearTemplateSource() {
    state = state.copyWith(clearTemplate: true);
  }
}

final generateDraftControllerProvider =
    StateNotifierProvider<GenerateDraftController, GenerateDraftState>((ref) {
  return GenerateDraftController();
});
