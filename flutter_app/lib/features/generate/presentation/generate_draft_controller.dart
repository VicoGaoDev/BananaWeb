import 'package:flutter_riverpod/legacy.dart';

import '../../templates/data/template_models.dart';

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
      numImages: template.numImages,
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
    state = state.copyWith(numImages: value);
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

  void clearTemplateSource() {
    state = state.copyWith(clearTemplate: true);
  }
}

final generateDraftControllerProvider =
    StateNotifierProvider<GenerateDraftController, GenerateDraftState>((ref) {
  return GenerateDraftController();
});
