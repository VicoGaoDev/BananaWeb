import 'package:flutter_riverpod/legacy.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;

import '../../../core/network/app_exception.dart';
import '../data/upload_models.dart';
import '../data/upload_repository.dart';

class ReferenceUploadState {
  const ReferenceUploadState({
    this.isUploading = false,
    this.images = const [],
    this.errorMessage,
  });

  final bool isUploading;
  final List<UploadedReferenceImage> images;
  final String? errorMessage;

  ReferenceUploadState copyWith({
    bool? isUploading,
    List<UploadedReferenceImage>? images,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ReferenceUploadState(
      isUploading: isUploading ?? this.isUploading,
      images: images ?? this.images,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ReferenceUploadController extends StateNotifier<ReferenceUploadState> {
  ReferenceUploadController(this.ref) : super(const ReferenceUploadState());

  final Ref ref;
  final ImagePicker _picker = ImagePicker();

  Future<void> pickAndUpload() async {
    state = state.copyWith(isUploading: true, clearError: true);

    try {
      final files = await _picker.pickMultiImage(limit: 3);
      if (files.isEmpty) {
        state = state.copyWith(isUploading: false);
        return;
      }

      final uploaded = <UploadedReferenceImage>[...state.images];
      for (final file in files) {
        final result = await ref.read(uploadRepositoryProvider).uploadReferenceImage(file);
        uploaded.add(result);
      }

      state = state.copyWith(
        isUploading: false,
        images: uploaded,
      );
    } on AppException catch (error) {
      state = state.copyWith(
        isUploading: false,
        errorMessage: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        isUploading: false,
        errorMessage: '参考图上传失败，请稍后重试。',
      );
    }
  }

  void removeAt(int index) {
    final nextImages = [...state.images]..removeAt(index);
    state = state.copyWith(images: nextImages, clearError: true);
  }

  void clear() {
    state = const ReferenceUploadState();
  }
}

final referenceUploadControllerProvider =
    StateNotifierProvider<ReferenceUploadController, ReferenceUploadState>((ref) {
  return ReferenceUploadController(ref);
});
